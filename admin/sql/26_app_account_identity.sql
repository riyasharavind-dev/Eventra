-- Separate app identities; SMS delivery and OTP verification are not enabled here.
begin;
set local lock_timeout='10s';

create table if not exists eventra_security.account_phone_identities (
 user_id uuid primary key references public.users(id) on delete cascade,
 account_role text not null check (account_role in ('customer','vendor')),
 phone_e164 text not null check (phone_e164 ~ '^\+[1-9][0-9]{6,14}$'),
 verified_at timestamptz not null default now(),
 verification_provider text not null check (length(trim(verification_provider)) between 1 and 80),
 verification_reference text not null check (length(trim(verification_reference)) between 1 and 200),
 unique(account_role,phone_e164)
);
alter table eventra_security.account_phone_identities enable row level security;
revoke all on eventra_security.account_phone_identities from public,anon,authenticated,service_role;
comment on table eventra_security.account_phone_identities is
 'Verified login aliases only. Contact/profile phones never populate this table. Same phone may map to one customer UID and a different vendor UID.';

create or replace function eventra_security.guard_account_identity() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if tg_table_name='users' then
  if new.id is distinct from old.id or new.role is distinct from old.role then
   raise exception 'Account identity and account type cannot be changed' using errcode='42501';
  end if;
 else
  if not exists(select 1 from public.users where id=new.id and role=case tg_table_name when 'vendors' then 'vendor' else 'customer' end) then
   raise exception 'Profile must match its account type' using errcode='42501';
  end if;
 end if;
 return new;
end $$;
revoke all on function eventra_security.guard_account_identity() from public,anon,authenticated,service_role;
drop trigger if exists eventor_account_identity_guard on public.users;
create trigger eventor_account_identity_guard before update of id,role on public.users
 for each row execute function eventra_security.guard_account_identity();
drop trigger if exists eventor_profile_identity_guard on public.vendors;
create trigger eventor_profile_identity_guard before insert or update of id on public.vendors
 for each row execute function eventra_security.guard_account_identity();
drop trigger if exists eventor_profile_identity_guard on public.customers;
create trigger eventor_profile_identity_guard before insert or update of id on public.customers
 for each row execute function eventra_security.guard_account_identity();

-- The future trusted OTP broker calls this ONLY after validating the provider's
-- one-time proof, intended app, authenticated linking account and expiry. A phone
-- string, profile field, client metadata or an SMS-send response is not proof.
create or replace function public.bind_verified_app_phone(
 p_user_id uuid,p_app_role text,p_phone_e164 text,p_provider text,p_verification_reference text
) returns void language plpgsql security definer set search_path='' as $$
begin
 if p_app_role is null or p_app_role not in ('customer','vendor')
 or p_phone_e164 is null or p_phone_e164 !~ '^\+[1-9][0-9]{6,14}$'
 or p_provider is null or length(trim(p_provider)) not between 1 and 80
 or p_verification_reference is null or length(trim(p_verification_reference)) not between 1 and 200 then
  raise exception 'Invalid verified phone identity' using errcode='22023';
 end if;
 -- Serialize linking/removal for an account; unique(role,phone) arbitrates
 -- simultaneous claims by different accounts without stealing a binding.
 perform 1 from auth.users a join public.users u on u.id=a.id
 where a.id=p_user_id and u.role=p_app_role and a.deleted_at is null
 and (a.banned_until is null or a.banned_until<=now()) for update of a;
 if not found then raise exception 'Account permission required' using errcode='42501'; end if;
 insert into eventra_security.account_phone_identities(user_id,account_role,phone_e164,verification_provider,verification_reference)
 values(p_user_id,p_app_role,p_phone_e164,trim(p_provider),trim(p_verification_reference))
 on conflict(user_id) do update set account_role=excluded.account_role,phone_e164=excluded.phone_e164,
 verified_at=now(),verification_provider=excluded.verification_provider,verification_reference=excluded.verification_reference;
 perform eventra_security.touch_app_revision('user:'||p_user_id::text,'access');
end $$;

create or replace function public.resolve_verified_app_phone(p_app_role text,p_phone_e164 text)
returns uuid language sql stable security definer set search_path='' as $$
 select i.user_id from eventra_security.account_phone_identities i
 join public.users u on u.id=i.user_id and u.role=i.account_role
 join auth.users a on a.id=i.user_id
 where i.account_role=p_app_role and i.phone_e164=p_phone_e164
 and a.deleted_at is null and (a.banned_until is null or a.banned_until<=now())
$$;
create or replace function public.remove_verified_app_phone(p_user_id uuid,p_app_role text)
returns void language plpgsql security definer set search_path='' as $$
begin
 perform 1 from public.users u join auth.users a on a.id=u.id
 where u.id=p_user_id and u.role=p_app_role for update of a;
 if not found then raise exception 'Account permission required' using errcode='42501';end if;
 delete from eventra_security.account_phone_identities where user_id=p_user_id and account_role=p_app_role;
 perform eventra_security.touch_app_revision('user:'||p_user_id::text,'access');
end $$;
revoke all on function public.bind_verified_app_phone(uuid,text,text,text,text),
 public.resolve_verified_app_phone(text,text),public.remove_verified_app_phone(uuid,text)
 from public,anon,authenticated;
grant execute on function public.bind_verified_app_phone(uuid,text,text,text,text),
 public.resolve_verified_app_phone(text,text),public.remove_verified_app_phone(uuid,text) to service_role;

create or replace function public.get_my_app_account(p_app_role text) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 if p_app_role is null or p_app_role not in ('customer','vendor') then
  raise exception 'Choose a valid application' using errcode='22023';end if;
 perform eventra_security.require_actor(p_app_role);
 select jsonb_build_object('user_id',u.id,'account_role',u.role,
 'verified_phone',i.phone_e164,'phone_verified_at',i.verified_at) into result
 from public.users u left join eventra_security.account_phone_identities i
 on i.user_id=u.id and i.account_role=u.role where u.id=auth.uid();
 return result;
end $$;
revoke all on function public.get_my_app_account(text) from public,anon;
grant execute on function public.get_my_app_account(text) to authenticated;
-- Existing callers also reject suspended/deleted accounts.
create or replace function public.get_my_account_role() returns text
language sql stable security definer set search_path='' as $$
 select eventra_security.actor_role()
$$;
revoke all on function public.get_my_account_role() from public,anon;
grant execute on function public.get_my_account_role() to authenticated;
commit;
