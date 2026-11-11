begin;
create or replace function public.customer_service_overview(p_service_id uuid) returns jsonb
language sql stable security definer set search_path = pg_catalog, public, eventra_feed as $$
select jsonb_build_object('business_name',b.name,'subdistrict',r.name,
 'rating',case when m.review_count>0 then round(m.rating_sum::numeric/m.review_count,1) end,
 'review_count',coalesce(m.review_count,0),'completed_count',coalesce(m.completed_count,0),
 'price',s.price,'pricing_type',s.pricing_type,'pricing_unit',s.pricing_unit,
 'previous_price',s.previous_price,'previous_pricing_type',s.previous_pricing_type,'previous_pricing_unit',s.previous_pricing_unit,'price_changed_at',s.price_changed_at,
 'booking_count',(select count(*) from public.bookings bk where bk.service_id=e.id),
 'business_summary',jsonb_build_object('id',b.id,'name',b.name,'description',b.description,'logo_url',b.logo_url,
 'rating',case when totals.review_count>0 then round(totals.rating_sum::numeric/totals.review_count,1) end,
 'review_count',totals.review_count,'completed_count',totals.completed_count,'service_count',totals.service_count))
from eventra_feed.eligible_services e join public.services s on s.id=e.id join public.businesses b on b.id=e.business_id
left join public.administrative_regions r on r.id=b.shop_subdistrict_id
left join eventra_feed.service_metrics m on m.service_id=e.id
left join lateral (
 select count(*) service_count,coalesce(sum(sm.review_count),0) review_count,
 coalesce(sum(sm.rating_sum),0) rating_sum,coalesce(sum(sm.completed_count),0) completed_count
 from public.services bs left join eventra_feed.service_metrics sm on sm.service_id=bs.id
 where bs.business_id=b.id
) totals on true
where e.id=p_service_id;
$$;
revoke all on function public.customer_service_overview(uuid) from public;
grant execute on function public.customer_service_overview(uuid) to anon, authenticated;


notify pgrst, 'reload schema';
commit;
