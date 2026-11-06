begin;
create or replace function public.get_my_account_role() returns text language sql stable security definer set search_path='' as $$ select role::text from public.users where id=auth.uid() $$;
revoke all on function public.get_my_account_role() from public, anon;
grant execute on function public.get_my_account_role() to authenticated;
create or replace function public.protect_account_role() returns trigger language plpgsql set search_path='' as $$
begin
 if new.role is distinct from old.role and current_user in ('authenticated','anon') then
  raise exception 'Account type cannot be changed';
 end if;
 return new;
end $$;
drop trigger if exists protect_account_role on public.users;
create trigger protect_account_role before update on public.users for each row execute function public.protect_account_role();
commit;
