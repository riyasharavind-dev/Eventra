"""Rebuild the English fallback and idempotent SQL seed from the tracked catalog.
Run: python admin/tools/build_translation_catalog.py
New languages and edits are managed in the admin workspace, not this file.
"""
from pathlib import Path
import json,re
root=Path(__file__).resolve().parents[2]
rows=json.loads((root/'admin/data/vendor_translation_catalog.json').read_text(encoding='utf-8'))
keys={r['key'] for r in rows}
assert len(keys)==len(rows), 'Duplicate catalog keys'
for row in rows:
 assert row['default_text'].strip() and row['tamil'].strip(), row['key']
 assert set(re.findall(r'\{([A-Za-z][A-Za-z0-9_]*)\}',row['default_text']))==set(re.findall(r'\{([A-Za-z][A-Za-z0-9_]*)\}',row['tamil'])), row['key']
def quote(s):return json.dumps(s,ensure_ascii=False).replace('$',r'\$')
output='// Generated English fallback only. All other languages come from published packs.\nconst vendorEnglishStrings = <String, String>{\n'+''.join('  '+quote(r['key'])+': '+quote(r['default_text'])+',\n' for r in sorted(rows,key=lambda r:r['key']))+'};\n'
(root/'vendor/lib/l10n/vendor_strings.dart').write_text(output,encoding='utf-8')
data=root/'admin/data/vendor_translation_catalog.json';data.parent.mkdir(exist_ok=True)
data.write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf-8')
seed=json.dumps(rows,ensure_ascii=False);assert '$eventor_catalog_seed$' not in seed
sql=r'''-- Initial vendor UI catalog. Tamil lives here / in DB, never in the app bundle.
begin;
insert into public.app_languages(code,name,native_name,direction)values('en','English','English','ltr'),('ta','Tamil','தமிழ்','ltr') on conflict(code)do nothing;
with seed as(select * from jsonb_to_recordset($eventor_catalog_seed$SEED$eventor_catalog_seed$::jsonb) as x(key text,default_text text,tamil text,module text,notes text))
insert into public.app_translation_keys(key,default_text,module,notes)
select key,default_text,module,notes from seed on conflict(key)do update set default_text=excluded.default_text,module=excluded.module,notes=excluded.notes
where (app_translation_keys.default_text,app_translation_keys.module,app_translation_keys.notes) is distinct from (excluded.default_text,excluded.module,excluded.notes);
with seed as(select * from jsonb_to_recordset($eventor_catalog_seed$SEED$eventor_catalog_seed$::jsonb) as x(key text,default_text text,tamil text,module text,notes text))
insert into public.app_translation_drafts(language_code,key,value)
select 'ta',key,tamil from seed where length(trim(tamil))>0
union all select 'en',key,default_text from seed
on conflict(language_code,key)do nothing;
do $$ declare l record;messages jsonb;payload text;missing integer;begin
 for l in select * from public.app_languages where code in ('en','ta') and published_version=0 for update loop
 select count(*) filter(where length(trim(coalesce(d.value,'')))=0),
 jsonb_object_agg(k.key,case when length(trim(coalesce(d.value,'')))=0 then k.default_text else d.value end)
 into missing,messages from public.app_translation_keys k left join public.app_translation_drafts d on d.key=k.key and d.language_code=l.code where k.is_active;
 if exists(select 1 from public.app_translation_keys k join public.app_translation_drafts d using(key) where d.language_code=l.code and k.is_active and eventor_i18n.placeholders(k.default_text)<>eventor_i18n.placeholders(d.value))then raise exception 'Invalid seeded placeholders';end if;
 payload:=jsonb_build_object('schema',1,'app','vendor','code',l.code,'version',1,'direction',l.direction,'messages',messages)::text;
 if octet_length(payload)>2097152 then raise exception 'Seed language pack too large';end if;
 insert into public.app_language_releases(language_code,version,pack_json,sha256,fallback_count)values(l.code,1,payload,encode(extensions.digest(convert_to(payload,'UTF8'),'sha256'),'hex'),missing);
 update public.app_languages set published_version=1,is_enabled=true where code=l.code;
 end loop;
end $$;
commit;
'''.replace('SEED',seed)
(root/'admin/sql/30_vendor_translation_catalog.sql').write_text(sql,encoding='utf-8')

print('Catalog keys:',len(rows),'Tamil translations:',sum(bool(r['tamil']) for r in rows),'English fallback:',sum(not r['tamil'] for r in rows))
