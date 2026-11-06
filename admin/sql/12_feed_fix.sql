begin;
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

revoke all on all functions in schema eventra_feed from public,anon,authenticated;
commit;