begin;
create or replace function public.customer_search(p_query text,p_kind text default 'all',p_offset integer default 0,p_limit integer default 20)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare q text:=lower(trim(regexp_replace(coalesce(p_query,''),'\s+',' ','g'))); result jsonb;
begin
 if p_kind not in ('all','services','vendors') or p_kind is null or p_offset is null or p_limit is null or p_offset<0 or p_offset>10000 or p_limit<1 or p_limit>30 then raise exception 'Invalid search options'; end if;
 if length(q)<2 then return jsonb_build_object('items','[]'::jsonb,'has_more',false); end if;
 if length(q)>80 then raise exception 'Search must be 80 characters or fewer'; end if;
 with recursive category_path(id,parent_id,names,visited) as (
   select id,parent_id,name,array[id] from public.category_nodes
   union all
   select p.id,c.parent_id,p.names||' '||c.name,p.visited||c.id from category_path p join public.category_nodes c on c.id=p.parent_id where not c.id=any(p.visited)
 ), category_names as (
   select distinct on(id) id,names from category_path order by id,cardinality(visited) desc
 ), base as (
   select e.*,s.pricing_type,s.pricing_unit,lower(concat_ws(' ',e.name,left(e.description,2000),e.vendor_name,e.business_name,c.names,et.name)) search_text
   from eventra_feed.eligible_services e join public.services s on s.id=e.id
   left join category_names c on c.id=e.category_node_id
   left join public.event_types et on et.id=e.event_type_id and et.is_active
 ), matched as (
   select * from base b where not exists(select 1 from unnest(regexp_split_to_array(q,'\s+')) word where position(word in b.search_text)=0)
 ), vendor_totals as (
   select s.vendor_id,coalesce(sum(m.completed_count),0) completed_count,coalesce(sum(m.review_count),0) review_count,coalesce(sum(m.rating_sum),0) rating_sum from public.services s left join eventra_feed.service_metrics m on m.service_id=s.id where s.vendor_id in (select vendor_id from matched) group by s.vendor_id
 ), candidates as (
   select m.id,'services'::text kind,m.name,
     case when lower(m.name)=q then 0 when starts_with(lower(m.name),q) then 1 when position(q in lower(m.name))>0 then 2 else 3 end rank,
     jsonb_build_object('id',m.id,'type','services','name',m.name,'description',m.description,'image_url',m.gallery->>0,'price',m.price,
       'pricing_type',m.pricing_type,'pricing_unit',m.pricing_unit,'review_count',m.review_count,'rating',case when m.review_count>0 then round(m.rating_sum::numeric/m.review_count,1) end,
       'category_name',m.category_name,'vendor_name',m.vendor_name,
       'service',jsonb_build_object('id',m.id,'vendor_id',m.vendor_id,'business_id',m.business_id,'category_node_id',m.category_node_id,'event_type_id',m.event_type_id,'name',m.name,'slug',m.slug,'description',m.description,'price',m.price,'pricing_type',m.pricing_type,'pricing_unit',m.pricing_unit,'gallery',m.gallery,'is_active',true,'created_at',m.created_at,
         'category_nodes',jsonb_build_object('id',m.category_node_id,'name',m.category_name,'slug',m.category_slug,'parent_id',m.category_parent_id))) payload
   from matched m where p_kind in ('all','services')
   union all
   select m.vendor_id,'vendors',m.vendor_name,
     case when lower(m.vendor_name)=q then 0 when starts_with(lower(m.vendor_name),q) then 1 when position(q in lower(m.vendor_name))>0 then 2 else 4 end,
     jsonb_build_object('id',m.vendor_id,'type','vendors','name',m.vendor_name,'description',m.about_me,'image_url',m.profile_image_url,'verified',m.verified,'price',min(m.price),'completed_count',t.completed_count,'review_count',t.review_count,'rating',case when t.review_count>0 then round(t.rating_sum::numeric/t.review_count,1) end)
   from matched m join vendor_totals t on t.vendor_id=m.vendor_id where p_kind in ('all','vendors')
   group by m.vendor_id,m.vendor_name,m.about_me,m.profile_image_url,m.verified,t.completed_count,t.review_count,t.rating_sum
 ), page as (
   select * from candidates order by rank,lower(name),kind,id offset p_offset limit p_limit+1
 ), numbered as (select *,row_number() over(order by rank,lower(name),kind,id) n from page)
 select jsonb_build_object('items',coalesce(jsonb_agg(payload order by n) filter(where n<=p_limit),'[]'::jsonb),'has_more',count(*)>p_limit) into result from numbered;
 return result;
end $$;
revoke all on function public.customer_search(text,text,integer,integer) from public;
grant execute on function public.customer_search(text,text,integer,integer) to anon,authenticated;
commit;
select jsonb_build_object('service_results',jsonb_array_length(public.customer_search('decoration','services')->'items'),'vendor_results',jsonb_array_length(public.customer_search('demo','vendors')->'items')) as search_check;
