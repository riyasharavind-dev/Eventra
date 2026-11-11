begin;
alter table public.services add column if not exists previous_price numeric;
alter table public.services add column if not exists previous_pricing_type text;
alter table public.services add column if not exists previous_pricing_unit text;
alter table public.services add column if not exists price_changed_at timestamptz;
create or replace function public.track_service_price_change() returns trigger language plpgsql set search_path = pg_catalog as $$
begin
 if tg_op='INSERT' then
  new.previous_price := null; new.previous_pricing_type := null; new.previous_pricing_unit := null; new.price_changed_at := null;
 elsif new.price is distinct from old.price or new.pricing_type is distinct from old.pricing_type or new.pricing_unit is distinct from old.pricing_unit then
  new.previous_price := old.price; new.previous_pricing_type := old.pricing_type; new.previous_pricing_unit := old.pricing_unit; new.price_changed_at := clock_timestamp();
 else
  new.previous_price := old.previous_price; new.previous_pricing_type := old.previous_pricing_type; new.previous_pricing_unit := old.previous_pricing_unit; new.price_changed_at := old.price_changed_at;
 end if;
 return new;
end;
$$;
revoke all on function public.track_service_price_change() from public;
drop trigger if exists service_price_change_tracking on public.services;
create trigger service_price_change_tracking before insert or update on public.services for each row execute function public.track_service_price_change();
create or replace function public.customer_service_overview(p_service_id uuid) returns jsonb
language sql stable security definer set search_path = pg_catalog, public, eventra_feed as $$
select jsonb_build_object('business_name',b.name,'subdistrict',r.name,
 'rating',case when m.review_count>0 then round(m.rating_sum::numeric/m.review_count,1) end,
 'review_count',coalesce(m.review_count,0),'completed_count',coalesce(m.completed_count,0),
 'price',s.price,'pricing_type',s.pricing_type,'pricing_unit',s.pricing_unit,
 'previous_price',s.previous_price,'previous_pricing_type',s.previous_pricing_type,'previous_pricing_unit',s.previous_pricing_unit,'price_changed_at',s.price_changed_at)
from eventra_feed.eligible_services e join public.services s on s.id=e.id join public.businesses b on b.id=e.business_id
left join public.administrative_regions r on r.id=b.shop_subdistrict_id
left join eventra_feed.service_metrics m on m.service_id=e.id
where e.id=p_service_id;
$$;
revoke all on function public.customer_service_overview(uuid) from public;
grant execute on function public.customer_service_overview(uuid) to anon, authenticated;

notify pgrst, 'reload schema';
commit;
