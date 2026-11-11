begin;
create table public.customer_addresses(
 id uuid primary key default gen_random_uuid(),customer_id uuid not null references public.customers(id) on delete cascade,
 label text not null default 'Home',address_line text not null,local_area text not null default '',pin_code text,
 state_id text references public.administrative_regions(id),district_id text references public.administrative_regions(id),subdistrict_id text references public.administrative_regions(id),
 state_name text,district_name text,subdistrict_name text,full_address text not null,
 is_active boolean not null default false,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 check(length(label) between 1 and 40),check(length(address_line) between 1 and 1000),check(length(local_area)<=200),check(length(full_address)<=2000),check(pin_code is null or pin_code ~ '^[0-9]{6}$')
);
create unique index customer_one_active_address on public.customer_addresses(customer_id) where is_active;
create index customer_address_owner on public.customer_addresses(customer_id,created_at);
alter table public.customer_addresses enable row level security;
revoke all on public.customer_addresses from public,anon,authenticated;
grant select on public.customer_addresses to authenticated;
create policy own_customer_addresses on public.customer_addresses for select to authenticated using(customer_id=auth.uid() and eventra_security.actor_role()='customer');
-- Preserve existing addresses without guessing their state/district.
insert into public.customer_addresses(customer_id,label,address_line,full_address,is_active)
select id,'Saved address',address,address,true from public.customers where nullif(trim(address),'') is not null;

create or replace function public.save_customer_address(p_id uuid,p_label text,p_address_line text,p_local_area text,p_pin_code text,p_state_id text,p_district_id text,p_subdistrict_id text,p_make_active boolean default false) returns uuid
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); result_id uuid:=coalesce(p_id,gen_random_uuid()); st text; dist text; sub text; formatted text; activate boolean; old_active boolean;
begin
 perform eventra_security.require_actor('customer');
 perform 1 from public.customers where id=actor for update;
 if not found then raise exception 'Customer not found'; end if;
 if p_id is not null then
  select is_active into old_active from public.customer_addresses where id=p_id and customer_id=actor;
  if not found then raise exception 'Address not found' using errcode='42501'; end if;
 elsif (select count(*) from public.customer_addresses where customer_id=actor)>=20 then raise exception 'Maximum 20 saved addresses'; end if;
 if p_label is null or length(trim(p_label)) not between 1 and 40 or p_address_line is null or length(trim(p_address_line)) not between 3 and 1000 or p_local_area is null or length(trim(p_local_area)) not between 2 and 200 or p_pin_code is null or p_pin_code !~ '^[0-9]{6}$' then raise exception 'Enter house/street, local area and a six-digit PIN code'; end if;
 select name into st from public.administrative_regions where id=p_state_id and level='state' and is_active;
 if st is null then raise exception 'Choose a valid state'; end if;
 select name into dist from public.administrative_regions where id=p_district_id and parent_id=p_state_id and level='district' and is_active;
 if dist is null then raise exception 'District does not belong to the chosen state'; end if;
 if p_subdistrict_id is not null then
  select name into sub from public.administrative_regions where id=p_subdistrict_id and parent_id=p_district_id and level='subdistrict' and is_active;
  if sub is null then raise exception 'Sub-district does not belong to the chosen district'; end if;
 end if;
 formatted:=concat_ws(', ',trim(p_address_line),trim(p_local_area),sub,dist,st)||' - '||p_pin_code;
 activate:=coalesce(p_make_active,false) or coalesce(old_active,false) or not exists(select 1 from public.customer_addresses where customer_id=actor and is_active);
 if activate then update public.customer_addresses set is_active=false where customer_id=actor and is_active; end if;
 insert into public.customer_addresses(id,customer_id,label,address_line,local_area,pin_code,state_id,district_id,subdistrict_id,state_name,district_name,subdistrict_name,full_address,is_active)
 values(result_id,actor,trim(p_label),trim(p_address_line),trim(p_local_area),p_pin_code,p_state_id,p_district_id,p_subdistrict_id,st,dist,sub,formatted,activate)
 on conflict(id) do update set label=excluded.label,address_line=excluded.address_line,local_area=excluded.local_area,pin_code=excluded.pin_code,state_id=excluded.state_id,district_id=excluded.district_id,subdistrict_id=excluded.subdistrict_id,state_name=excluded.state_name,district_name=excluded.district_name,subdistrict_name=excluded.subdistrict_name,full_address=excluded.full_address,is_active=excluded.is_active,updated_at=now();
 update public.customers set address=(select full_address from public.customer_addresses where customer_id=actor and is_active),updated_at=now() where id=actor;
 return result_id;
end $$;
create or replace function public.activate_customer_address(p_id uuid) returns void language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); value text;
begin
 perform eventra_security.require_actor('customer');
 perform 1 from public.customers where id=actor for update;
 select full_address into value from public.customer_addresses where id=p_id and customer_id=actor;
 if not found then raise exception 'Address not found' using errcode='42501'; end if;
 update public.customer_addresses set is_active=false where customer_id=actor and is_active;
 update public.customer_addresses set is_active=true,updated_at=now() where id=p_id and customer_id=actor;
 update public.customers set address=value,updated_at=now() where id=actor;
end $$;
create or replace function public.delete_customer_address(p_id uuid) returns void language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); was_active boolean; replacement uuid;
begin
 perform eventra_security.require_actor('customer');
 perform 1 from public.customers where id=actor for update;
 delete from public.customer_addresses where id=p_id and customer_id=actor returning is_active into was_active;
 if not found then raise exception 'Address not found' using errcode='42501'; end if;
 if was_active then
  select id into replacement from public.customer_addresses where customer_id=actor order by updated_at desc,id limit 1;
  update public.customer_addresses set is_active=true where id=replacement;
 end if;
 update public.customers set address=(select full_address from public.customer_addresses where customer_id=actor and is_active),updated_at=now() where id=actor;
end $$;
revoke all on function public.save_customer_address(uuid,text,text,text,text,text,text,text,boolean),public.activate_customer_address(uuid),public.delete_customer_address(uuid) from public,anon;
grant execute on function public.save_customer_address(uuid,text,text,text,text,text,text,text,boolean),public.activate_customer_address(uuid),public.delete_customer_address(uuid) to authenticated;
notify pgrst,'reload schema';
commit;
