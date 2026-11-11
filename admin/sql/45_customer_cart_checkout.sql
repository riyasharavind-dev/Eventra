begin;
create table if not exists eventra_feed.customer_cart_checkouts (
 customer_id uuid not null references public.customers(id) on delete cascade,
 request_id text not null, booking_ids uuid[] not null, created_at timestamptz not null default now(),
 primary key(customer_id,request_id)
);
alter table eventra_feed.customer_cart_checkouts enable row level security;
revoke all on eventra_feed.customer_cart_checkouts from public,anon,authenticated;
create or replace function public.customer_book_cart(p_items jsonb,p_event_date date,p_guest_count integer,p_requirement text,p_request_id text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); entry jsonb; svc public.services%rowtype; ids uuid[]:='{}'; existing uuid[]; booking_id uuid; item_count integer;
begin
 perform eventra_security.require_actor('customer');
 if p_request_id is null or length(p_request_id)<16 or length(p_request_id)>80 then raise exception 'Invalid booking request'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(actor::text||p_request_id,0));
 select booking_ids into existing from eventra_feed.customer_cart_checkouts where customer_id=actor and request_id=p_request_id;
 if found then return jsonb_build_object('booking_ids',existing); end if;
 if p_event_date is null or p_event_date<(now() at time zone 'Asia/Kolkata')::date or p_guest_count is null or p_guest_count<=0 then raise exception 'Choose a valid event date and guest count'; end if;
 if jsonb_typeof(p_items) is distinct from 'array' then raise exception 'Invalid cart'; end if;
 item_count:=jsonb_array_length(p_items);
 if item_count<1 or item_count>30 or length(coalesce(p_requirement,''))>10000 then raise exception 'Choose between 1 and 30 services'; end if;
 if (select count(distinct x->>'id') from jsonb_array_elements(p_items) x)<>item_count then raise exception 'Duplicate cart services'; end if;
 -- Lock in a consistent order; no booking is inserted until every item passes.
 for entry in select value from jsonb_array_elements(p_items) order by value->>'id' loop
  select * into svc from public.services where id=(entry->>'id')::uuid for share;
  if not found or not exists(select 1 from eventra_feed.eligible_services e where e.id=svc.id) or svc.vendor_id=actor then raise exception 'A service is no longer available. Refresh your cart.'; end if;
  if svc.price is distinct from (entry->>'price')::numeric or svc.pricing_type is distinct from entry->>'pricing_type' or svc.pricing_unit is distinct from entry->>'pricing_unit' then raise exception 'Pricing changed. Refresh your cart before booking.'; end if;
 end loop;
 for entry in select value from jsonb_array_elements(p_items) order by value->>'id' loop
  select * into svc from public.services where id=(entry->>'id')::uuid;
  insert into public.bookings(customer_id,vendor_id,service_id,event_type_id,event_date,guest_count,requirement,price,status,location)
  values(actor,svc.vendor_id,svc.id,svc.event_type_id,p_event_date,p_guest_count,nullif(trim(p_requirement),''),svc.price,'pending','') returning id into booking_id;
  ids:=array_append(ids,booking_id);
 end loop;
 insert into eventra_feed.customer_cart_checkouts(customer_id,request_id,booking_ids) values(actor,p_request_id,ids);
 return jsonb_build_object('booking_ids',ids);
end $$;
revoke all on function public.customer_book_cart(jsonb,date,integer,text,text) from public,anon;
grant execute on function public.customer_book_cart(jsonb,date,integer,text,text) to authenticated;
notify pgrst,'reload schema';
commit;
