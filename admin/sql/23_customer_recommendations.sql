begin;
-- Private, bounded per-customer signals. Never expose another person's history.
create table if not exists eventra_feed.customer_service_signals (
 customer_id uuid not null references public.customers(id) on delete cascade,
 service_id uuid not null references public.services(id) on delete cascade,
 viewed_at timestamptz, saved_at timestamptz, updated_at timestamptz not null default now(),
 primary key(customer_id,service_id)
);
alter table eventra_feed.customer_service_signals enable row level security;
revoke all on eventra_feed.customer_service_signals from public,anon,authenticated;
create index if not exists recommendation_signals_recent on eventra_feed.customer_service_signals(customer_id,updated_at desc);
create index if not exists recommendation_bookings on public.bookings(customer_id,created_at desc) include(service_id,status);
create index if not exists recommendation_services_recent on public.services(created_at desc,id) where is_active;
create index if not exists recommendation_services_category on public.services(category_node_id,created_at desc) where is_active;
create index if not exists recommendation_services_event on public.services(event_type_id,created_at desc) where is_active;
create index if not exists recommendation_quality on eventra_feed.service_metrics(completed_count desc,service_id);

create or replace function public.customer_service_signal(p_service_id uuid,p_action text)
returns void language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();
begin
 perform eventra_security.require_actor('customer');
 if p_action is null or p_action not in ('view','save','unsave') then raise exception 'Invalid service signal' using errcode='22023'; end if;
 -- Unsave remains possible after a listing is deactivated.
 if p_action='unsave' then
  update eventra_feed.customer_service_signals set saved_at=null,updated_at=now() where customer_id=actor and service_id=p_service_id;
  return;
 end if;
 if not exists(select 1 from eventra_feed.eligible_services where id=p_service_id) then return; end if;
 insert into eventra_feed.customer_service_signals(customer_id,service_id,viewed_at,saved_at)
 values(actor,p_service_id,case when p_action='view' then now() end,case when p_action='save' then now() end)
 on conflict(customer_id,service_id) do update set
 viewed_at=case when p_action='view' then now() else customer_service_signals.viewed_at end,
 saved_at=case when p_action='save' then now() else customer_service_signals.saved_at end,updated_at=now()
 where (p_action='view' and (customer_service_signals.viewed_at is null or customer_service_signals.viewed_at<now()-interval '10 minutes'))
 or (p_action='save' and customer_service_signals.saved_at is null);
 -- Storage stays bounded even for heavy browsers. No raw click stream or search text.
 delete from eventra_feed.customer_service_signals where customer_id=actor and (updated_at<now()-interval '180 days' or service_id in (
  select service_id from eventra_feed.customer_service_signals where customer_id=actor order by updated_at desc,service_id offset 200));
end $$;
revoke all on function public.customer_service_signal(uuid,text) from public,anon;
grant execute on function public.customer_service_signal(uuid,text) to authenticated;

create or replace function public.customer_recommendations(p_service_id uuid default null,p_offset int default 0,p_limit int default 12)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor uuid; result jsonb;
begin
 if p_offset is null or p_limit is null or p_offset<0 or p_offset>200 or p_limit<1 or p_limit>20 then
  raise exception 'Invalid recommendation page' using errcode='22023';
 end if;
 -- Guests receive public discovery only; suspended/wrong-role accounts cannot read personalization.
 if auth.uid() is not null then perform eventra_security.require_actor('customer'); actor:=auth.uid(); end if;
 if p_service_id is not null and not exists(select 1 from eventra_feed.eligible_services where id=p_service_id) then
  return jsonb_build_object('items','[]'::jsonb,'has_more',false,'next_offset',p_offset,'personalized',false);
 end if;
 with recursive
 anchor as (select e.*,s.pricing_type,s.pricing_unit from eventra_feed.eligible_services e join public.services s on s.id=e.id where e.id=p_service_id),
 anchor_path(id,parent_id,path) as (
  select c.id,c.parent_id,array[c.id] from public.category_nodes c join anchor a on c.id=a.category_node_id
  union all select c.id,c.parent_id,p.path||c.id from public.category_nodes c join anchor_path p on c.id=p.parent_id where not c.id=any(p.path)
 ), signals as (
  select s.category_node_id,s.event_type_id,
   (case when x.saved_at is not null then 4.0 else 1.0 end)*exp(-extract(epoch from(now()-x.updated_at))/2592000.0) weight
  from eventra_feed.customer_service_signals x join public.services s on s.id=x.service_id
  where x.customer_id=actor and x.updated_at>now()-interval '180 days'
  union all
  select s.category_node_id,s.event_type_id,(case when b.status='completed' then 6.0 when b.status='accepted' then 4.0 else 2.0 end)*exp(-extract(epoch from(now()-b.created_at))/5184000.0)
  from (select service_id,status,created_at from public.bookings where customer_id=actor and status in ('pending','accepted','completed') and created_at>now()-interval '180 days' order by created_at desc limit 100) b
  join public.services s on s.id=b.service_id
 ), interests as (
  select category_node_id,sum(weight) weight from signals group by category_node_id order by sum(weight) desc limit 12
 ), interest_path(id,parent_id,weight,path) as (
  select c.id,c.parent_id,i.weight,array[c.id] from interests i join public.category_nodes c on c.id=i.category_node_id
  union all select c.id,c.parent_id,p.weight*0.4,p.path||c.id from interest_path p join public.category_nodes c on c.id=p.parent_id where not c.id=any(p.path)
 ), affinity as (select id,least(10.0,sum(weight)) weight from interest_path group by id),
 events as (select event_type_id,least(10.0,sum(weight)) weight from signals where event_type_id is not null group by event_type_id),
 pool_ids as (
  (select id from eventra_feed.eligible_services order by created_at desc,id limit 400)
  union (select e.id from eventra_feed.service_metrics m join eventra_feed.eligible_services e on e.id=m.service_id order by m.completed_count desc,m.review_count desc,e.id limit 200)
  union (select e.id from eventra_feed.eligible_services e where p_service_id is not null and (e.category_node_id in(select id from anchor_path) or e.category_parent_id in(select id from anchor_path) or e.event_type_id=(select event_type_id from anchor)) order by e.created_at desc,e.id limit 400)
  union (select e.id from eventra_feed.eligible_services e where e.category_node_id in(select id from affinity) or e.category_parent_id in(select id from affinity) or e.event_type_id in(select event_type_id from events) order by e.created_at desc,e.id limit 400)
 ), candidates as (
  select e.*,s.pricing_type,s.pricing_unit,
   coalesce((select weight from affinity where id=e.category_node_id),0)+coalesce((select weight from affinity where id=e.category_parent_id),0)*0.4+coalesce((select weight from events where event_type_id=e.event_type_id),0)*0.5 interest,
   case when e.category_node_id=a.category_node_id then 45 when e.category_parent_id=a.category_parent_id and a.category_parent_id is not null then 25 when e.category_node_id in(select id from anchor_path) or e.category_parent_id in(select id from anchor_path) then 12 else 0 end
    +case when e.event_type_id=a.event_type_id then 20 else 0 end relevance,
   case when s.pricing_type=a.pricing_type and s.pricing_unit is not distinct from a.pricing_unit then 8/(1+abs(e.price-a.price)/greatest(a.price,1)) else 0 end price_match,
   6*(e.rating_sum+20.0)/(e.review_count+5.0)/5 + least(4.0,ln(1+e.completed_count))
    +3*exp(-greatest(0,extract(epoch from(now()-e.created_at)))/2592000.0) quality
  from pool_ids p join eventra_feed.eligible_services e on e.id=p.id join public.services s on s.id=e.id left join anchor a on true
  where e.id is distinct from p_service_id
 ), scored as (
  select c.*,case when p_service_id is not null then relevance+price_match+quality else least(30.0,interest*3)+quality end score,
   case when p_service_id is null and interest=0 then 1 else 0 end lane
  from candidates c
 ), diversified as (
  select s.*,row_number() over(partition by vendor_id order by score desc,id) vendor_position from scored s
 ), ranked as (
  select d.*,row_number() over(partition by lane order by case when p_service_id is not null and relevance>0 then 0 else 1 end,score-12*(vendor_position-1) desc,id) n from diversified d
 ), ordered as (
  select r.*,row_number() over(order by case when p_service_id is null then case when lane=0 then ((n-1)/3)*4+((n-1)%3)+1 else n*4 end else n end,lane,id) seq from ranked r
 ), page as (select * from ordered where seq>p_offset and seq<=p_offset+p_limit+1)
 select jsonb_build_object('items',coalesce(jsonb_agg(jsonb_build_object(
  'id',id,'type','services','name',name,'description',description,'image_url',gallery->>0,'price',price,'pricing_type',pricing_type,'pricing_unit',pricing_unit,
  'rating',case when review_count>0 then round(rating_sum::numeric/review_count,1) end,'review_count',review_count,'completed_count',completed_count,
  'reason',case when p_service_id is not null and relevance>0 then 'Similar service' when p_service_id is not null then 'Discover more' when interest>0 then 'Based on your interests' else 'Discover something new' end,
  'service',jsonb_build_object('id',id,'vendor_id',vendor_id,'business_id',business_id,'category_node_id',category_node_id,'event_type_id',event_type_id,'name',name,'slug',slug,'description',description,'price',price,'pricing_type',pricing_type,'pricing_unit',pricing_unit,'gallery',gallery,'is_active',true,'created_at',created_at,
    'category_nodes',jsonb_build_object('id',category_node_id,'name',category_name,'slug',category_slug,'parent_id',category_parent_id))) order by seq) filter(where seq<=p_offset+p_limit),'[]'::jsonb),
  'has_more',count(*)>p_limit,'next_offset',p_offset+least(count(*),p_limit),'personalized',actor is not null and exists(select 1 from signals)) into result from page;
 return result;
end $$;
revoke all on function public.customer_recommendations(uuid,int,int) from public;
grant execute on function public.customer_recommendations(uuid,int,int) to anon,authenticated;
commit;
