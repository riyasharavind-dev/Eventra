begin;
create or replace function public.customer_signup_contact() returns trigger language plpgsql security definer set search_path='' as $$
declare contact text;
begin
 if nullif(trim(new.phone),'') is null then
  select raw_user_meta_data->>'phone' into contact from auth.users where id=new.id and raw_user_meta_data->>'role'='customer';
  if contact ~ '^\+[1-9][0-9]{9,14}$' then new.phone:=contact;end if;
 end if;
 return new;
end $$;
revoke all on function public.customer_signup_contact() from public,anon,authenticated;
drop trigger if exists customer_signup_contact on public.customers;
create trigger customer_signup_contact before insert on public.customers for each row execute function public.customer_signup_contact();
commit;
