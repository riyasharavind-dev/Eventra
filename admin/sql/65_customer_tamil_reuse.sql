begin;
insert into public.app_translation_drafts(language_code,key,value)
select distinct on(c.key) 'ta',c.key,d.value from public.app_translation_keys c join public.app_translation_keys v on v.default_text=c.default_text and v.key like 'vendor.%' join public.app_translation_drafts d on d.key=v.key and d.language_code='ta'
where c.key like 'customer.%' and length(trim(d.value))>0 and eventor_i18n.placeholders(c.default_text)=eventor_i18n.placeholders(d.value) order by c.key,v.key
on conflict(language_code,key) do nothing;
update public.app_languages set draft_revision=draft_revision+1 where code='ta';
commit;
