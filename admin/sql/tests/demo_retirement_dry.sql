-- Retire only the five explicitly seeded anniversary fixtures; archive for recovery.
begin;
create table if not exists eventra_feed.retired_demo_rows(source text not null,id uuid not null,row_data jsonb not null,retired_at timestamptz not null default now(),primary key(source,id));
alter table eventra_feed.retired_demo_rows enable row level security;
revoke all on eventra_feed.retired_demo_rows from public,anon,authenticated;
do $$ declare i integer; bid uuid; uid uuid; b public.bookings;
begin
 for i in 1..5 loop
  bid:=('da120000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid;
  uid:=('da110000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid;
  select * into b from public.bookings where id=bid for update;
  if not found then continue; end if;
  if b.customer_id<>uid or b.service_id<>'46d3be9e-f501-4b06-83ff-241ab1ddb264'::uuid or b.location<>'[Demo] Anniversary event location' or not exists(select 1 from auth.users where id=uid and raw_user_meta_data->>'is_demo'='true' and email='anniversary-demo-'||i||'@example.invalid') then raise exception 'Fixture changed; cleanup stopped';end if;
  if exists(select 1 from public.service_reviews where booking_id=bid and review_text not like '[Demo review]%') then raise exception 'Review fixture changed; cleanup stopped';end if;
  insert into eventra_feed.retired_demo_rows(source,id,row_data) select 'service_reviews',id,to_jsonb(r) from public.service_reviews r where booking_id=bid on conflict do nothing;
  insert into eventra_feed.retired_demo_rows(source,id,row_data) values('bookings',bid,to_jsonb(b)) on conflict do nothing;
  delete from public.service_reviews where booking_id=bid;
  delete from public.bookings where id=bid;
 end loop;
end $$;
select (select count(*) from eventra_feed.retired_demo_rows) archived_rows,(select count(*) from public.service_reviews where customer_id::text like 'da110000-%') remaining_seed_reviews;
rollback;
