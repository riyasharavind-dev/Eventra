begin;
create schema if not exists eventra_feed;
revoke all on schema eventra_feed from public,anon,authenticated;
create table if not exists public.home_feed_sections (
 id uuid primary key default gen_random_uuid(), title text not null check(length(btrim(title)) between 1 and 100),
 content_type text not null default 'services' check(content_type in ('services','vendors')),
 layout text not null default 'horizontal' check(layout in ('horizontal','grid')),
 selection_mode text not null default 'automatic' check(selection_mode in ('automatic','manual','mixed')),
 rules jsonb not null default '{}', sort_by text not null default 'newest' check(sort_by in ('newest','rating','bookings','nearest','price_low','price_high')),
 item_limit int not null default 8 check(item_limit between 1 and 20), sort_order int not null default 0,
 is_active boolean not null default false, starts_at timestamptz, ends_at timestamptz,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 check(ends_at is null or starts_at is null or ends_at>starts_at)
);
create table if not exists public.home_feed_pinned_items (
 id uuid primary key default gen_random_uuid(), section_id uuid not null references public.home_feed_sections on delete cascade,
 service_id uuid references public.services on delete cascade, vendor_id uuid references public.vendors on delete cascade,
 sort_order int not null default 0, check(num_nonnulls(service_id,vendor_id)=1)
);
create unique index if not exists home_feed_pin_service on public.home_feed_pinned_items(section_id,service_id) where service_id is not null;
create unique index if not exists home_feed_pin_vendor on public.home_feed_pinned_items(section_id,vendor_id) where vendor_id is not null;
create index if not exists home_feed_section_order on public.home_feed_sections(sort_order,id) where is_active;
alter table public.home_feed_sections enable row level security;
alter table public.home_feed_pinned_items enable row level security;
revoke all on public.home_feed_sections,public.home_feed_pinned_items from anon,authenticated;

create or replace function eventra_feed.validate_section() returns trigger language plpgsql set search_path='' as $$
declare k text; v jsonb;
begin
 if jsonb_typeof(new.rules)<>'object' then raise exception 'Feed rules must be an object'; end if;
 for k,v in select * from jsonb_each(new.rules) loop
  if k not in ('category_id','event_type_id','state_id','district_id','subdistrict_id','min_price','max_price','min_rating','min_reviews','verified_only','new_days','radius_km') then raise exception 'Unsupported feed rule: %',k; end if;
  if v='null'::jsonb then raise exception 'Remove empty rules'; end if;
  if k in ('min_price','max_price','min_rating','min_reviews','new_days','radius_km') and (jsonb_typeof(v)<>'number' or (v::text)::numeric<0) then raise exception 'Invalid numeric rule: %',k; end if;
  if k='verified_only' and jsonb_typeof(v)<>'boolean' then raise exception 'Invalid verification rule'; end if;
  if k in ('category_id','event_type_id','state_id','district_id','subdistrict_id') and jsonb_typeof(v)<>'string' then raise exception 'Invalid selection rule: %',k; end if;
 end loop;
 if (new.rules->>'min_rating')::numeric>5 or (new.rules->>'radius_km')::numeric>5000 or (new.rules->>'new_days')::numeric>3650 then raise exception 'Rule outside supported range'; end if;
 if coalesce((new.rules->>'min_price')::numeric,0)>coalesce((new.rules->>'max_price')::numeric,1e20) then raise exception 'Minimum price exceeds maximum'; end if;
 if new.rules ? 'category_id' and not exists(select 1 from public.category_nodes where id=(new.rules->>'category_id')::uuid) then raise exception 'Category not found'; end if;
 if new.rules ? 'event_type_id' and not exists(select 1 from public.event_types where id=(new.rules->>'event_type_id')::uuid and is_active) then raise exception 'Event type not available'; end if;
 for k in select unnest(array['state_id','district_id','subdistrict_id']) loop
  if new.rules ? k and not exists(select 1 from public.administrative_regions where id=new.rules->>k and is_active and level=replace(k,'_id','')) then raise exception 'Region not available: %',k; end if;
 end loop;
 new.updated_at:=now(); return new;
end $$;
drop trigger if exists home_feed_validate on public.home_feed_sections;
create trigger home_feed_validate before insert or update on public.home_feed_sections for each row execute function eventra_feed.validate_section();

-- Cache only review/booking aggregates; eligibility and shop details are always live.
create table if not exists eventra_feed.service_metrics (
 service_id uuid primary key references public.services on delete cascade,
 completed_count bigint not null default 0, review_count bigint not null default 0, rating_sum bigint not null default 0
);
create index if not exists home_feed_completed on public.bookings(service_id) where status='completed';
create index if not exists home_feed_visible_reviews on public.service_reviews(service_id) where moderation_status='visible';
create or replace function eventra_feed.refresh_metrics(p_id uuid) returns void language plpgsql security definer set search_path='' as $$
begin
 perform pg_advisory_xact_lock(hashtextextended(p_id::text,609));
 if exists(select 1 from public.services where id=p_id) then
 insert into eventra_feed.service_metrics(service_id,completed_count,review_count,rating_sum)
 select p_id,(select count(*) from public.bookings where service_id=p_id and status='completed'),count(*),coalesce(sum(rating),0)
 from public.service_reviews where service_id=p_id and moderation_status='visible'
 on conflict(service_id) do update set completed_count=excluded.completed_count,review_count=excluded.review_count,rating_sum=excluded.rating_sum;
 end if;
end $$;
create or replace function eventra_feed.metrics_changed() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_op<>'DELETE' then perform eventra_feed.refresh_metrics(new.service_id); end if;
 if tg_op='DELETE' then perform eventra_feed.refresh_metrics(old.service_id);
 elsif tg_op='UPDATE' and old.service_id is distinct from new.service_id then perform eventra_feed.refresh_metrics(old.service_id); end if;
 return null;
end $$;
drop trigger if exists home_feed_booking_metrics on public.bookings;
create trigger home_feed_booking_metrics after insert or update or delete on public.bookings for each row execute function eventra_feed.metrics_changed();
drop trigger if exists home_feed_review_metrics on public.service_reviews;
create trigger home_feed_review_metrics after insert or update or delete on public.service_reviews for each row execute function eventra_feed.metrics_changed();
select eventra_feed.refresh_metrics(id) from public.services;

create or replace view eventra_feed.eligible_services as
select s.id,s.vendor_id,s.business_id,s.category_node_id,s.event_type_id,s.name,s.description,s.price,s.gallery,s.slug,s.created_at,
 v.name vendor_name,v.about_me,v.profile_image_url,v.created_at vendor_created_at,
 b.name business_name,b.shop_state_id,b.shop_district_id,b.shop_subdistrict_id,b.latitude,b.longitude,b.shop_address,
 c.name category_name,c.parent_id category_parent_id,c.slug category_slug,
 coalesce(m.completed_count,0) completed_count,coalesce(m.review_count,0) review_count,coalesce(m.rating_sum,0) rating_sum,
 exists(select 1 from public.vendor_verifications vv where vv.vendor_id=v.id and vv.status='verified') verified
from public.services s join public.vendors v on v.id=s.vendor_id join auth.users u on u.id=v.id
join public.businesses b on b.id=s.business_id and b.vendor_id=s.vendor_id
join public.category_nodes c on c.id=s.category_node_id
left join eventra_feed.service_metrics m on m.service_id=s.id
where s.is_active and coalesce(s.vendor_enabled,true) and b.is_active and coalesce(b.availability_status,'active')<>'archived'
and u.deleted_at is null and (u.banned_until is null or u.banned_until<now());

create or replace function eventra_feed.items(p_section public.home_feed_sections,p_offset int default 0,p_limit int default 8,p_lat double precision default null,p_lng double precision default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb; r jsonb:=p_section.rules; has_location boolean:=p_lat is not null and p_lng is not null;
begin
 if p_offset<0 or p_offset>10000 or p_limit<1 or p_limit>50 then raise exception 'Invalid pagination'; end if;
 if has_location and (not (p_lat between -90 and 90) or not (p_lng between -180 and 180)) then raise exception 'Invalid coordinates'; end if;
 if (p_section.sort_by='nearest' or r ? 'radius_km') and not has_location then return jsonb_build_object('items','[]'::jsonb,'has_more',false,'requires_location',true); end if;
 with recursive cats(id) as (
  select id from public.category_nodes where id=(r->>'category_id')::uuid
  union select c.id from public.category_nodes c join cats on c.parent_id=cats.id
 ), base as (
  select e.*, case when has_location and latitude between -90 and 90 and longitude between -180 and 180 then
    6371 * 2 * asin(sqrt(least(1.0,power(sin(radians(latitude-p_lat)/2),2)+cos(radians(p_lat))*cos(radians(latitude))*power(sin(radians(longitude-p_lng)/2),2)))) end distance_km
  from eventra_feed.eligible_services e
 ), filtered as (
  select * from base e where
  (not(r ? 'category_id') or category_node_id in(select id from cats)) and
  (not(r ? 'event_type_id') or event_type_id=(r->>'event_type_id')::uuid) and
  (not(r ? 'state_id') or shop_state_id=r->>'state_id') and (not(r ? 'district_id') or shop_district_id=r->>'district_id') and
  (not(r ? 'subdistrict_id') or shop_subdistrict_id=r->>'subdistrict_id') and
  (not(r ? 'min_price') or price>=(r->>'min_price')::numeric) and (not(r ? 'max_price') or price<=(r->>'max_price')::numeric) and
  (not coalesce((r->>'verified_only')::boolean,false) or verified) and
  (not(r ? 'radius_km') or distance_km<=(r->>'radius_km')::numeric)
 ), service_candidates as (
  select id item_id,vendor_id,name,description,price,gallery->>0 image_url,created_at,completed_count,review_count,
   rating_sum::numeric/nullif(review_count,0) rating,distance_km,verified,
   jsonb_build_object('id',id,'vendor_id',vendor_id,'category_node_id',category_node_id,'name',name,'slug',slug,'description',description,'price',price,'gallery',gallery,'is_active',true,
   'category_nodes',jsonb_build_object('id',category_node_id,'name',category_name,'slug',category_slug,'parent_id',category_parent_id)) service
  from base where p_section.content_type='services'
 ), vendor_totals as (
  select s.vendor_id,coalesce(sum(m.completed_count),0) completed_count,coalesce(sum(m.review_count),0) review_count,
    sum(m.rating_sum)::numeric/nullif(sum(m.review_count),0) rating
  from public.services s left join eventra_feed.service_metrics m on m.service_id=s.id group by s.vendor_id
 ), vendor_candidates as (
  select distinct on(b.vendor_id) b.vendor_id item_id,b.vendor_id,b.vendor_name name,b.about_me description,
    b.price,b.profile_image_url image_url,b.vendor_created_at created_at,t.completed_count,t.review_count,t.rating,b.distance_km,b.verified,null::jsonb service
  from base b join vendor_totals t using(vendor_id) where p_section.content_type='vendors'
  order by b.vendor_id,case when exists(select 1 from filtered f where f.id=b.id) then 0 else 1 end,b.distance_km nulls last,b.price,b.id
 ), candidates as (select * from service_candidates union all select * from vendor_candidates),
 ranked as (
  select c.*,pin.sort_order pin_order,pin.id pin_id from candidates c
  left join public.home_feed_pinned_items pin on pin.section_id=p_section.id and coalesce(pin.service_id,pin.vendor_id)=c.item_id
  where (p_section.selection_mode in('manual','mixed') and pin.id is not null)
  or (p_section.selection_mode in('automatic','mixed') and
    (case when p_section.content_type='services' then exists(select 1 from filtered f where f.id=c.item_id) else exists(select 1 from filtered f where f.vendor_id=c.item_id) end)
    and (not(r ? 'min_rating') or c.rating>=(r->>'min_rating')::numeric)
    and c.review_count>=coalesce((r->>'min_reviews')::numeric,0)
    and (not(r ? 'new_days') or c.created_at>=now()-make_interval(days=>(r->>'new_days')::int)))
 ), ordered as (
  select *,row_number() over(order by
    case when p_section.selection_mode<>'automatic' and pin_id is not null then 0 else 1 end,
    case when p_section.selection_mode<>'automatic' then pin_order end nulls last,
    case when p_section.sort_by='rating' then rating end desc nulls last,
    case when p_section.sort_by='bookings' then completed_count end desc,
    case when p_section.sort_by='nearest' then distance_km end asc nulls last,
    case when p_section.sort_by='price_low' then price end asc,
    case when p_section.sort_by='price_high' then price end desc,
    created_at desc,item_id) seq from ranked
 ), page as (select * from ordered where seq>p_offset and seq<=p_offset+p_limit+1)
 select jsonb_build_object('items',coalesce(jsonb_agg(jsonb_build_object('id',item_id,'type',p_section.content_type,'name',name,'description',description,'price',price,'image_url',image_url,
   'rating',round(rating,1),'review_count',review_count,'completed_count',completed_count,'distance_km',round(distance_km::numeric,1),'verified',verified,'service',service) order by seq) filter(where seq<=p_offset+p_limit),'[]'::jsonb),
   'has_more',count(*)>p_limit,'requires_location',false) into result from page;
 return result;
end $$;

create or replace function public.home_feed_items(p_section_id uuid,p_offset int default 0,p_limit int default 20,p_lat double precision default null,p_lng double precision default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare s public.home_feed_sections;
begin
 select * into s from public.home_feed_sections where id=p_section_id and is_active and (starts_at is null or starts_at<=now()) and (ends_at is null or ends_at>now());
 if not found then return jsonb_build_object('items','[]'::jsonb,'has_more',false); end if;
 return eventra_feed.items(s,p_offset,p_limit,p_lat,p_lng);
end $$;
create or replace function public.home_feed_page(p_offset int default 0,p_limit int default 3,p_lat double precision default null,p_lng double precision default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb:='[]'; s public.home_feed_sections; n int:=0;
begin
 if p_offset<0 or p_offset>10000 or p_limit<1 or p_limit>10 then raise exception 'Invalid section pagination'; end if;
 for s in select * from public.home_feed_sections where is_active and (starts_at is null or starts_at<=now()) and (ends_at is null or ends_at>now()) order by sort_order,id offset p_offset limit p_limit+1 loop
  n:=n+1; if n<=p_limit then result:=result||jsonb_build_array(jsonb_build_object('id',s.id,'title',s.title,'content_type',s.content_type,'layout',s.layout)||eventra_feed.items(s,0,s.item_limit,p_lat,p_lng)); end if;
 end loop;
 return jsonb_build_object('sections',result,'has_more',n>p_limit,'next_offset',p_offset+least(n,p_limit));
end $$;

insert into eventra_admin.modules(name,label,section,pk,can_create,editable,choices,actions,sort_column)
values('home_feed_sections','Home Feed','Customer App','id',true,array['title','content_type','layout','selection_mode','rules','sort_by','item_limit','sort_order','is_active','starts_at','ends_at'],'{}','{}','sort_order')
on conflict(name) do update set editable=excluded.editable,label=excluded.label;

create or replace function public.admin_home_feed_workspace() returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 perform eventra_admin.require_access(false);
 return jsonb_build_object('sections',(select coalesce(jsonb_agg(to_jsonb(s)||jsonb_build_object('_revision',md5(to_jsonb(s)::text),'pins',(select coalesce(jsonb_agg(jsonb_build_object('id',coalesce(p.service_id,p.vendor_id),'name',coalesce((select name from public.services where id=p.service_id),(select name from public.vendors where id=p.vendor_id),'Unavailable item')) order by p.sort_order,p.id),'[]') from public.home_feed_pinned_items p where p.section_id=s.id)) order by s.sort_order,s.id),'[]') from public.home_feed_sections s),
  'categories',(select coalesce(jsonb_agg(jsonb_build_object('id',c.id,'name',c.name,'parent_id',c.parent_id) order by c.name),'[]') from public.category_nodes c),
  'events',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name) order by name),'[]') from public.event_types where is_active),
  'states',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name) order by name),'[]') from public.administrative_regions where level='state' and is_active));
end $$;
create table if not exists eventra_feed.save_requests(request_id uuid primary key,actor_id uuid not null,payload jsonb not null,result jsonb not null);
create or replace function public.admin_home_feed_save(p_data jsonb,p_pins uuid[] default '{}',p_id uuid default null,p_revision text default null,p_request_id uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare saved jsonb; sid uuid; kind text; pid uuid; n int:=0; previous_pins jsonb; cached jsonb; request_payload jsonb:=jsonb_build_object('data',p_data,'pins',p_pins);
begin
 perform eventra_admin.require_access(true);
 if p_id is null and p_request_id is not null then
  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text,610));
  select result into cached from eventra_feed.save_requests where request_id=p_request_id and actor_id=auth.uid() and payload=request_payload;
  if found then return cached; end if;
  if exists(select 1 from eventra_feed.save_requests where request_id=p_request_id) then raise exception 'This creation request already completed. Reload Home Feed before editing.'; end if;
 end if;
 if coalesce(array_length(p_pins,1),0)>100 then raise exception 'Maximum 100 pinned items'; end if;
 saved:=public.admin_save('home_feed_sections',p_data,p_id::text,p_revision,p_request_id);
 sid:=(saved->>'id')::uuid;
 select content_type into kind from public.home_feed_sections where id=sid for update;
 select coalesce(jsonb_agg(to_jsonb(p) order by p.sort_order,p.id),'[]') into previous_pins from public.home_feed_pinned_items p where section_id=sid;
 delete from public.home_feed_pinned_items where section_id=sid;
 foreach pid in array p_pins loop
  if kind='services' and not exists(select 1 from public.services where id=pid) or kind='vendors' and not exists(select 1 from public.vendors where id=pid) then raise exception 'Pinned item not found'; end if;
  insert into public.home_feed_pinned_items(section_id,service_id,vendor_id,sort_order) values(sid,case when kind='services' then pid end,case when kind='vendors' then pid end,n) on conflict do nothing;
  n:=n+1;
 end loop;
 insert into public.admin_audit_log(actor_id,module,record_id,action,before_data,after_data) values(auth.uid(),'home_feed_sections',sid::text,'update_pins',previous_pins,jsonb_build_object('pins',p_pins));
 if p_id is null and p_request_id is not null then insert into eventra_feed.save_requests values(p_request_id,auth.uid(),request_payload,saved); end if;
 return saved;
end $$;
create or replace function public.admin_home_feed_preview(p_id uuid,p_lat double precision default null,p_lng double precision default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare s public.home_feed_sections;
begin
 perform eventra_admin.require_access(false);
 select * into strict s from public.home_feed_sections where id=p_id;
 return eventra_feed.items(s,0,s.item_limit,p_lat,p_lng);
end $$;
create or replace function public.admin_home_feed_choices(p_type text,p_search text default '',p_parent text default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 perform eventra_admin.require_access(false);
 if p_type in ('district','subdistrict') then return (select coalesce(jsonb_agg(x),'[]') from(select id,name from public.administrative_regions where is_active and level=p_type and parent_id=p_parent order by name limit 500)x); end if;
 if p_type='services' then return (select coalesce(jsonb_agg(x),'[]') from(select id,name from public.services where name ilike '%'||left(p_search,100)||'%' order by name,id limit 40)x); end if;
 if p_type='vendors' then return (select coalesce(jsonb_agg(x),'[]') from(select id,name from public.vendors where name ilike '%'||left(p_search,100)||'%' order by name,id limit 40)x); end if;
 raise exception 'Unknown choices';
end $$;
revoke all on all functions in schema eventra_feed from public,anon,authenticated;
revoke all on function public.home_feed_page(int,int,double precision,double precision),public.home_feed_items(uuid,int,int,double precision,double precision) from public;
grant execute on function public.home_feed_page(int,int,double precision,double precision),public.home_feed_items(uuid,int,int,double precision,double precision) to anon,authenticated;
revoke all on function public.admin_home_feed_workspace(),public.admin_home_feed_save(jsonb,uuid[],uuid,text,uuid),public.admin_home_feed_preview(uuid,double precision,double precision),public.admin_home_feed_choices(text,text,text) from public,anon;
grant execute on function public.admin_home_feed_workspace(),public.admin_home_feed_save(jsonb,uuid[],uuid,text,uuid),public.admin_home_feed_preview(uuid,double precision,double precision),public.admin_home_feed_choices(text,text,text) to authenticated;
insert into public.home_feed_sections(title,sort_by,is_active,sort_order) select 'Popular Services','bookings',true,10 where not exists(select 1 from public.home_feed_sections);
insert into public.home_feed_sections(title,content_type,sort_by,is_active,sort_order) select 'Top Vendors','vendors','rating',true,20 where not exists(select 1 from public.home_feed_sections where title='Top Vendors');
insert into public.home_feed_sections(title,sort_by,is_active,sort_order) select 'New on Eventra','newest',true,30 where not exists(select 1 from public.home_feed_sections where title='New on Eventra');
commit;
