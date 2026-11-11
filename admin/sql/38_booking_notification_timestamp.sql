begin;
alter table public.bookings add column if not exists updated_at timestamptz;
update public.bookings set updated_at = coalesce(created_at, now()) where updated_at is null;
alter table public.bookings alter column updated_at set default now();
create or replace function public.stamp_booking_notification_update() returns trigger language plpgsql set search_path = pg_catalog as $$
begin
  if new.status is distinct from old.status then
    new.updated_at := clock_timestamp();
  else
    new.updated_at := old.updated_at;
  end if;
  return new;
end;
$$;
drop trigger if exists booking_notification_timestamp on public.bookings;
create trigger booking_notification_timestamp before update on public.bookings for each row execute function public.stamp_booking_notification_update();
revoke all on function public.stamp_booking_notification_update() from public;
grant select (updated_at) on public.bookings to authenticated;
notify pgrst, 'reload schema';
commit;
