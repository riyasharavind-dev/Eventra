begin;
drop trigger if exists trigger_notify_customer_booking_status on public.bookings;
create trigger trigger_notify_customer_booking_status after update of status,vendor_completed_at,quote_version,event_date,event_start_time on public.bookings for each row
when(old.status is distinct from new.status or old.vendor_completed_at is distinct from new.vendor_completed_at or old.quote_version is distinct from new.quote_version or old.event_date is distinct from new.event_date or old.event_start_time is distinct from new.event_start_time)
execute function public.notify_customer_booking_status();
commit;
