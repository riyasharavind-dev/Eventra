begin;
-- One bounded signal per customer/category; raw search text is never stored.
create table if not exists eventra_feed.category_search_signals(
 customer_id uuid not null references public.customers(id) on delete cascade,
 category_id uuid not null references public.category_nodes(id) on delete cascade,
 searched_at timestamptz not null default now(),primary key(customer_id,category_id));
alter table eventra_feed.category_search_signals enable row level security;
revoke all on eventra_feed.category_search_signals from public,anon,authenticated;
create index if not exists category_search_recency on eventra_feed.category_search_signals(searched_at desc,category_id);
create or replace function public.customer_record_category_search(p_query text)returns void
language plpgsql security definer set search_path='' as $$
declare q text:=lower(trim(regexp_replace(coalesce(p_query,''),'\s+',' ','g')));changed integer;
begin
 perform eventra_security.require_actor('customer');
 if length(q)<2 or length(q)>80 then return;end if;
 with recursive paths(id,parent_id,names,visited) as(
  select id,parent_id,lower(name||' '||replace(slug,'-',' ')),array[id] from public.category_nodes
  union all select p.id,c.parent_id,p.names||' '||lower(c.name),p.visited||c.id from paths p join public.category_nodes c on c.id=p.parent_id where not c.id=any(p.visited)
 ), full_paths as(select distinct on(id) id,names from paths order by id,cardinality(visited) desc),
 matches as(
  select id from full_paths p where not exists(select 1 from unnest(regexp_split_to_array(q,'\s+')) w where position(w in p.names)=0)
  union select e.category_node_id from eventra_feed.eligible_services e join full_paths p on p.id=e.category_node_id
   where not exists(select 1 from unnest(regexp_split_to_array(q,'\s+')) w where position(w in lower(concat_ws(' ',e.name,left(e.description,2000),e.vendor_name,e.business_name,p.names)))=0)
 ), seeds as(select id from matches order by id limit 20),
 ancestors(id,parent_id,visited) as(
  select c.id,c.parent_id,array[c.id] from public.category_nodes c join seeds s using(id)
  union all select c.id,c.parent_id,a.visited||c.id from ancestors a join public.category_nodes c on c.id=a.parent_id where not c.id=any(a.visited)
 )
 insert into eventra_feed.category_search_signals(customer_id,category_id)
 select auth.uid(),id from ancestors group by id
 on conflict(customer_id,category_id) do update set searched_at=now()
 where category_search_signals.searched_at<now()-interval '10 minutes';
 get diagnostics changed=row_count;
 delete from eventra_feed.category_search_signals where customer_id=auth.uid() and
 (searched_at<now()-interval '180 days' or category_id in(select category_id from eventra_feed.category_search_signals where customer_id=auth.uid() order by searched_at desc,category_id offset 200));
 if changed>0 and not exists(select 1 from public.app_data_revisions where audience='public' and dataset='category_trends' and changed_at>now()-interval '5 minutes') then
  perform eventra_security.touch_app_revision('public','category_trends');
 end if;
end $$;
create or replace function public.customer_category_rankings()returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object('category_id',category_id,'score',score) order by score desc,category_id),'[]'::jsonb)
 from(select category_id,sum(case when searched_at>now()-interval '7 days' then 2 else 1 end) score
 from eventra_feed.category_search_signals where searched_at>now()-interval '30 days' group by category_id) ranked
$$;
create or replace function public.customer_category_services(p_category_id uuid,p_offset integer default 0,p_limit integer default 24)returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;begin
 if p_category_id is null or p_offset is null or p_limit is null or p_offset<0 or p_offset>10000 or p_limit<1 or p_limit>48 then raise exception 'Invalid category page' using errcode='22023';end if;
 with recursive subtree(id,visited)as(
  select id,array[id] from public.category_nodes where id=p_category_id
  union all select c.id,t.visited||c.id from public.category_nodes c join subtree t on c.parent_id=t.id where not c.id=any(t.visited)
 ), page as(
  select s.*,jsonb_build_object('id',c.id,'name',c.name,'slug',c.slug,'parent_id',c.parent_id) category_nodes
  from eventra_feed.eligible_services e join public.services s on s.id=e.id join public.category_nodes c on c.id=s.category_node_id
  where s.category_node_id in(select id from subtree) order by s.created_at desc,s.id offset p_offset limit p_limit+1
 ), numbered as(select to_jsonb(p) payload,row_number()over(order by created_at desc,id) n from page p)
 select jsonb_build_object('items',coalesce(jsonb_agg(payload order by n)filter(where n<=p_limit),'[]'::jsonb),'has_more',count(*)>p_limit) into result from numbered;
 return result;
end $$;
revoke all on function public.customer_record_category_search(text),public.customer_category_rankings(),public.customer_category_services(uuid,integer,integer) from public,anon,authenticated;
grant execute on function public.customer_record_category_search(text) to authenticated;
grant execute on function public.customer_category_rankings(),public.customer_category_services(uuid,integer,integer) to anon,authenticated;
commit;
