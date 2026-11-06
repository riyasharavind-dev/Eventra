begin;
create schema if not exists eventra_admin;
revoke all on schema eventra_admin from public,anon,authenticated;
create table if not exists public.admins (
 id uuid primary key references auth.users(id) on delete cascade,
 name text not null,
 access_level text not null default 'admin' check(access_level in ('owner','admin','viewer')),
 is_active boolean not null default true,
 phone text, avatar_url text,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now()
);
alter table public.admins enable row level security;
revoke all on public.admins from public,anon,authenticated;
create table if not exists public.admin_audit_log (
 id bigint generated always as identity primary key,
 actor_id uuid references auth.users(id) on delete set null,
 module text not null,record_id text,action text not null,
 before_data jsonb,after_data jsonb,reason text,
 created_at timestamptz not null default now()
);
alter table public.admin_audit_log enable row level security;
revoke all on public.admin_audit_log from public,anon,authenticated;
revoke all on sequence public.admin_audit_log_id_seq from public,anon,authenticated;
create index if not exists admin_audit_record_idx on public.admin_audit_log(module,record_id,created_at desc);
create table if not exists eventra_admin.modules (
 name text primary key,label text not null,section text not null,pk text not null default 'id',
 can_create boolean not null default false,editable text[] not null default '{}',
 choices jsonb not null default '{}',actions text[] not null default '{}',sort_column text not null default 'created_at'
);
revoke all on all tables in schema eventra_admin from public,anon,authenticated;
create table if not exists eventra_admin.mutation_requests(request_id uuid primary key,actor_id uuid not null,module text not null,result jsonb not null,created_at timestamptz not null default now());
revoke all on eventra_admin.mutation_requests from public,anon,authenticated;

create or replace function public.eventra_is_admin() returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.admins where id=auth.uid() and is_active)
$$;
create or replace function eventra_admin.require_access(p_write boolean default false) returns text
language plpgsql stable security definer set search_path='' as $$
declare level text;
begin
 select access_level into level from public.admins where id=auth.uid() and is_active;
 if level is null or (p_write and level='viewer') then raise exception 'Admin permission required' using errcode='42501'; end if;
 return level;
end $$;
create or replace function public.admin_context() returns jsonb
language sql stable security definer set search_path='' as $$
 select to_jsonb(a)||jsonb_build_object('email',u.email,'role','admin') from public.admins a join auth.users u on u.id=a.id
 where a.id=auth.uid() and a.is_active
$$;
revoke all on function public.eventra_is_admin() from public;
grant execute on function public.eventra_is_admin() to anon,authenticated;
create or replace function public.eventra_admin_can_write() returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.admins where id=auth.uid() and is_active and access_level in ('owner','admin'))
$$;
revoke all on function public.eventra_admin_can_write() from public,anon;
grant execute on function public.eventra_admin_can_write() to authenticated;
revoke all on function public.admin_context() from public,anon;
grant execute on function public.admin_context() to authenticated;

-- Admin Auth users have no vendor/customer profile. Signup metadata never grants
-- admin rights: only a trusted owner inserts/updates the separate admins table.
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path='' as $$
declare requested_role text;
begin
 requested_role:=new.raw_user_meta_data->>'role';
 if requested_role='admin' then return new; end if;
 if requested_role is null or requested_role not in ('vendor','customer') then raise exception 'Choose a vendor or customer account type'; end if;
 insert into public.users(id,name,email,role) values(new.id,coalesce(new.raw_user_meta_data->>'name',''),new.email,requested_role);
 if requested_role='vendor' then insert into public.vendors(id,name,email) values(new.id,coalesce(new.raw_user_meta_data->>'name',''),new.email);
 else insert into public.customers(id,name,email) values(new.id,coalesce(new.raw_user_meta_data->>'name',''),new.email); end if;
 return new;
end $$;

create or replace function eventra_admin.clean(p_module text,p_row jsonb) returns jsonb
language sql immutable set search_path='' as $$
 select case when p_module='fcm_tokens' and p_row is not null then p_row||jsonb_build_object('token','••••'||right(p_row->>'token',6)) else p_row end
$$;
create or replace function eventra_admin.decorate(p_module text,p_row jsonb) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare rel record; ref jsonb; labels jsonb:='{}';
begin
 if p_row is null then return null; end if;
 for rel in select a.attname as column_name,n.nspname as ref_schema,c.relname as ref_table,ra.attname as ref_column
 from pg_catalog.pg_constraint k join pg_catalog.pg_attribute a on a.attrelid=k.conrelid and a.attnum=k.conkey[1]
 join pg_catalog.pg_class c on c.oid=k.confrelid join pg_catalog.pg_namespace n on n.oid=c.relnamespace
 join pg_catalog.pg_attribute ra on ra.attrelid=k.confrelid and ra.attnum=k.confkey[1]
 where k.contype='f' and k.conrelid=to_regclass('public.'||p_module) and array_length(k.conkey,1)=1
 loop
  if p_row->>rel.column_name is not null then
   if rel.ref_schema='auth' and rel.ref_table='users' then
    select jsonb_build_object('label',coalesce(email,id::text),'table',case when exists(select 1 from public.admins where id=u.id) then 'admins' else 'users' end,'id',id) into ref from auth.users u where id::text=p_row->>rel.column_name;
   else
    execute format('select jsonb_build_object(''label'',coalesce(to_jsonb(x)->>''name'',to_jsonb(x)->>''subject'',to_jsonb(x)->>''title'',to_jsonb(x)->>''email'',x.%I::text),''table'',%L,''id'',x.%I::text) from %I.%I x where x.%I::text=$1 limit 1',rel.ref_column,rel.ref_table,rel.ref_column,rel.ref_schema,rel.ref_table,rel.ref_column)
    into ref using p_row->>rel.column_name;
   end if;
   labels:=labels||jsonb_build_object(rel.column_name,ref);
  end if;
 end loop;
 return eventra_admin.clean(p_module,p_row)||jsonb_build_object('_revision',md5(p_row::text),'_relations',labels);
end $$;

create or replace function public.admin_catalog() returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 perform eventra_admin.require_access(false);
 return coalesce((select jsonb_agg(to_jsonb(m)||jsonb_build_object('fields',(
  select jsonb_agg(jsonb_build_object('name',c.column_name,'type',c.udt_name,
   'required',c.is_nullable='NO' and c.column_default is null and c.is_identity='NO',
   'nullable',c.is_nullable='YES','default',c.column_default,'writable',c.column_name=any(m.editable),
   'choices',m.choices->c.column_name,
   'reference_table',(select rc.relname from pg_catalog.pg_constraint k join pg_catalog.pg_class rc on rc.oid=k.confrelid join pg_catalog.pg_attribute a on a.attrelid=k.conrelid and a.attnum=k.conkey[1] where k.contype='f' and k.conrelid=to_regclass('public.'||m.name) and a.attname=c.column_name limit 1),
   'reference_column',(select a.attname from pg_catalog.pg_constraint k join pg_catalog.pg_attribute a on a.attrelid=k.confrelid and a.attnum=k.confkey[1] join pg_catalog.pg_attribute la on la.attrelid=k.conrelid and la.attnum=k.conkey[1] where k.contype='f' and k.conrelid=to_regclass('public.'||m.name) and la.attname=c.column_name limit 1)
  ) order by c.ordinal_position) from information_schema.columns c where c.table_schema='public' and c.table_name=m.name
  )) order by m.section,m.label) from eventra_admin.modules m),'[]'::jsonb);
end $$;

create or replace function public.admin_records(p_module text,p_search text default '',p_offset integer default 0,p_limit integer default 30,p_filters jsonb default '{}') returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare m eventra_admin.modules; where_sql text:='true'; key text; val jsonb; records jsonb; total bigint;
begin
 perform eventra_admin.require_access(false);
 select * into m from eventra_admin.modules where name=p_module;
 if not found then raise exception 'Unknown admin module'; end if;
 for key,val in select * from jsonb_each(coalesce(p_filters,'{}')) loop
  if not exists(select 1 from information_schema.columns where table_schema='public' and table_name=m.name and column_name=key) then raise exception 'Invalid filter'; end if;
  if val='null'::jsonb then where_sql:=where_sql||format(' and to_jsonb(t)->>%L is null',key);
  else where_sql:=where_sql||format(' and to_jsonb(t)->>%L = %L',key,val#>>'{}'); end if;
 end loop;
 if length(trim(coalesce(p_search,'')))>0 then
  where_sql:=where_sql||' and (exists(select 1 from jsonb_each_text(to_jsonb(t)) kv where position(lower($1) in lower(kv.value))>0))';
 end if;
 execute format('select count(*) from public.%I t where %s',m.name,where_sql) into total using trim(p_search);
 execute format('select coalesce(jsonb_agg(eventra_admin.decorate(%L,r.data)),''[]''::jsonb) from (select to_jsonb(t) data from public.%I t where %s order by t.%I desc nulls last,t.%I::text desc offset $2 limit $3) r',m.name,m.name,where_sql,m.sort_column,m.pk)
 into records using trim(p_search),greatest(coalesce(p_offset,0),0),greatest(1,least(coalesce(p_limit,30),100));
 return jsonb_build_object('total',total,'rows',records);
end $$;

create or replace function public.admin_record(p_module text,p_id text) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare m eventra_admin.modules; data jsonb;
begin
 perform eventra_admin.require_access(false);select * into m from eventra_admin.modules where name=p_module;
 if not found then raise exception 'Unknown admin module'; end if;
 execute format('select to_jsonb(t) from public.%I t where t.%I::text=$1',m.name,m.pk) into data using p_id;
 if data is null then raise exception 'Record not found'; end if;
 return eventra_admin.decorate(m.name,data);
end $$;

create or replace function public.admin_save(p_module text,p_data jsonb,p_id text default null,p_revision text default null,p_request_id uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare m eventra_admin.modules; before_row jsonb; after_row jsonb; key text; cols text; values_sql text; updates text; payload jsonb:=p_data; saved_id text; parent uuid; cycle_found boolean;
begin
 perform eventra_admin.require_access(true);select * into m from eventra_admin.modules where name=p_module;
 if not found then raise exception 'Unknown admin module'; end if;
 if p_id is null and p_request_id is not null then
  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text,802));
  select result into after_row from eventra_admin.mutation_requests where request_id=p_request_id and actor_id=auth.uid() and module=m.name;
  if found then return after_row; end if;
 end if;
 if m.name='admins' and p_id is distinct from auth.uid()::text and eventra_admin.require_access(true)<>'owner' then raise exception 'Only an owner can edit other admin profiles'; end if;
 if p_id is null and not m.can_create then raise exception 'Creation is not available for this module'; end if;
 if jsonb_typeof(payload)<>'object' or payload='{}'::jsonb then raise exception 'Enter values to save'; end if;
 for key in select jsonb_object_keys(payload) loop if not key=any(m.editable) then raise exception 'Field cannot be changed: %',key; end if; end loop;
 if p_id is not null then
  execute format('select to_jsonb(t) from public.%I t where t.%I::text=$1 for update',m.name,m.pk) into before_row using p_id;
  if before_row is null then raise exception 'Record not found'; end if;
  if p_revision is distinct from md5(before_row::text) then raise exception 'This record changed. Reload before saving.'; end if;
  if payload ? m.pk and payload->>m.pk is distinct from before_row->>m.pk then raise exception 'Record identity cannot be changed'; end if;
 end if;
 if m.name='legal_documents' then
  if before_row->>'published_at' is not null then raise exception 'Published legal text is immutable. Create a new draft version.'; end if;
  if p_id is null then
   perform pg_advisory_xact_lock(hashtextextended(concat(payload->>'document_type',':',payload->>'audience',':',payload->>'language_code'),801));
   payload:=payload||jsonb_build_object('version',coalesce((select max(version) from public.legal_documents where document_type=payload->>'document_type' and audience=payload->>'audience' and language_code=payload->>'language_code'),0)+1,'status','draft','created_by',auth.uid());
  end if;
 end if;
 if m.name='category_nodes' and payload->>'parent_id' is not null and p_id is not null then
  parent:=(payload->>'parent_id')::uuid;
  with recursive ancestors(id,parent_id) as (select id,parent_id from public.category_nodes where id=parent union select n.id,n.parent_id from public.category_nodes n join ancestors a on n.id=a.parent_id)
  select exists(select 1 from ancestors where id::text=p_id) into cycle_found;
  if cycle_found then raise exception 'Category hierarchy cannot contain a cycle'; end if;
 end if;
 if m.name='businesses' and payload ? 'availability_status' then
  if payload->>'availability_status' not in ('active','unavailable','archived') then raise exception 'Invalid business availability'; end if;
 end if;
 if m.name='services' then
  if p_id is not null and (payload->>'vendor_id') is distinct from (before_row->>'vendor_id') and payload ? 'vendor_id' then raise exception 'Existing service vendor cannot be changed'; end if;
  if coalesce(payload->>'business_id',before_row->>'business_id') is not null and not exists(select 1 from public.businesses where id::text=coalesce(payload->>'business_id',before_row->>'business_id') and vendor_id::text=coalesce(payload->>'vendor_id',before_row->>'vendor_id')) then raise exception 'Business and vendor must match'; end if;
  if coalesce(payload->>'business_id',before_row->>'business_id') is not null and not exists(
   with recursive allowed(id) as (select category_node_id from public.business_category_nodes where business_id::text=coalesce(payload->>'business_id',before_row->>'business_id') union select n.id from public.category_nodes n join allowed a on n.parent_id=a.id)
   select 1 from allowed where id::text=coalesce(payload->>'category_node_id',before_row->>'category_node_id')
  ) then raise exception 'Service category must belong to the selected business'; end if;
 end if;
 if exists(select 1 from information_schema.columns where table_schema='public' and table_name=m.name and column_name='updated_at') then payload:=payload||jsonb_build_object('updated_at',now()); end if;
 select string_agg(format('%I',k),','),string_agg(format('x.%I',k),','),string_agg(format('%I=x.%I',k,k),',') into cols,values_sql,updates from jsonb_object_keys(payload) k;
 if p_id is null then
  execute format('insert into public.%I(%s) select %s from jsonb_populate_record(null::public.%I,$1) x returning to_jsonb(%I.*)',m.name,cols,values_sql,m.name,m.name) into after_row using payload;
 else
  execute format('update public.%I t set %s from jsonb_populate_record(null::public.%I,$1) x where t.%I::text=$2 returning to_jsonb(t)',m.name,updates,m.name,m.pk) into after_row using payload,p_id;
 end if;
 saved_id:=after_row->>m.pk;
 insert into public.admin_audit_log(actor_id,module,record_id,action,before_data,after_data)
 values(auth.uid(),m.name,saved_id,case when p_id is null then 'create' else 'update' end,eventra_admin.clean(m.name,before_row),eventra_admin.clean(m.name,after_row));
 after_row:=eventra_admin.decorate(m.name,after_row);
 if p_id is null and p_request_id is not null then insert into eventra_admin.mutation_requests(request_id,actor_id,module,result) values(p_request_id,auth.uid(),m.name,after_row);end if;
 return after_row;
end $$;

create or replace function public.admin_overview() returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare counts jsonb:='{}'; m record; value bigint;
begin
 perform eventra_admin.require_access(false);
 for m in select name from eventra_admin.modules loop execute format('select count(*) from public.%I',m.name) into value;counts:=counts||jsonb_build_object(m.name,value);end loop;
 return jsonb_build_object('counts',counts,'pending_bookings',(select count(*) from public.bookings where status='pending'),
  'open_tickets',(select count(*) from public.support_tickets where status not in ('resolved','closed')),
  'verification_queue',(select count(*) from public.vendor_verifications where status in ('pending','under_review','resubmission_required')),
  'open_reports',(select count(*) from public.service_review_reports where status='open'),
  'deletion_queue',(select count(*) from public.account_deletion_requests where status in ('pending','in_review')),
  'recent_audit',(select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) from (select id,actor_id,module,record_id,action,created_at from public.admin_audit_log order by id desc limit 10) x));
end $$;

revoke all on all functions in schema eventra_admin from public,anon,authenticated;
revoke all on function public.admin_catalog() from public,anon;
revoke all on function public.admin_records(text,text,integer,integer,jsonb) from public,anon;
revoke all on function public.admin_record(text,text) from public,anon;
revoke all on function public.admin_save(text,jsonb,text,text,uuid) from public,anon;
revoke all on function public.admin_overview() from public,anon;
grant execute on function public.admin_catalog(),public.admin_records(text,text,integer,integer,jsonb),public.admin_record(text,text),public.admin_save(text,jsonb,text,text,uuid),public.admin_overview() to authenticated;

drop policy if exists eventra_admin_storage_read on storage.objects;
create policy eventra_admin_storage_read on storage.objects for select to authenticated using(public.eventra_is_admin() and bucket_id in ('profile-images','banners','profile','service-gallery','vendor-verification-documents','support-attachments','business-media','business-documents'));
drop policy if exists eventra_admin_storage_upload on storage.objects;
create policy eventra_admin_storage_upload on storage.objects for insert to authenticated with check(public.eventra_admin_can_write() and bucket_id in ('banners','profile','service-gallery','business-media'));
commit;
