begin;
alter table public.bookings add column if not exists quantity integer not null default 1 check(quantity between 1 and 100000);
alter table public.bookings add column if not exists unit_price numeric;
alter table public.bookings add column if not exists pricing_type text not null default 'fixed';
alter table public.bookings add column if not exists pricing_unit text;
alter table public.bookings add column if not exists quote_amount numeric check(quote_amount>=0 and quote_amount<=1000000000);
alter table public.bookings add column if not exists quote_version integer not null default 0;
alter table public.bookings add column if not exists quote_approved_at timestamptz;


create or replace function eventra_security.booking_insert_guard() returns trigger language plpgsql security definer set search_path='' as $$
declare s public.services;
begin
 if current_setting('role',true) in ('anon','authenticated') then
  perform eventra_security.require_actor('customer');
  if new.customer_id is distinct from auth.uid() or new.status is distinct from 'pending' then raise exception 'Invalid booking owner or status' using errcode='42501';end if;
  select * into s from public.services where id=new.service_id for share;
  if not found or not eventra_security.public_service(s.id) or s.vendor_id is distinct from new.vendor_id or new.customer_id=new.vendor_id then raise exception 'Service is not available for booking' using errcode='42501';end if;
  if new.quantity is null or new.quantity not between 1 and 100000 or (s.pricing_type in ('fixed','starting_from') and new.quantity<>1) then raise exception 'Invalid quantity';end if;
  if new.price is null or new.price is distinct from s.price*new.quantity or new.price::text in ('NaN','Infinity','-Infinity') then raise exception 'Service price changed. Refresh before booking.' using errcode='22023';end if;
  new.unit_price:=s.price;new.pricing_type:=s.pricing_type;new.pricing_unit:=s.pricing_unit;
  if new.event_type_id is not null and new.event_type_id is distinct from s.event_type_id then raise exception 'Invalid event type' using errcode='22023';end if;
  new.event_type_id:=s.event_type_id;
 end if;
 return new;
end $$;

create or replace function public.customer_book_services(p_items jsonb,p_event_date date,p_guest_count integer,p_event_time time,p_location text,p_request_id text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); entry jsonb; svc public.services%rowtype; ids uuid[]:='{}'; existing uuid[]; booking_id uuid; item_count integer; qty integer; finish timestamp;
begin
 perform eventra_security.require_actor('customer');
 if p_request_id is null or length(p_request_id)<16 or length(p_request_id)>80 then raise exception 'Invalid booking request'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(actor::text||p_request_id,0));
 select booking_ids into existing from eventra_feed.customer_cart_checkouts where customer_id=actor and request_id=p_request_id;
 if found then return jsonb_build_object('booking_ids',existing); end if;
 if p_event_date is null or p_event_date<(now() at time zone 'Asia/Kolkata')::date or p_guest_count is null or p_guest_count<=0 then raise exception 'Choose a valid event date and guest count'; end if;
 if p_event_time is null or p_location is null or length(trim(p_location))<5 or length(p_location)>2000 then raise exception 'Choose event time and enter the event address'; end if;
 if p_event_date=(now() at time zone 'Asia/Kolkata')::date and p_event_time<(now() at time zone 'Asia/Kolkata')::time then raise exception 'Event time must be in the future'; end if;
 if jsonb_typeof(p_items) is distinct from 'array' then raise exception 'Invalid cart'; end if;
 item_count:=jsonb_array_length(p_items);
 if item_count<1 or item_count>30 then raise exception 'Choose between 1 and 30 services'; end if;
 if (select count(distinct x->>'id') from jsonb_array_elements(p_items) x)<>item_count then raise exception 'Duplicate cart services'; end if;
 -- A phone is required for coordination, never used as identity or role mapping.
 if not exists(select 1 from public.customers where id=actor and length(regexp_replace(coalesce(phone,''),'[^0-9]','','g')) between 10 and 15) then raise exception 'Add a valid contact phone in My Profile before booking'; end if;
 -- Lock in a consistent order; no booking is inserted until every item passes.
 for entry in select value from jsonb_array_elements(p_items) order by value->>'id' loop
  select * into svc from public.services where id=(entry->>'id')::uuid for share;
  if not found or not exists(select 1 from eventra_feed.eligible_services e where e.id=svc.id) or svc.vendor_id=actor then raise exception 'A service is no longer available. Refresh your cart.'; end if;
  qty:=coalesce((entry->>'quantity')::integer,1);
  if qty not between 1 and 100000 or (svc.pricing_type in ('fixed','starting_from') and qty<>1) then raise exception 'Invalid quantity or duration'; end if;
  if svc.price*qty>1000000000 then raise exception 'Booking total is too large'; end if;
  if svc.price is distinct from (entry->>'price')::numeric or svc.pricing_type is distinct from entry->>'pricing_type' or svc.pricing_unit is distinct from entry->>'pricing_unit' then raise exception 'Pricing changed. Refresh your cart before booking.'; end if;
 end loop;
 for entry in select value from jsonb_array_elements(p_items) order by value->>'id' loop
  select * into svc from public.services where id=(entry->>'id')::uuid;
  qty:=coalesce((entry->>'quantity')::integer,1);
  finish:=case when svc.pricing_type='per_duration' then (p_event_date+p_event_time)+case svc.pricing_unit when 'hour' then make_interval(hours=>qty) when 'day' then make_interval(days=>qty) when 'week' then make_interval(weeks=>qty) when 'month' then make_interval(months=>qty) end else null end;
  insert into public.bookings(event_end_date,event_end_time,quantity,unit_price,pricing_type,pricing_unit,customer_id,vendor_id,service_id,event_type_id,event_date,guest_count,price,status,location,event_start_time,event_timezone)
  values(finish::date,finish::time,qty,svc.price,svc.pricing_type,svc.pricing_unit,actor,svc.vendor_id,svc.id,svc.event_type_id,p_event_date,p_guest_count,svc.price*qty,'pending',trim(p_location),p_event_time,'Asia/Kolkata') returning id into booking_id;
  ids:=array_append(ids,booking_id);
 end loop;
 insert into eventra_feed.customer_cart_checkouts(customer_id,request_id,booking_ids) values(actor,p_request_id,ids);
 return jsonb_build_object('booking_ids',ids);
end $$;
revoke all on function public.customer_book_services(jsonb,date,integer,time,text,text) from public,anon;
grant execute on function public.customer_book_services(jsonb,date,integer,time,text,text) to authenticated;


create or replace function public.vendor_set_booking_quote(p_booking_id uuid,p_amount numeric,p_expected_version integer) returns void language plpgsql security definer set search_path='' as $$
declare b public.bookings;
begin
 perform eventra_security.require_actor('vendor');
 select * into b from public.bookings where id=p_booking_id and vendor_id=auth.uid() for update;
 if not found or b.status<>'pending' or b.pricing_type<>'starting_from' then raise exception 'Quote cannot be changed for this booking'; end if;
 if b.quote_version<>p_expected_version then raise exception 'Quote changed. Refresh first'; end if;
 if p_amount is null or p_amount<0 or p_amount>1000000000 then raise exception 'Invalid quote amount'; end if;
 update public.bookings set quote_amount=round(p_amount,2),quote_version=quote_version+1,quote_approved_at=null where id=b.id;
end $$;
create or replace function public.customer_approve_booking_quote(p_booking_id uuid,p_expected_version integer) returns void language plpgsql security definer set search_path='' as $$
declare b public.bookings;
begin
 perform eventra_security.require_actor('customer');
 select * into b from public.bookings where id=p_booking_id and customer_id=auth.uid() for update;
 if not found or b.status<>'pending' or b.quote_amount is null or b.quote_version<>p_expected_version then raise exception 'Quote changed or unavailable. Refresh first'; end if;
 update public.bookings set price=quote_amount,quote_approved_at=coalesce(quote_approved_at,clock_timestamp()) where id=b.id;
end $$;
-- Preserve the existing overlap, ownership, status and completion checks.
do $$ declare def text;
begin
 select pg_get_functiondef(oid) into def from pg_proc where pronamespace='public'::regnamespace and proname='change_vendor_booking_status';
 if position('Quote approval required' in def)=0 then
  def:=replace(def,'if p_status=''accepted'' then',
   'if p_status=''accepted'' and b.pricing_type=''starting_from'' and (b.quote_amount is null or b.quote_approved_at is null) then raise exception ''Quote approval required before acceptance''; end if; if p_status=''accepted'' then');
  execute def;
 end if;
end $$;
create table if not exists public.booking_change_requests(
 id uuid primary key default gen_random_uuid(),booking_id uuid not null references public.bookings(id),customer_id uuid not null references public.customers(id),
 kind text not null check(kind in ('cancel','reschedule')),reason text not null check(length(reason) between 3 and 1000),
 requested_date date,requested_time time,status text not null default 'pending' check(status in ('pending','approved','rejected','withdrawn')),
 created_at timestamptz not null default now(),resolved_at timestamptz
);
create unique index if not exists one_pending_booking_change on public.booking_change_requests(booking_id) where status='pending';
alter table public.booking_change_requests enable row level security;
revoke all on public.booking_change_requests from public,anon,authenticated;
grant select on public.booking_change_requests to authenticated;
create policy booking_change_read on public.booking_change_requests for select to authenticated using(customer_id=auth.uid() or exists(select 1 from public.bookings b where b.id=booking_id and b.vendor_id=auth.uid()));
create or replace function public.customer_request_booking_change(p_booking_id uuid,p_kind text,p_reason text,p_date date default null,p_time time default null) returns uuid language plpgsql security definer set search_path='' as $$
declare b public.bookings; result uuid;
begin
 perform eventra_security.require_actor('customer');
 select * into b from public.bookings where id=p_booking_id and customer_id=auth.uid() for update;
 if not found or b.status not in ('pending','accepted') or b.vendor_completed_at is not null then raise exception 'Booking cannot be changed'; end if;
 if p_kind is null or p_kind not in ('cancel','reschedule') or length(trim(coalesce(p_reason,''))) not between 3 and 1000 then raise exception 'Choose a request and enter a reason'; end if;
 if p_kind='reschedule' and (p_date is null or p_time is null or (p_date+p_time) at time zone 'Asia/Kolkata'<=now()) then raise exception 'Choose a future date and time'; end if;
 insert into public.booking_change_requests(booking_id,customer_id,kind,reason,requested_date,requested_time) values(b.id,auth.uid(),p_kind,trim(p_reason),p_date,p_time) returning id into result;
 -- Touch the already observed dataset for both parties.
 update public.bookings set updated_at=clock_timestamp() where id=b.id;
 return result;
end $$;
create or replace function public.vendor_resolve_booking_change(p_request_id uuid,p_approve boolean,p_ack_overlap boolean default false) returns void language plpgsql security definer set search_path='' as $$
declare b public.bookings; r public.booking_change_requests;
begin
 perform eventra_security.require_actor('vendor');
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,72));
 select b0.* into b from public.bookings b0 join public.booking_change_requests r0 on r0.booking_id=b0.id where r0.id=p_request_id and b0.vendor_id=auth.uid() for update of b0;
 if not found then raise exception 'Booking not found'; end if;
 select * into r from public.booking_change_requests where id=p_request_id for update;
 if r.status<>'pending' then raise exception 'Request already resolved'; end if;
 if p_approve is null then raise exception 'Choose approve or reject'; end if;
 if p_approve then
  if b.status not in ('pending','accepted') or b.vendor_completed_at is not null then raise exception 'Booking is no longer changeable'; end if;
  if r.kind='cancel' then
   update public.bookings set status='cancelled',status_reason=r.reason where id=b.id;
  else
   if (r.requested_date+r.requested_time) at time zone 'Asia/Kolkata'<=now() then raise exception 'Requested time has passed'; end if;
   update public.bookings set event_date=r.requested_date,event_start_time=r.requested_time,event_end_date=null,event_end_time=null where id=b.id;
   if b.status='accepted' and jsonb_array_length(public.get_vendor_booking_conflicts(b.id))>0 and not p_ack_overlap then raise exception 'Another accepted event overlaps. Review the calendar before approving'; end if;
  end if;
 end if;
 update public.booking_change_requests set status=case when p_approve then 'approved' else 'rejected' end,resolved_at=clock_timestamp() where id=r.id;
 update public.bookings set updated_at=clock_timestamp() where id=b.id;
end $$;
create or replace function public.customer_withdraw_booking_change(p_request_id uuid) returns void language plpgsql security definer set search_path='' as $$
declare bid uuid;
begin
 perform eventra_security.require_actor('customer');
 select booking_id into bid from public.booking_change_requests where id=p_request_id and customer_id=auth.uid();
 if bid is null then raise exception 'Request not found'; end if;
 perform 1 from public.bookings where id=bid for update;
 update public.booking_change_requests set status='withdrawn',resolved_at=now() where id=p_request_id and customer_id=auth.uid() and status='pending';
 update public.bookings set updated_at=clock_timestamp() where id=bid;
end $$;
-- Vendor contact is returned only to the owner of a booking; no public phone list.
create or replace function public.customer_booking_contact(p_booking_id uuid) returns text language plpgsql stable security definer set search_path='' as $$
begin
 perform eventra_security.require_actor('customer');
 return (select v.phone from public.vendors v join public.bookings b on b.vendor_id=v.id where b.id=p_booking_id and b.customer_id=auth.uid());
end $$;
alter table public.support_tickets add column if not exists booking_id uuid references public.bookings(id);
create or replace function public.customer_booking_issue(p_booking_id uuid,p_request_id uuid,p_description text) returns uuid language plpgsql security definer set search_path='' as $$
declare tid uuid;
begin
 perform eventra_security.require_actor('customer');
 if not exists(select 1 from public.bookings where id=p_booking_id and customer_id=auth.uid()) then raise exception 'Booking not found'; end if;
 if length(trim(coalesce(p_description,''))) not between 10 and 5000 then raise exception 'Describe the issue (10 to 5000 characters)'; end if;
 select id into tid from public.support_tickets where id=p_request_id and user_id=auth.uid();
 if found then return tid; end if;
 insert into public.support_tickets(id,user_id,booking_id,category,subject,description) values(p_request_id,auth.uid(),p_booking_id,'Bookings','Booking issue #'||left(p_booking_id::text,8),trim(p_description)) returning id into tid;
 return tid;
end $$;
create table if not exists public.customer_service_collections(
 customer_id uuid not null references public.customers(id) on delete cascade,service_id uuid not null references public.services(id) on delete cascade,
 kind text not null check(kind in ('saved','added')),updated_at timestamptz not null default now(),primary key(customer_id,service_id,kind)
);
alter table public.customer_service_collections enable row level security;
revoke all on public.customer_service_collections from public,anon,authenticated;
grant select on public.customer_service_collections to authenticated;
create policy own_service_collection on public.customer_service_collections for select to authenticated using(customer_id=auth.uid());
create or replace function public.customer_update_service_collection(p_service_id uuid,p_kind text,p_present boolean) returns void language plpgsql security definer set search_path='' as $$
begin
 perform eventra_security.require_actor('customer');
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,573));
 if p_kind is null or p_kind not in ('saved','added') or p_present is null then raise exception 'Invalid collection'; end if;
 if p_present then
  if not exists(select 1 from eventra_feed.eligible_services where id=p_service_id) then raise exception 'Service unavailable'; end if;
  if not exists(select 1 from public.customer_service_collections where customer_id=auth.uid() and service_id=p_service_id and kind=p_kind) and (select count(*) from public.customer_service_collections where customer_id=auth.uid() and kind=p_kind)>=(case when p_kind='added' then 30 else 500 end) then raise exception 'Collection limit reached'; end if;
  insert into public.customer_service_collections(customer_id,service_id,kind) values(auth.uid(),p_service_id,p_kind) on conflict do nothing;
 else delete from public.customer_service_collections where customer_id=auth.uid() and service_id=p_service_id and kind=p_kind;
 end if;
end $$;
do $$ declare signature regprocedure;
begin
 for signature in select oid::regprocedure from pg_proc where pronamespace='public'::regnamespace and proname in('vendor_set_booking_quote','customer_approve_booking_quote','customer_request_booking_change','vendor_resolve_booking_change','customer_withdraw_booking_change','customer_booking_contact','customer_booking_issue','customer_update_service_collection') loop
  execute format('revoke all on function %s from public,anon',signature);
  execute format('grant execute on function %s to authenticated',signature);
 end loop;
end $$;
create trigger eventor_app_revision after insert or update or delete on public.booking_change_requests for each row execute function eventra_security.publish_app_change();
create trigger eventor_app_revision after insert or update or delete on public.customer_service_collections for each row execute function eventra_security.publish_app_change();
notify pgrst,'reload schema';
commit;

