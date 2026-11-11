-- Versioned offline language packs. App clients read only published snapshots.
begin;
create schema if not exists eventor_i18n;
revoke all on schema eventor_i18n from public,anon,authenticated;
create table if not exists public.app_languages(
 code text primary key check(code ~ '^[a-z]{2,3}(-[A-Za-z0-9]{2,8}){0,2}$'),
 name text not null check(length(trim(name)) between 1 and 80),
 native_name text not null check(length(trim(native_name)) between 1 and 80),
 direction text not null default 'ltr' check(direction in ('ltr','rtl')),
 is_enabled boolean not null default false,
 published_version integer not null default 0,
 draft_revision bigint not null default 0,
 updated_at timestamptz not null default now()
);
create table if not exists public.app_translation_keys(
 key text primary key check(key ~ '^[a-z0-9_.]+$'),
 module text not null,
 default_text text not null check(length(default_text) between 1 and 12000),
 notes text not null default '',
 is_active boolean not null default true,
 updated_at timestamptz not null default now()
);
create table if not exists public.app_translation_drafts(
 language_code text not null references public.app_languages(code),
 key text not null references public.app_translation_keys(key),
 value text not null check(length(value)<=12000),
 updated_at timestamptz not null default now(),
 primary key(language_code,key)
);
create table if not exists public.app_language_releases(
 language_code text not null references public.app_languages(code),
 version integer not null,
 pack_json text not null,
 sha256 text not null,
 fallback_count integer not null default 0,
 created_at timestamptz not null default now(),
 created_by uuid references auth.users(id) on delete set null,
 primary key(language_code,version)
);
create index if not exists translation_keys_module_idx on public.app_translation_keys(module,key) where is_active;
alter table public.app_languages enable row level security;
alter table public.app_translation_keys enable row level security;
alter table public.app_translation_drafts enable row level security;
alter table public.app_language_releases enable row level security;
revoke all on public.app_languages,public.app_translation_keys,public.app_translation_drafts,public.app_language_releases from public,anon,authenticated;
insert into eventra_admin.modules(name,label,section,pk,can_create,editable) values
 ('app_languages','Languages & Translations','Localization','code',false,'{}'),
 ('app_language_releases','Language Publishing','Localization','language_code',false,'{}')
on conflict(name) do update set label=excluded.label,section=excluded.section,can_create=false,editable='{}';

create or replace function eventor_i18n.placeholders(value text) returns text[]
language sql immutable set search_path='' as $$
 select coalesce(array_agg(distinct match[1] order by match[1]),'{}'::text[])
 from regexp_matches(value,'\{([A-Za-z][A-Za-z0-9_]*)\}','g') match
$$;
create or replace function eventor_i18n.audit(p_code text,p_action text,p_details jsonb) returns void
language sql security definer set search_path='' as $$
 insert into public.admin_audit_log(actor_id,module,record_id,action,after_data)
 values(auth.uid(),'app_languages',p_code,p_action,p_details)
$$;
create or replace function eventor_i18n.signal_change() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 perform eventra_security.touch_app_revision('admin',tg_table_name);
 if tg_table_name='app_language_releases' or (tg_table_name='app_languages' and
 (tg_op='INSERT' or (to_jsonb(new)-'draft_revision'-'updated_at') is distinct from (to_jsonb(old)-'draft_revision'-'updated_at'))) then
  perform eventra_security.touch_app_revision('public','app_languages');
 end if;
 return coalesce(new,old);
end $$;
do $$ declare name text;begin
 foreach name in array array['app_languages','app_translation_keys','app_translation_drafts','app_language_releases'] loop
 execute format('drop trigger if exists eventor_language_change on public.%I',name);
 execute format('create trigger eventor_language_change after insert or update or delete on public.%I for each row execute function eventor_i18n.signal_change()',name);
 end loop;
end $$;

create or replace function public.app_language_manifest() returns jsonb
language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object('code',l.code,'name',l.name,'native_name',l.native_name,
 'direction',(r.pack_json::jsonb)->>'direction','version',l.published_version,'sha256',r.sha256) order by case when l.code='en' then 0 else 1 end,l.name),'[]'::jsonb)
 from public.app_languages l join public.app_language_releases r on r.language_code=l.code and r.version=l.published_version
 where l.is_enabled
$$;
create or replace function public.app_language_pack(p_code text,p_version integer default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;begin
 select jsonb_build_object('content',r.pack_json,'sha256',r.sha256) into result
 from public.app_languages l join public.app_language_releases r on r.language_code=l.code
 and r.version=coalesce(p_version,l.published_version) where l.code=p_code and l.is_enabled;
 if result is null then raise exception 'Language pack unavailable' using errcode='22023';end if;
 return result;
end $$;

create or replace function public.admin_language_workspace() returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 perform eventra_admin.require_module('app_languages',false);
 return jsonb_build_object('languages',coalesce((select jsonb_agg(to_jsonb(l)||jsonb_build_object(
 'total',(select count(*) from public.app_translation_keys where is_active),
 'translated',(select count(*) from public.app_translation_drafts d join public.app_translation_keys k using(key)
 where d.language_code=l.code and k.is_active and length(trim(d.value))>0),
 'published_fallbacks',(select fallback_count from public.app_language_releases where language_code=l.code and version=l.published_version)) order by l.name)
 from public.app_languages l),'[]'),
 'modules',(select coalesce(jsonb_agg(module order by module),'[]') from (select distinct module from public.app_translation_keys where is_active)x));
end $$;
create or replace function public.admin_language_create(p_code text,p_name text,p_native_name text,p_direction text default 'ltr') returns void
language plpgsql security definer set search_path='' as $$
begin
 perform eventra_admin.require_module('app_languages',true);
 if (select count(*) from public.app_languages)>=100 then raise exception 'Maximum 100 languages';end if;
 insert into public.app_languages(code,name,native_name,direction) values(trim(p_code),trim(p_name),trim(p_native_name),p_direction);
 perform eventor_i18n.audit(p_code,'language_create',jsonb_build_object('name',p_name));
end $$;
create or replace function public.admin_language_update(p_code text,p_name text,p_native_name text,p_direction text,p_enabled boolean,p_expected_revision bigint) returns void
language plpgsql security definer set search_path='' as $$
declare l public.app_languages;begin
 perform eventra_admin.require_module('app_languages',true);
 select * into l from public.app_languages where code=p_code for update;
 if not found or l.draft_revision is distinct from p_expected_revision then raise exception 'Language changed. Reload before saving.' using errcode='40001';end if;
 if p_enabled is distinct from l.is_enabled then perform eventra_admin.require_module('app_language_releases',true);end if;
 if p_enabled and l.published_version=0 then raise exception 'Publish a pack before enabling the language';end if;
 if p_code='en' and not p_enabled then raise exception 'English fallback must stay available';end if;
 update public.app_languages set name=trim(p_name),native_name=trim(p_native_name),direction=p_direction,is_enabled=p_enabled,draft_revision=draft_revision+1,updated_at=now() where code=p_code;
 perform eventor_i18n.audit(p_code,'language_update',jsonb_build_object('enabled',p_enabled));
end $$;
create or replace function public.admin_language_entries(p_code text,p_search text default '',p_module text default '',p_missing boolean default false,p_offset integer default 0,p_limit integer default 50) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;begin
 perform eventra_admin.require_module('app_languages',false);
 if p_offset<0 or p_limit not between 1 and 100 then raise exception 'Invalid page';end if;
 with rows as (
 select k.*,coalesce(d.value,'') as translation,eventor_i18n.placeholders(k.default_text) as placeholders,
 (length(trim(coalesce(d.value,'')))>0 and eventor_i18n.placeholders(k.default_text)<>eventor_i18n.placeholders(d.value)) as invalid
 from public.app_translation_keys k left join public.app_translation_drafts d on d.key=k.key and d.language_code=p_code
 where k.is_active and (p_module='' or k.module=p_module)
 and (p_search='' or k.key ilike '%'||p_search||'%' or k.default_text ilike '%'||p_search||'%' or d.value ilike '%'||p_search||'%')
 and (not p_missing or length(trim(coalesce(d.value,'')))=0)
 )select jsonb_build_object('total',(select count(*) from rows),'rows',coalesce((select jsonb_agg(to_jsonb(x)) from(select * from rows order by module,key offset p_offset limit p_limit)x),'[]'),
 'revision',(select draft_revision from public.app_languages where code=p_code)) into result;
 return result;
end $$;
create or replace function public.admin_language_save(p_code text,p_values jsonb,p_expected_revision bigint) returns bigint
language plpgsql security definer set search_path='' as $$
declare l public.app_languages;item record;revision bigint;begin
 perform eventra_admin.require_module('app_languages',true);
 select * into l from public.app_languages where code=p_code for update;
 if not found or l.draft_revision is distinct from p_expected_revision then raise exception 'Translations changed. Reload before saving.' using errcode='40001';end if;
 if jsonb_typeof(p_values)<>'object' or (select count(*) from jsonb_object_keys(p_values)) not between 1 and 5000 or octet_length(p_values::text)>2097152 then raise exception 'Import 1 to 5000 keys within 2MB';end if;
 for item in select * from jsonb_each(p_values) loop
  if jsonb_typeof(item.value)<>'string' or length(item.value#>>'{}')>12000 or not exists(select 1 from public.app_translation_keys where key=item.key and is_active) then raise exception 'Invalid translation key or value: %',item.key;end if;
  insert into public.app_translation_drafts(language_code,key,value)values(p_code,item.key,item.value#>>'{}')
  on conflict(language_code,key)do update set value=excluded.value,updated_at=now();
 end loop;
 update public.app_languages set draft_revision=draft_revision+1,updated_at=now() where code=p_code returning draft_revision into revision;
 perform eventor_i18n.audit(p_code,'translation_save',jsonb_build_object('keys',(select count(*) from jsonb_object_keys(p_values)),'revision',revision));
 return revision;
end $$;
create or replace function public.admin_language_validate(p_code text) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 perform eventra_admin.require_module('app_languages',false);
 return jsonb_build_object('revision',(select draft_revision from public.app_languages where code=p_code),
 'missing',coalesce((select jsonb_agg(k.key order by k.key) from public.app_translation_keys k left join public.app_translation_drafts d on d.key=k.key and d.language_code=p_code where k.is_active and length(trim(coalesce(d.value,'')))=0),'[]'),
 'invalid',coalesce((select jsonb_agg(k.key order by k.key) from public.app_translation_keys k join public.app_translation_drafts d using(key) where k.is_active and d.language_code=p_code and length(trim(d.value))>0 and eventor_i18n.placeholders(k.default_text)<>eventor_i18n.placeholders(d.value)),'[]'));
end $$;
create or replace function public.admin_language_publish(p_code text,p_expected_revision bigint,p_allow_english_fallback boolean default false) returns jsonb
language plpgsql security definer set search_path='' as $$
declare l public.app_languages;validation jsonb;messages jsonb;payload text;hash text;version integer;missing integer;begin
 perform eventra_admin.require_module('app_language_releases',true);
 -- Reading drafts also requires explicit translation-module access for staff.
 perform eventra_admin.require_module('app_languages',false);
 select * into l from public.app_languages where code=p_code for update;
 if not found or l.draft_revision is distinct from p_expected_revision then raise exception 'Draft changed. Validate the latest revision.' using errcode='40001';end if;
 validation:=public.admin_language_validate(p_code);
 missing:=jsonb_array_length(validation->'missing');
 if jsonb_array_length(validation->'invalid')>0 then raise exception 'Fix placeholder errors before publishing' using errcode='22023';end if;
 if missing>0 and not coalesce(p_allow_english_fallback,false) then raise exception '% translations are missing. Complete them or explicitly allow English fallback.',missing using errcode='22023';end if;
 select jsonb_object_agg(k.key,case when length(trim(coalesce(d.value,'')))=0 then k.default_text else d.value end) into messages
 from public.app_translation_keys k left join public.app_translation_drafts d on d.key=k.key and d.language_code=p_code where k.is_active;
 if messages is null then raise exception 'Register application text before publishing';end if;
 version:=l.published_version+1;
 payload:=jsonb_build_object('schema',1,'app','vendor','code',p_code,'version',version,'direction',l.direction,'messages',messages)::text;
 if octet_length(payload)>2097152 then raise exception 'Language pack exceeds 2MB';end if;
 hash:=encode(extensions.digest(convert_to(payload,'UTF8'),'sha256'),'hex');
 insert into public.app_language_releases(language_code,version,pack_json,sha256,fallback_count,created_by)values(p_code,version,payload,hash,missing,auth.uid());
 update public.app_languages set published_version=version,updated_at=now() where code=p_code;
 perform eventor_i18n.audit(p_code,'language_publish',jsonb_build_object('version',version,'sha256',hash,'fallbacks',missing));
 return jsonb_build_object('version',version,'sha256',hash,'fallbacks',missing);
end $$;
create or replace function public.admin_language_history(p_code text) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 perform eventra_admin.require_module('app_languages',false);
 return coalesce((select jsonb_agg(to_jsonb(x)) from(select version,sha256,fallback_count,created_at from public.app_language_releases where language_code=p_code order by version desc limit 30)x),'[]');
end $$;
create or replace function public.admin_language_restore_draft(p_code text,p_version integer,p_expected_revision bigint) returns void
language plpgsql security definer set search_path='' as $$
declare l public.app_languages;messages jsonb;begin
 perform eventra_admin.require_module('app_languages',true);
 select * into l from public.app_languages where code=p_code for update;
 if not found or l.draft_revision is distinct from p_expected_revision then raise exception 'Draft changed. Reload first.' using errcode='40001';end if;
 select (pack_json::jsonb)->'messages' into messages from public.app_language_releases where language_code=p_code and version=p_version;
 if messages is null then raise exception 'Release not found';end if;
 delete from public.app_translation_drafts where language_code=p_code;
 insert into public.app_translation_drafts(language_code,key,value)
 select p_code,e.key,e.value from jsonb_each_text(messages)e join public.app_translation_keys k on k.key=e.key where k.is_active;
 update public.app_languages set draft_revision=draft_revision+1,updated_at=now() where code=p_code;
 perform eventor_i18n.audit(p_code,'restore_language_draft',jsonb_build_object('source_version',p_version));
end $$;
create or replace function public.admin_language_export(p_code text) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 perform eventra_admin.require_module('app_languages',false);
 return jsonb_build_object('code',p_code,'messages',coalesce((select jsonb_object_agg(k.key,coalesce(d.value,'')) from public.app_translation_keys k left join public.app_translation_drafts d on d.key=k.key and d.language_code=p_code where k.is_active),'{}'),
 'source',coalesce((select jsonb_object_agg(key,default_text) from public.app_translation_keys where is_active),'{}'));
end $$;
revoke all on all functions in schema eventor_i18n from public,anon,authenticated;
do $$ declare f record;begin
 for f in select oid::regprocedure as signature,proname from pg_proc where pronamespace='public'::regnamespace and (proname like 'admin_language_%' or proname in ('app_language_manifest','app_language_pack')) loop
 execute format('revoke all on function %s from public,anon,authenticated',f.signature);
 execute format('grant execute on function %s to authenticated',f.signature);
 if f.proname in ('app_language_manifest','app_language_pack')then execute format('grant execute on function %s to anon',f.signature);end if;
 end loop;
end $$;
commit;
