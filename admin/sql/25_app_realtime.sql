begin;
create table if not exists public.app_data_revisions (
 audience text not null, dataset text not null,
 version bigint not null default 1, changed_at timestamptz not null default clock_timestamp(),
 primary key(audience,dataset),
 check(audience in ('public','admin') or audience like 'user:%'),
 check(length(dataset) between 1 and 80)
);
alter table public.app_data_revisions enable row level security;
revoke all on public.app_data_revisions from public,anon,authenticated;
grant select on public.app_data_revisions to anon,authenticated;
create or replace function eventra_security.can_observe_admin() returns boolean language plpgsql stable security definer set search_path='' as $$
begin perform eventra_admin.require_access(false); return true;
exception when insufficient_privilege then return false;end $$;
revoke all on function eventra_security.can_observe_admin() from public,anon,authenticated;
create or replace function public.can_read_app_revision(p_audience text) returns boolean language sql stable security definer set search_path='' as $$
 select p_audience='public' or (auth.uid() is not null and p_audience='user:'||auth.uid()::text)
 or (p_audience='admin' and eventra_security.can_observe_admin())
$$;
revoke all on function public.can_read_app_revision(text) from public;
grant execute on function public.can_read_app_revision(text) to anon,authenticated;
drop policy if exists app_revision_read on public.app_data_revisions;
create policy app_revision_read on public.app_data_revisions for select to anon,authenticated using(public.can_read_app_revision(audience));

create or replace function eventra_security.touch_app_revision(p_audience text,p_dataset text) returns void language sql security definer set search_path='' as $$
 insert into public.app_data_revisions(audience,dataset) values(p_audience,p_dataset)
 on conflict(audience,dataset) do update set version=app_data_revisions.version+1,changed_at=clock_timestamp()
$$;
revoke all on function eventra_security.touch_app_revision(text,text) from public,anon,authenticated;
create or replace function eventra_security.publish_app_change() returns trigger language plpgsql security definer set search_path='' as $$
declare old_row jsonb:='{}'; new_row jsonb:='{}'; r jsonb; k text; uid text; recipients text[]:='{}';
 dataset text:=tg_table_name; target uuid; parent jsonb;
begin
 if tg_op<>'INSERT' then old_row:=to_jsonb(old);end if;
 if tg_op<>'DELETE' then new_row:=to_jsonb(new);end if;
 if tg_op='UPDATE' and old_row=new_row then return null;end if;
 if tg_table_schema='auth' then dataset:='access';end if;
 if tg_table_schema='storage' then dataset:='storage';end if;
 if tg_table_schema='eventra_feed' and tg_table_name='customer_service_signals' then dataset:='recommendations';end if;
 -- Only dataset names and monotonically increasing revisions leave the DB.
 if dataset in ('services','businesses','business_category_nodes','vendors','category_nodes','event_types','banners','legal_documents','about_eventra_content','support_faqs','support_settings','social_links','administrative_regions','administrative_region_boundaries','home_feed_sections','home_feed_pinned_items','service_reviews','service_metrics') then
  recipients:=array_append(recipients,'public');
 end if;
 recipients:=array_append(recipients,'admin');
 foreach r in array array[old_row,new_row] loop
  foreach k in array array['vendor_id','customer_id','user_id','recipient_id','reporter_id','author_id','actor_id','admin_id'] loop
   uid:=r->>k;
   if uid is not null and uid ~* '^[0-9a-f]{8}-[0-9a-f-]{27}$' then recipients:=array_append(recipients,'user:'||uid);end if;
  end loop;
  if dataset in ('users','vendors','customers','admins','access') and r->>'id' is not null then
   recipients:=array_append(recipients,'user:'||(r->>'id'));
  end if;
  if r->>'service_id' is not null and dataset<>'recommendations' then
   select vendor_id into target from public.services where id=(r->>'service_id')::uuid;
   if target is not null then recipients:=array_append(recipients,'user:'||target::text);end if;
  end if;
  if r->>'business_id' is not null then
   select vendor_id into target from public.businesses where id=(r->>'business_id')::uuid;
   if target is not null then recipients:=array_append(recipients,'user:'||target::text);end if;
  end if;
  if r->>'booking_id' is not null then
   select to_jsonb(b) into parent from public.bookings b where id=(r->>'booking_id')::uuid;
   if parent->>'vendor_id' is not null then recipients:=array_append(recipients,'user:'||(parent->>'vendor_id'));end if;
   if dataset<>'booking_vendor_notes' and parent->>'customer_id' is not null then recipients:=array_append(recipients,'user:'||(parent->>'customer_id'));end if;
  end if;
  if r->>'ticket_id' is not null then
   select user_id into target from public.support_tickets where id=(r->>'ticket_id')::uuid;
   if target is not null then recipients:=array_append(recipients,'user:'||target::text);end if;
  end if;
  if dataset='vendor_announcements' and r->>'recipient_id' is null then
   -- A global announcement signal contains no announcement text or recipients.
   recipients:=array_append(recipients,'public');
  end if;
 end loop;
 if tg_table_schema='auth' and (tg_op<>'UPDATE' or old_row->'banned_until' is distinct from new_row->'banned_until' or old_row->'deleted_at' is distinct from new_row->'deleted_at')
 and exists(select 1 from public.vendors where id=coalesce(new_row->>'id',old_row->>'id')::uuid) then
  perform eventra_security.touch_app_revision('public','services');
 end if;
 for uid in select distinct x from unnest(recipients) x where x is not null order by x loop
  perform eventra_security.touch_app_revision(uid,dataset);
 end loop;
 return null;
end $$;
revoke all on function eventra_security.publish_app_change() from public,anon,authenticated;
do $$ declare t record;
begin
 for t in select schemaname,tablename from pg_tables where
  (schemaname='public' and tablename<>'app_data_revisions') or
  (schemaname='auth' and tablename='users') or
  (schemaname='storage' and tablename='objects') or
  (schemaname='eventra_feed' and tablename in ('customer_service_signals','service_metrics')) or
  (schemaname='eventra_admin' and tablename in ('modules','module_permissions','team_permissions','team_invitations','company_email_settings')) loop
  execute format('drop trigger if exists eventor_app_revision on %I.%I',t.schemaname,t.tablename);
  execute format('create trigger eventor_app_revision after insert or update or delete on %I.%I for each row execute function eventra_security.publish_app_change()',t.schemaname,t.tablename);
 end loop;
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='app_data_revisions') then
  alter publication supabase_realtime add table public.app_data_revisions;
 end if;
end $$;
commit;
