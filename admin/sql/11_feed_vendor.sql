begin;
create or replace function public.home_feed_vendor_services(p_vendor_id uuid,p_offset int default 0) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 if p_offset<0 or p_offset>10000 then raise exception 'Invalid offset'; end if;
 with ranked as(select e.*,row_number() over(order by created_at desc,id) seq from eventra_feed.eligible_services e where vendor_id=p_vendor_id),
 page as(select * from ranked where seq>p_offset and seq<=p_offset+21)
 select jsonb_build_object('items',coalesce(jsonb_agg(jsonb_build_object('id',id,'type','services','name',name,'description',description,'price',price,'image_url',gallery->>0,
 'rating',round(rating_sum::numeric/nullif(review_count,0),1),'review_count',review_count,'completed_count',completed_count,
 'service',jsonb_build_object('id',id,'vendor_id',vendor_id,'category_node_id',category_node_id,'name',name,'slug',slug,'description',description,'price',price,'gallery',gallery,'is_active',true,
 'category_nodes',jsonb_build_object('id',category_node_id,'name',category_name,'slug',category_slug,'parent_id',category_parent_id))) order by seq) filter(where seq<=p_offset+20),'[]'),'has_more',count(*)>20) into result from page;
 return result;
end $$;
revoke all on function public.home_feed_vendor_services(uuid,int) from public;
grant execute on function public.home_feed_vendor_services(uuid,int) to anon,authenticated;
commit;
