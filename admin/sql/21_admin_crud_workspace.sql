begin;
alter table eventra_admin.modules add column if not exists can_delete boolean not null default false;
alter table eventra_admin.modules add column if not exists management_mode text not null default 'records';
alter table eventra_admin.modules add column if not exists description text not null default '';
update eventra_admin.modules set can_delete=name in ('category_nodes','event_types','administrative_regions','businesses','services','banners','social_links','support_faqs','support_settings','about_eventra_content','legal_documents','vendor_announcements','home_feed_sections');
update eventra_admin.modules set management_mode=case
 when name in ('admins','users','customers','vendors','account_deletion_requests') then 'accounts'
 when name in ('business_category_nodes','home_feed_pinned_items') then 'linked'
 when name in ('admin_audit_log','booking_status_history','booking_vendor_notes','support_messages','vendor_notifications') then 'history'
 when name in ('published_about_eventra_content','published_support_faqs','current_legal_documents','active_social_links') then 'published'
 when cardinality(actions)>0 then 'workflow' else 'records' end;
update eventra_admin.modules set description=case name
 when 'users' then 'Account identity. Suspension is owner-controlled; account deletion follows reviewed requests.'
 when 'admins' then 'Manage invitations, roles, MFA and staff access in Team & Access.'
 when 'vendors' then 'Vendor profiles, businesses, services and verification relationships.'
 when 'customers' then 'Customer profiles, bookings and support relationships.'
 when 'business_category_nodes' then 'Business category links are managed from the business record to keep its primary category consistent.'
 when 'home_feed_pinned_items' then 'Manage ordered pins in the Home Feed editor.'
 when 'bookings' then 'Manage event details and guarded booking status transitions. Booking history is retained.'
 when 'service_reviews' then 'Moderate genuine customer reviews; ratings cannot be fabricated or overwritten.'
 when 'legal_documents' then 'Create drafts, publish versions and retain immutable published legal history.'
 when 'category_nodes' then 'Manage main categories and their subcategories shared by both apps.'
 when 'event_types' then 'Manage event names, images, active status and display order.'
 when 'services' then 'Create vendor services, manage pricing and visibility, and inspect linked bookings.'
 when 'businesses' then 'Create vendor businesses, maintain shop information and manage category links.'
 when 'support_tickets' then 'Create support cases for existing app users, reply and manage resolution.'
 when 'admin_audit_log' then 'Permanent operation history. Changes and deletions are not available.'
 else case management_mode when 'history' then 'System-generated history retained for traceability.' when 'published' then 'Live app content. Edit its source record to change publication.' when 'workflow' then 'Review and process records through validated workflow actions.' else 'Manage '||lower(label)||' with audited create and edit operations.' end end;
update eventra_admin.modules set can_create=true,editable=array(select distinct v from unnest(editable||array['vendor_id','primary_category_id','is_active','availability_status'])v),choices=choices||'{"availability_status":["active","unavailable","archived"]}'::jsonb where name='businesses';
-- Existing app RPCs supply their own IDs; defaults support trusted admin creation.
alter table public.support_tickets alter column id set default gen_random_uuid();
update eventra_admin.modules set can_create=true,editable=array['user_id','category','subject','description'],management_mode='workflow' where name='support_tickets';

create or replace function public.admin_catalog() returns jsonb language plpgsql stable security definer set search_path='' as $$
declare level text:=eventra_admin.require_access(false);result jsonb:='[]';item jsonb;may_write boolean;begin
 for item in select value from jsonb_array_elements(eventra_admin.team_legacy_admin_catalog()) loop
  if level<>'owner' and item->>'name' in ('admins','admin_audit_log','admin_storage_cleanup','fcm_tokens') then continue;end if;
  if level not in ('owner','admin') and not exists(select 1 from eventra_admin.team_permissions where admin_id=auth.uid() and module=item->>'name') then continue;end if;
  may_write:=level in ('owner','admin') or (level='staff' and exists(select 1 from eventra_admin.team_permissions where admin_id=auth.uid() and module=item->>'name' and can_write));
  item:=item||jsonb_build_object('permitted_write',may_write,'can_create',may_write and (item->>'can_create')::boolean,'can_delete',level='owner' and (item->>'can_delete')::boolean);
  if level<>'owner' and item->>'name'='users' then item:=jsonb_set(item,'{actions}','[]');end if;
  if not may_write then item:=jsonb_set(item,'{fields}',coalesce((select jsonb_agg(f||'{"writable":false}'::jsonb) from jsonb_array_elements(item->'fields')f),'[]'));end if;
  result:=result||jsonb_build_array(item);
 end loop;
 return result;
end $$;

create or replace function public.admin_save(p_module text,p_data jsonb,p_id text default null,p_revision text default null,p_request_id uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare previous jsonb;result jsonb;begin
 perform eventra_admin.require_module(p_module,true);
 if p_module='businesses' then
  if p_id is not null and p_data ? 'vendor_id' then
   select to_jsonb(b) into previous from public.businesses b where id::text=p_id;
   if p_data->>'vendor_id' is distinct from previous->>'vendor_id' then raise exception 'An existing business cannot be moved to another vendor';end if;
  end if;
  if p_data->>'primary_category_id' is not null and not exists(select 1 from public.category_nodes where id::text=p_data->>'primary_category_id' and parent_id is null) then raise exception 'Choose a main category for this business';end if;
  if p_id is not null and p_data ? 'primary_category_id' and p_data->>'primary_category_id' is not null and not exists(select 1 from public.business_category_nodes where business_id::text=p_id and category_node_id::text=p_data->>'primary_category_id') then raise exception 'Use Manage categories to change the primary category';end if;
 elsif p_module='support_tickets' then
  if p_id is not null and p_data ? 'user_id' and not exists(select 1 from public.support_tickets where id::text=p_id and user_id::text=p_data->>'user_id') then raise exception 'A support case cannot be moved to another user';end if;
  if p_data ? 'user_id' and not exists(select 1 from public.users where id::text=p_data->>'user_id' and role in ('customer','vendor')) then raise exception 'Choose an existing customer or vendor';end if;
 end if;
 result:=eventra_admin.team_legacy_admin_save(p_module,p_data,p_id,p_revision,p_request_id);
 if p_module='businesses' and p_id is null and result->>'primary_category_id' is not null then
  insert into public.business_category_nodes(business_id,category_node_id) values((result->>'id')::uuid,(result->>'primary_category_id')::uuid) on conflict do nothing;
 end if;
 return result;
end $$;

create or replace function public.admin_delete_record(p_module text,p_id text,p_revision text,p_reason text,p_confirmation text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare m eventra_admin.modules;before_row jsonb;fk record;join_sql text;has_reference boolean;media boolean;begin
 if eventra_admin.require_access(true)<>'owner' then raise exception 'Only an owner can delete records' using errcode='42501';end if;
 perform eventra_admin.require_module(p_module,true);
 select * into m from eventra_admin.modules where name=p_module and can_delete;
 if not found or p_module not in ('category_nodes','event_types','administrative_regions','businesses','services','banners','social_links','support_faqs','support_settings','about_eventra_content','legal_documents','vendor_announcements','home_feed_sections') then raise exception 'This module uses a protected lifecycle; direct deletion is unavailable' using errcode='42501';end if;
 if length(trim(coalesce(p_reason,''))) not between 5 and 1000 or p_confirmation is distinct from p_id then raise exception 'Enter a reason and type the exact record ID';end if;
 execute format('select to_jsonb(t) from public.%I t where t.%I::text=$1 for update',m.name,m.pk) into before_row using p_id;
 if before_row is null then raise exception 'Record not found';end if;
 if md5(before_row::text) is distinct from p_revision then raise exception 'Record changed. Reload before deleting.';end if;
 if m.name='legal_documents' and (before_row->>'status'<>'draft' or before_row->>'published_at' is not null) then raise exception 'Published legal history must be archived, never deleted';end if;
 -- Locking the parent row also serializes concurrent FK inserts. Block CASCADE
 -- and SET NULL references as well as RESTRICT, including self-referencing trees.
 for fk in select k.oid,k.conrelid,k.conkey,k.confkey,n.nspname,c.relname
 from pg_constraint k join pg_class c on c.oid=k.conrelid join pg_namespace n on n.oid=c.relnamespace
 where k.contype='f' and k.confrelid=to_regclass('public.'||m.name) loop
  if fk.nspname='eventra_feed' and fk.relname='service_metrics' then continue;end if;
  if m.name='businesses' and fk.nspname='public' and fk.relname='business_category_nodes' then continue;end if;
  select string_agg(format('c.%I=p.%I',ca.attname,pa.attname),' and ') into join_sql
  from unnest(fk.conkey,fk.confkey) as keys(child_key,parent_key)
  join pg_attribute ca on ca.attrelid=fk.conrelid and ca.attnum=keys.child_key
  join pg_attribute pa on pa.attrelid=to_regclass('public.'||m.name) and pa.attnum=keys.parent_key;
  execute format('select exists(select 1 from %I.%I c join public.%I p on %s where p.%I::text=$1)',fk.nspname,fk.relname,m.name,join_sql,m.pk) into has_reference using p_id;
  if has_reference then raise exception 'Cannot delete: linked records exist in %. Use the status/archive workflow instead.',fk.relname;end if;
 end loop;
 execute format('delete from public.%I where %I::text=$1',m.name,m.pk) using p_id;
 insert into public.admin_audit_log(actor_id,module,record_id,action,before_data,reason) values(auth.uid(),m.name,p_id,'delete',eventra_admin.clean(m.name,before_row),trim(p_reason));
 media:=before_row->>'image_url' is not null or before_row->>'logo_url' is not null or before_row->>'banner_url' is not null or (jsonb_typeof(before_row->'gallery')='array' and jsonb_array_length(before_row->'gallery')>0);
 return jsonb_build_object('deleted',true,'retained_media',coalesce(media,false));
end $$;
revoke all on function public.admin_delete_record(text,text,text,text,text) from public,anon;
grant execute on function public.admin_delete_record(text,text,text,text,text) to authenticated;
update eventra_admin.modules set actions=array['suspend_account','restore_account'] where name='users';
create or replace function public.admin_record(p_module text,p_id text) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;raw_row jsonb;ban timestamptz;begin
 perform eventra_admin.require_module(p_module,false);
 result:=eventra_admin.team_legacy_admin_record(p_module,p_id);
 if p_module='users' then
  select to_jsonb(u),a.banned_until into raw_row,ban from public.users u join auth.users a on a.id=u.id where u.id::text=p_id;
  result:=result||jsonb_build_object('_revision',md5(raw_row::text||coalesce(ban::text,'')),'_account_suspended',ban>now(),'_managed_admin',exists(select 1 from public.admins where id::text=p_id));
 end if;
 return result;
end $$;
create or replace function public.admin_action(p_module text,p_id text,p_action text,p_revision text,p_values jsonb default '{}') returns jsonb
language plpgsql security definer set search_path='' as $$
declare level text;raw_row jsonb;ban timestamptz;reason text:=trim(coalesce(p_values->>'reason',''));begin
 perform eventra_admin.require_module(p_module,true);
 if p_module='users' and p_action in ('suspend_account','restore_account') then
  level:=eventra_admin.require_access(true);
  if level<>'owner' then raise exception 'Only an owner can change account access' using errcode='42501';end if;
  if exists(select 1 from public.admins where id::text=p_id) then raise exception 'Manage admin access through Team & Access';end if;
  if length(reason) not between 5 and 1000 then raise exception 'Enter a reason of at least five characters';end if;
  select banned_until into ban from auth.users where id::text=p_id for update;
  select to_jsonb(u) into raw_row from public.users u where u.id::text=p_id for update;
  if raw_row is null then raise exception 'Account not found';end if;
  if p_revision is distinct from md5(raw_row::text||coalesce(ban::text,'')) then raise exception 'Account changed. Reload before continuing.';end if;
  update auth.users set banned_until=case when p_action='suspend_account' then now()+interval '100 years' else null end,updated_at=now() where id::text=p_id;
  insert into public.admin_audit_log(actor_id,module,record_id,action,before_data,after_data,reason) values(auth.uid(),'users',p_id,p_action,jsonb_build_object('suspended',ban>now()),jsonb_build_object('suspended',p_action='suspend_account'),reason);
  return public.admin_record('users',p_id);
 end if;
 return eventra_admin.team_legacy_admin_action(p_module,p_id,p_action,p_revision,p_values);
end $$;

notify pgrst,'reload schema';
commit;
