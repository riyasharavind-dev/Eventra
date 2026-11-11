begin;
create extension if not exists pg_cron;
select cron.schedule('eventor-booking-push-retry','*/2 * * * *','select public.retry_booking_push()');
create index if not exists booking_push_retry_idx on public.booking_push_outbox(status,created_at) where status<>'sent';
create or replace function public.claim_booking_push(p_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare row public.booking_push_outbox;
begin
 if auth.role()<>'service_role' then raise exception 'Forbidden' using errcode='42501'; end if;
 -- Retry only the latest event for a booking, so an old acceptance cannot replace a newer cancellation.
 update public.booking_push_outbox o set status='sent',sent_at=clock_timestamp() where o.id=p_id and o.status='pending' and exists(select 1 from public.booking_push_outbox n where n.booking_id=o.booking_id and (n.created_at,n.id)>(o.created_at,o.id));
 update public.booking_push_outbox set status='processing',attempts=attempts+1,attempted_at=clock_timestamp()
 where id=p_id and attempts<5 and (status='pending' or (status='processing' and attempted_at<now()-interval '5 minutes')) returning * into row;
 return to_jsonb(row);
end $$;
do $$ declare def text;
begin
 select pg_get_functiondef(oid) into def from pg_proc where pronamespace='public'::regnamespace and proname='notify_customer_booking_status';
 def:=replace(def,$n$else return new;$n$,$n$
 elsif old.event_date is distinct from new.event_date or old.event_start_time is distinct from new.event_start_time then
  kind:='booking_rescheduled';heading:='Event Rescheduled';message:='Your approved event schedule has changed. Open Booking Details for the new date and time.';
 else return new;
 $n$);
 execute def;
end $$;
commit;
