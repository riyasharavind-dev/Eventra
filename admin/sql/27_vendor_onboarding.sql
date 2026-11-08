-- Vendor learning progress is private and independent from real setup completion.
begin;
set local lock_timeout='10s';
create table if not exists public.vendor_guide_progress (
 vendor_id uuid not null references public.vendors(id) on delete cascade,
 guide_version integer not null default 1 check(guide_version=1),
 status text not null check(status in ('in_progress','skipped','completed')),
 last_step integer not null default 0 check(last_step between 0 and 6),
 updated_at timestamptz not null default now(),
 primary key(vendor_id,guide_version),
 check(status<>'completed' or last_step=6)
);
alter table public.vendor_guide_progress enable row level security;
revoke all on public.vendor_guide_progress from public,anon,authenticated;
drop policy if exists own_vendor_guide on public.vendor_guide_progress;
create policy own_vendor_guide on public.vendor_guide_progress for select to authenticated
 using(vendor_id=(select auth.uid()) and (select eventra_security.actor_role())='vendor');
grant select on public.vendor_guide_progress to authenticated;

create or replace function public.get_vendor_guide_state(p_account_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 perform eventra_security.require_actor('vendor');
 if p_account_id is distinct from auth.uid() then raise exception 'Account changed' using errcode='42501';end if;
 select jsonb_build_object('status',status,'last_step',last_step,'guide_version',guide_version)
 into result from public.vendor_guide_progress where vendor_id=auth.uid() and guide_version=1;
 return coalesce(result,'{"status":"pending","last_step":0,"guide_version":1}'::jsonb);
end $$;
create or replace function public.save_vendor_guide_progress(
 p_account_id uuid,p_status text,p_step integer,p_restart boolean default false
) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 perform eventra_security.require_actor('vendor');
 if p_account_id is distinct from auth.uid() then raise exception 'Account changed' using errcode='42501';end if;
 if p_status is null or p_status not in ('in_progress','skipped','completed')
 or p_step is null or p_step not between 0 and 6 or (p_status='completed' and p_step<>6)
 or (coalesce(p_restart,false) and (p_status<>'in_progress' or p_step<>0)) then
  raise exception 'Invalid guide progress' using errcode='22023';end if;
 insert into public.vendor_guide_progress(vendor_id,status,last_step)
 values(auth.uid(),p_status,p_step)
 on conflict(vendor_id,guide_version) do update set
 status=case when p_restart then 'in_progress'
   when vendor_guide_progress.status='completed' then 'completed' else excluded.status end,
 last_step=case when p_restart then 0 else greatest(vendor_guide_progress.last_step,excluded.last_step) end,
 updated_at=now();
 return public.get_vendor_guide_state(p_account_id);
end $$;
create or replace function public.get_vendor_setup_checklist(p_account_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 perform eventra_security.require_actor('vendor');
 if p_account_id is distinct from auth.uid() then raise exception 'Account changed' using errcode='42501';end if;
 return jsonb_build_object(
 'profile_complete',exists(select 1 from public.vendors where id=auth.uid()
   and length(trim(name))>0 and length(trim(coalesce(phone,'')))>0),
 'business_count',(select count(*) from public.businesses where vendor_id=auth.uid()),
 'service_count',(select count(*) from public.services where vendor_id=auth.uid()));
end $$;
revoke all on function public.get_vendor_guide_state(uuid),public.save_vendor_guide_progress(uuid,text,integer,boolean),public.get_vendor_setup_checklist(uuid) from public,anon;
grant execute on function public.get_vendor_guide_state(uuid),public.save_vendor_guide_progress(uuid,text,integer,boolean),public.get_vendor_setup_checklist(uuid) to authenticated;
drop trigger if exists eventor_app_revision on public.vendor_guide_progress;
create trigger eventor_app_revision after insert or update or delete on public.vendor_guide_progress
 for each row execute function eventra_security.publish_app_change();
commit;
