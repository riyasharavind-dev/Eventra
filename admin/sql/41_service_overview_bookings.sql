create or replace function public.customer_service_overview(p_service_id uuid) returns jsonb
language sql stable security definer set search_path = pg_catalog, public, eventra_feed as $$
select jsonb_build_object('business_name',b.name,'subdistrict',r.name,
 'rating',case when m.review_count>0 then round(m.rating_sum::numeric/m.review_count,1) end,
 'review_count',coalesce(m.review_count,0),'completed_count',coalesce(m.completed_count,0))
from eventra_feed.eligible_services e join public.businesses b on b.id=e.business_id
left join public.administrative_regions r on r.id=b.shop_subdistrict_id
left join eventra_feed.service_metrics m on m.service_id=e.id
where e.id=p_service_id;
$$;
revoke all on function public.customer_service_overview(uuid) from public;
grant execute on function public.customer_service_overview(uuid) to anon, authenticated;
