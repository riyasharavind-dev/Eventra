-- Explicitly labelled sample records requested for UI review.
begin;
set local lock_timeout='5s';
do $$
declare svc public.services%rowtype; uid uuid; bid uuid; i integer; stars integer[]:=array[5,4,5,4,5]; comments text[]:=array[
 '[Demo review] The anniversary stage looked beautiful and matched our chosen theme.',
 '[Demo review] Good decoration and friendly coordination. The overall setup was neat.',
 '[Demo review] Loved the flowers and lighting. A lovely backdrop for our photos.',
 '[Demo review] The team understood our requirements and arranged the setup nicely.',
 '[Demo review] Very happy with the anniversary decoration and colour combination.'
]; muted text[]:='{}'; t record; trigger_name text;
begin
 select * into svc from public.services where id='46d3be9e-f501-4b06-83ff-241ab1ddb264';
 if svc.id is null or svc.name<>'Wedding Anniversary' then raise exception 'Expected service not found'; end if;
 -- Do not send vendor/customer booking alerts for synthetic fixtures.
 for t in select tgname from pg_trigger where tgrelid='public.bookings'::regclass and tgenabled='O' and tgname in('trigger_notify_vendor_new_booking','trigger_notify_customer_booking_status') loop
  execute format('alter table public.bookings disable trigger %I',t.tgname); muted:=array_append(muted,t.tgname);
 end loop;
 for i in 1..5 loop
  uid:=('da110000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid;
  bid:=('da120000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid;
  insert into auth.users(id,email,raw_user_meta_data,banned_until) values(uid,'anniversary-demo-'||i||'@example.invalid',jsonb_build_object('role','customer','name','Demo Customer '||i,'is_demo',true),'infinity'::timestamptz) on conflict(id) do nothing;
  insert into public.bookings(id,customer_id,vendor_id,service_id,business_id,event_date,price,status,location,created_at)
  values(bid,uid,svc.vendor_id,svc.id,svc.business_id,current_date-i,svc.price,'completed','[Demo] Anniversary event location',now()-make_interval(days=>i)) on conflict(id) do nothing;
  insert into public.service_reviews(booking_id,customer_id,vendor_id,service_id,business_id,rating,review_text,created_at,updated_at)
  values(bid,uid,svc.vendor_id,svc.id,svc.business_id,stars[i],comments[i],now()-make_interval(days=>i),now()-make_interval(days=>i)) on conflict(booking_id) do nothing;
 end loop;
 foreach trigger_name in array muted loop
  execute format('alter table public.bookings enable trigger %I',trigger_name);
 end loop;
end $$;
select count(*) demo_reviews,round(avg(rating)::numeric,1) demo_average from public.service_reviews where service_id='46d3be9e-f501-4b06-83ff-241ab1ddb264' and customer_id::text like 'da110000-%';
commit;
