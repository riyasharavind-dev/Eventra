begin;
create temporary table trend_checks(label text);
grant select,insert on trend_checks to anon,authenticated;
create function pg_temp.trend_ok(v boolean,label text)returns void language plpgsql as $$begin if v is distinct from true then raise exception 'FAILED: %',label;end if;insert into trend_checks values(label);end $$;
create function pg_temp.trend_denied(command text,label text)returns void language plpgsql as $$declare blocked boolean=false;begin begin execute command;exception when insufficient_privilege then blocked=true;end;perform pg_temp.trend_ok(blocked,label);end $$;
insert into auth.users(id,email,raw_user_meta_data,email_confirmed_at)values
('89000000-0000-4000-8000-000000000001','trend-c1@example.invalid','{"role":"customer","name":"Trend C1"}',now()),
('89000000-0000-4000-8000-000000000002','trend-c2@example.invalid','{"role":"customer","name":"Trend C2"}',now()),
('89000000-0000-4000-8000-000000000003','trend-v@example.invalid','{"role":"vendor","name":"Trend V"}',now());
insert into public.category_nodes(id,name,slug)values('89000000-0000-4000-8000-000000000010','Zztrend Decorations','zztrend-decoration');
insert into public.category_nodes(id,parent_id,name,slug)values
('89000000-0000-4000-8000-000000000011','89000000-0000-4000-8000-000000000010','Zztrend Flowers','zztrend-flowers'),
('89000000-0000-4000-8000-000000000012','89000000-0000-4000-8000-000000000011','Zztrend Roses','zztrend-roses');
insert into public.businesses(id,vendor_id,name)values('89000000-0000-4000-8000-000000000020','89000000-0000-4000-8000-000000000003','Trend Test Business');
insert into public.services(id,vendor_id,business_id,category_node_id,name,slug,price,is_active,pricing_type)values
('89000000-0000-4000-8000-000000000030','89000000-0000-4000-8000-000000000003','89000000-0000-4000-8000-000000000020','89000000-0000-4000-8000-000000000010','Trend Root Service','zztrend-root-service',100,true,'fixed'),
('89000000-0000-4000-8000-000000000031','89000000-0000-4000-8000-000000000003','89000000-0000-4000-8000-000000000020','89000000-0000-4000-8000-000000000012','Trend Deep Service','zztrend-deep-service',200,true,'fixed'),
('89000000-0000-4000-8000-000000000032','89000000-0000-4000-8000-000000000003','89000000-0000-4000-8000-000000000020','89000000-0000-4000-8000-000000000012','Trend Hidden Service','zztrend-hidden-service',100,false,'fixed');
select pg_temp.trend_ok((select relrowsecurity from pg_class where oid='eventra_feed.category_search_signals'::regclass),'private signals have RLS');
select pg_temp.trend_ok(not has_table_privilege('authenticated','eventra_feed.category_search_signals','SELECT'),'no client raw history reads');
set local role anon;
select set_config('request.jwt.claims','{}',true);
select pg_temp.trend_ok(jsonb_typeof(public.customer_category_rankings())='array','anonymous aggregate read');
select pg_temp.trend_ok((public.customer_search_filtered('Trend','services','price_high',0,1)#>>'{items,0,price}')::numeric=200,'descending price sorts before pagination');
select pg_temp.trend_ok((public.customer_search_filtered('Trend','services','price_low',0,1)#>>'{items,0,price}')::numeric=100,'ascending price sorts globally');
select pg_temp.trend_ok((public.customer_search_filtered('Trend','services','price_high',1,1)#>>'{items,0,price}')::numeric=100,'second page retains price ordering');
select pg_temp.trend_ok(public.customer_search_filtered('Trend','vendors','rating')#>>'{items,0,type}'='vendors','vendor type filter retained');
select pg_temp.trend_ok(jsonb_array_length(public.customer_category_results('89000000-0000-4000-8000-000000000011','services')->'items')=1,'unified results stay in selected subtree');
select pg_temp.trend_ok((public.customer_category_results('89000000-0000-4000-8000-000000000010','services','price_high',0,1)#>>'{items,0,price}')::numeric=200,'unified category sort applies globally');
select pg_temp.trend_ok(public.customer_category_results('89000000-0000-4000-8000-000000000010','vendors')#>>'{items,0,type}'='vendors','unified category vendors remain scoped');


select pg_temp.trend_denied($q$select public.customer_record_category_search('zztrend roses')$q$,'guest cannot write signals');
select pg_temp.trend_ok(jsonb_array_length(public.customer_category_services('89000000-0000-4000-8000-000000000010')->'items')=2,'parent page includes deep descendants but excludes inactive services');
select pg_temp.trend_ok((public.customer_category_services('89000000-0000-4000-8000-000000000010',0,1)->>'has_more')::boolean,'category page is paginated');
select pg_temp.trend_ok(not (public.customer_category_services('89000000-0000-4000-8000-000000000010',1,1)->>'has_more')::boolean,'last category page terminates');
select pg_temp.trend_ok(jsonb_array_length(public.customer_category_services('89000000-0000-4000-8000-000000000011')->'items')=1,'subtype services exclude unrelated parent services');
reset role;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"89000000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal1"}',true);
select public.customer_record_category_search('zztrend roses');
select public.customer_record_category_search('zztrend roses');
reset role;
select pg_temp.trend_ok((select count(*)=3 from eventra_feed.category_search_signals where customer_id='89000000-0000-4000-8000-000000000001'),'leaf search promotes all ancestors and repeated search deduplicates');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"89000000-0000-4000-8000-000000000002","role":"authenticated","aal":"aal1"}',true);
select public.customer_record_category_search('zztrend roses');
reset role;
select pg_temp.trend_ok((select (r->>'score')::int=4 from jsonb_array_elements(public.customer_category_rankings()) r where r->>'category_id'='89000000-0000-4000-8000-000000000010'),'multiple customers drive parent ranking');
update eventra_feed.category_search_signals set searched_at=now()-interval '15 days' where customer_id='89000000-0000-4000-8000-000000000001';
select pg_temp.trend_ok((select (r->>'score')::int=3 from jsonb_array_elements(public.customer_category_rankings()) r where r->>'category_id'='89000000-0000-4000-8000-000000000010'),'recent interest gets greater weight');
update eventra_feed.category_search_signals set searched_at=now()-interval '31 days' where customer_id='89000000-0000-4000-8000-000000000001';
select pg_temp.trend_ok((select (r->>'score')::int=2 from jsonb_array_elements(public.customer_category_rankings()) r where r->>'category_id'='89000000-0000-4000-8000-000000000010'),'old signals leave ranking');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"89000000-0000-4000-8000-000000000003","role":"authenticated","aal":"aal1"}',true);
select pg_temp.trend_denied($q$select public.customer_record_category_search('zztrend roses')$q$,'vendor cannot write customer trends');
reset role;
select pg_temp.trend_ok(not exists(select 1 from information_schema.columns where table_schema='eventra_feed' and table_name='category_search_signals' and column_name in ('query','search_text','raw_query')),'raw search phrases are not stored');
select count(*) as passed_trend_checks from trend_checks;
rollback;
