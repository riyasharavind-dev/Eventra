begin;

set local storage.allow_delete_query='true';
-- Transactional role tests. Synthetic accounts and objects are rolled back.
-- Append inside the migration transaction before its final COMMIT/ROLLBACK.
alter table public.bookings disable trigger trigger_notify_vendor_new_booking;
alter table public.bookings disable trigger trigger_notify_customer_booking_status;
create temporary table access_results(label text primary key);
grant select,insert on access_results to anon,authenticated;
create function pg_temp.assert_access(ok boolean,label text) returns void language plpgsql as $$
begin if ok is distinct from true then raise exception 'FAILED: %',label;end if;insert into access_results values(label);end $$;
create function pg_temp.expect_denied(command text,label text,codes text[] default array['42501']) returns void language plpgsql as $$
declare denied boolean:=false;
begin
 begin execute command;exception when others then if sqlstate=any(codes) then denied:=true;else raise;end if;end;
 perform pg_temp.assert_access(denied,label);
end $$;
insert into auth.users(id,email,raw_user_meta_data,email_confirmed_at) values
 ('fa000000-0000-4000-8000-000000000001','security-v1@example.invalid','{"role":"vendor","name":"Security Vendor 1"}',now()),
 ('fa000000-0000-4000-8000-000000000002','security-v2@example.invalid','{"role":"vendor","name":"Security Vendor 2"}',now()),
 ('fa000000-0000-4000-8000-000000000003','security-c1@example.invalid','{"role":"customer","name":"Security Customer 1"}',now()),
 ('fa000000-0000-4000-8000-000000000004','security-c2@example.invalid','{"role":"customer","name":"Security Customer 2"}',now()),
 ('fa000000-0000-4000-8000-000000000005','security-owner@example.invalid','{"role":"admin","name":"Security Owner"}',now()),
 ('fa000000-0000-4000-8000-000000000006','security-viewer@example.invalid','{"role":"admin","name":"Security Viewer"}',now());
insert into public.admins(id,name,access_level) values
 ('fa000000-0000-4000-8000-000000000005','Security Owner','owner'),
 ('fa000000-0000-4000-8000-000000000006','Security Viewer','viewer');
insert into public.businesses(id,vendor_id,name) values
 ('fb000000-0000-4000-8000-000000000001','fa000000-0000-4000-8000-000000000001','Security Business 1'),
 ('fb000000-0000-4000-8000-000000000002','fa000000-0000-4000-8000-000000000002','Security Business 2');
insert into public.category_nodes(id,name,slug) values('fc000000-0000-4000-8000-000000000001','Security Category','security-rls-test-category');
insert into public.business_category_nodes(business_id,category_node_id) values
 ('fb000000-0000-4000-8000-000000000001','fc000000-0000-4000-8000-000000000001'),
 ('fb000000-0000-4000-8000-000000000002','fc000000-0000-4000-8000-000000000001');
insert into public.services(id,vendor_id,business_id,category_node_id,name,slug,price) values
 ('fd000000-0000-4000-8000-000000000001','fa000000-0000-4000-8000-000000000001','fb000000-0000-4000-8000-000000000001','fc000000-0000-4000-8000-000000000001','Security Service 1','security-rls-service-1',100),
 ('fd000000-0000-4000-8000-000000000002','fa000000-0000-4000-8000-000000000002','fb000000-0000-4000-8000-000000000002','fc000000-0000-4000-8000-000000000001','Security Service 2','security-rls-service-2',200);
insert into storage.objects(bucket_id,name) values('profile','vendors/fa000000-0000-4000-8000-000000000002/security.jpg');
select pg_temp.assert_access(not exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='r' and not c.relrowsecurity),'all public tables have RLS');

set local role anon;
do $$ begin perform set_config('request.jwt.claims','{}',true);end $$;
select pg_temp.assert_access((select count(*)=2 from public.services where id in ('fd000000-0000-4000-8000-000000000001','fd000000-0000-4000-8000-000000000002')),'anon can discover active services');
select pg_temp.expect_denied('select * from public.customers','anon customer PII blocked');
select pg_temp.expect_denied('select * from public.vendors','anon vendor PII blocked');
select pg_temp.expect_denied('select * from public.fcm_tokens','anon device tokens blocked');
select pg_temp.expect_denied('select * from public.bookings','anon bookings blocked');
select pg_temp.expect_denied('select * from public.admins','anon admin authority blocked');
select pg_temp.expect_denied('update public.services set price=0','anon service changes blocked');
select pg_temp.expect_denied($q$insert into storage.objects(bucket_id,name) values('banners','security-anon.jpg')$q$,'anon banner uploads blocked');
select pg_temp.assert_access(public.home_feed_page(0,3,null,null) is not null,'public home feed RPC still works');
select pg_temp.assert_access(public.customer_search('Security Service','services',0,20) is not null,'public customer search works');
select pg_temp.assert_access(public.get_review_summary('fd000000-0000-4000-8000-000000000001') is not null,'public rating summary works');
select pg_temp.assert_access(not has_function_privilege('anon','public.emit_vendor_notification(uuid,text,text,text,text,uuid,text,timestamp with time zone,jsonb)','EXECUTE'),'internal notification emitter not callable');
reset role;

set local role authenticated;
do $$ begin perform set_config('request.jwt.claims','{"sub":"fa000000-0000-4000-8000-000000000001","role":"authenticated"}',true);end $$;
select pg_temp.assert_access((select count(*)=1 from public.users),'vendor sees own identity only');
select pg_temp.assert_access((select count(*)=1 from public.vendors),'vendor sees own private profile only');
select pg_temp.assert_access((select count(*)=0 from public.customers),'vendor cannot enumerate customers');
with x as(update public.businesses set name='Forbidden change' where id='fb000000-0000-4000-8000-000000000002' returning id)
 select pg_temp.assert_access((select count(*)=0 from x),'vendor cannot edit another business');
with x as(update public.services set price=1 where id='fd000000-0000-4000-8000-000000000002' returning id)
 select pg_temp.assert_access((select count(*)=0 from x),'vendor cannot edit another service');
update public.services set price=110 where id='fd000000-0000-4000-8000-000000000001';
select pg_temp.assert_access((select price=110 from public.services where id='fd000000-0000-4000-8000-000000000001'),'vendor can update own service');
select pg_temp.expect_denied($q$update public.users set role='admin'$q$,'role escalation blocked');
select pg_temp.expect_denied($q$update public.vendors set email='spoof@example.invalid'$q$,'identity email tampering blocked');
select pg_temp.expect_denied($q$update public.services set vendor_id='fa000000-0000-4000-8000-000000000001' where id='fd000000-0000-4000-8000-000000000002'$q$,'service owner reassignment blocked');
select pg_temp.expect_denied($q$insert into public.admins(id,name) values('fa000000-0000-4000-8000-000000000001','bad')$q$,'admin membership writes blocked');
select pg_temp.expect_denied($q$update public.vendor_verifications set status='approved'$q$,'vendor cannot self-approve verification');
select pg_temp.expect_denied($q$select public.delete_vendor_service('fd000000-0000-4000-8000-000000000002')$q$,'delete RPC blocks another vendor service');
insert into public.services(id,vendor_id,business_id,category_node_id,name,slug,price) values('fd000000-0000-4000-8000-000000000003','fa000000-0000-4000-8000-000000000001','fb000000-0000-4000-8000-000000000001','fc000000-0000-4000-8000-000000000001','Disposable Security Service','security-disposable-service',50);
select pg_temp.assert_access(public.delete_vendor_service('fd000000-0000-4000-8000-000000000003') ? 'gallery','own unbooked service deletion works');
select pg_temp.expect_denied('select public.admin_catalog()','vendor admin RPC denied');
select pg_temp.expect_denied($q$insert into storage.objects(bucket_id,name) values('profile','vendors/fa000000-0000-4000-8000-000000000002/hack.jpg')$q$,'cross-vendor upload blocked');
insert into storage.objects(bucket_id,name) values('profile','vendors/fa000000-0000-4000-8000-000000000001/security.jpg');
select pg_temp.assert_access(exists(select 1 from storage.objects where bucket_id='profile' and name='vendors/fa000000-0000-4000-8000-000000000001/security.jpg'),'own avatar upload allowed');
with x as(delete from storage.objects where bucket_id='profile' and name='vendors/fa000000-0000-4000-8000-000000000002/security.jpg' returning id)
 select pg_temp.assert_access((select count(*)=0 from x),'cross-vendor media deletion blocked');
select pg_temp.expect_denied($q$insert into storage.objects(bucket_id,name) values('banners','vendors/fa000000-0000-4000-8000-000000000001/ad.jpg')$q$,'vendor cannot upload platform banners');
select pg_temp.expect_denied($q$select public.save_vendor_business_location('fb000000-0000-4000-8000-000000000002','{}','{}')$q$,'business RPC ownership enforced',array['P0001','42501']);
select pg_temp.assert_access(public.get_vendor_dashboard_overview() is not null,'vendor dashboard works');
insert into public.fcm_tokens(user_id,token,platform) values('fa000000-0000-4000-8000-000000000001','security-token-v1','android');
select pg_temp.expect_denied($q$insert into public.fcm_tokens(user_id,token) values('fa000000-0000-4000-8000-000000000002','security-token-spoof')$q$,'device token owner spoofing blocked');
reset role;

set local role authenticated;
do $$ begin perform set_config('request.jwt.claims','{"sub":"fa000000-0000-4000-8000-000000000003","role":"authenticated"}',true);end $$;
select pg_temp.assert_access((select count(*)=0 from public.fcm_tokens),'customer cannot read vendor tokens');
update public.customers set name='Updated Customer' where id='fa000000-0000-4000-8000-000000000003';
select pg_temp.assert_access((select name='Updated Customer' from public.customers where id='fa000000-0000-4000-8000-000000000003'),'customer can edit own profile');
select pg_temp.expect_denied($q$insert into public.bookings(customer_id,vendor_id,service_id,event_date,location,price,status) values('fa000000-0000-4000-8000-000000000003','fa000000-0000-4000-8000-000000000001','fd000000-0000-4000-8000-000000000001',current_date,'test',1,'pending')$q$,'booking price tampering blocked',array['22023']);
select pg_temp.expect_denied($q$insert into public.bookings(customer_id,vendor_id,service_id,event_date,location,price,status) values('fa000000-0000-4000-8000-000000000004','fa000000-0000-4000-8000-000000000001','fd000000-0000-4000-8000-000000000001',current_date,'test',110,'pending')$q$,'booking customer spoofing blocked');
insert into public.bookings(id,customer_id,vendor_id,service_id,event_date,location,price,status) values('fe000000-0000-4000-8000-000000000001','fa000000-0000-4000-8000-000000000003','fa000000-0000-4000-8000-000000000001','fd000000-0000-4000-8000-000000000001',current_date,'test',110,'pending');
select pg_temp.assert_access(exists(select 1 from public.bookings where id='fe000000-0000-4000-8000-000000000001'),'valid customer booking allowed');
select pg_temp.assert_access(exists(select 1 from public.bookings b join public.vendors v on v.id=b.vendor_id join public.services s on s.id=b.service_id where b.id='fe000000-0000-4000-8000-000000000001'),'customer booking service/vendor joins work');
select pg_temp.expect_denied($q$update public.bookings set status='completed' where id='fe000000-0000-4000-8000-000000000001'$q$,'customer cannot self-complete bookings');
select pg_temp.expect_denied($q$select public.submit_service_review('fe000000-0000-4000-8000-000000000001',5,'fake',0)$q$,'pending booking cannot be reviewed',array['P0001']);
select pg_temp.expect_denied('select public.get_vendor_dashboard_overview()','customer cannot use vendor RPC');
select pg_temp.expect_denied($q$insert into storage.objects(bucket_id,name) values('service-gallery','services/fa000000-0000-4000-8000-000000000003/hack.jpg')$q$,'customer cannot upload vendor service media');
select pg_temp.assert_access((select count(*)=0 from public.verification_documents),'customer cannot read vendor proof metadata');
reset role;

set local role authenticated;
do $$ begin perform set_config('request.jwt.claims','{"sub":"fa000000-0000-4000-8000-000000000004","role":"authenticated"}',true);end $$;
select pg_temp.assert_access((select count(*)=0 from public.bookings),'unrelated customer cannot see bookings');
select pg_temp.assert_access((select count(*)=0 from public.vendors),'unrelated customer cannot enumerate vendor private profiles');
reset role;
set local role authenticated;
do $$ begin perform set_config('request.jwt.claims','{"sub":"fa000000-0000-4000-8000-000000000002","role":"authenticated"}',true);end $$;
select pg_temp.expect_denied($q$select public.change_vendor_booking_status('fe000000-0000-4000-8000-000000000001','pending','accepted',null,false)$q$,'unrelated vendor cannot accept booking',array['P0001']);
reset role;
set local role authenticated;
do $$ begin perform set_config('request.jwt.claims','{"sub":"fa000000-0000-4000-8000-000000000001","role":"authenticated"}',true);end $$;
select public.change_vendor_booking_status('fe000000-0000-4000-8000-000000000001','pending','accepted',null,false);
select pg_temp.assert_access((select status='accepted' from public.bookings where id='fe000000-0000-4000-8000-000000000001'),'own vendor can accept through guarded RPC');
select pg_temp.expect_denied($q$select public.delete_vendor_service('fd000000-0000-4000-8000-000000000001')$q$,'booked service cannot be deleted with cascading history',array['P0001']);
reset role;
set local role authenticated;
do $$ begin perform set_config('request.jwt.claims','{"sub":"fa000000-0000-4000-8000-000000000006","role":"authenticated"}',true);end $$;
select pg_temp.assert_access(public.admin_catalog() is not null,'admin viewer reads guarded catalog');
select pg_temp.expect_denied($q$select public.admin_grant_access('security-c1@example.invalid','bad','admin')$q$,'viewer cannot grant admin access');
select pg_temp.expect_denied($q$insert into storage.objects(bucket_id,name) values('banners','admins/fa000000-0000-4000-8000-000000000006/ad.jpg')$q$,'viewer cannot upload admin media');
reset role;
set local role authenticated;
do $$ begin perform set_config('request.jwt.claims','{"sub":"fa000000-0000-4000-8000-000000000005","role":"authenticated","aal":"aal2"}',true);end $$;
select pg_temp.assert_access(public.admin_catalog() is not null,'owner admin catalog works');
insert into storage.objects(bucket_id,name) values('banners','admins/fa000000-0000-4000-8000-000000000005/security.jpg');
select pg_temp.assert_access(public.eventra_admin_can_write(),'owner admin write authority preserved');
reset role;
select count(*) as passed_access_checks from access_results;

reset role;
select set_config('request.jwt.claims','{}',true);
update public.services set gallery='["https://example.invalid/service-thumbnail.png"]'::jsonb where id='fd000000-0000-4000-8000-000000000001';
insert into public.vendor_announcements(id,recipient_id,kind,title,body,is_active,image_url) values('ef000000-0000-4000-8000-000000000022','fa000000-0000-4000-8000-000000000001','offer','Image fixture','Notification image rollback fixture',true,'https://example.invalid/announcement.png');
select public.emit_vendor_notification('fa000000-0000-4000-8000-000000000001','booking','Image test','Fixture','booking','fe000000-0000-4000-8000-000000000001','notification-image-booking');
select public.emit_vendor_notification('fa000000-0000-4000-8000-000000000001','review','Image test','Fixture','review','fd000000-0000-4000-8000-000000000002','notification-image-cross-owner');
select public.emit_vendor_notification('fa000000-0000-4000-8000-000000000001','account','Invalid image','Fixture','message',null,'notification-image-invalid',now(),'{"image_url":"javascript:alert(1)"}');
select pg_temp.assert_access((select image_url='https://example.invalid/service-thumbnail.png' from public.vendor_notifications where event_key='notification-image-booking'),'booking notification snapshots the service image');
select pg_temp.assert_access((select image_url is null from public.vendor_notifications where event_key='notification-image-cross-owner'),'notification image lookup does not cross vendor ownership');
select pg_temp.assert_access((select image_url is null and not data ? 'image_url' from public.vendor_notifications where event_key='notification-image-invalid'),'invalid image cannot break alert insertion');
select pg_temp.assert_access(not has_function_privilege('authenticated','public.eventor_notification_image()','EXECUTE'),'image trigger is not client callable');
create temporary table image_state(locator text);
grant select,insert on image_state to authenticated;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"fa000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select public.sync_vendor_announcements();
select pg_temp.assert_access((select image_url='https://example.invalid/announcement.png' from public.vendor_notifications where announcement_id='ef000000-0000-4000-8000-000000000022'),'announcement image reaches the vendor inbox');
select public.mark_vendor_notifications_read(array(select id from public.vendor_notifications where announcement_id='ef000000-0000-4000-8000-000000000022'));
insert into image_state select ctid::text from public.vendor_notifications where announcement_id='ef000000-0000-4000-8000-000000000022';
select public.sync_vendor_announcements();
select pg_temp.assert_access((select ctid::text=(select locator from image_state) from public.vendor_notifications where announcement_id='ef000000-0000-4000-8000-000000000022'),'unchanged image sync performs no update or realtime feedback loop');
reset role;
select set_config('request.jwt.claims','{}',true);
update public.vendor_announcements set image_url=null where id='ef000000-0000-4000-8000-000000000022';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"fa000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select public.sync_vendor_announcements();
select pg_temp.assert_access((select image_url is null and not data ? 'image_url' and read_at is not null from public.vendor_notifications where announcement_id='ef000000-0000-4000-8000-000000000022'),'removing an image preserves read state and clears stale payload');
select pg_temp.assert_access(not has_column_privilege('authenticated','public.vendor_notifications','image_url','UPDATE'),'vendor cannot mutate inbox image columns directly');
reset role;
select count(*) as passed_access_and_notification_image_checks from access_results;
rollback;
