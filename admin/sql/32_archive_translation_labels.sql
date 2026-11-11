-- Register new archive labels and extend published packs without publishing unrelated drafts.
begin;
create temporary table archive_words as select * from jsonb_to_recordset($words$[{"key": "listing.archive", "default_text": "Archive", "tamil": "காப்பகப்படுத்து", "module": "listings", "notes": "Service archive workflow"}, {"key": "listing.archived", "default_text": "Archived", "tamil": "காப்பகத்தில்", "module": "listings", "notes": "Service archive workflow"}, {"key": "listing.restore", "default_text": "Restore", "tamil": "மீட்டெடு", "module": "listings", "notes": "Service archive workflow"}, {"key": "listing.archived_message", "default_text": "Service archived.", "tamil": "சேவை காப்பகப்படுத்தப்பட்டது.", "module": "listings", "notes": "Service archive workflow"}, {"key": "listing.restored_message", "default_text": "Service restored as inactive. Activate it when ready.", "tamil": "சேவை செயலற்ற நிலையில் மீட்டெடுக்கப்பட்டது. தயாரானதும் செயல்படுத்தவும்.", "module": "listings", "notes": "Service archive workflow"}]$words$::jsonb) as x(key text,default_text text,tamil text,module text,notes text);
insert into public.app_translation_keys(key,default_text,module,notes) select key,default_text,module,notes from archive_words on conflict(key)do nothing;
insert into public.app_translation_drafts(language_code,key,value)
select 'en',key,default_text from archive_words union all select 'ta',key,tamil from archive_words on conflict(language_code,key)do nothing;
do $$declare l record; previous jsonb; extra jsonb; payload text; version integer; fallbacks integer;begin
for l in select * from public.app_languages where code in ('en','ta') and published_version>0 for update loop
 select pack_json::jsonb,fallback_count into previous,fallbacks from public.app_language_releases r where r.language_code=l.code and r.version=l.published_version;
 select jsonb_object_agg(key,case when l.code='ta' then tamil else default_text end) into extra from archive_words where not (previous->'messages')?key;
 if extra is null then continue;end if;
 version:=l.published_version+1;
 payload:=jsonb_set(jsonb_set(previous,'{messages}',(previous->'messages')||extra),'{version}',to_jsonb(version))::text;
 insert into public.app_language_releases(language_code,version,pack_json,sha256,fallback_count)values(l.code,version,payload,encode(extensions.digest(convert_to(payload,'UTF8'),'sha256'),'hex'),fallbacks);
 update public.app_languages set published_version=version,updated_at=now() where code=l.code;
end loop;
end $$;
drop table archive_words;
commit;
