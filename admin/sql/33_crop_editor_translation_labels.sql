-- Register crop editor labels and extend published packs without publishing unrelated drafts.
begin;
create temporary table cropper_words as select * from jsonb_to_recordset($words$[{"key": "cropper.grid", "default_text": "Crop grid", "tamil": "செதுக்கும் கட்டம்", "module": "photos", "notes": "Shared image editor controls"}, {"key": "cropper.hint", "default_text": "Drag to position. Pinch or use the slider to zoom.", "tamil": "இடத்தை மாற்ற இழுக்கவும். பெரிதாக்க விரல்களை விரிக்கவும் அல்லது ஸ்லைடரைப் பயன்படுத்தவும்.", "module": "photos", "notes": "Shared image editor controls"}, {"key": "cropper.original", "default_text": "Original", "tamil": "அசல்", "module": "photos", "notes": "Shared image editor controls"}, {"key": "cropper.rotate_left", "default_text": "Rotate left", "tamil": "இடப்புறம் சுழற்று", "module": "photos", "notes": "Shared image editor controls"}, {"key": "cropper.rotate_right", "default_text": "Rotate right", "tamil": "வலப்புறம் சுழற்று", "module": "photos", "notes": "Shared image editor controls"}, {"key": "cropper.zoom", "default_text": "Zoom", "tamil": "பெரிதாக்கு", "module": "photos", "notes": "Shared image editor controls"}, {"key": "cropper.use_photo", "default_text": "Use photo", "tamil": "படத்தைப் பயன்படுத்து", "module": "photos", "notes": "Shared image editor controls"}, {"key": "cropper.use_banner", "default_text": "Use banner", "tamil": "பேனரைப் பயன்படுத்து", "module": "photos", "notes": "Shared image editor controls"}, {"key": "cropper.saving", "default_text": "Preparing photo…", "tamil": "படம் தயாராகிறது…", "module": "photos", "notes": "Shared image editor controls"}]$words$::jsonb) as x(key text,default_text text,tamil text,module text,notes text);
insert into public.app_translation_keys(key,default_text,module,notes) select key,default_text,module,notes from cropper_words on conflict(key)do nothing;
insert into public.app_translation_drafts(language_code,key,value)
select 'en',key,default_text from cropper_words union all select 'ta',key,tamil from cropper_words on conflict(language_code,key)do nothing;
do $$declare l record; previous jsonb; extra jsonb; payload text; version integer; fallbacks integer;begin
for l in select * from public.app_languages where code in ('en','ta') and published_version>0 for update loop
 select pack_json::jsonb,fallback_count into previous,fallbacks from public.app_language_releases r where r.language_code=l.code and r.version=l.published_version;
 select jsonb_object_agg(key,case when l.code='ta' then tamil else default_text end) into extra from cropper_words where not (previous->'messages')?key;
 if extra is null then continue;end if;
 version:=l.published_version+1;
 payload:=jsonb_set(jsonb_set(previous,'{messages}',(previous->'messages')||extra),'{version}',to_jsonb(version))::text;
 insert into public.app_language_releases(language_code,version,pack_json,sha256,fallback_count)values(l.code,version,payload,encode(extensions.digest(convert_to(payload,'UTF8'),'sha256'),'hex'),fallbacks);
 update public.app_languages set published_version=version,updated_at=now() where code=l.code;
end loop;
end $$;
drop table cropper_words;
commit;
