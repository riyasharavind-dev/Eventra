begin;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('social-icons','social-icons',true,2097152,array['image/png','image/webp','image/jpeg'])
on conflict(id) do update set public=true,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists eventra_social_icons_read on storage.objects;
create policy eventra_social_icons_read on storage.objects for select to anon,authenticated using(bucket_id='social-icons');
drop policy if exists eventra_social_icons_upload on storage.objects;
create policy eventra_social_icons_upload on storage.objects for insert to authenticated with check(
 bucket_id='social-icons' and public.eventra_admin_can_write()
 and (storage.foldername(name))[1]='admins' and (storage.foldername(name))[2]=auth.uid()::text
);
-- Uploads always get a new versioned name; existing published icons are never overwritten.
create or replace function public.eventra_social_icon_can_delete(p_path text)
returns boolean language sql stable security definer set search_path='' as $$
 select public.eventra_admin_can_write() and not exists(
  select 1 from public.social_links where split_part(icon_url,'?',1) like '%/storage/v1/object/public/social-icons/'||p_path
 );
$$;
revoke all on function public.eventra_social_icon_can_delete(text) from public,anon;
grant execute on function public.eventra_social_icon_can_delete(text) to authenticated;
drop policy if exists eventra_social_icons_delete on storage.objects;
create policy eventra_social_icons_delete on storage.objects for delete to authenticated using(
 bucket_id='social-icons' and public.eventra_social_icon_can_delete(name)
);

-- Known fallback choices remain useful if an uploaded icon cannot load.
update eventra_admin.modules set choices=choices||jsonb_build_object('icon',
 (select jsonb_agg(icon order by icon) from (
 select unnest(array['link','instagram','whatsapp','facebook','youtube','telegram','website','email','linkedin','x','threads','tiktok','discord']) icon
 union select distinct icon from public.social_links
 ) q)) where name='social_links';
comment on column public.social_links.icon_url is 'Admin-uploaded social icon public URL (social-icons bucket), or an HTTPS image URL. PNG/WebP preserve transparency.';
commit;
