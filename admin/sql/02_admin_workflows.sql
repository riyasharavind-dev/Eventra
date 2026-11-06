begin;
-- Reviewers are Admin Auth identities, not vendor/customer-only public.users.
alter table public.vendor_verifications drop constraint if exists vendor_verifications_reviewed_by_fkey;
alter table public.vendor_verifications add constraint vendor_verifications_reviewed_by_fkey foreign key(reviewed_by) references auth.users(id) on delete set null;
alter table public.verification_documents drop constraint if exists verification_documents_reviewed_by_fkey;
alter table public.verification_documents add constraint verification_documents_reviewed_by_fkey foreign key(reviewed_by) references auth.users(id) on delete set null;

create table if not exists public.admin_storage_cleanup (
 id uuid primary key default gen_random_uuid(),request_id uuid references public.account_deletion_requests(id) on delete set null,
 files jsonb not null default '[]',status text not null default 'pending' check(status in ('pending','completed')),
 created_at timestamptz not null default now(),completed_at timestamptz
);
alter table public.admin_storage_cleanup enable row level security;
revoke all on public.admin_storage_cleanup from public,anon,authenticated;
drop policy if exists eventra_admin_storage_delete on storage.objects;
create policy eventra_admin_storage_delete on storage.objects for delete to authenticated using(public.eventra_admin_can_write() and bucket_id in ('profile-images','banners','profile','service-gallery','vendor-verification-documents','support-attachments','business-media','business-documents'));

create or replace function public.admin_action(p_module text,p_id text,p_action text,p_revision text,p_values jsonb default '{}')
returns jsonb language plpgsql security definer set search_path='' as $$
declare m eventra_admin.modules; level text; before_row jsonb; after_row jsonb; note text; ids uuid[]; primary_id uuid; target_user uuid; target_email text; files jsonb;
begin
 level:=eventra_admin.require_access(true);
 select * into m from eventra_admin.modules where name=p_module;
 if not found or not p_action=any(m.actions) then raise exception 'Action is not available for this module'; end if;
 execute format('select to_jsonb(t) from public.%I t where t.%I::text=$1 for update',m.name,m.pk) into before_row using p_id;
 if before_row is null then raise exception 'Record not found'; end if;
 if p_revision is distinct from md5(before_row::text) then raise exception 'This record changed. Reload before continuing.'; end if;
 note:=nullif(trim(p_values->>'reason'),'');
 if m.name='bookings' then
  if not ((before_row->>'status'='pending' and p_action in ('accepted','rejected','cancelled')) or (before_row->>'status'='accepted' and p_action in ('completed','cancelled'))) then raise exception 'Invalid booking transition'; end if;
  if p_action in ('rejected','cancelled') and length(coalesce(note,''))<3 then raise exception 'A reason is required'; end if;
  if p_action='completed' and (
   coalesce((before_row->>'event_end_date')::date,(before_row->>'event_date')::date)>(now() at time zone (before_row->>'event_timezone'))::date
   or ((before_row->>'event_end_time') is not null and ((coalesce((before_row->>'event_end_date')::date,(before_row->>'event_date')::date)+(before_row->>'event_end_time')::time) at time zone (before_row->>'event_timezone'))>now())
   or ((before_row->>'event_end_time') is null and (before_row->>'event_start_time') is not null and (((before_row->>'event_date')::date+(before_row->>'event_start_time')::time) at time zone (before_row->>'event_timezone'))>now())
  ) then raise exception 'This event has not finished yet'; end if;
  update public.bookings set status=p_action,status_reason=note where id::text=p_id;
 elsif m.name='vendor_verifications' then
  if p_action in ('rejected','resubmission_required') and note is null then raise exception 'A review reason is required'; end if;
  if p_action='verified' and not exists(select 1 from public.verification_documents where vendor_id::text=before_row->>'vendor_id' and status='verified') then raise exception 'Verify the uploaded proof documents first'; end if;
  update public.vendor_verifications set status=p_action,reviewed_at=now(),reviewed_by=auth.uid(),review_note=note,rejection_reason=case when p_action in ('rejected','resubmission_required') then note else null end,updated_at=now() where id::text=p_id;
 elsif m.name='verification_documents' then
  if p_action in ('rejected','resubmission_required') and note is null then raise exception 'A reason is required'; end if;
  if p_action='verified' and (before_row->>'storage_path' is null or not exists(select 1 from storage.objects where bucket_id='vendor-verification-documents' and name=before_row->>'storage_path')) then raise exception 'Uploaded proof file is missing'; end if;
  update public.verification_documents set status=p_action,reviewed_at=now(),reviewed_by=auth.uid(),rejection_reason=case when p_action in ('rejected','resubmission_required') then note else null end,updated_at=now() where id::text=p_id;
 elsif m.name='vendor_identity_verifications' then
  if note is null then raise exception 'Record the manual identity-review reason'; end if;
  update public.vendor_identity_verifications set status=p_action,verification_method='manual_admin_review',verification_provider='Eventor Admin',verified_at=case when p_action='verified' then now() else null end,failure_reason=case when p_action='failed' then note else null end,updated_at=now() where id::text=p_id;
 elsif m.name='business_verifications' then
  if p_action='rejected' and note is null then raise exception 'A rejection reason is required'; end if;
  if p_action='approved' and not exists(select 1 from storage.objects where bucket_id='business-documents' and name=before_row->>'document_path') then raise exception 'Business proof file is missing'; end if;
  update public.business_verifications set status=p_action,reviewed_at=now(),review_note=note where business_id::text=p_id;
 elsif m.name='service_reviews' then
  if note is null then raise exception 'A moderation reason is required'; end if;
  update public.service_reviews set moderation_status=p_action,moderation_note=note,moderated_at=now(),moderated_by=auth.uid() where id::text=p_id;
 elsif m.name='service_review_reports' then
  if note is null then raise exception 'Record the report decision'; end if;
  update public.service_review_reports set status=p_action,admin_note=note,resolved_at=now() where id::text=p_id;
 elsif m.name='support_tickets' then
  if p_action='reply' then
   if length(trim(coalesce(p_values->>'body',''))) not between 1 and 4000 then raise exception 'Enter a reply (maximum 4000 characters)'; end if;
   insert into public.support_messages(ticket_id,author_id,sender_role,body) values(p_id::uuid,auth.uid(),'support',trim(p_values->>'body'));
   update public.support_tickets set status='waiting_for_vendor' where id::text=p_id;
  else update public.support_tickets set status=p_action where id::text=p_id; end if;
 elsif m.name='legal_documents' then
  if p_action='new_version' then
   return public.admin_save('legal_documents',jsonb_build_object('document_type',before_row->>'document_type','audience',before_row->>'audience','language_code',before_row->>'language_code','title',before_row->>'title','content_markdown',before_row->>'content_markdown'));
  elsif p_action='publish' then
   if before_row->>'status'<>'draft' then raise exception 'Only drafts can be published'; end if;
   if (before_row->>'effective_at')::timestamptz>now() then raise exception 'Future-dated publication is not enabled. Publish when the effective date arrives.'; end if;
   perform pg_advisory_xact_lock(hashtextextended(concat(before_row->>'document_type',':',before_row->>'audience',':',before_row->>'language_code'),801));
   update public.legal_documents set status='archived' where document_type=before_row->>'document_type' and audience=before_row->>'audience' and language_code=before_row->>'language_code' and status='published';
   update public.legal_documents set status='published',published_at=now(),effective_at=coalesce(effective_at,now()),published_by=auth.uid() where id::text=p_id;
  else update public.legal_documents set status='archived' where id::text=p_id; end if;
 elsif m.name='businesses' and p_action='categories' then
  ids:=array(select jsonb_array_elements_text(p_values->'category_ids')::uuid);primary_id:=(p_values->>'primary_category_id')::uuid;
  if coalesce(array_length(ids,1),0)=0 or primary_id is null or not primary_id=any(ids) then raise exception 'Choose parent categories and one primary category'; end if;
  if exists(select 1 from unnest(ids) x where not exists(select 1 from public.category_nodes where id=x and parent_id is null)) then raise exception 'Business categories must be parent categories'; end if;
  if exists(with recursive allowed(id) as (select unnest(ids) union select n.id from public.category_nodes n join allowed a on n.parent_id=a.id) select 1 from public.services where business_id::text=p_id and category_node_id not in(select id from allowed)) then raise exception 'An existing service still uses a category you removed'; end if;
  delete from public.business_category_nodes where business_id::text=p_id;
  insert into public.business_category_nodes(business_id,category_node_id) select p_id::uuid,x from (select distinct unnest(ids) x) a;
  update public.businesses set primary_category_id=primary_id,updated_at=now() where id::text=p_id;
 elsif m.name='account_deletion_requests' then
  if before_row->>'status' not in ('pending','in_review') then raise exception 'This request has already been processed'; end if;
  if p_action='delete_account' then
   if level<>'owner' then raise exception 'Only an owner can delete an account'; end if;
   if before_row->>'status'<>'in_review' then raise exception 'Mark the request In Review first'; end if;
   target_user:=(before_row->>'user_id')::uuid;
   if target_user is null or target_user=auth.uid() or exists(select 1 from public.admins where id=target_user) then raise exception 'This account cannot be deleted through a customer/vendor request'; end if;
   select email into target_email from auth.users where id=target_user;
   if lower(coalesce(p_values->>'confirm_email',''))<>lower(coalesce(target_email,'')) or target_email is null then raise exception 'Type the exact account email to confirm deletion'; end if;
   if exists(select 1 from public.bookings where (vendor_id=target_user or customer_id=target_user) and status in ('pending','accepted')) then raise exception 'Resolve pending/accepted bookings before deleting this account'; end if;
   if note is null then raise exception 'A processing reason is required'; end if;
   select coalesce(jsonb_agg(jsonb_build_object('bucket',bucket_id,'path',name)),'[]'::jsonb) into files from storage.objects
   where bucket_id in ('profile','profile-images','service-gallery','business-media','vendor-verification-documents','business-documents','support-attachments')
    and ((storage.foldername(name))[1]=target_user::text or ((storage.foldername(name))[1] in ('services','businesses','vendors','profiles') and (storage.foldername(name))[2]=target_user::text));
   if jsonb_array_length(files)>0 then insert into public.admin_storage_cleanup(request_id,files) values(p_id::uuid,files); end if;
   delete from public.verification_documents where vendor_id=target_user;
   delete from public.vendor_verifications where vendor_id=target_user;
   update public.account_deletion_requests set status='completed',public_note=note,reviewed_by=auth.uid(),completed_at=now() where id::text=p_id;
   delete from auth.users where id=target_user;
  else
   if p_action='rejected' and note is null then raise exception 'A rejection reason is required'; end if;
   update public.account_deletion_requests set status=p_action,public_note=note,reviewed_by=auth.uid() where id::text=p_id;
  end if;
 elsif m.name='fcm_tokens' and p_action='revoke' then
  if note is null then raise exception 'A revocation reason is required'; end if;
  delete from public.fcm_tokens where id::text=p_id;
 elsif m.name='admin_storage_cleanup' and p_action='cleanup_completed' then
  if exists(select 1 from jsonb_array_elements(before_row->'files') f join storage.objects o on o.bucket_id=f->>'bucket' and o.name=f->>'path') then raise exception 'Storage files are still present. Retry cleanup first.'; end if;
  update public.admin_storage_cleanup set status='completed',completed_at=now() where id::text=p_id;
 elsif m.name='admins' then
  if level<>'owner' then raise exception 'Only an owner can manage admin access'; end if;
  if p_action='deactivate' then
   if p_id=auth.uid()::text then raise exception 'You cannot deactivate your own session'; end if;
   if before_row->>'access_level'='owner' and (select count(*) from public.admins where access_level='owner' and is_active)<=1 then raise exception 'Keep at least one active owner'; end if;
   update public.admins set is_active=false,updated_at=now() where id::text=p_id;
  else update public.admins set is_active=true,updated_at=now() where id::text=p_id; end if;
 else raise exception 'Unsupported admin action'; end if;
 if not (m.name='fcm_tokens' and p_action='revoke') then execute format('select to_jsonb(t) from public.%I t where t.%I::text=$1',m.name,m.pk) into after_row using p_id; end if;
 insert into public.admin_audit_log(actor_id,module,record_id,action,before_data,after_data,reason)
 values(auth.uid(),m.name,p_id,p_action,eventra_admin.clean(m.name,before_row),eventra_admin.clean(m.name,after_row),note);
 return eventra_admin.decorate(m.name,after_row);
end $$;

create or replace function public.admin_grant_access(p_email text,p_name text,p_access_level text default 'admin') returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid; result jsonb;
begin
 if eventra_admin.require_access(true)<>'owner' then raise exception 'Only an owner can grant access'; end if;
 if p_access_level not in ('owner','admin','viewer') then raise exception 'Invalid access level'; end if;
 select id into uid from auth.users where lower(email)=lower(trim(p_email));
 if uid is null then raise exception 'Create the Auth account first using trusted account provisioning'; end if;
 if exists(select 1 from public.admins where id=uid and access_level='owner' and is_active) and p_access_level<>'owner' and (select count(*) from public.admins where access_level='owner' and is_active)<=1 then raise exception 'Keep at least one active owner'; end if;
 insert into public.admins(id,name,access_level) values(uid,trim(p_name),p_access_level)
 on conflict(id) do update set name=excluded.name,access_level=excluded.access_level,is_active=true,updated_at=now() returning to_jsonb(admins.*) into result;
 insert into public.admin_audit_log(actor_id,module,record_id,action,after_data) values(auth.uid(),'admins',uid::text,'grant_access',result);
 return result;
end $$;
revoke all on function public.admin_action(text,text,text,text,jsonb),public.admin_grant_access(text,text,text) from public,anon;
grant execute on function public.admin_action(text,text,text,text,jsonb),public.admin_grant_access(text,text,text) to authenticated;
commit;
