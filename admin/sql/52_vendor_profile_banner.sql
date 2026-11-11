begin;
create or replace function public.customer_card_display_metadata(p_items jsonb) returns jsonb
language sql stable security definer set search_path=pg_catalog,public,eventra_feed as $$
with recursive requested as(select x->>'id' id,x->>'type' kind from jsonb_array_elements(p_items) x limit 100),
matched as (
 select distinct on(q.kind,q.id) q.kind,q.id,e.category_node_id,b.id business_id,b.name business_name,b.logo_url business_logo_url,b.banner_url business_banner_url,b.description business_description,extract(year from b.created_at) since_year,r.name location
 from requested q join eventra_feed.eligible_services e on(q.kind='vendors' and e.vendor_id::text=q.id) or(q.kind='services' and e.id::text=q.id)
 join public.businesses b on b.id=e.business_id left join public.administrative_regions r on r.id=b.shop_subdistrict_id
 order by q.kind,q.id,e.created_at desc,e.id
), paths(kind,id,node,parent_id,name,visited,depth) as (
 select m.kind,m.id,c.id,c.parent_id,c.name,array[c.id],0 from matched m join public.category_nodes c on c.id=m.category_node_id
 union all select p.kind,p.id,c.id,c.parent_id,c.name,p.visited||c.id,p.depth+1 from paths p join public.category_nodes c on c.id=p.parent_id where not c.id=any(p.visited)
), roots as(select distinct on(kind,id) kind,id,name from paths order by kind,id,depth desc)
select coalesce(jsonb_object_agg(m.kind||':'||m.id,jsonb_build_object('location',m.location,'business_id',m.business_id,'business_name',m.business_name,'business_logo_url',m.business_logo_url,'business_banner_url',m.business_banner_url,'business_description',m.business_description,'since_year',m.since_year,'parent_category',roots.name)),'{}'::jsonb) from matched m left join roots using(kind,id);
$$;
revoke all on function public.customer_card_display_metadata(jsonb) from public;
grant execute on function public.customer_card_display_metadata(jsonb) to anon,authenticated;
create or replace function public.customer_related_vendors(p_service_id uuid,p_offset integer default 0,p_limit integer default 12) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 if p_offset is null or p_offset<0 or p_offset>200 or p_limit is null or p_limit<1 or p_limit>24 then raise exception 'Invalid page'; end if;
 with recursive anchor as (select * from eventra_feed.eligible_services where id=p_service_id),
 path(id,parent_id,visited) as (
  select c.id,c.parent_id,array[c.id] from public.category_nodes c join anchor a on a.category_node_id=c.id
  union all select c.id,c.parent_id,p.visited||c.id from path p join public.category_nodes c on c.id=p.parent_id where not c.id=any(p.visited)
 ), family(id,visited) as (
  select p.id,array[p.id] from path p where p.parent_id is null
  union all select c.id,f.visited||c.id from family f join public.category_nodes c on c.parent_id=f.id where not c.id=any(f.visited)
 ), matches as (
  select e.*,case when e.category_node_id=a.category_node_id then 60 when e.category_parent_id=a.category_parent_id and a.category_parent_id is not null then 35 else 15 end
   +case when e.event_type_id=a.event_type_id then 8 else 0 end relevance
  from eventra_feed.eligible_services e cross join anchor a
  where e.vendor_id<>a.vendor_id and (e.category_node_id=a.category_node_id or e.category_node_id in(select id from family))
 ), representatives as (
  select distinct on(vendor_id) * from matches order by vendor_id,relevance desc,created_at desc,id
 ), totals as (
  select s.vendor_id,coalesce(sum(m.completed_count),0) completed_count,coalesce(sum(m.review_count),0) review_count,coalesce(sum(m.rating_sum),0) rating_sum
  from public.services s left join eventra_feed.service_metrics m on m.service_id=s.id where s.vendor_id in(select vendor_id from representatives) group by s.vendor_id
 ), scored as (
  select e.*,t.completed_count vendor_completed,t.review_count vendor_reviews,t.rating_sum vendor_rating,
  e.relevance+2*(t.rating_sum+20.0)/(t.review_count+5.0)+least(6.0,ln(1+t.completed_count)) score,
  r.name location,b.name card_business_name,b.logo_url card_business_logo,b.id card_business_id,b.banner_url card_business_banner,b.description card_business_description,extract(year from b.created_at) card_since_year
  from representatives e join totals t on t.vendor_id=e.vendor_id left join public.businesses b on b.id=e.business_id left join public.administrative_regions r on r.id=b.shop_subdistrict_id
 ), page as (select *,row_number() over(order by score desc,vendor_id) n from scored), limited as (
  select * from page where n>p_offset and n<=p_offset+p_limit+1
 )
 select jsonb_build_object('items',coalesce(jsonb_agg(jsonb_build_object('id',vendor_id,'type','vendors','name',vendor_name,'description',about_me,'image_url',profile_image_url,'verified',verified,'location',location,'business_id',card_business_id,'business_name',card_business_name,'business_logo_url',card_business_logo,'business_banner_url',card_business_banner,'business_description',card_business_description,'since_year',card_since_year,'parent_category',(select c.name from path p join public.category_nodes c on c.id=p.id where p.parent_id is null limit 1),
 'rating',case when vendor_reviews>0 then round(vendor_rating::numeric/vendor_reviews,1) end,'review_count',vendor_reviews,'completed_count',vendor_completed) order by n) filter(where n<=p_offset+p_limit),'[]'::jsonb),
 'has_more',count(*)>p_limit,'next_offset',p_offset+least(count(*),p_limit),'personalized',false) into result from limited;
 return result;
end $$;
revoke all on function public.customer_related_vendors(uuid,integer,integer) from public;
grant execute on function public.customer_related_vendors(uuid,integer,integer) to anon,authenticated;
notify pgrst,'reload schema';


commit;
