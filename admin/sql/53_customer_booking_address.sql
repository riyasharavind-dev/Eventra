begin;
alter table public.bookings add column if not exists customer_address text;
create or replace function public.snapshot_booking_customer_address() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if tg_op='INSERT' then
  select nullif(trim(c.address),'') into new.customer_address from public.customers c where c.id=new.customer_id;
 else
  new.customer_address:=old.customer_address;
 end if;
 return new;
end $$;
revoke all on function public.snapshot_booking_customer_address() from public;
create trigger snapshot_customer_contact_address before insert or update on public.bookings for each row execute function public.snapshot_booking_customer_address();
notify pgrst,'reload schema';
commit;
