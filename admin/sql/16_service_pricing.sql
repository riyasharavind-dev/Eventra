begin;
alter table public.services add column if not exists pricing_type text not null default 'fixed';
alter table public.services add column if not exists pricing_unit text;
alter table public.services drop constraint if exists services_pricing_valid;
alter table public.services add constraint services_pricing_valid check (
  pricing_type in ('fixed','starting_from','per_unit','per_duration')
  and case
    when pricing_type in ('fixed','starting_from') then pricing_unit is null
    when pricing_type='per_unit' then pricing_unit is not null and length(trim(pricing_unit)) between 1 and 40
    when pricing_type='per_duration' then pricing_unit is not null and pricing_unit in ('hour','day','week','month')
    else false end
  and price <> 'NaN'::numeric and price <> 'Infinity'::numeric
);
-- Extend the existing guarded business save; retain all ownership/category checks.
do $$
declare definition text; marker text := 'vendor_enabled=excluded.vendor_enabled,updated_at=now();';
begin
 select pg_get_functiondef(oid) into definition from pg_proc
 where proname='save_business_service' and pronamespace='public'::regnamespace;
 if definition is null then raise exception 'Missing business service save function'; end if;
 if position('pricing_type' in definition)=0 then
   if position(marker in definition)=0 then raise exception 'Unexpected business save definition'; end if;
   definition:=replace(definition, marker, marker || $patch$
 update public.services set
 pricing_type=case when p_data ? 'pricing_type' then p_data->>'pricing_type' else pricing_type end,
 pricing_unit=case when p_data ? 'pricing_type' then
   case when p_data->>'pricing_type' in ('per_unit','per_duration') then trim(p_data->>'pricing_unit') else null end
   else pricing_unit end
 where id=p_id and vendor_id=auth.uid();
 $patch$);
   -- Existing per-unit rows must receive their new pricing alongside the upsert,
   -- so the old valid pricing stays valid until this second atomic update.
   execute definition;
 end if;
end $$;
commit;
select jsonb_build_object('services',count(*),'existing_fixed',count(*) filter(where pricing_type='fixed')) as pricing_migration from public.services;
