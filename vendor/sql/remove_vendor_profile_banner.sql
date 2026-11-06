begin;
alter table public.vendors drop column if exists banner_url;
update eventra_admin.modules set editable=array_remove(editable,'banner_url') where name='vendors';
commit;
