begin;
create or replace function public.save_customer_profile(
  p_name text, p_phone text, p_avatar_url text default null
) returns jsonb language plpgsql security invoker set search_path='' as $$
declare
  account_id uuid := auth.uid();
  profile public.customers;
begin
  if account_id is null then
    raise exception 'Sign in required' using errcode='42501';
  end if;
  if nullif(btrim(p_name), '') is null then
    raise exception 'Name is required' using errcode='22023';
  end if;
  update public.customers set
    name=btrim(p_name), phone=nullif(btrim(p_phone), ''),
    avatar_url=coalesce(p_avatar_url, avatar_url), updated_at=now()
  where id=account_id returning * into profile;
  if not found then
    raise exception 'Customer profile unavailable' using errcode='42501';
  end if;
  update public.users set name=profile.name where id=account_id;
  if not found then
    raise exception 'Customer account unavailable' using errcode='42501';
  end if;
  return to_jsonb(profile);
end $$;
revoke all on function public.save_customer_profile(text,text,text) from public, anon;
grant execute on function public.save_customer_profile(text,text,text) to authenticated;
notify pgrst, 'reload schema';
commit;
