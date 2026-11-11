-- Public card location is explicitly limited to the requested sub-district name.
create or replace function public.customer_card_subdistricts(p_items jsonb) returns jsonb
language sql stable security definer set search_path = pg_catalog, public, eventra_feed as $$
with requested as (select x->>'id' id, x->>'type' kind from jsonb_array_elements(p_items) x limit 100),
matched as (
 select distinct on (q.kind,q.id) q.kind,q.id,r.name location
 from requested q join eventra_feed.eligible_services e on (q.kind='vendors' and e.vendor_id::text=q.id) or (q.kind='services' and e.id::text=q.id)
 join public.businesses b on b.id=e.business_id left join public.administrative_regions r on r.id=b.shop_subdistrict_id
 order by q.kind,q.id,e.created_at desc,e.id
)
select coalesce(jsonb_object_agg(kind||':'||id,location),'{}'::jsonb) from matched;
$$;
revoke all on function public.customer_card_subdistricts(jsonb) from public;
grant execute on function public.customer_card_subdistricts(jsonb) to anon, authenticated;
