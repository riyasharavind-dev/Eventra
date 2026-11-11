begin;
do $$ declare definition text; needle text;
begin
 select pg_get_functiondef(oid) into definition from pg_proc where pronamespace='public'::regnamespace and proname='vendor_resolve_booking_change';
 needle:='update public.bookings set event_date=r.requested_date,event_start_time=r.requested_time,event_end_date=null,event_end_time=null where id=b.id;';
 if position(needle in definition)=0 then raise exception 'Unexpected reschedule workflow'; end if;
 definition:=replace(definition,needle,$n$
   update public.bookings set event_date=r.requested_date,event_start_time=r.requested_time,
    event_end_date=case when b.pricing_type='per_duration' then ((r.requested_date+r.requested_time)+case b.pricing_unit when 'hour' then make_interval(hours=>b.quantity) when 'day' then make_interval(days=>b.quantity) when 'week' then make_interval(weeks=>b.quantity) when 'month' then make_interval(months=>b.quantity) end)::date else null end,
    event_end_time=case when b.pricing_type='per_duration' then ((r.requested_date+r.requested_time)+case b.pricing_unit when 'hour' then make_interval(hours=>b.quantity) when 'day' then make_interval(days=>b.quantity) when 'week' then make_interval(weeks=>b.quantity) when 'month' then make_interval(months=>b.quantity) end)::time else null end where id=b.id;
 $n$);
 execute definition;
end $$;
create or replace function eventra_security.publish_customer_collection_change() returns trigger language plpgsql security definer set search_path='' as $$
begin
 perform eventra_security.touch_app_revision('user:'||coalesce(new.customer_id,old.customer_id)::text,'customer_service_collections');
 perform eventra_security.touch_app_revision('admin','customer_service_collections');
 return null;
end $$;
revoke all on function eventra_security.publish_customer_collection_change() from public,anon,authenticated;
drop trigger eventor_app_revision on public.customer_service_collections;
create trigger eventor_app_revision after insert or update or delete on public.customer_service_collections for each row execute function eventra_security.publish_customer_collection_change();
commit;
