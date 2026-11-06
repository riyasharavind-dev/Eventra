-- Apply after review: participant-scoped booking access and Realtime.
-- Existing booking guard triggers continue to validate writes.
begin;
alter table public.bookings enable row level security;
drop policy if exists eventra_booking_participant_read on public.bookings;
create policy eventra_booking_participant_read on public.bookings for select to authenticated
using (customer_id = (select auth.uid()) or vendor_id = (select auth.uid()) or public.eventra_is_admin());
drop policy if exists eventra_booking_customer_insert on public.bookings;
create policy eventra_booking_customer_insert on public.bookings for insert to authenticated
with check (customer_id = (select auth.uid()) or public.eventra_is_admin());
drop policy if exists eventra_booking_participant_update on public.bookings;
create policy eventra_booking_participant_update on public.bookings for update to authenticated
using (customer_id = (select auth.uid()) or vendor_id = (select auth.uid()) or public.eventra_is_admin())
with check (customer_id = (select auth.uid()) or vendor_id = (select auth.uid()) or public.eventra_is_admin());
drop policy if exists eventra_booking_admin_delete on public.bookings;
create policy eventra_booking_admin_delete on public.bookings for delete to authenticated
using (public.eventra_is_admin());
do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'bookings') then
    alter publication supabase_realtime add table public.bookings;
  end if;
end $$;
commit;