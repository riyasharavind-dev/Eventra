-- Archive is separate from temporary deactivation. Existing RLS remains authoritative.
begin;
alter table public.services add column if not exists is_archived boolean not null default false;
do $$begin
 if not exists(select 1 from pg_constraint where conrelid='public.services'::regclass and conname='services_archive_inactive') then
 alter table public.services add constraint services_archive_inactive check(not is_archived or not is_active);
 end if;
end $$;
grant select(is_archived) on public.services to anon,authenticated;
grant update(is_archived) on public.services to authenticated;
comment on column public.services.is_archived is 'Vendor archive; archived services must be inactive. Restore leaves inactive until explicitly activated.';
commit;
