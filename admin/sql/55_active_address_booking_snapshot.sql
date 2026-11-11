create or replace function public.snapshot_booking_customer_address() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if tg_op='INSERT' then
  select coalesce((select a.full_address from public.customer_addresses a where a.customer_id=new.customer_id and a.is_active),nullif(trim(c.address),'')) into new.customer_address from public.customers c where c.id=new.customer_id;
 else new.customer_address:=old.customer_address;
 end if;
 return new;
end $$;
revoke all on function public.snapshot_booking_customer_address() from public;
