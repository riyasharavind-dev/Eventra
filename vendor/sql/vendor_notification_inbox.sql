begin;
create table if not exists public.vendor_announcements (
 id uuid primary key default gen_random_uuid(),
 recipient_id uuid references public.vendors(id) on delete cascade,
 kind text not null default 'offer' check (kind in ('offer','account','payment')),
 title text not null check (length(trim(title)) between 1 and 160),
 body text not null check (length(trim(body)) between 1 and 3000),
 reference text,
 is_active boolean not null default false,
 starts_at timestamptz not null default now(),
 expires_at timestamptz,
 created_at timestamptz not null default now(),
 check (expires_at is null or expires_at>starts_at),
 check (kind<>'payment' or recipient_id is not null)
);
create table if not exists public.vendor_notifications (
 id uuid primary key default gen_random_uuid(),
 recipient_id uuid not null references public.vendors(id) on delete cascade,
 kind text not null check (kind in ('booking','payment','review','offer','account','support')),
 title text not null,
 body text not null,
 target_type text not null default 'message',
 target_id uuid,
 data jsonb not null default '{}'::jsonb,
 event_key text not null,
 announcement_id uuid references public.vendor_announcements(id) on delete cascade,
 created_at timestamptz not null default now(),
 read_at timestamptz,
 unique(recipient_id,event_key)
);
create index if not exists vendor_notifications_feed_idx on public.vendor_notifications(recipient_id,created_at desc,id desc);
create index if not exists vendor_notifications_unread_idx on public.vendor_notifications(recipient_id) where read_at is null;
alter table public.vendor_notifications enable row level security;
alter table public.vendor_announcements enable row level security;
revoke all on public.vendor_notifications,public.vendor_announcements from anon,authenticated;
grant select on public.vendor_notifications to authenticated;
grant select on public.vendor_announcements to authenticated;
drop policy if exists vendor_announcement_visibility on public.vendor_announcements;
create policy vendor_announcement_visibility on public.vendor_announcements for select to authenticated using (
 exists(select 1 from public.users where id=auth.uid() and role='vendor') and
 is_active and starts_at<=now() and (expires_at is null or expires_at>now()) and (recipient_id is null or recipient_id=auth.uid())
);
drop policy if exists vendor_notification_owner on public.vendor_notifications;
create policy vendor_notification_owner on public.vendor_notifications for select to authenticated using (
 recipient_id=auth.uid() and exists(select 1 from public.users where id=auth.uid() and role='vendor') and
 (announcement_id is null or exists(select 1 from public.vendor_announcements a where a.id=announcement_id))
);

create or replace function public.emit_vendor_notification(p_recipient uuid,p_kind text,p_title text,p_body text,p_target text,p_target_id uuid,p_key text,p_created timestamptz default now(),p_data jsonb default '{}') returns void
language sql security definer set search_path='' as $$
 insert into public.vendor_notifications(recipient_id,kind,title,body,target_type,target_id,event_key,created_at,data)
 select p_recipient,p_kind,p_title,p_body,p_target,p_target_id,p_key,p_created,p_data
 where exists(select 1 from public.users where id=p_recipient and role='vendor')
 on conflict(recipient_id,event_key) do nothing;
$$;
revoke all on function public.emit_vendor_notification(uuid,text,text,text,text,uuid,text,timestamptz,jsonb) from public,anon,authenticated;

create or replace function public.sync_vendor_announcements() returns void
language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.users where id=auth.uid() and role='vendor') then raise exception 'Vendor account required' using errcode='42501'; end if;
 insert into public.vendor_notifications(recipient_id,kind,title,body,event_key,announcement_id,created_at,data)
 select auth.uid(),a.kind,a.title,a.body,'announcement:'||a.id,a.id,greatest(a.created_at,a.starts_at),jsonb_build_object('reference',a.reference)
 from public.vendor_announcements a
 where a.is_active and a.starts_at<=now() and (a.expires_at is null or a.expires_at>now())
 and (a.recipient_id is null or a.recipient_id=auth.uid())
 on conflict(recipient_id,event_key) do nothing;
end $$;
create or replace function public.vendor_notification_unread_count() returns bigint
language sql stable security invoker set search_path='' as $$
 select count(*) from public.vendor_notifications where read_at is null;
$$;
create or replace function public.mark_vendor_notifications_read(p_ids uuid[] default null,p_before timestamptz default now()) returns void
language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.users where id=auth.uid() and role='vendor') then raise exception 'Vendor account required' using errcode='42501'; end if;
 update public.vendor_notifications set read_at=now()
 where recipient_id=auth.uid() and read_at is null and created_at<=p_before and (p_ids is null or id=any(p_ids));
end $$;
revoke all on function public.sync_vendor_announcements(),public.vendor_notification_unread_count(),public.mark_vendor_notifications_read(uuid[],timestamptz) from public,anon;
grant execute on function public.sync_vendor_announcements(),public.vendor_notification_unread_count(),public.mark_vendor_notifications_read(uuid[],timestamptz) to authenticated;

create or replace function public.eventra_vendor_inbox_event() returns trigger
language plpgsql security definer set search_path='' as $$
declare recipient uuid; service_name text; actor_name text; label text;
begin
 if tg_table_name='bookings' then
  select name into service_name from public.services where id=new.service_id;
  select name into actor_name from public.customers where id=new.customer_id;
  if tg_op='INSERT' then
   perform public.emit_vendor_notification(new.vendor_id,'booking','New booking request',coalesce(actor_name,'A customer')||' requested '||coalesce(service_name,'your service')||'.','booking',new.id,'booking:'||new.id,new.created_at);
  elsif new.status is distinct from old.status then
   perform public.emit_vendor_notification(new.vendor_id,'booking','Booking '||new.status,coalesce(service_name,'Your booking')||' is now '||new.status||'.','booking',new.id,'booking-status:'||new.id||':'||gen_random_uuid());
  end if;
 elsif tg_table_name='service_reviews' then
  if new.moderation_status='visible' and (tg_op='INSERT' or old.moderation_status is distinct from new.moderation_status or old.rating is distinct from new.rating or old.review_text is distinct from new.review_text) then
   select name into service_name from public.services where id=new.service_id;
   perform public.emit_vendor_notification(new.vendor_id,'review','Customer review',coalesce(service_name,'Your service')||' received a '||new.rating||'-star review.','review',new.service_id,'review:'||new.id||':'||new.version,now(),jsonb_build_object('review_id',new.id));
  end if;
 elsif tg_table_name='support_messages' then
  if new.sender_role='support' then
  select user_id into recipient from public.support_tickets where id=new.ticket_id;
  perform public.emit_vendor_notification(recipient,'support','Support replied','You have a new reply to your support request.','support',new.ticket_id,'support:'||new.id,new.created_at);
  end if;
 elsif tg_table_name='vendor_verifications' then
  if tg_op='INSERT' or new.status is distinct from old.status then
   perform public.emit_vendor_notification(new.vendor_id,'account','Verification update','Your account verification is '||replace(new.status,'_',' ')||'.','verification',new.vendor_id,'verification:'||new.id||':'||gen_random_uuid());
  end if;
 elsif tg_table_name='business_verifications' then
  if tg_op='INSERT' or new.status is distinct from old.status then
   select vendor_id,name into recipient,label from public.businesses where id=new.business_id;
   perform public.emit_vendor_notification(recipient,'account','Business verification update',coalesce(label,'Your business')||' verification is '||replace(new.status,'_',' ')||'.','business',new.business_id,'business-verification:'||new.business_id||':'||gen_random_uuid());
  end if;
 end if;
 return new;
end $$;
revoke all on function public.eventra_vendor_inbox_event() from public,anon,authenticated;
drop trigger if exists eventra_vendor_inbox_booking on public.bookings;
create trigger eventra_vendor_inbox_booking after insert or update of status on public.bookings for each row execute function public.eventra_vendor_inbox_event();
drop trigger if exists eventra_vendor_inbox_review on public.service_reviews;
create trigger eventra_vendor_inbox_review after insert or update on public.service_reviews for each row execute function public.eventra_vendor_inbox_event();
drop trigger if exists eventra_vendor_inbox_support on public.support_messages;
create trigger eventra_vendor_inbox_support after insert on public.support_messages for each row execute function public.eventra_vendor_inbox_event();
drop trigger if exists eventra_vendor_inbox_verification on public.vendor_verifications;
create trigger eventra_vendor_inbox_verification after insert or update of status on public.vendor_verifications for each row execute function public.eventra_vendor_inbox_event();
drop trigger if exists eventra_vendor_inbox_business_verification on public.business_verifications;
create trigger eventra_vendor_inbox_business_verification after insert or update of status on public.business_verifications for each row execute function public.eventra_vendor_inbox_event();

create or replace function public.publish_vendor_announcement() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 -- Only eligible recipients receive a row. Future announcements are synced on
 -- opening/resuming the inbox; no background scheduler is needed.
 if new.is_active and new.starts_at<=now() and (new.expires_at is null or new.expires_at>now()) then
  insert into public.vendor_notifications(recipient_id,kind,title,body,event_key,announcement_id,created_at,data)
  select v.id,new.kind,new.title,new.body,'announcement:'||new.id,new.id,greatest(new.created_at,new.starts_at),jsonb_build_object('reference',new.reference)
  from public.vendors v where new.recipient_id is null or new.recipient_id=v.id
  on conflict(recipient_id,event_key) do update set kind=excluded.kind,title=excluded.title,body=excluded.body,data=excluded.data;
 end if;
 return new;
end $$;
revoke all on function public.publish_vendor_announcement() from public,anon,authenticated;
drop trigger if exists eventra_vendor_announcement on public.vendor_announcements;
create trigger eventra_vendor_announcement after insert or update on public.vendor_announcements for each row execute function public.publish_vendor_announcement();

-- Existing recent activity appears as history without creating unread alerts.
insert into public.vendor_notifications(recipient_id,kind,title,body,target_type,target_id,event_key,created_at,read_at)
 select b.vendor_id,'booking','Booking request',coalesce(s.name,'Your service')||' booking request.','booking',b.id,'booking:'||b.id,b.created_at,now()
 from public.bookings b left join public.services s on s.id=b.service_id where b.created_at>now()-interval '90 days'
 on conflict(recipient_id,event_key) do nothing;
insert into public.vendor_notifications(recipient_id,kind,title,body,target_type,target_id,event_key,created_at,read_at,data)
 select r.vendor_id,'review','Customer review',coalesce(s.name,'Your service')||' received a '||r.rating||'-star review.','review',r.service_id,'review:'||r.id||':'||r.version,r.created_at,now(),jsonb_build_object('review_id',r.id)
 from public.service_reviews r left join public.services s on s.id=r.service_id where r.moderation_status='visible' and r.created_at>now()-interval '90 days'
 on conflict(recipient_id,event_key) do nothing;

insert into eventra_admin.modules(name,label,section,pk,can_create,editable,choices,actions,sort_column) values
 ('vendor_announcements','Vendor Offers & Announcements','Content','id',true,array['recipient_id','kind','title','body','reference','is_active','starts_at','expires_at'],'{"kind":["offer","account","payment"]}','{}','created_at'),
 ('vendor_notifications','Vendor Notification History','Operations','id',false,'{}','{"kind":["booking","payment","review","offer","account","support"]}','{}','created_at')
 on conflict(name) do update set label=excluded.label,section=excluded.section,editable=excluded.editable,choices=excluded.choices;
do $$ begin
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='vendor_notifications') then
  alter publication supabase_realtime add table public.vendor_notifications;
 end if;
end $$;
commit;
