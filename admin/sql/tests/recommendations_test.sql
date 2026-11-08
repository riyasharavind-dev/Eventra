begin;
create temporary table recommendation_checks(label text);
grant select,insert on recommendation_checks to anon,authenticated;
create function pg_temp.check_rec(ok boolean,label text) returns void language plpgsql as $$
begin if ok is distinct from true then raise exception 'FAILED: %',label; end if;insert into recommendation_checks values(label);end $$;
create function pg_temp.denied_rec(command text,label text) returns void language plpgsql as $$
declare denied boolean:=false;
begin begin execute command;exception when insufficient_privilege or invalid_parameter_value then denied:=true;end;
perform pg_temp.check_rec(denied,label);end $$;
insert into auth.users(id,email,raw_user_meta_data,email_confirmed_at) values
 ('71000000-0000-4000-8000-000000000001','rec-v1@example.invalid','{"role":"vendor","name":"Rec Vendor 1"}',now()),
 ('71000000-0000-4000-8000-000000000002','rec-v2@example.invalid','{"role":"vendor","name":"Rec Vendor 2"}',now()),
 ('71000000-0000-4000-8000-000000000003','rec-c1@example.invalid','{"role":"customer","name":"Rec Customer 1"}',now()),
 ('71000000-0000-4000-8000-000000000004','rec-c2@example.invalid','{"role":"customer","name":"Rec Customer 2"}',now());
insert into public.category_nodes(id,name,slug) values
 ('71000000-0000-4000-8000-000000000010','Recommendation Root','recommendation-test-root'),
 ('71000000-0000-4000-8000-000000000012','Unrelated Root','recommendation-test-other');
insert into public.category_nodes(id,parent_id,name,slug) values
 ('71000000-0000-4000-8000-000000000011','71000000-0000-4000-8000-000000000010','Recommendation Leaf','recommendation-test-leaf'),
 ('71000000-0000-4000-8000-000000000013','71000000-0000-4000-8000-000000000010','Recommendation Sibling','recommendation-test-sibling');
insert into public.businesses(id,vendor_id,name) values
 ('71000000-0000-4000-8000-000000000020','71000000-0000-4000-8000-000000000001','Rec Business 1'),
 ('71000000-0000-4000-8000-000000000021','71000000-0000-4000-8000-000000000002','Rec Business 2');
insert into public.businesses(id,vendor_id,name) values
 ('71000000-0000-4000-8000-000000000022','71000000-0000-4000-8000-000000000002','Rec Other Business');
insert into public.business_category_nodes(business_id,category_node_id) values
 ('71000000-0000-4000-8000-000000000020','71000000-0000-4000-8000-000000000010'),
 ('71000000-0000-4000-8000-000000000021','71000000-0000-4000-8000-000000000010'),
 ('71000000-0000-4000-8000-000000000022','71000000-0000-4000-8000-000000000012');
insert into public.services(id,vendor_id,business_id,category_node_id,name,slug,price,pricing_type,pricing_unit,is_active) values
 ('71000000-0000-4000-8000-000000000030','71000000-0000-4000-8000-000000000001','71000000-0000-4000-8000-000000000020','71000000-0000-4000-8000-000000000011','Rec Anchor','rec-test-anchor',100,'per_unit','chair',true),
 ('71000000-0000-4000-8000-000000000031','71000000-0000-4000-8000-000000000002','71000000-0000-4000-8000-000000000021','71000000-0000-4000-8000-000000000011','Rec Exact','rec-test-exact',100,'per_unit','chair',true),
 ('71000000-0000-4000-8000-000000000032','71000000-0000-4000-8000-000000000001','71000000-0000-4000-8000-000000000020','71000000-0000-4000-8000-000000000013','Rec Sibling','rec-test-sibling',100,'fixed',null,true),
 ('71000000-0000-4000-8000-000000000033','71000000-0000-4000-8000-000000000002','71000000-0000-4000-8000-000000000022','71000000-0000-4000-8000-000000000012','Rec Discovery','rec-test-discovery',100,'fixed',null,true),
 ('71000000-0000-4000-8000-000000000034','71000000-0000-4000-8000-000000000001','71000000-0000-4000-8000-000000000020','71000000-0000-4000-8000-000000000011','Rec Hidden','rec-test-hidden',100,'fixed',null,false);
set local role anon;
select set_config('request.jwt.claims','{}',true);
select pg_temp.check_rec(jsonb_array_length(public.customer_recommendations()->'items')>0,'guest cold-start works');
select pg_temp.check_rec(not (public.customer_recommendations()->>'personalized')::boolean,'guest has no personalization');
select pg_temp.check_rec(jsonb_array_length(public.customer_recommendations(null,0,3)->'items')=3,'page size bounded');
select pg_temp.check_rec((public.customer_recommendations(null,0,3)->>'next_offset')::int=3,'cursor advances');
select pg_temp.check_rec(public.customer_recommendations('71000000-0000-4000-8000-000000000030',0,3)->'items'->0->>'id'='71000000-0000-4000-8000-000000000031','exact category and compatible price rank first');
select pg_temp.check_rec(not exists(select 1 from jsonb_array_elements(public.customer_recommendations('71000000-0000-4000-8000-000000000030',0,20)->'items') j where j->>'id'='71000000-0000-4000-8000-000000000030'),'anchor excluded');
select pg_temp.check_rec(not exists(select 1 from jsonb_array_elements(public.customer_recommendations(null,0,20)->'items') j where j->>'id'='71000000-0000-4000-8000-000000000034'),'inactive excluded');
select pg_temp.check_rec(public.customer_recommendations('71000000-0000-4000-8000-000000000030',0,3)->'items'->0->'service'->>'pricing_unit'='chair','unit pricing retained');
select pg_temp.check_rec(jsonb_array_length(public.customer_recommendations('71000000-0000-4000-8000-000000000034')->'items')=0,'unavailable anchor returns no data');
select pg_temp.denied_rec('select public.customer_recommendations(null,-1,3)','negative offset rejected');
select pg_temp.denied_rec('select public.customer_recommendations(null,0,21)','oversized limit rejected');
select pg_temp.denied_rec('select public.customer_recommendations(null,0,null)','null limit rejected');
select pg_temp.denied_rec('select * from eventra_feed.customer_service_signals','guest history reads denied');
select pg_temp.denied_rec($q$select public.customer_service_signal('71000000-0000-4000-8000-000000000030','view')$q$,'guest writes denied');
reset role;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"71000000-0000-4000-8000-000000000003","role":"authenticated"}',true);
select pg_temp.check_rec(not (public.customer_recommendations()->>'personalized')::boolean,'new customer fallback');
select public.customer_service_signal('71000000-0000-4000-8000-000000000030','view');
select public.customer_service_signal('71000000-0000-4000-8000-000000000030','view');
select pg_temp.check_rec((public.customer_recommendations()->>'personalized')::boolean,'views personalize home');
select pg_temp.check_rec(exists(select 1 from jsonb_array_elements(public.customer_recommendations()->'items') j where j->>'reason'='Based on your interests'),'interest matches returned');
select pg_temp.denied_rec('select * from eventra_feed.customer_service_signals','authenticated direct history reads denied');
select pg_temp.denied_rec($q$select public.customer_service_signal('71000000-0000-4000-8000-000000000030','fake')$q$,'arbitrary signals rejected');
select public.customer_service_signal('71000000-0000-4000-8000-000000000031','save');
reset role;
select pg_temp.check_rec((select count(*)=1 from eventra_feed.customer_service_signals where customer_id='71000000-0000-4000-8000-000000000003' and service_id='71000000-0000-4000-8000-000000000030'),'duplicate views use one bounded row');
select pg_temp.check_rec((select saved_at is not null from eventra_feed.customer_service_signals where customer_id='71000000-0000-4000-8000-000000000003' and service_id='71000000-0000-4000-8000-000000000031'),'save signal stored');
update eventra_feed.customer_service_signals set viewed_at=now()-interval '1 minute',updated_at=now()-interval '1 minute' where customer_id='71000000-0000-4000-8000-000000000003' and service_id='71000000-0000-4000-8000-000000000030';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"71000000-0000-4000-8000-000000000003","role":"authenticated"}',true);
select public.customer_service_signal('71000000-0000-4000-8000-000000000030','view');
select public.customer_service_signal('71000000-0000-4000-8000-000000000031','unsave');
reset role;
select pg_temp.check_rec((select viewed_at=now()-interval '1 minute' from eventra_feed.customer_service_signals where customer_id='71000000-0000-4000-8000-000000000003' and service_id='71000000-0000-4000-8000-000000000030'),'view writes throttled ten minutes');
select pg_temp.check_rec((select saved_at is null from eventra_feed.customer_service_signals where customer_id='71000000-0000-4000-8000-000000000003' and service_id='71000000-0000-4000-8000-000000000031'),'unsave removes favorite weight');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"71000000-0000-4000-8000-000000000004","role":"authenticated"}',true);
select pg_temp.check_rec(not (public.customer_recommendations()->>'personalized')::boolean,'second customer cannot inherit first customer history');
select public.customer_service_signal('71000000-0000-4000-8000-000000000033','save');
reset role;
select pg_temp.check_rec((select count(*)=1 from eventra_feed.customer_service_signals where customer_id='71000000-0000-4000-8000-000000000004'),'writes use caller identity');

-- Exercise the per-customer storage cap with synthetic data, all rolled back.
insert into public.services(id,vendor_id,business_id,category_node_id,name,slug,price)
select ('71000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 '71000000-0000-4000-8000-000000000001','71000000-0000-4000-8000-000000000020','71000000-0000-4000-8000-000000000011',
 'Rec cap '||n,'rec-test-cap-'||n,100 from generate_series(1000,1239) n;
insert into eventra_feed.customer_service_signals(customer_id,service_id,viewed_at,updated_at)
select '71000000-0000-4000-8000-000000000003',id,now()-interval '1 day',now()-interval '1 day'
from public.services where slug like 'rec-test-cap-%';
update eventra_feed.customer_service_signals set updated_at=now()-interval '181 days' where customer_id='71000000-0000-4000-8000-000000000003' and service_id='71000000-0000-4000-8000-000000000031';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"71000000-0000-4000-8000-000000000003","role":"authenticated"}',true);
select public.customer_service_signal('71000000-0000-4000-8000-000000000030','view');
reset role;
select pg_temp.check_rec((select count(*)=200 from eventra_feed.customer_service_signals where customer_id='71000000-0000-4000-8000-000000000003'),'history capped at 200 service rows');
select pg_temp.check_rec(not exists(select 1 from eventra_feed.customer_service_signals where customer_id='71000000-0000-4000-8000-000000000003' and updated_at<now()-interval '180 days'),'old signals pruned on activity');
select pg_temp.check_rec((select count(*)=1 from eventra_feed.customer_service_signals where customer_id='71000000-0000-4000-8000-000000000004'),'pruning cannot affect another customer');

-- Isolate booking-interest computation from booking workflow/webhook tests.
-- Trigger state and all fixtures are restored by this transaction's rollback.
delete from eventra_feed.customer_service_signals where customer_id='71000000-0000-4000-8000-000000000004';
alter table public.bookings disable trigger user;
insert into public.bookings(id,customer_id,vendor_id,business_id,service_id,event_date,location,price,status)
values('71000000-0000-4000-8000-000000000050','71000000-0000-4000-8000-000000000004','71000000-0000-4000-8000-000000000001','71000000-0000-4000-8000-000000000020','71000000-0000-4000-8000-000000000030',current_date,'Recommendation test',100,'completed');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"71000000-0000-4000-8000-000000000004","role":"authenticated"}',true);
select pg_temp.check_rec((public.customer_recommendations()->>'personalized')::boolean,'completed booking alone personalizes home');
reset role;
update public.bookings set status='cancelled' where id='71000000-0000-4000-8000-000000000050';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"71000000-0000-4000-8000-000000000004","role":"authenticated"}',true);
select pg_temp.check_rec(not (public.customer_recommendations()->>'personalized')::boolean,'cancelled booking creates no positive interest');
reset role;
update auth.users set banned_until=now()+interval '1 day' where id='71000000-0000-4000-8000-000000000002';
set local role anon;
select set_config('request.jwt.claims','{}',true);
select pg_temp.check_rec(not exists(select 1 from jsonb_array_elements(public.customer_recommendations()->'items') j where j->'service'->>'vendor_id'='71000000-0000-4000-8000-000000000002'),'suspended vendor excluded immediately');
reset role;
update auth.users set banned_until=now()+interval '1 day' where id='71000000-0000-4000-8000-000000000003';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"71000000-0000-4000-8000-000000000003","role":"authenticated"}',true);
select pg_temp.denied_rec('select public.customer_recommendations()','suspended customer denied');
select pg_temp.denied_rec($q$select public.customer_service_signal('71000000-0000-4000-8000-000000000030','view')$q$,'suspended customer cannot track');
select set_config('request.jwt.claims','{"sub":"71000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select pg_temp.denied_rec('select public.customer_recommendations()','vendor cannot read customer personalization');
reset role;
select pg_temp.check_rec((select relrowsecurity from pg_class where oid='eventra_feed.customer_service_signals'::regclass),'signal RLS enabled');
select count(*) as passed_recommendation_checks from recommendation_checks;
rollback;
