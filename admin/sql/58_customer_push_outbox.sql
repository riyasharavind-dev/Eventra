begin;
create table public.booking_push_outbox(
 id uuid primary key default gen_random_uuid(),booking_id uuid not null references public.bookings(id),customer_id uuid not null,
 event_type text not null,status text not null default 'pending' check(status in ('pending','processing','sent')),
 title text not null,body text not null,attempts integer not null default 0,created_at timestamptz not null default now(),attempted_at timestamptz,sent_at timestamptz
);
alter table public.booking_push_outbox enable row level security;
revoke all on public.booking_push_outbox from public,anon,authenticated;
grant select,update on public.booking_push_outbox to service_role;
create or replace function public.claim_booking_push(p_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare row public.booking_push_outbox;
begin
 if auth.role()<>'service_role' then raise exception 'Forbidden' using errcode='42501'; end if;
 update public.booking_push_outbox set status='processing',attempts=attempts+1,attempted_at=clock_timestamp()
 where id=p_id and attempts<5 and (status='pending' or (status='processing' and attempted_at<now()-interval '5 minutes')) returning * into row;
 return to_jsonb(row);
end $$;
revoke all on function public.claim_booking_push(uuid) from public,anon,authenticated;
grant execute on function public.claim_booking_push(uuid) to service_role;
create or replace function public.notify_customer_booking_status() returns trigger language plpgsql security definer set search_path='' as $$
declare eid uuid; kind text; heading text; message text;
begin
 if old.vendor_completed_at is null and new.vendor_completed_at is not null and new.status='accepted' then
  kind:='completion_requested';heading:='Confirm Event Completion';message:='Your vendor marked the service as complete. Please confirm in Bookings.';
 elsif old.quote_version is distinct from new.quote_version and new.quote_amount is not null then
  kind:='quote_updated';heading:='Final Quote Ready';message:='Review and approve the vendor final quote in Booking Details.';
 elsif old.status is distinct from new.status and new.status in ('accepted','rejected','cancelled','completed') then
  kind:='booking_'||new.status;heading:='Booking '||initcap(new.status);message:='Open Booking Details to view the latest update.';
 else return new;
 end if;
 insert into public.booking_push_outbox(booking_id,customer_id,event_type,title,body) values(new.id,new.customer_id,kind,heading,message) returning id into eid;
 perform net.http_post(url:='https://hrrimcxwpfdikbmywznf.supabase.co/functions/v1/send-booking-status-notification',headers:='{"Content-Type":"application/json"}'::jsonb,body:=jsonb_build_object('event_id',eid));
 return new;
end $$;
-- Retries are bounded; completed sends cannot be replayed by resubmitting an event ID.
create or replace function public.retry_booking_push() returns void language plpgsql security definer set search_path='' as $$
declare r record;
begin
 for r in select id from public.booking_push_outbox where attempts<5 and ((status='pending' and coalesce(attempted_at,created_at)<now()-interval '2 minutes') or (status='processing' and attempted_at<now()-interval '5 minutes')) order by created_at limit 50 loop
  perform net.http_post(url:='https://hrrimcxwpfdikbmywznf.supabase.co/functions/v1/send-booking-status-notification',headers:='{"Content-Type":"application/json"}'::jsonb,body:=jsonb_build_object('event_id',r.id));
 end loop;
 delete from public.booking_push_outbox where created_at<now()-interval '30 days';
end $$;
revoke all on function public.retry_booking_push() from public,anon,authenticated;
do $$ begin
 if exists(select 1 from pg_extension where extname='pg_cron') then
  perform cron.schedule('eventor-booking-push-retry','*/2 * * * *','select public.retry_booking_push()');
 end if;
end $$;
commit;
