begin;
create temporary table language_checks(label text);
grant select,insert on language_checks to anon,authenticated;
create function pg_temp.ok_language(value boolean,label text)returns void language plpgsql as $$begin if value is distinct from true then raise exception 'FAILED: %',label;end if;insert into language_checks values(label);end $$;
create function pg_temp.reject_language(command text,expected text,label text)returns void language plpgsql as $$declare code text;begin begin execute command;exception when others then get stacked diagnostics code=returned_sqlstate;end;perform pg_temp.ok_language(code=expected,label);end $$;
insert into auth.users(id,email,raw_user_meta_data,email_confirmed_at)values
 ('76000000-0000-4000-8000-000000000001','language-owner@example.invalid','{"role":"admin"}',now()),
 ('76000000-0000-4000-8000-000000000002','language-translator@example.invalid','{"role":"admin"}',now()),
 ('76000000-0000-4000-8000-000000000003','language-viewer@example.invalid','{"role":"admin"}',now()),
 ('76000000-0000-4000-8000-000000000004','language-vendor@example.invalid','{"role":"vendor","name":"Language vendor"}',now());
insert into public.admins(id,name,access_level)values
 ('76000000-0000-4000-8000-000000000001','Language owner','owner'),
 ('76000000-0000-4000-8000-000000000002','Translator','staff'),
 ('76000000-0000-4000-8000-000000000003','Language reader','viewer');
insert into eventra_admin.team_permissions(admin_id,module,can_write)values
 ('76000000-0000-4000-8000-000000000002','app_languages',true),
 ('76000000-0000-4000-8000-000000000003','app_languages',false);
select pg_temp.ok_language((select count(*)=4 from pg_class where oid in ('public.app_languages'::regclass,'public.app_translation_keys'::regclass,'public.app_translation_drafts'::regclass,'public.app_language_releases'::regclass)and relrowsecurity),'all localization tables have RLS');
select pg_temp.ok_language(not has_table_privilege('authenticated','public.app_language_releases','insert,update,delete'),'client cannot mutate releases');
select pg_temp.ok_language(not has_table_privilege('anon','public.app_translation_drafts','select'),'anonymous cannot read drafts');
set local role anon;
select set_config('request.jwt.claims','{}',true);
select pg_temp.ok_language(jsonb_array_length(public.app_language_manifest())>=2,'guest can list published languages');
select pg_temp.ok_language(public.app_language_pack('ta')->>'content' is not null,'guest can download Tamil');
select pg_temp.reject_language('select public.admin_language_workspace()','42501','guest cannot access translation editor');
reset role;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"76000000-0000-4000-8000-000000000004","role":"authenticated"}',true);
select pg_temp.reject_language('select public.admin_language_workspace()','42501','vendor cannot access admin language workflow');
select pg_temp.reject_language($q$select public.admin_language_save('ta','{}',0)$q$,'42501','vendor cannot write translations');
select set_config('request.jwt.claims','{"sub":"76000000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal1"}',true);
select pg_temp.reject_language('select public.admin_language_workspace()','42501','owner requires MFA');
select set_config('request.jwt.claims','{"sub":"76000000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);
select public.admin_language_create('zz','Test language','Test native','rtl');
select pg_temp.ok_language(not exists(select 1 from jsonb_array_elements(public.app_language_manifest())x where x->>'code'='zz'),'unpublished language hidden');
select pg_temp.reject_language($q$select public.app_language_pack('zz')$q$,'22023','unpublished pack cannot be read');
select pg_temp.reject_language($q$select public.admin_language_update('zz','Test language','Test native','rtl',true,0)$q$,'P0001','cannot enable before publication');
select pg_temp.ok_language(jsonb_array_length(public.admin_language_validate('zz')->'missing')>0,'missing translations reported');
select public.admin_language_save('zz','{"common.booking_count.other":"Broken {wrong}"}',0);
select pg_temp.reject_language($q$select public.admin_language_save('zz','{"common.booking_count.other":"Stale {count}"}',0)$q$,'40001','stale draft edit rejected');
select pg_temp.ok_language(jsonb_array_length(public.admin_language_validate('zz')->'invalid')=1,'placeholder errors reported');
select pg_temp.reject_language($q$select public.admin_language_publish('zz',1,true)$q$,'22023','placeholder errors block publishing');
select public.admin_language_save('zz','{"common.booking_count.other":"Test {count}"}',1);
select pg_temp.reject_language($q$select public.admin_language_publish('zz',2,false)$q$,'22023','missing words need explicit fallback approval');
select set_config('request.jwt.claims','{"sub":"76000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select pg_temp.ok_language(public.admin_language_workspace() is not null,'translator can read assigned module');
select public.admin_language_save('zz','{"common.booking_count.other":"Translator {count}"}',2);
select pg_temp.reject_language($q$select public.admin_language_publish('zz',3,true)$q$,'42501','translator cannot publish without separate permission');
select set_config('request.jwt.claims','{"sub":"76000000-0000-4000-8000-000000000003","role":"authenticated"}',true);
select pg_temp.ok_language(public.admin_language_workspace() is not null,'assigned viewer can read');
select pg_temp.reject_language($q$select public.admin_language_save('zz','{"common.booking_count.other":"Bad {count}"}',3)$q$,'42501','viewer cannot edit');
select set_config('request.jwt.claims','{"sub":"76000000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);
select pg_temp.ok_language((public.admin_language_publish('zz',3,true)->>'version')::int=1,'publishing creates version one');
select public.admin_language_update('zz','Test language','Test native','rtl',true,3);
select pg_temp.ok_language(exists(select 1 from jsonb_array_elements(public.app_language_manifest())x where x->>'code'='zz'),'enabled published language visible');
select pg_temp.ok_language((public.app_language_pack('zz')->>'content')::jsonb->>'direction'='rtl','RTL metadata published');
select public.admin_language_save('zz','{"common.booking_count.other":"Second {count}"}',4);
select pg_temp.ok_language((public.app_language_pack('zz')->>'content')::jsonb#>>'{messages,common.booking_count.other}'='Translator {count}','draft edit does not change live pack');
select public.admin_language_publish('zz',5,true);
select pg_temp.ok_language((public.app_language_pack('zz',1)->>'content')::jsonb#>>'{messages,common.booking_count.other}'='Translator {count}','old release remains immutable');
select public.admin_language_restore_draft('zz',1,5);
select pg_temp.ok_language((public.app_language_pack('zz')->>'content')::jsonb->>'version'='2','restore does not change live version');
select pg_temp.ok_language((public.admin_language_publish('zz',6,true)->>'version')::int=3,'rollback publishes a new monotonic version');
select pg_temp.ok_language(public.admin_language_export('zz')->'source' is not null,'source context exported');
reset role;
select pg_temp.ok_language((select sha256=encode(extensions.digest(convert_to(pack_json,'UTF8'),'sha256'),'hex') from public.app_language_releases where language_code='zz' and version=3),'release checksum matches exact wire content');
select pg_temp.ok_language((select (pack_json::jsonb)->'messages'?'common.booking_count.other' from public.app_language_releases where language_code='ta' and version=1),'Tamil release includes plural keys');
select pg_temp.ok_language(not exists(select 1 from pg_publication_tables where tablename in ('app_translation_drafts','app_translation_keys','app_language_releases')),'draft/release rows not directly published');
select count(*) as passed_language_workflow_checks from language_checks;
rollback;
