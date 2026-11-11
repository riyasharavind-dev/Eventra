begin;
create temporary table review_permission_checks(label text);
create function pg_temp.assert_review(value boolean,label text) returns void language plpgsql as $$begin if value is distinct from true then raise exception 'FAILED: %',label;end if;insert into review_permission_checks values(label);end $$;
select pg_temp.assert_review(not has_function_privilege('authenticated','public.reply_service_review(uuid,text,integer)','execute'),'authenticated cannot reply');
select pg_temp.assert_review(not has_function_privilege('anon','public.reply_service_review(uuid,text,integer)','execute'),'anonymous cannot reply');
select pg_temp.assert_review(not has_column_privilege('authenticated','public.service_reviews','vendor_reply','update'),'direct reply column writes unavailable');
select pg_temp.assert_review(not has_column_privilege('authenticated','public.service_reviews','reply_version','update'),'reply version writes unavailable');
select pg_temp.assert_review(exists(select 1 from pg_proc where pronamespace='public'::regnamespace and proname='get_service_reviews' and position('''can_reply'',false' in pg_get_functiondef(oid))>0),'backend reports reply capability false');
select pg_temp.assert_review(has_function_privilege('authenticated','public.report_service_review(uuid,text)','execute'),'report access preserved');
select pg_temp.assert_review(exists(select 1 from pg_proc where pronamespace='public'::regnamespace and proname='get_service_reviews' and has_function_privilege('authenticated',oid,'execute')),'review reading preserved');
set local role authenticated;
do $$ begin
 begin
  perform public.reply_service_review('00000000-0000-0000-0000-000000000000','not allowed',0);
  raise exception 'Reply unexpectedly allowed';
 exception when insufficient_privilege then null;
 end;
end $$;
reset role;
select count(*) as passed_review_read_only_checks from review_permission_checks;
rollback;
