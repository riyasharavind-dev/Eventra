begin;
alter table public.vendor_announcements add column if not exists image_url text;
alter table public.vendor_notifications add column if not exists image_url text;
alter table public.vendor_announcements drop constraint if exists vendor_announcements_image_url_check;
alter table public.vendor_announcements add constraint vendor_announcements_image_url_check check(image_url is null or image_url ~ '^https?://[^[:space:]]+$');
create or replace function public.eventor_notification_image() returns trigger language plpgsql security definer set search_path='' as $$
declare img text;begin
 if new.announcement_id is not null then
  select a.image_url into img from public.vendor_announcements a where a.id=new.announcement_id and (a.recipient_id is null or a.recipient_id=new.recipient_id);
 else
  img:=coalesce(nullif(new.image_url,''),nullif(new.data->>'image_url',''));
  if img is null and new.target_type='booking' then
   select coalesce(case jsonb_typeof(s.gallery->0) when 'string' then s.gallery->>0 when 'object' then s.gallery->0->>'url' end,b.logo_url)
   into img from public.bookings k join public.services s on s.id=k.service_id left join public.businesses b on b.id=s.business_id where k.id=new.target_id and k.vendor_id=new.recipient_id;
  elsif img is null and new.target_type='review' then
   select coalesce(case jsonb_typeof(s.gallery->0) when 'string' then s.gallery->>0 when 'object' then s.gallery->0->>'url' end,b.logo_url)
   into img from public.services s left join public.businesses b on b.id=s.business_id where s.id=new.target_id and s.vendor_id=new.recipient_id;
  elsif img is null and new.target_type='business' then
   select logo_url into img from public.businesses where id=new.target_id and vendor_id=new.recipient_id;
  elsif img is null and new.target_type='verification' then
   select profile_image_url into img from public.vendors where id=new.recipient_id;
  end if;
 end if;
 if img is not null and img !~ '^https?://[^[:space:]]+$' then img:=null;end if;
 new.image_url:=img;
 new.data:=coalesce(new.data,'{}')-'image_url';
 if img is not null then new.data:=new.data||jsonb_build_object('image_url',img);end if;
 return new;
end $$;
revoke all on function public.eventor_notification_image() from public,anon,authenticated;
drop trigger if exists eventor_notification_image on public.vendor_notifications;
create trigger eventor_notification_image before insert or update of image_url,data,target_type,target_id,announcement_id on public.vendor_notifications for each row execute function public.eventor_notification_image();
create or replace function public.sync_vendor_announcements() returns void language plpgsql security definer set search_path='' as $$
begin
 perform eventra_security.require_actor('vendor');
 insert into public.vendor_notifications(recipient_id,kind,title,body,event_key,announcement_id,created_at,data,image_url)
 select auth.uid(),a.kind,a.title,a.body,'announcement:'||a.id,a.id,greatest(a.created_at,a.starts_at),jsonb_build_object('reference',a.reference),a.image_url
 from public.vendor_announcements a where a.is_active and a.starts_at<=now() and (a.expires_at is null or a.expires_at>now()) and (a.recipient_id is null or a.recipient_id=auth.uid())
 on conflict(recipient_id,event_key) do update set image_url=excluded.image_url
 where vendor_notifications.image_url is distinct from excluded.image_url;
end $$;
-- Populate existing alert thumbnails without modifying read state or timestamps.
update public.vendor_notifications set image_url=image_url where image_url is null and (target_type in ('booking','review','business','verification') or announcement_id is not null or data ? 'image_url');
update eventra_admin.modules set editable=array(select distinct x from unnest(editable||array['image_url'])x) where name='vendor_announcements';
notify pgrst,'reload schema';
commit;
