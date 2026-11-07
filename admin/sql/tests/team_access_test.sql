-- Run in a transaction; no fixture identities or grants survive ROLLBACK.
begin;
create temporary table team_results(label text primary key);
grant select,insert on team_results to authenticated,anon;
create function pg_temp.ok(value boolean,label text) returns void language plpgsql as $$begin if value is distinct from true then raise exception 'FAILED: %',label;end if;insert into team_results values(label);end $$;
create function pg_temp.denied(command text,label text) returns void language plpgsql as $$declare blocked boolean:=false;begin begin execute command;exception when insufficient_privilege then blocked:=true;end;perform pg_temp.ok(blocked,label);end $$;
insert into auth.users(id,email,raw_user_meta_data,email_confirmed_at) values
 ('ea000000-0000-4000-8000-000000000001','team-owner@example.invalid','{"role":"admin"}',now()),
 ('ea000000-0000-4000-8000-000000000002','team-staff@example.invalid','{"role":"admin"}',now()),
 ('ea000000-0000-4000-8000-000000000003','team-viewer@example.invalid','{"role":"admin"}',now()),
 ('ea000000-0000-4000-8000-000000000004','team-invite@example.invalid','{"role":"admin"}',now());
insert into public.admins(id,name,access_level) values
 ('ea000000-0000-4000-8000-000000000001','Fixture Owner','owner'),
 ('ea000000-0000-4000-8000-000000000002','Fixture Staff','staff'),
 ('ea000000-0000-4000-8000-000000000003','Fixture Viewer','viewer');
insert into eventra_admin.team_permissions values
 ('ea000000-0000-4000-8000-000000000002','support_faqs',true),
 ('ea000000-0000-4000-8000-000000000003','support_faqs',false);
select pg_temp.ok(not has_function_privilege('anon','public.admin_team_workspace()','EXECUTE'),'anon cannot read team');
select pg_temp.ok(not has_function_privilege('authenticated','public.admin_team_invite_result(uuid,uuid,boolean)','EXECUTE'),'client cannot finalize invitation delivery');
select pg_temp.ok(not has_function_privilege('authenticated','eventra_admin.team_legacy_admin_records(text,text,integer,integer,jsonb)','EXECUTE'),'private legacy endpoint cannot bypass permissions');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"ea000000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal1"}',true);
select pg_temp.ok(public.admin_context()->>'access_level'='owner','owner identity available before MFA');
select pg_temp.denied('select public.admin_catalog()','owner requires MFA before data access');
select pg_temp.ok(not public.eventra_is_admin(),'owner storage privileges require MFA');
select set_config('request.jwt.claims','{"sub":"ea000000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);
select pg_temp.ok(jsonb_array_length(public.admin_catalog())>30,'MFA owner catalog available');
select pg_temp.ok(public.admin_team_workspace() ? 'email_settings','owner team workspace available');
select pg_temp.ok(public.admin_team_invite_prepare('team-invite@example.invalid','Invitee','staff','{"support_faqs":true}') ? 'id','owner creates pending invitation');
reset role;
select set_config('request.jwt.claims','{}',true);
update eventra_admin.team_invitations set user_id='ea000000-0000-4000-8000-000000000004' where email='team-invite@example.invalid';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"ea000000-0000-4000-8000-000000000002","role":"authenticated","aal":"aal1"}',true);
select pg_temp.ok(jsonb_array_length(public.admin_catalog())=1,'staff catalog contains only assigned module');
select pg_temp.ok(public.admin_records('support_faqs')->>'total' is not null,'staff can read assigned module');
select pg_temp.ok(public.admin_save('support_faqs','{"slug":"team-test-faq","audience":"vendor","category":"Other","question":"Team test?","answer":"Fixture only.","is_published":false}') ? 'id','staff can write assigned module');
select pg_temp.denied($q$select public.admin_records('customers')$q$,'staff cannot read unassigned customer PII');
select pg_temp.denied('select public.admin_overview()','staff cannot leak global dashboard counts');
select pg_temp.denied('select public.admin_team_workspace()','staff cannot manage team');
select pg_temp.ok(not public.eventor_admin_media_access('service-gallery','admins/ea000000-0000-4000-8000-000000000002/services/test.jpg',true),'staff cannot upload unassigned service media');
select pg_temp.ok(public.eventor_admin_media_access('banners','admins/ea000000-0000-4000-8000-000000000002/support_faqs/test.jpg',true),'staff can upload own media for assigned module');
select pg_temp.ok(not public.eventor_admin_media_access('banners','admins/ea000000-0000-4000-8000-000000000003/support_faqs/test.jpg',true),'staff cannot upload as another staff member');
select pg_temp.denied($q$select public.admin_save('admins','{"access_level":"owner"}','ea000000-0000-4000-8000-000000000002')$q$,'staff cannot escalate role');
select pg_temp.denied('select public.admin_connections_inventory()','staff cannot inspect infrastructure');
select pg_temp.denied($q$select public.admin_home_feed_workspace()$q$,'staff cannot bypass scope through custom feed endpoint');
select pg_temp.denied('select * from eventra_admin.team_permissions','staff cannot edit private assignments');
select pg_temp.denied('select public.admin_team_accept_invite()','uninvited account cannot activate access');
select set_config('request.jwt.claims','{"sub":"ea000000-0000-4000-8000-000000000003","role":"authenticated","aal":"aal1"}',true);
select pg_temp.ok(public.admin_records('support_faqs') is not null,'viewer reads assigned module');
select pg_temp.denied($q$select public.admin_save('support_faqs','{"question":"hack"}')$q$,'viewer cannot write');
select set_config('request.jwt.claims','{"sub":"ea000000-0000-4000-8000-000000000004","role":"authenticated","aal":"aal1"}',true);
reset role;
select set_config('request.jwt.claims','{}',true);
update eventra_admin.team_invitations set status='revoked' where email='team-invite@example.invalid';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"ea000000-0000-4000-8000-000000000004","role":"authenticated","aal":"aal1"}',true);
select pg_temp.denied('select public.admin_team_accept_invite()','revoked invite cannot activate');
reset role;
select set_config('request.jwt.claims','{}',true);
update eventra_admin.team_invitations set status='pending',expires_at=now()-interval '1 minute' where email='team-invite@example.invalid';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"ea000000-0000-4000-8000-000000000004","role":"authenticated","aal":"aal1"}',true);
select pg_temp.denied('select public.admin_team_accept_invite()','expired invite cannot activate');
reset role;
select set_config('request.jwt.claims','{}',true);
update eventra_admin.team_invitations set expires_at=now()+interval '1 day' where email='team-invite@example.invalid';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"ea000000-0000-4000-8000-000000000004","role":"authenticated","aal":"aal1"}',true);
select public.admin_team_accept_invite();
select pg_temp.ok(public.admin_context()->>'access_level'='staff','verified invitee activates correct role');
select pg_temp.ok(jsonb_array_length(public.admin_catalog())=1,'accepted invitation inherits only assigned permissions');
reset role;
select set_config('request.jwt.claims','{}',true);
update public.admins set is_active=false where id='ea000000-0000-4000-8000-000000000002';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"ea000000-0000-4000-8000-000000000002","role":"authenticated","aal":"aal1"}',true);
select pg_temp.denied($q$select public.admin_records('support_faqs')$q$,'suspended staff existing token immediately denied');
select pg_temp.ok(public.admin_context() is null,'suspended member context unavailable');
reset role;
select set_config('request.jwt.claims','{}',true);
-- Verify the last-owner trigger against the fixture only, preserving real owners.
update public.admins set is_active=false where access_level='owner' and id<>'ea000000-0000-4000-8000-000000000001';
do $$declare blocked boolean:=false;begin begin update public.admins set is_active=false where id='ea000000-0000-4000-8000-000000000001';exception when raise_exception then blocked:=true;end;perform pg_temp.ok(blocked,'last active owner cannot be suspended');end $$;
select count(*) as passed_assertions from team_results;
rollback;
