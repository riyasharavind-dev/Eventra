begin;
create temporary table archive_checks(label text);
create function pg_temp.archive_ok(v boolean,label text)returns void language plpgsql as $$begin if v is distinct from true then raise exception 'FAILED: %',label;end if;insert into archive_checks values(label);end $$;
select pg_temp.archive_ok(has_column_privilege('authenticated','public.services','is_archived','UPDATE'),'vendor column privilege');
select pg_temp.archive_ok((select relrowsecurity from pg_class where oid='public.services'::regclass),'service RLS retained');
do $$declare target uuid;blocked boolean=false;begin
select id into target from public.services limit 1;
if target is null then raise exception 'Archive test requires an existing service';end if;
update public.services set is_archived=true,is_active=false where id=target;
perform pg_temp.archive_ok((select is_archived and not is_active from public.services where id=target),'archive hides service');
begin update public.services set is_active=true where id=target;exception when check_violation then blocked=true;end;
perform pg_temp.archive_ok(blocked,'archived service cannot activate');
update public.services set is_archived=false where id=target;
perform pg_temp.archive_ok((select not is_archived and not is_active from public.services where id=target),'restore remains inactive');
end $$;
grant select,insert on archive_checks to authenticated;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"88000000-0000-4000-8000-000000000099","role":"authenticated","aal":"aal1"}',true);
with changed as(update public.services set is_archived=true,is_active=false returning id)
select pg_temp.archive_ok((select count(*)=0 from changed),'unrelated identity cannot archive services');
reset role;
select count(*) as passed_archive_checks from archive_checks;
rollback;
