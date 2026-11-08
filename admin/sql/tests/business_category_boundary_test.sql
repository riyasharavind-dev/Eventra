begin;
create temporary table business_location_checks(label text);
grant select,insert on business_location_checks to anon,authenticated;
create function pg_temp.assert_business(ok boolean,label text) returns void language plpgsql as $$
begin if ok is distinct from true then raise exception 'FAILED: %',label;end if;insert into business_location_checks values(label);end $$;
create function pg_temp.blocked_business(command text,label text) returns void language plpgsql as $$
declare denied boolean:=false;
begin begin execute command;exception when sqlstate '22023' or sqlstate '23505' or sqlstate 'P0001' or insufficient_privilege then denied:=true;end;
perform pg_temp.assert_business(denied,label);end $$;
insert into auth.users(id,email,raw_user_meta_data,email_confirmed_at) values
 ('72000000-0000-4000-8000-000000000001','business-v1@example.invalid','{"role":"vendor","name":"Boundary Vendor 1"}',now()),
 ('72000000-0000-4000-8000-000000000002','business-v2@example.invalid','{"role":"vendor","name":"Boundary Vendor 2"}',now());
insert into public.category_nodes(id,name,slug) values
 ('72000000-0000-4000-8000-000000000010','Boundary Parent','boundary-test-parent'),
 ('72000000-0000-4000-8000-000000000011','Other Parent','boundary-test-other');
insert into public.category_nodes(id,parent_id,name,slug) values
 ('72000000-0000-4000-8000-000000000012','72000000-0000-4000-8000-000000000010','Boundary Child','boundary-test-child');
insert into public.administrative_regions(id,name,level,parent_id) values
 ('boundary-test-state','Test State','state',null),
 ('boundary-test-district','Test District','district','boundary-test-state'),
 ('boundary-test-taluk','Test Taluk','subdistrict','boundary-test-district'),
 ('boundary-test-missing','Missing Taluk','subdistrict','boundary-test-district');
insert into public.administrative_region_boundaries(region_id,source_url,source_shape_id,source_year,geometry) values
 ('boundary-test-taluk','https://example.invalid/test','test',2018,
 '{"type":"Polygon","coordinates":[[[79,11],[79.04,11],[79.04,11.04],[79,11.04],[79,11]],[[79.015,11.015],[79.025,11.015],[79.025,11.025],[79.015,11.025],[79.015,11.015]]]}');
create temporary table business_payload(data jsonb);
insert into business_payload values('{"name":"Boundary Shop","primary_category_id":"72000000-0000-4000-8000-000000000010","shop_address":"Shop address test","shop_state_id":"boundary-test-state","shop_district_id":"boundary-test-district","shop_subdistrict_id":"boundary-test-taluk","latitude":11.01,"longitude":79.01}');
grant select on business_payload to authenticated;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"72000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select pg_temp.assert_business(public.get_shop_region_boundary('boundary-test-taluk')->>'id'='boundary-test-taluk','vendor reads selected polygon');
select pg_temp.blocked_business($q$select public.get_shop_region_boundary('boundary-test-missing')$q$,'missing border never silently substitutes another area');
select pg_temp.blocked_business('select * from public.administrative_region_boundaries','no direct boundary table access');
select pg_temp.blocked_business($q$select public.save_vendor_business_location('72000000-0000-4000-8000-000000000020',(select data from business_payload),array['72000000-0000-4000-8000-000000000010','72000000-0000-4000-8000-000000000011']::uuid[])$q$,'multiple categories rejected by RPC');
select pg_temp.blocked_business($q$select public.save_vendor_business_location('72000000-0000-4000-8000-000000000020',(select data||'{"primary_category_id":"72000000-0000-4000-8000-000000000012"}'::jsonb from business_payload),array['72000000-0000-4000-8000-000000000012']::uuid[])$q$,'child category rejected by RPC');
select public.save_vendor_business_location('72000000-0000-4000-8000-000000000020',(select data from business_payload),array['72000000-0000-4000-8000-000000000010']::uuid[]);
select pg_temp.assert_business((select count(*)=1 from public.business_category_nodes where business_id='72000000-0000-4000-8000-000000000020'),'one category saved atomically');
select pg_temp.blocked_business($q$select public.save_vendor_business_location('72000000-0000-4000-8000-000000000020',(select data||'{"latitude":12,"longitude":80}'::jsonb from business_payload),array['72000000-0000-4000-8000-000000000010']::uuid[])$q$,'outside point rejected server-side');
select pg_temp.blocked_business($q$select public.save_vendor_business_location('72000000-0000-4000-8000-000000000020',(select data||'{"latitude":11.02,"longitude":79.02}'::jsonb from business_payload),array['72000000-0000-4000-8000-000000000010']::uuid[])$q$,'polygon hole rejected server-side');
select public.save_vendor_business_location('72000000-0000-4000-8000-000000000020',(select data||'{"latitude":11,"longitude":79.01}'::jsonb from business_payload),array['72000000-0000-4000-8000-000000000010']::uuid[]);
select pg_temp.assert_business((select latitude=11 from public.businesses where id='72000000-0000-4000-8000-000000000020'),'exact border edge accepted');
select pg_temp.blocked_business($q$select public.save_vendor_business_location('72000000-0000-4000-8000-000000000021',(select data||'{"shop_subdistrict_id":"boundary-test-missing"}'::jsonb from business_payload),array['72000000-0000-4000-8000-000000000010']::uuid[])$q$,'new pin requires known border');
select pg_temp.blocked_business($q$select public.save_vendor_business_location('72000000-0000-4000-8000-000000000021',(select data||'{"shop_district_id":"boundary-test-state"}'::jsonb from business_payload),array['72000000-0000-4000-8000-000000000010']::uuid[])$q$,'region hierarchy still validated');
select set_config('request.jwt.claims','{"sub":"72000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select pg_temp.blocked_business($q$select public.save_vendor_business_location('72000000-0000-4000-8000-000000000020',(select data from business_payload),array['72000000-0000-4000-8000-000000000010']::uuid[])$q$,'another vendor cannot edit business');
reset role;
select pg_temp.blocked_business($q$insert into public.business_category_nodes(business_id,category_node_id) values('72000000-0000-4000-8000-000000000020','72000000-0000-4000-8000-000000000011')$q$,'unique constraint blocks multiple links');
select pg_temp.blocked_business($q$update public.businesses set primary_category_id='72000000-0000-4000-8000-000000000012' where id='72000000-0000-4000-8000-000000000020'$q$,'primary field cannot become child category');
-- Legacy points survive unrelated edits, even when old geographic coverage is absent.
update public.businesses set shop_subdistrict_id='boundary-test-missing' where id='72000000-0000-4000-8000-000000000020';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"72000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select public.save_vendor_business_location('72000000-0000-4000-8000-000000000020',(select data||'{"name":"Renamed Shop","latitude":11,"shop_subdistrict_id":"boundary-test-missing"}'::jsonb from business_payload),array['72000000-0000-4000-8000-000000000010']::uuid[]);
select pg_temp.assert_business((select name='Renamed Shop' from public.businesses where id='72000000-0000-4000-8000-000000000020'),'non-location legacy edit remains possible');
reset role;
set local role anon;
select set_config('request.jwt.claims','{}',true);
select pg_temp.blocked_business($q$select public.get_shop_region_boundary('boundary-test-taluk')$q$,'anonymous boundary RPC denied');
reset role;
select pg_temp.assert_business((select relrowsecurity from pg_class where oid='public.administrative_region_boundaries'::regclass),'boundary RLS enabled');
select count(*) as passed_business_boundary_checks from business_location_checks;
rollback;
