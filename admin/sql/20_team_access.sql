begin;
do $$begin perform set_config('eventor.seed_viewers',case when to_regclass('eventra_admin.team_permissions') is null then 'true' else 'false' end,true);end $$;
alter table public.admins drop constraint if exists admins_access_level_check;
alter table public.admins add constraint admins_access_level_check check(access_level in ('owner','admin','staff','viewer'));
create table if not exists eventra_admin.team_invitations(
 id uuid primary key default gen_random_uuid(), email text not null unique,
 name text not null, access_level text not null check(access_level in ('owner','admin','staff','viewer')),
 permissions jsonb not null default '{}', user_id uuid references auth.users(id) on delete set null,
 status text not null default 'pending' check(status in ('pending','accepted','revoked')),
 invited_by uuid references auth.users(id), created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(), last_sent_at timestamptz,
 expires_at timestamptz not null default now()+interval '7 days', delivery_error boolean not null default false
);
create table if not exists eventra_admin.team_permissions(
 admin_id uuid not null references public.admins(id) on delete cascade,
 module text not null references eventra_admin.modules(name), can_write boolean not null default false,
 primary key(admin_id,module)
);
create table if not exists eventra_admin.company_email_settings(
 id boolean primary key default true check(id), sender_name text not null default 'Eventor',
 sender_email text not null default '',reply_to text not null default '',provider text not null default '',
 admin_url text not null default 'https://eventor-admin.onrender.com',updated_at timestamptz not null default now()
);
insert into eventra_admin.company_email_settings(id) values(true) on conflict do nothing;
alter table eventra_admin.team_invitations enable row level security;
alter table eventra_admin.team_permissions enable row level security;
alter table eventra_admin.company_email_settings enable row level security;
revoke all on eventra_admin.team_invitations,eventra_admin.team_permissions,eventra_admin.company_email_settings from public,anon,authenticated;
-- Preserve existing viewer module access during rollout, excluding owner-only data.
insert into eventra_admin.team_permissions(admin_id,module)
select a.id,m.name from public.admins a cross join eventra_admin.modules m
where current_setting('eventor.seed_viewers',true)='true' and a.access_level='viewer' and m.name not in ('admins','admin_audit_log','admin_storage_cleanup','fcm_tokens') on conflict do nothing;

create or replace function eventra_admin.mfa_ok() returns boolean language sql stable security definer set search_path='' as $$
 select coalesce(auth.jwt()->>'aal','aal1')='aal2' or (
 not exists(select 1 from public.admins where id=auth.uid() and access_level in ('owner','admin'))
 and not exists(select 1 from auth.mfa_factors where user_id=auth.uid() and status='verified'))
$$;
create or replace function eventra_admin.require_access(p_write boolean default false) returns text
language plpgsql stable security definer set search_path='' as $$
declare level text;begin
 select access_level into level from public.admins where id=auth.uid() and is_active;
 if not eventra_security.live_account(auth.uid()) or level is null or (p_write and level='viewer') then raise exception 'Admin permission required' using errcode='42501';end if;
 if not eventra_admin.mfa_ok() then raise exception 'Complete authenticator verification first' using errcode='42501';end if;
 return level;
end $$;
create or replace function public.eventra_is_admin() returns boolean language sql stable security definer set search_path='' as $$
 select eventra_security.live_account(auth.uid()) and eventra_admin.mfa_ok() and exists(select 1 from public.admins where id=auth.uid() and is_active and access_level in ('owner','admin'))
$$;
create or replace function public.eventra_admin_can_write() returns boolean language sql stable security definer set search_path='' as $$select public.eventra_is_admin()$$;
create or replace function public.admin_context() returns jsonb language sql stable security definer set search_path='' as $$
 select to_jsonb(a)||jsonb_build_object('email',u.email,'role','admin','mfa_required',a.access_level in ('owner','admin'),
 'permissions',coalesce((select jsonb_object_agg(module,can_write) from eventra_admin.team_permissions where admin_id=a.id),'{}'::jsonb))
 from public.admins a join auth.users u on u.id=a.id where a.id=auth.uid() and a.is_active and eventra_security.live_account(a.id)
$$;
create or replace function eventra_admin.require_module(p_module text,p_write boolean default false) returns void
language plpgsql stable security definer set search_path='' as $$
declare level text:=eventra_admin.require_access(p_write);begin
 if p_module in ('admins','admin_audit_log','admin_storage_cleanup','fcm_tokens','__infrastructure') and level<>'owner' then raise exception 'Owner permission required' using errcode='42501';end if;
 if level in ('owner','admin') then return;end if;
 if not exists(select 1 from eventra_admin.team_permissions where admin_id=auth.uid() and module=p_module and (not p_write or can_write)) then raise exception 'Module permission required' using errcode='42501';end if;
end $$;
create or replace function eventra_admin.validate_permissions(p_permissions jsonb) returns void language plpgsql set search_path='' as $$
declare item record;begin
 if jsonb_typeof(p_permissions)<>'object' then raise exception 'Invalid module permissions';end if;
 for item in select * from jsonb_each(p_permissions) loop
 if jsonb_typeof(item.value)<>'boolean' or item.key in ('admins','admin_audit_log','admin_storage_cleanup','fcm_tokens') or not exists(select 1 from eventra_admin.modules where name=item.key) then raise exception 'Invalid module permission: %',item.key;end if;
 end loop;
end $$;
create or replace function eventra_admin.guard_team() returns trigger language plpgsql security definer set search_path='' as $$
begin
 perform pg_advisory_xact_lock(903027);
 if tg_op<>'INSERT' and old.access_level='owner' and old.is_active and
 (tg_op='DELETE' or new.access_level<>'owner' or not new.is_active) and
 not exists(select 1 from public.admins where access_level='owner' and is_active and id<>old.id) then raise exception 'Keep at least one active owner';end if;
 if auth.uid() is not null and coalesce(auth.role(),'')<>'service_role' and
 not exists(select 1 from public.admins where id=auth.uid() and access_level='owner' and is_active) then raise exception 'Only owners can change team access' using errcode='42501';end if;
 if tg_op='DELETE' then return old;end if;return new;
end $$;
drop trigger if exists eventor_guard_team on public.admins;
create trigger eventor_guard_team before insert or update or delete on public.admins for each row execute function eventra_admin.guard_team();

create or replace function public.admin_team_workspace() returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if eventra_admin.require_access(false)<>'owner' then raise exception 'Owner permission required' using errcode='42501';end if;
 return jsonb_build_object('members',coalesce((select jsonb_agg(to_jsonb(a)||jsonb_build_object('email',u.email,'last_login',u.last_sign_in_at,'revision',md5(to_jsonb(a)::text),
 'permissions',coalesce((select jsonb_object_agg(module,can_write) from eventra_admin.team_permissions where admin_id=a.id),'{}'::jsonb))) from public.admins a join auth.users u on u.id=a.id),'[]'),
 'invitations',coalesce((select jsonb_agg(to_jsonb(i) order by created_at desc) from eventra_admin.team_invitations i where status<>'accepted'),'[]'),
 'modules',coalesce((select jsonb_agg(jsonb_build_object('name',name,'label',label) order by label) from eventra_admin.modules where name not in ('admins','admin_audit_log','admin_storage_cleanup','fcm_tokens')),'[]'),
 'activity',coalesce((select jsonb_agg(to_jsonb(x)) from (select id,actor_id,record_id,action,created_at from public.admin_audit_log where module='team_access' order by created_at desc limit 50)x),'[]'),
 'email_settings',(select to_jsonb(s) from eventra_admin.company_email_settings s));
end $$;
create or replace function public.admin_team_invite_prepare(p_email text,p_name text,p_level text,p_permissions jsonb default '{}',p_resend boolean default false) returns jsonb
language plpgsql security definer set search_path='' as $$
declare inv eventra_admin.team_invitations; v_email text:=lower(trim(p_email));begin
 if eventra_admin.require_access(true)<>'owner' then raise exception 'Owner permission required' using errcode='42501';end if;
 if p_level not in ('owner','admin','staff','viewer') or length(trim(p_name)) not between 1 and 100 or v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' or length(v_email)>254 then raise exception 'Enter a valid name, email and role';end if;
 perform eventra_admin.validate_permissions(p_permissions);
 perform pg_advisory_xact_lock(hashtextextended(v_email,903028));
 if exists(select 1 from public.users where lower(public.users.email)=v_email) then raise exception 'Use a separate staff work email, not a vendor/customer account';end if;
 if exists(select 1 from public.admins a join auth.users u on a.id=u.id where lower(u.email)=v_email) then raise exception 'This account is already a team member. Edit its access instead.';end if;
 select * into inv from eventra_admin.team_invitations where team_invitations.email=v_email for update;
 if found and inv.last_sent_at>now()-interval '60 seconds' then raise exception 'Wait one minute before resending';end if;
 if (select count(*) from public.admin_audit_log where module='team_access' and action='invite_requested' and actor_id=auth.uid() and created_at>now()-interval '1 hour')>=20 then raise exception 'Hourly invitation limit reached';end if;
 if p_resend and inv.id is null then raise exception 'Invitation not found';end if;
 insert into eventra_admin.team_invitations(email,name,access_level,permissions,invited_by,last_sent_at,user_id)
 values(v_email,trim(p_name),p_level,p_permissions,auth.uid(),now(),(select id from auth.users where lower(auth.users.email)=v_email)) on conflict(email) do update set name=excluded.name,access_level=excluded.access_level,permissions=excluded.permissions,status='pending',expires_at=now()+interval '7 days',updated_at=now(),last_sent_at=now(),delivery_error=false returning * into inv;
 insert into public.admin_audit_log(actor_id,module,record_id,action) values(auth.uid(),'team_access',inv.id::text,'invite_requested');
 return to_jsonb(inv)||(select jsonb_build_object('admin_url',admin_url,'email_configured',sender_email<>'' and provider<>'') from eventra_admin.company_email_settings);
end $$;
-- Called only by the invite Edge Function using its server secret.
create or replace function public.admin_team_invite_result(p_id uuid,p_user_id uuid default null,p_failed boolean default false) returns void
language plpgsql security definer set search_path='' as $$
begin
 if auth.role()<>'service_role' then raise exception 'Server permission required' using errcode='42501';end if;
 update eventra_admin.team_invitations i set user_id=coalesce(p_user_id,i.user_id),delivery_error=p_failed,updated_at=now()
 where id=p_id and status='pending' and (p_user_id is null or exists(select 1 from auth.users u where u.id=p_user_id and lower(u.email)=i.email));
end $$;
create or replace function public.admin_team_accept_invite() returns void language plpgsql security definer set search_path='' as $$
declare i eventra_admin.team_invitations;begin
 select * into i from eventra_admin.team_invitations where user_id=auth.uid() and status='pending' and expires_at>now() for update;
 if not found or not eventra_security.live_account(auth.uid()) or not exists(select 1 from auth.users where id=auth.uid() and email_confirmed_at is not null and lower(email)=i.email) then raise exception 'Invitation expired, revoked or not verified' using errcode='42501';end if;
 if exists(select 1 from public.admins where id=auth.uid()) then raise exception 'Already a team member';end if;
 -- Only this trusted function may provision a verified invitation. Trigger allows via local flag below.
 perform set_config('eventor.accept_invite','true',true);
 insert into public.admins(id,name,access_level,is_active) values(auth.uid(),i.name,i.access_level,true);
 insert into eventra_admin.team_permissions(admin_id,module,can_write) select auth.uid(),key,case when i.access_level='viewer' then false else value::text::boolean end from jsonb_each(i.permissions);
 update eventra_admin.team_invitations set status='accepted',updated_at=now() where id=i.id;
 insert into public.admin_audit_log(actor_id,module,record_id,action) values(auth.uid(),'team_access',auth.uid()::text,'invite_accepted');
end $$;
-- guard_team's invitation exception is independently bound to the pending verified user.
create or replace function eventra_admin.guard_team() returns trigger language plpgsql security definer set search_path='' as $$
begin
 perform pg_advisory_xact_lock(903027);
 if tg_op<>'INSERT' and old.access_level='owner' and old.is_active and
 (tg_op='DELETE' or new.access_level<>'owner' or not new.is_active) and
 not exists(select 1 from public.admins where access_level='owner' and is_active and id<>old.id) then raise exception 'Keep at least one active owner';end if;
 if auth.uid() is not null and coalesce(auth.role(),'')<>'service_role' and
 not exists(select 1 from public.admins where id=auth.uid() and access_level='owner' and is_active) then
 if tg_op<>'INSERT' or current_setting('eventor.accept_invite',true) is distinct from 'true' or new.id<>auth.uid() or not exists(select 1 from eventra_admin.team_invitations where user_id=auth.uid() and status='pending' and expires_at>now() and access_level=new.access_level) then raise exception 'Only owners can change team access' using errcode='42501';end if;
 end if;
 if tg_op='DELETE' then return old;end if;return new;
end $$;
create or replace function public.admin_team_update(p_id uuid,p_revision text,p_name text,p_level text,p_active boolean,p_permissions jsonb default '{}') returns void
language plpgsql security definer set search_path='' as $$
declare before_row public.admins;begin
 if eventra_admin.require_access(true)<>'owner' then raise exception 'Owner permission required' using errcode='42501';end if;
 perform pg_advisory_xact_lock(903027);
 select * into before_row from public.admins where id=p_id for update;
 if not found or md5(to_jsonb(before_row)::text) is distinct from p_revision then raise exception 'Team member changed. Reload before saving.';end if;
 if length(trim(p_name)) not between 1 and 100 or p_level not in ('owner','admin','staff','viewer') then raise exception 'Invalid member details';end if;
 perform eventra_admin.validate_permissions(p_permissions);
 update public.admins set name=trim(p_name),access_level=p_level,is_active=p_active,updated_at=now() where id=p_id;
 delete from eventra_admin.team_permissions where admin_id=p_id;
 insert into eventra_admin.team_permissions(admin_id,module,can_write) select p_id,key,case when p_level='viewer' then false else value::text::boolean end from jsonb_each(p_permissions);
 insert into public.admin_audit_log(actor_id,module,record_id,action,before_data,after_data) values(auth.uid(),'team_access',p_id::text,'member_updated',to_jsonb(before_row),jsonb_build_object('name',p_name,'role',p_level,'active',p_active,'permissions',p_permissions));
end $$;
create or replace function public.admin_team_revoke(p_id uuid) returns void language plpgsql security definer set search_path='' as $$
begin
 if eventra_admin.require_access(true)<>'owner' then raise exception 'Owner permission required' using errcode='42501';end if;
 update eventra_admin.team_invitations set status='revoked',updated_at=now() where id=p_id and status='pending';
 insert into public.admin_audit_log(actor_id,module,record_id,action) values(auth.uid(),'team_access',p_id::text,'invite_revoked');
end $$;
create or replace function public.admin_company_email_save(p_name text,p_email text,p_reply_to text,p_provider text) returns void language plpgsql security definer set search_path='' as $$
begin
 if eventra_admin.require_access(true)<>'owner' then raise exception 'Owner permission required' using errcode='42501';end if;
 if length(trim(p_name)) not between 1 and 100 or length(p_provider)>100 or (p_email<>'' and p_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$') or (p_reply_to<>'' and p_reply_to !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$') then raise exception 'Invalid sender settings';end if;
 update eventra_admin.company_email_settings set sender_name=trim(p_name),sender_email=lower(trim(p_email)),reply_to=lower(trim(p_reply_to)),provider=trim(p_provider),updated_at=now();
 insert into public.admin_audit_log(actor_id,module,action) values(auth.uid(),'team_access','email_settings_updated');
end $$;

-- Wrap every legacy admin endpoint; private implementations retain existing business behavior.
do $wrap$
declare r record; impl text;check_sql text;body text;begin
 for r in select p.oid,p.proname,pg_get_function_arguments(p.oid) args,pg_get_function_identity_arguments(p.oid) identity_args,
 pg_get_function_result(p.oid) result,array_to_string(p.proargnames,',') call_args
 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and p.proname in ('admin_records','admin_record','admin_save','admin_action','admin_catalog','admin_overview','admin_connections_inventory','admin_storage_objects','admin_system_records','admin_home_feed_workspace','admin_home_feed_choices','admin_home_feed_preview','admin_home_feed_save','admin_grant_access') loop
 impl:='team_legacy_'||r.proname;
 if to_regprocedure(format('eventra_admin.%I(%s)',impl,oidvectortypes((select proargtypes from pg_proc where oid=r.oid)))) is not null then continue;end if;
 execute format('alter function public.%I(%s) set schema eventra_admin',r.proname,r.identity_args);
 execute format('alter function eventra_admin.%I(%s) rename to %I',r.proname,r.identity_args,impl);
 execute format('revoke all on function eventra_admin.%I(%s) from public,anon,authenticated',impl,r.identity_args);
 check_sql:=case
 when r.proname in ('admin_records','admin_record') then 'perform eventra_admin.require_module(p_module,false);'
 when r.proname in ('admin_save','admin_action') then 'perform eventra_admin.require_module(p_module,true);'
 when r.proname like 'admin_home_feed_%' then format('perform eventra_admin.require_module(''home_feed_sections'',%s);',case when r.proname='admin_home_feed_save' then 'true' else 'false' end)
 when r.proname='admin_catalog' then 'perform eventra_admin.require_access(false);'
 when r.proname='admin_grant_access' then 'raise exception ''Use Team & Access invitations to grant access'' using errcode=''42501'';'
 else 'perform eventra_admin.require_module(''__infrastructure'',false);' end;
 if r.proname='admin_catalog' then
 body:=check_sql||format(' return coalesce((select jsonb_agg(x) from jsonb_array_elements(eventra_admin.%I()) x where (eventra_admin.require_access(false)=''owner'' or x->>''name'' not in (''admins'',''admin_audit_log'',''admin_storage_cleanup'',''fcm_tokens'')) and (eventra_admin.require_access(false) in (''owner'',''admin'') or exists(select 1 from eventra_admin.team_permissions where admin_id=auth.uid() and module=x->>''name''))),''[]''::jsonb);',impl);
 else body:=check_sql||format(' return eventra_admin.%I(%s);',impl,coalesce(r.call_args,''));end if;
 execute format('create function public.%I(%s) returns %s language plpgsql security definer set search_path='''' as %L',r.proname,r.args,r.result,'begin '||body||' end');
 execute format('grant execute on function public.%I(%s) to authenticated',r.proname,r.identity_args);
 execute format('revoke all on function public.%I(%s) from public,anon',r.proname,r.identity_args);
 end loop;
end $wrap$;
create or replace function eventra_admin.team_legacy_admin_system_records(p_source text,p_offset integer default 0,p_limit integer default 30) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare query text;rows jsonb;total bigint;
begin
 perform eventra_admin.require_access(false);
 if p_offset is null or p_offset<0 or p_limit is null or p_limit not between 1 and 100 then raise exception 'Invalid system page';end if;
 query:=case p_source
 when 'eventra_admin.team_invitations' then 'select id,email,name,access_level,status,user_id,invited_by,created_at,expires_at,delivery_error from eventra_admin.team_invitations order by created_at desc'
 when 'eventra_admin.team_permissions' then 'select admin_id,module,can_write from eventra_admin.team_permissions order by admin_id,module'
 when 'eventra_admin.company_email_settings' then 'select sender_name,sender_email,reply_to,provider,admin_url,updated_at from eventra_admin.company_email_settings'
 when 'eventra_admin.modules' then 'select name,label,section,can_create,editable,actions from eventra_admin.modules order by section,name'
 when 'eventra_admin.mutation_requests' then 'select request_id,actor_id,module,created_at from eventra_admin.mutation_requests order by created_at desc,request_id'
 when 'eventra_feed.save_requests' then 'select request_id,actor_id from eventra_feed.save_requests order by request_id'
 when 'eventra_feed.service_metrics' then 'select * from eventra_feed.service_metrics order by service_id'
 when 'eventra_feed.eligible_services' then 'select id as service_id,vendor_id,business_id,name as service_name from eventra_feed.eligible_services order by id'
 else null end;
 if query is null then raise exception 'System source is not allowlisted' using errcode='42501';end if;
 execute 'select count(*) from ('||query||') x' into total;
 execute 'select coalesce(jsonb_agg(to_jsonb(x)),''[]''::jsonb) from ('||query||' limit $1 offset $2) x' into rows using p_limit,p_offset;
 return jsonb_build_object('total',total,'rows',rows);
end $$;
-- Block generic admin profile editing; dedicated team RPC adds concurrency and audit checks.
update eventra_admin.modules set can_create=false,editable='{}',actions='{}' where name='admins';
revoke all on all functions in schema eventra_admin from public,anon,authenticated;
do $$declare r record;begin
 for r in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and (p.proname like 'admin_team_%' or p.proname='admin_company_email_save') loop
 execute format('revoke all on function %s from public,anon,authenticated',r.signature);
 if r.signature::text not like 'admin_team_invite_result(%' then execute format('grant execute on function %s to authenticated',r.signature);end if;
 end loop;
end $$;
grant execute on function public.admin_team_invite_result(uuid,uuid,boolean) to service_role;
-- Policy helpers must remain callable by storage policies.
grant execute on function public.eventra_is_admin() to anon,authenticated;
grant execute on function public.eventra_admin_can_write(),public.admin_context() to authenticated;
-- Staff media operations are scoped to their assigned operational module.
create or replace function public.eventor_admin_media_access(p_bucket text,p_path text,p_write boolean default false) returns boolean
language plpgsql stable security definer set search_path='' as $$
declare level text; target text;begin
 select access_level into level from public.admins where id=auth.uid() and is_active;
 if level is null or not eventra_security.live_account(auth.uid()) or not eventra_admin.mfa_ok() then return false;end if;
 if level in ('owner','admin') then return not p_write;end if;
 if p_write then
   if level<>'staff' or split_part(p_path,'/',1)<>'admins' or split_part(p_path,'/',2)<>auth.uid()::text then return false;end if;
   target:=split_part(p_path,'/',3);
   if p_bucket is distinct from (case when target='social_links' then 'social-icons' when target='services' then 'service-gallery' when target='vendors' then 'profile' when target='businesses' then 'business-media' else 'banners' end) then return false;end if;
   return exists(select 1 from eventra_admin.team_permissions where admin_id=auth.uid() and module=target and can_write);
 end if;
 return exists(select 1 from eventra_admin.team_permissions where admin_id=auth.uid() and (
   p_bucket='support-attachments' and module in ('support_tickets','support_messages') or
   p_bucket='vendor-verification-documents' and module in ('vendor_verifications','verification_documents','vendor_identity_verifications') or
   p_bucket='business-documents' and module='business_verifications'));
end $$;
revoke all on function public.eventor_admin_media_access(text,text,boolean) from public,anon;
grant execute on function public.eventor_admin_media_access(text,text,boolean) to authenticated;
drop policy if exists eventor_staff_media_read on storage.objects;
create policy eventor_staff_media_read on storage.objects for select to authenticated using(public.eventor_admin_media_access(bucket_id,name,false));
drop policy if exists eventor_staff_media_insert on storage.objects;
create policy eventor_staff_media_insert on storage.objects for insert to authenticated with check(public.eventor_admin_media_access(bucket_id,name,true));
drop policy if exists eventor_staff_media_delete on storage.objects;
create policy eventor_staff_media_delete on storage.objects for delete to authenticated using(
 split_part(name,'/',1)='admins' and split_part(name,'/',2)=auth.uid()::text
 and public.eventor_admin_media_access(bucket_id,name,true)
 and (bucket_id<>'social-icons' or public.eventra_social_icon_can_delete(name)));

notify pgrst,'reload schema';
commit;
