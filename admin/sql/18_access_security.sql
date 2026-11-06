-- Eventra production access baseline. Run after existing application migrations.
-- No application records are deleted. Server-owned RPCs retain their explicit checks.
begin;
set local lock_timeout='10s';
create schema if not exists eventra_security;
revoke all on schema eventra_security from public,anon,authenticated;
grant usage on schema eventra_security to anon,authenticated;
revoke create on schema public from public,anon,authenticated;

create or replace function eventra_security.actor_role() returns text
language sql stable security definer set search_path='' as $$
 select u.role::text from public.users u join auth.users a on a.id=u.id
 where u.id=auth.uid() and a.deleted_at is null and (a.banned_until is null or a.banned_until<=now())
$$;
create or replace function eventra_security.require_actor(expected text default null) returns void
language plpgsql stable security definer set search_path='' as $$
declare actual text:=eventra_security.actor_role();
begin
 if actual is null or actual not in ('vendor','customer') or (expected is not null and actual<>expected) then
  raise exception 'Account permission required' using errcode='42501';
 end if;
end $$;
create or replace function eventra_security.owns_business(bid uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select eventra_security.actor_role()='vendor' and exists(select 1 from public.businesses where id=bid and vendor_id=auth.uid())
$$;
create or replace function eventra_security.public_service(sid uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.services s join auth.users a on a.id=s.vendor_id
 left join public.businesses b on b.id=s.business_id
 where s.id=sid and s.is_active and s.vendor_enabled and a.deleted_at is null
 and (a.banned_until is null or a.banned_until<=now())
 and (s.business_id is null or (b.vendor_id=s.vendor_id and b.is_active and b.availability_status='active')))
$$;
create or replace function eventra_security.booked_service(sid uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select eventra_security.actor_role()='customer' and exists(select 1 from public.bookings where service_id=sid and customer_id=auth.uid())
$$;
create or replace function eventra_security.booked_vendor(vid uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select eventra_security.actor_role()='customer' and exists(select 1 from public.bookings where vendor_id=vid and customer_id=auth.uid())
$$;
create or replace function eventra_security.service_has_bookings(sid uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.bookings where service_id=sid)
$$;

create or replace function eventra_security.live_account(uid uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from auth.users where id=uid and deleted_at is null and (banned_until is null or banned_until<=now()))
$$;

-- Replace permissive policies rather than OR-ing stricter rules with old ones.
do $$ declare r record;begin
 for r in select policyname,tablename from pg_policies where schemaname='public' loop
  execute format('drop policy %I on public.%I',r.policyname,r.tablename);
 end loop;
 for r in select c.relname from pg_class c join pg_namespace n on n.oid=c.relnamespace
 where n.nspname='public' and c.relkind in ('r','p') loop
  execute format('alter table public.%I enable row level security',r.relname);
 end loop;
end $$;
revoke all privileges on all tables in schema public from public,anon,authenticated;
revoke all privileges on all sequences in schema public from public,anon,authenticated;
-- Table-level REVOKE does not remove pre-existing per-column grants.
do $$ declare r record;begin
 for r in select c.relname,a.attname from pg_attribute a join pg_class c on c.oid=a.attrelid
 join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind in ('r','p','v')
 and a.attnum>0 and not a.attisdropped and a.attacl is not null loop
 execute format('revoke select(%I),insert(%I),update(%I),references(%I) on public.%I from public,anon,authenticated',r.attname,r.attname,r.attname,r.attname,r.relname);
 end loop;
end $$;
alter default privileges for role postgres in schema public revoke all on tables from public,anon,authenticated;
alter default privileges for role postgres in schema public revoke all on sequences from public,anon,authenticated;
alter default privileges for role postgres in schema public revoke execute on functions from public,anon,authenticated;

-- Private account data; account type, identity, email and approval fields are server-owned.
grant select on public.users,public.vendors,public.customers to authenticated;
grant update(name) on public.users to authenticated;
grant update(name,phone,profile_image_url,about_me,preferred_contact_language,updated_at) on public.vendors to authenticated;
grant update(name,phone,avatar_url,address,latitude,longitude,updated_at) on public.customers to authenticated;
create policy account_read on public.users for select to authenticated using(id=(select auth.uid()));
create policy account_edit on public.users for update to authenticated using(id=(select auth.uid()) and (select eventra_security.actor_role()) is not null) with check(id=(select auth.uid()));
create policy vendor_read on public.vendors for select to authenticated using((id=(select auth.uid()) and (select eventra_security.actor_role())='vendor') or eventra_security.booked_vendor(id));
create policy vendor_edit on public.vendors for update to authenticated using(id=(select auth.uid()) and (select eventra_security.actor_role())='vendor') with check(id=(select auth.uid()));
create policy customer_read on public.customers for select to authenticated using(id=(select auth.uid()) and (select eventra_security.actor_role())='customer');
create policy customer_edit on public.customers for update to authenticated using(id=(select auth.uid()) and (select eventra_security.actor_role())='customer') with check(id=(select auth.uid()));

-- Public marketplace data is read-only; vendor edits require the same owner.
grant select on public.category_nodes,public.event_types,public.administrative_regions,public.services,public.businesses,public.business_category_nodes to anon,authenticated;
create policy categories_read on public.category_nodes for select to anon,authenticated using(true);
create policy events_read on public.event_types for select to anon,authenticated using(is_active);
create policy regions_read on public.administrative_regions for select to anon,authenticated using(is_active);
create policy business_read on public.businesses for select to anon,authenticated using(
 (is_active and availability_status='active' and eventra_security.live_account(vendor_id))
 or eventra_security.owns_business(id));
grant insert(id,vendor_id,name,description,logo_url,banner_url,phone,email,address,latitude,longitude,is_active,whatsapp,travels_to_customer,started_year,website_url,instagram_url,primary_category_id,portfolio,availability_status,shop_address,shop_state_id,shop_district_id,shop_subdistrict_id) on public.businesses to authenticated;
grant update(name,description,logo_url,banner_url,phone,email,address,latitude,longitude,is_active,updated_at,whatsapp,travels_to_customer,started_year,website_url,instagram_url,primary_category_id,portfolio,availability_status,shop_address,shop_state_id,shop_district_id,shop_subdistrict_id) on public.businesses to authenticated;
create policy business_insert on public.businesses for insert to authenticated with check(vendor_id=(select auth.uid()) and (select eventra_security.actor_role())='vendor');
create policy business_edit on public.businesses for update to authenticated using(eventra_security.owns_business(id)) with check(vendor_id=(select auth.uid()));
create policy service_read on public.services for select to anon,authenticated using(eventra_security.public_service(id) or (vendor_id=(select auth.uid()) and (select eventra_security.actor_role())='vendor') or eventra_security.booked_service(id));
grant insert(id,vendor_id,category_node_id,name,slug,description,price,gallery,is_active,event_type_id,business_id,vendor_enabled,pricing_type,pricing_unit) on public.services to authenticated;
grant update(category_node_id,name,slug,description,price,gallery,is_active,updated_at,event_type_id,business_id,vendor_enabled,pricing_type,pricing_unit) on public.services to authenticated;
grant delete on public.services to authenticated;
create policy service_insert on public.services for insert to authenticated with check(vendor_id=(select auth.uid()) and (select eventra_security.actor_role())='vendor' and (business_id is null or eventra_security.owns_business(business_id)));
create policy service_edit on public.services for update to authenticated using(vendor_id=(select auth.uid()) and (select eventra_security.actor_role())='vendor') with check(vendor_id=(select auth.uid()) and (business_id is null or eventra_security.owns_business(business_id)));
create policy service_delete on public.services for delete to authenticated using(vendor_id=(select auth.uid()) and (select eventra_security.actor_role())='vendor' and not eventra_security.service_has_bookings(id));
grant insert(business_id,category_node_id),delete on public.business_category_nodes to authenticated;
create policy business_category_read on public.business_category_nodes for select to anon,authenticated using(exists(select 1 from public.businesses b where b.id=business_id));
create policy business_category_insert on public.business_category_nodes for insert to authenticated with check(eventra_security.owns_business(business_id));
create policy business_category_delete on public.business_category_nodes for delete to authenticated using(eventra_security.owns_business(business_id));

-- Bookings: participant reads, customer creates; all status/note/history writes use guarded RPCs.
grant select on public.bookings to authenticated;
grant insert(id,customer_id,vendor_id,service_id,event_type_id,event_date,guest_count,location,requirement,price,status,latitude,longitude,event_start_time,event_end_time,event_end_date,event_timezone) on public.bookings to authenticated;
create policy booking_read on public.bookings for select to authenticated using(
 (customer_id=(select auth.uid()) and (select eventra_security.actor_role())='customer') or
 (vendor_id=(select auth.uid()) and (select eventra_security.actor_role())='vendor'));
create policy booking_create on public.bookings for insert to authenticated with check(customer_id=(select auth.uid()) and (select eventra_security.actor_role())='customer' and status='pending');
create or replace function eventra_security.booking_insert_guard() returns trigger
language plpgsql security definer set search_path='' as $$
declare s public.services;
begin
 if current_setting('role',true) in ('anon','authenticated') then
  perform eventra_security.require_actor('customer');
  if new.customer_id is distinct from auth.uid() or new.status is distinct from 'pending' then raise exception 'Invalid booking owner or status' using errcode='42501';end if;
  select * into s from public.services where id=new.service_id for share;
  if not found or not eventra_security.public_service(s.id) or s.vendor_id is distinct from new.vendor_id or new.customer_id=new.vendor_id then raise exception 'Service is not available for booking' using errcode='42501';end if;
  -- Current checkout books one base unit. Future quantity/quotes must use a server-calculated RPC.
  if new.price is null or new.price is distinct from s.price or new.price::text in ('NaN','Infinity','-Infinity') then raise exception 'Service price changed. Refresh before booking.' using errcode='22023';end if;
  if new.event_type_id is not null and new.event_type_id is distinct from s.event_type_id then raise exception 'Invalid event type' using errcode='22023';end if;
  new.event_type_id:=s.event_type_id;
 end if;
 return new;
end $$;
drop trigger if exists eventra_secure_booking_insert on public.bookings;
create trigger eventra_secure_booking_insert before insert on public.bookings for each row execute function eventra_security.booking_insert_guard();

-- Serialize service removal with booking creation and retain booked-service history.
create or replace function public.delete_vendor_service(p_service_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare s public.services;
begin
 perform eventra_security.require_actor('vendor');
 select * into s from public.services where id=p_service_id and vendor_id=auth.uid() for update;
 if not found then raise exception 'Service not found' using errcode='42501';end if;
 if exists(select 1 from public.bookings where service_id=s.id) then raise exception 'This service has bookings. Deactivate it to retain booking history.';end if;
 delete from public.services where id=s.id;
 return jsonb_build_object('gallery',s.gallery);
end $$;
revoke delete on public.services from authenticated;

-- Device tokens are private and cannot be registered on another account.
grant select,delete on public.fcm_tokens to authenticated;
grant insert(user_id,token,platform,updated_at),update(user_id,token,platform,updated_at) on public.fcm_tokens to authenticated;
create policy token_read on public.fcm_tokens for select to authenticated using(user_id=(select auth.uid()) and (select eventra_security.actor_role()) is not null);
create policy token_create on public.fcm_tokens for insert to authenticated with check(user_id=(select auth.uid()) and (select eventra_security.actor_role()) is not null);
create policy token_edit on public.fcm_tokens for update to authenticated using(user_id=(select auth.uid()) and (select eventra_security.actor_role()) is not null) with check(user_id=(select auth.uid()));
create policy token_delete on public.fcm_tokens for delete to authenticated using(user_id=(select auth.uid()) and (select eventra_security.actor_role()) is not null);

-- Read-only published content. Invoker views obey base-table policies.
grant select on public.banners,public.legal_documents,public.about_eventra_content,public.support_faqs,public.support_settings,public.social_links to anon,authenticated;
create policy banners_read on public.banners for select to anon,authenticated using(is_active and (start_at is null or start_at<=now()) and (end_at is null or end_at>now()));
create policy legal_read on public.legal_documents for select to anon,authenticated using(status='published' and effective_at<=now());
create policy about_read on public.about_eventra_content for select to anon,authenticated using(is_published);
create policy faq_read on public.support_faqs for select to anon,authenticated using(is_published);
create policy support_contact_read on public.support_settings for select to anon,authenticated using(true);
create policy social_read on public.social_links for select to anon,authenticated using(is_active);
alter view public.current_legal_documents set(security_invoker=true);
alter view public.published_about_eventra_content set(security_invoker=true);
alter view public.published_support_faqs set(security_invoker=true);
alter view public.active_social_links set(security_invoker=true);
grant select on public.current_legal_documents,public.published_about_eventra_content,public.published_support_faqs,public.active_social_links to anon,authenticated;

grant select on public.vendor_verifications,public.business_verifications,public.verification_documents,public.vendor_identity_verifications,public.vendor_notifications,public.vendor_announcements to authenticated;
create policy vendor_verification_read on public.vendor_verifications for select to authenticated using(vendor_id=(select auth.uid()) and (select eventra_security.actor_role())='vendor');
create policy business_verification_read on public.business_verifications for select to authenticated using(eventra_security.owns_business(business_id));
create policy document_read on public.verification_documents for select to authenticated using(vendor_id=(select auth.uid()) and (select eventra_security.actor_role())='vendor');
create policy identity_read on public.vendor_identity_verifications for select to authenticated using(vendor_id=(select auth.uid()) and (select eventra_security.actor_role())='vendor');
create policy announcement_read on public.vendor_announcements for select to authenticated using((select eventra_security.actor_role())='vendor' and is_active and starts_at<=now() and (expires_at is null or expires_at>now()) and (recipient_id is null or recipient_id=(select auth.uid())));
create policy notification_read on public.vendor_notifications for select to authenticated using(recipient_id=(select auth.uid()) and (select eventra_security.actor_role())='vendor' and (announcement_id is null or exists(select 1 from public.vendor_announcements a where a.id=announcement_id)));

-- All other tables remain RPC-only (including admins, reviews, moderation, support,
-- deletion queues, booking notes/history, audit, and home-feed configuration).

CREATE OR REPLACE FUNCTION public.get_vendor_booking_data(p_booking_id uuid DEFAULT NULL::uuid, p_before_created timestamp with time zone DEFAULT NULL::timestamp with time zone, p_before_id uuid DEFAULT NULL::uuid, p_limit integer DEFAULT 200)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
 perform eventra_security.require_actor('vendor');
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 return coalesce((select jsonb_agg(row_data order by created_at desc,id desc) from (
  select b.id,b.created_at,to_jsonb(b)||jsonb_build_object(
   'customers',jsonb_build_object('name',c.name,'email',c.email,'phone',c.phone),
   'vendors',jsonb_build_object('name',v.name,'email',v.email),
   'services',jsonb_build_object('name',s.name,'gallery',s.gallery),
   'event_types',jsonb_build_object('name',e.name),
   'business_name',coalesce(b.business_name,x.name),
   'vendor_note',coalesce(n.note,''),'note_version',coalesce(n.version,0)
  ) row_data
  from public.bookings b
  join public.customers c on c.id=b.customer_id
  join public.vendors v on v.id=b.vendor_id
  join public.services s on s.id=b.service_id
  left join public.businesses x on x.id=b.business_id
  left join public.event_types e on e.id=b.event_type_id
  left join public.booking_vendor_notes n on n.booking_id=b.id and n.vendor_id=auth.uid()
  where b.vendor_id=auth.uid() and (p_booking_id is null or b.id=p_booking_id)
   and (p_before_created is null or (b.created_at,b.id)<(p_before_created,p_before_id))
  order by b.created_at desc,b.id desc limit greatest(1,least(coalesce(p_limit,200),200))
 ) rows), '[]'::jsonb);
end $function$
;

CREATE OR REPLACE FUNCTION public.get_vendor_booking_history(p_booking_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
 perform eventra_security.require_actor('vendor');
 if not exists(select 1 from public.bookings where id=p_booking_id and vendor_id=auth.uid()) then raise exception 'Booking not found'; end if;
 return coalesce((select jsonb_agg(to_jsonb(h) order by h.occurred_at,h.id)
 from public.booking_status_history h where h.booking_id=p_booking_id),'[]'::jsonb);
end $function$
;

CREATE OR REPLACE FUNCTION public.get_vendor_booking_conflicts(p_booking_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare b public.bookings;
begin
 perform eventra_security.require_actor('vendor');
 select * into b from public.bookings where id=p_booking_id and vendor_id=auth.uid();
 if not found then raise exception 'Booking not found'; end if;
 if b.business_id is null then return '[]'::jsonb; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('id',x.id,'service_name',s.name,'event_date',x.event_date))
 from public.bookings x join public.services s on s.id=x.service_id
 where x.vendor_id=b.vendor_id and x.business_id=b.business_id and x.id<>b.id and x.status='accepted'
 and case when b.event_start_time is not null and b.event_end_time is not null
  and x.event_start_time is not null and x.event_end_time is not null then
  ((b.event_date+b.event_start_time) at time zone b.event_timezone)<((coalesce(x.event_end_date,x.event_date)+x.event_end_time) at time zone x.event_timezone)
  and ((x.event_date+x.event_start_time) at time zone x.event_timezone)<((coalesce(b.event_end_date,b.event_date)+b.event_end_time) at time zone b.event_timezone)
 else b.event_date<=coalesce(x.event_end_date,x.event_date) and x.event_date<=coalesce(b.event_end_date,b.event_date) end
 ),'[]'::jsonb);
end $function$
;

CREATE OR REPLACE FUNCTION public.change_vendor_booking_status(p_booking_id uuid, p_expected_status text, p_status text, p_reason text DEFAULT NULL::text, p_ack_overlap boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare b public.bookings; conflict_list jsonb;
begin
 perform eventra_security.require_actor('vendor');
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 -- Serializes acceptance across the vendor, including a second device.
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,72));
 select * into b from public.bookings where id=p_booking_id and vendor_id=auth.uid() for update;
 if not found then raise exception 'Booking not found'; end if;
 if b.status is distinct from p_expected_status then raise exception 'Booking changed. Refresh and try again.'; end if;
 if p_status is null or not ((b.status='pending' and p_status in ('accepted','rejected','cancelled')) or
   (b.status='accepted' and p_status in ('completed','cancelled'))) then raise exception 'Invalid status transition'; end if;
 if p_status in ('rejected','cancelled') and length(trim(coalesce(p_reason,'')))<3 then raise exception 'Enter a reason (at least 3 characters)'; end if;
 if length(coalesce(p_reason,''))>1000 then raise exception 'Reason is too long'; end if;
 if p_status='accepted' then
  conflict_list:=public.get_vendor_booking_conflicts(p_booking_id);
  if jsonb_array_length(conflict_list)>0 and not coalesce(p_ack_overlap,false) then raise exception 'Another accepted event overlaps. Review the warning and confirm again.'; end if;
 end if;
 if p_status='completed' and (
   coalesce(b.event_end_date,b.event_date)>(now() at time zone b.event_timezone)::date
   or (b.event_end_time is not null and
     ((coalesce(b.event_end_date,b.event_date)+b.event_end_time) at time zone b.event_timezone)>now())
   or (b.event_end_time is null and b.event_start_time is not null and
     ((b.event_date+b.event_start_time) at time zone b.event_timezone)>now())
 ) then raise exception 'This event has not finished yet'; end if;
 update public.bookings set status=p_status,status_reason=nullif(trim(p_reason),'') where id=b.id;
 -- Existing customer-status notification trigger remains active.
end $function$
;

CREATE OR REPLACE FUNCTION public.save_vendor_booking_note(p_booking_id uuid, p_note text, p_expected_version integer)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare current_version integer;
begin
 perform eventra_security.require_actor('vendor');
 perform 1 from public.bookings where id=p_booking_id and vendor_id=auth.uid() for update;
 if not found then raise exception 'Booking not found'; end if;
 if length(coalesce(p_note,''))>3000 then raise exception 'Maximum 3000 characters'; end if;
 select version into current_version from public.booking_vendor_notes where booking_id=p_booking_id;
 if coalesce(current_version,0) is distinct from p_expected_version then raise exception 'Notes changed on another device. Reload before saving.'; end if;
 insert into public.booking_vendor_notes(booking_id,vendor_id,note,version)
 values(p_booking_id,auth.uid(),coalesce(p_note,''),1)
 on conflict(booking_id) do update set note=excluded.note,version=public.booking_vendor_notes.version+1,updated_at=now()
 returning version into current_version;
 return current_version;
end $function$
;

CREATE OR REPLACE FUNCTION public.get_booking_review_context(p_booking_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare b public.bookings; r public.service_reviews; service_name text;
begin
 perform eventra_security.require_actor('customer');
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 select * into b from public.bookings where id=p_booking_id and customer_id=auth.uid();
 if not found then raise exception 'Booking not found'; end if;
 select * into r from public.service_reviews where booking_id=b.id;
 select name into service_name from public.services where id=b.service_id;
 return jsonb_build_object('booking_id',b.id,'service_id',b.service_id,'service_name',service_name,
  'status',b.status,'can_review',b.status='completed' and b.customer_id<>b.vendor_id,
  'review',case when r.id is null then null else to_jsonb(r)-'moderation_note'-'moderated_by' end);
end $function$
;

CREATE OR REPLACE FUNCTION public.submit_service_review(p_booking_id uuid, p_rating integer, p_text text DEFAULT ''::text, p_expected_version integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare b public.bookings; r public.service_reviews;
begin
 perform eventra_security.require_actor('customer');
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 -- One lock for this booking prevents concurrent duplicate submissions.
 select * into b from public.bookings where id=p_booking_id and customer_id=auth.uid() for update;
 if not found then raise exception 'Booking not found'; end if;
 if b.status<>'completed' then raise exception 'Only completed bookings can be reviewed'; end if;
 if b.customer_id=b.vendor_id then raise exception 'You cannot review your own service'; end if;
 if p_rating is null or p_rating not between 1 and 5 then raise exception 'Choose 1 to 5 stars'; end if;
 if length(coalesce(p_text,''))>2000 then raise exception 'Maximum 2000 characters'; end if;
 select * into r from public.service_reviews where booking_id=b.id for update;
 if coalesce(r.version,0) is distinct from p_expected_version then raise exception 'Review changed. Reload before saving.'; end if;
 if r.id is null then
  insert into public.service_reviews(booking_id,customer_id,vendor_id,service_id,business_id,rating,review_text)
  values(b.id,b.customer_id,b.vendor_id,b.service_id,b.business_id,p_rating,trim(coalesce(p_text,''))) returning * into r;
 else
  -- Editing never republishes an admin-hidden review or changes its ownership.
  update public.service_reviews set rating=p_rating,review_text=trim(coalesce(p_text,'')),version=version+1,updated_at=now()
  where id=r.id returning * into r;
 end if;
 return to_jsonb(r)-'moderation_note'-'moderated_by';
end $function$
;

CREATE OR REPLACE FUNCTION public.reply_service_review(p_review_id uuid, p_reply text, p_expected_version integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare r public.service_reviews;
begin
 perform eventra_security.require_actor('vendor');
 select * into r from public.service_reviews where id=p_review_id and vendor_id=auth.uid() for update;
 if not found then raise exception 'Review not found'; end if;
 if r.reply_version is distinct from p_expected_version then raise exception 'Reply changed. Reload before saving.'; end if;
 if length(coalesce(p_reply,''))>2000 then raise exception 'Maximum 2000 characters'; end if;
 update public.service_reviews set vendor_reply=nullif(trim(p_reply),''),replied_at=now(),reply_version=reply_version+1 where id=r.id;
end $function$
;

CREATE OR REPLACE FUNCTION public.report_service_review(p_review_id uuid, p_reason text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
 perform eventra_security.require_actor(null);
 if not exists(select 1 from public.service_reviews where id=p_review_id and vendor_id=auth.uid()) then raise exception 'Review not found'; end if;
 if length(trim(coalesce(p_reason,''))) not between 3 and 1000 then raise exception 'Enter a reason (3 to 1000 characters)'; end if;
 insert into public.service_review_reports(review_id,reporter_id,reason) values(p_review_id,auth.uid(),trim(p_reason))
 on conflict(review_id,reporter_id) do nothing;
 -- Reporting does NOT hide the review or change the rating.
end $function$
;

CREATE OR REPLACE FUNCTION public.sync_vendor_announcements()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
 perform eventra_security.require_actor('vendor');
 if not exists(select 1 from public.users where id=auth.uid() and role='vendor') then raise exception 'Vendor account required' using errcode='42501'; end if;
 insert into public.vendor_notifications(recipient_id,kind,title,body,event_key,announcement_id,created_at,data)
 select auth.uid(),a.kind,a.title,a.body,'announcement:'||a.id,a.id,greatest(a.created_at,a.starts_at),jsonb_build_object('reference',a.reference)
 from public.vendor_announcements a
 where a.is_active and a.starts_at<=now() and (a.expires_at is null or a.expires_at>now())
 and (a.recipient_id is null or a.recipient_id=auth.uid())
 on conflict(recipient_id,event_key) do nothing;
end $function$
;

CREATE OR REPLACE FUNCTION public.mark_vendor_notifications_read(p_ids uuid[] DEFAULT NULL::uuid[], p_before timestamp with time zone DEFAULT now())
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
 perform eventra_security.require_actor('vendor');
 if not exists(select 1 from public.users where id=auth.uid() and role='vendor') then raise exception 'Vendor account required' using errcode='42501'; end if;
 update public.vendor_notifications set read_at=now()
 where recipient_id=auth.uid() and read_at is null and created_at<=p_before and (p_ids is null or id=any(p_ids));
end $function$
;

CREATE OR REPLACE FUNCTION public.get_vendor_listing_metrics()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 select coalesce(jsonb_object_agg(s.id::text,jsonb_build_object(
 'bookings',coalesce(b.total,0),'rating',r.average)), '{}'::jsonb)
 from public.services s
 left join (select service_id,count(*) total from public.bookings where vendor_id=auth.uid() group by service_id) b on b.service_id=s.id
 left join (select service_id,round(avg(rating)::numeric,1) average from public.service_reviews where vendor_id=auth.uid() and moderation_status='visible' group by service_id) r on r.service_id=s.id
 where s.vendor_id=auth.uid();
$function$
;

CREATE OR REPLACE FUNCTION public.update_customer_contact_phone(p_phone text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare cleaned text := nullif(trim(p_phone), '');
begin
 perform eventra_security.require_actor('customer');
  if auth.uid() is null then raise exception 'Please log in again.'; end if;
  if cleaned is not null and cleaned !~ '^\+[1-9][0-9]{6,14}$' then
    raise exception 'Enter an international phone number, for example +919876543210.';
  end if;
  update public.customers v set phone = cleaned, updated_at = now()
  where v.id = auth.uid() and exists (
    select 1 from public.users u where u.id = v.id and u.role = 'customer');
  if not found then raise exception 'Customer account not found.'; end if;
  return cleaned;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.get_customer_account_security()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare result jsonb;
begin
 perform eventra_security.require_actor('customer');
  if auth.uid() is null then raise exception 'Please log in again.'; end if;
  select jsonb_build_object(
    'email', a.email,
    'pending_email', nullif(a.email_change, ''),
    'phone', v.phone,
    'deletion_request', (select jsonb_build_object(
      'id', d.id, 'status', d.status, 'requested_at', d.requested_at,
      'public_note', d.public_note)
      from public.account_deletion_requests d where d.user_id = a.id
      order by d.requested_at desc, d.id desc limit 1)
  ) into result
  from auth.users a join public.users u on u.id = a.id and u.role = 'customer'
  join public.customers v on v.id = a.id where a.id = auth.uid();
  if result is null then raise exception 'Customer account not found.'; end if;
  return result;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.request_customer_account_deletion(p_reason text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare request public.account_deletion_requests;
begin
 perform eventra_security.require_actor('customer');
  if auth.uid() is null or not exists (
    select 1 from public.users u join public.customers v on v.id = u.id
    where u.id = auth.uid() and u.role = 'customer') then
    raise exception 'Customer account not found.';
  end if;
  insert into public.account_deletion_requests(user_id, reason)
  values(auth.uid(), nullif(trim(p_reason), ''))
  on conflict(user_id) where status in ('pending','in_review') do nothing
  returning * into request;
  if request.id is null then
    select * into request from public.account_deletion_requests
    where user_id = auth.uid() and status in ('pending','in_review');
  end if;
  return jsonb_build_object('id',request.id,'status',request.status,
    'requested_at',request.requested_at,'public_note',request.public_note);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.cancel_customer_account_deletion()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
 perform eventra_security.require_actor('customer');
  if auth.uid() is null then raise exception 'Please log in again.'; end if;
  update public.account_deletion_requests set status = 'cancelled'
  where user_id = auth.uid() and status = 'pending';
  if not found then raise exception 'Only a pending request can be cancelled.'; end if;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.get_vendor_dashboard_overview(p_business_id uuid DEFAULT NULL::uuid, p_unassigned boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare result jsonb; rating_data jsonb; recent jsonb; verification text;
begin
 perform eventra_security.require_actor('vendor');
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 if p_business_id is not null and not exists(select 1 from public.businesses where id=p_business_id and vendor_id=auth.uid()) then raise exception 'Business not found'; end if;
 if p_business_id is not null and p_unassigned then raise exception 'Choose one business scope'; end if;
 select jsonb_build_object('total',count(*),'pending',count(*) filter(where status='pending'),
  'upcoming',count(*) filter(where status='accepted' and (case when event_end_date>event_date and event_end_time='00:00'::time then event_end_date-1 else coalesce(event_end_date,event_date) end)>=(now() at time zone event_timezone)::date),
  'completed',count(*) filter(where status='completed'),'rejected',count(*) filter(where status='rejected'),
  'cancelled',count(*) filter(where status='cancelled')) into result
 from public.bookings where vendor_id=auth.uid()
  and (p_business_id is null or business_id=p_business_id) and (not p_unassigned or business_id is null);
 select jsonb_build_object('review_count',count(*),'rating_average',round(avg(rating),2)) into rating_data
 from public.service_reviews where vendor_id=auth.uid() and moderation_status='visible'
  and (p_business_id is null or business_id=p_business_id) and (not p_unassigned or business_id is null);
 select coalesce(jsonb_agg(data order by created_at desc,id desc),'[]'::jsonb) into recent from (
  select r.id,r.created_at,jsonb_build_object('id',r.id,'service_id',r.service_id,'vendor_id',r.vendor_id,'business_id',r.business_id,
   'customer_name',c.name,'service_name',s.name,'rating',r.rating,'review_text',r.review_text,
   'created_at',r.created_at,'updated_at',r.updated_at,'version',r.version,'vendor_reply',r.vendor_reply,
   'reply_version',r.reply_version,'replied_at',r.replied_at,'can_reply',true,'moderation_status',r.moderation_status) data
  from public.service_reviews r join public.customers c on c.id=r.customer_id join public.services s on s.id=r.service_id
  where r.vendor_id=auth.uid() and r.moderation_status='visible'
   and (p_business_id is null or r.business_id=p_business_id) and (not p_unassigned or r.business_id is null)
  order by r.created_at desc,r.id desc limit 3
 ) recent_rows;
 select status into verification from public.vendor_verifications where vendor_id=auth.uid() order by updated_at desc limit 1;
 return result||jsonb_build_object('rating',rating_data,'recent_reviews',recent,'verification_status',coalesce(verification,'not_submitted'),
  'active_businesses',(select count(*) from public.businesses where vendor_id=auth.uid() and is_active and (p_business_id is null or id=p_business_id) and not p_unassigned),
  'active_services',(select count(*) from public.services where vendor_id=auth.uid() and is_active and (p_business_id is null or business_id=p_business_id) and (not p_unassigned or business_id is null)));
end $function$
;

CREATE OR REPLACE FUNCTION public.save_vendor_business_location(p_id uuid, p_data jsonb, p_categories uuid[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare old_b public.businesses; state text; district text; subdistrict text; payload jsonb; result jsonb; lat double precision; lng double precision;
begin
 perform eventra_security.require_actor('vendor');
 if auth.uid() is null then raise exception 'Sign in required';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_id::text,0));
 select * into old_b from public.businesses where id=p_id for update;
 if found and old_b.vendor_id<>auth.uid() then raise exception 'Not your business';end if;
 if length(trim(coalesce(p_data->>'shop_address','')))<5 then raise exception 'Enter your shop address';end if;
 state:=p_data->>'shop_state_id';district:=p_data->>'shop_district_id';subdistrict:=p_data->>'shop_subdistrict_id';
 if state is null or not exists(select 1 from public.administrative_regions where id=state and level='state' and is_active) then raise exception 'Select your shop state';end if;
 if district is null or not exists(select 1 from public.administrative_regions where id=district and level='district' and parent_id=state and is_active) then raise exception 'Select a district in your state';end if;
 if subdistrict is null or not exists(select 1 from public.administrative_regions where id=subdistrict and level='subdistrict' and parent_id=district and is_active) then raise exception 'Select a sub-district in your district';end if;
 lat:=(p_data->>'latitude')::double precision;lng:=(p_data->>'longitude')::double precision;
 if lat is null or lng is null or lat not between -90 and 90 or lng not between -180 and 180 then raise exception 'Mark the exact shop location on the map';end if;
 payload:=p_data||jsonb_build_object('address',trim(p_data->>'shop_address'),
 'portfolio',coalesce(old_b.portfolio,'[]'::jsonb),'availability_status',coalesce(old_b.availability_status,'active'),
 'started_year',old_b.started_year,'website_url',old_b.website_url,'instagram_url',old_b.instagram_url,
 'travels_to_customer',coalesce(old_b.travels_to_customer,true));
 perform public.save_vendor_business(p_id,payload,p_categories);
 update public.businesses set shop_state_id=state,shop_district_id=district,shop_subdistrict_id=subdistrict,
 shop_address=trim(p_data->>'shop_address') where id=p_id returning to_jsonb(businesses.*) into result;
 return result;
end $function$
;

CREATE OR REPLACE FUNCTION public.get_vendor_support_tickets(p_ticket_id uuid DEFAULT NULL::uuid)
 RETURNS SETOF support_tickets
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
 perform eventra_security.require_actor(null);
  if auth.uid() is null then raise exception 'Please log in again.'; end if;
  return query select * from public.support_tickets
  where user_id = auth.uid() and (p_ticket_id is null or id = p_ticket_id)
  order by created_at desc;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.get_vendor_support_messages(p_ticket_id uuid)
 RETURNS SETOF support_messages
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
 perform eventra_security.require_actor(null);
  if auth.uid() is null or not exists (
    select 1 from public.support_tickets where id = p_ticket_id and user_id = auth.uid()
  ) then raise exception 'Support request not found.'; end if;
  return query select * from public.support_messages
  where ticket_id = p_ticket_id order by created_at, id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.reply_vendor_support_ticket(p_ticket_id uuid, p_body text)
 RETURNS support_messages
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  ticket public.support_tickets;
  message public.support_messages;
begin
 perform eventra_security.require_actor('vendor');
  if auth.uid() is null then raise exception 'Please log in again.'; end if;
  select * into ticket from public.support_tickets
  where id = p_ticket_id and user_id = auth.uid() for update;
  if ticket.id is null then raise exception 'Support request not found.'; end if;
  if ticket.status = 'closed' then raise exception 'This request is closed. Create a new request for further help.'; end if;
  insert into public.support_messages(ticket_id, author_id, sender_role, body)
  values(p_ticket_id, auth.uid(), 'vendor', trim(p_body)) returning * into message;
  update public.support_tickets set status = 'open' where id = p_ticket_id;
  return message;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.get_vendor_account_security()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare result jsonb;
begin
 perform eventra_security.require_actor('vendor');
  if auth.uid() is null then raise exception 'Please log in again.'; end if;
  select jsonb_build_object(
    'email', a.email,
    'pending_email', nullif(a.email_change, ''),
    'phone', v.phone,
    'deletion_request', (select jsonb_build_object(
      'id', d.id, 'status', d.status, 'requested_at', d.requested_at,
      'public_note', d.public_note)
      from public.account_deletion_requests d where d.user_id = a.id
      order by d.requested_at desc, d.id desc limit 1)
  ) into result
  from auth.users a join public.users u on u.id = a.id and u.role = 'vendor'
  join public.vendors v on v.id = a.id where a.id = auth.uid();
  if result is null then raise exception 'Vendor account not found.'; end if;
  return result;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.update_vendor_contact_phone(p_phone text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare cleaned text := nullif(trim(p_phone), '');
begin
 perform eventra_security.require_actor('vendor');
  if auth.uid() is null then raise exception 'Please log in again.'; end if;
  if cleaned is not null and cleaned !~ '^\+[1-9][0-9]{6,14}$' then
    raise exception 'Enter an international phone number, for example +919876543210.';
  end if;
  update public.vendors v set phone = cleaned, updated_at = now()
  where v.id = auth.uid() and exists (
    select 1 from public.users u where u.id = v.id and u.role = 'vendor');
  if not found then raise exception 'Vendor account not found.'; end if;
  return cleaned;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.request_vendor_account_deletion(p_reason text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare request public.account_deletion_requests;
begin
 perform eventra_security.require_actor('vendor');
  if auth.uid() is null or not exists (
    select 1 from public.users u join public.vendors v on v.id = u.id
    where u.id = auth.uid() and u.role = 'vendor') then
    raise exception 'Vendor account not found.';
  end if;
  insert into public.account_deletion_requests(user_id, reason)
  values(auth.uid(), nullif(trim(p_reason), ''))
  on conflict(user_id) where status in ('pending','in_review') do nothing
  returning * into request;
  if request.id is null then
    select * into request from public.account_deletion_requests
    where user_id = auth.uid() and status in ('pending','in_review');
  end if;
  return jsonb_build_object('id',request.id,'status',request.status,
    'requested_at',request.requested_at,'public_note',request.public_note);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.cancel_vendor_account_deletion()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
 perform eventra_security.require_actor('vendor');
  if auth.uid() is null then raise exception 'Please log in again.'; end if;
  update public.account_deletion_requests set status = 'cancelled'
  where user_id = auth.uid() and status = 'pending';
  if not found then raise exception 'Only a pending request can be cancelled.'; end if;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.create_vendor_support_ticket(p_request_id uuid, p_category text, p_subject text, p_description text, p_screenshot_path text DEFAULT NULL::text)
 RETURNS support_tickets
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  actor uuid := auth.uid();
  ticket public.support_tickets;
begin
 perform eventra_security.require_actor(null);
  if actor is null then raise exception 'Please log in again.'; end if;
  if p_screenshot_path is not null and (
    split_part(p_screenshot_path, '/', 1) <> actor::text or
    split_part(p_screenshot_path, '/', 2) <> p_request_id::text
  ) then raise exception 'Invalid attachment path.'; end if;

  insert into public.support_tickets(id, user_id, category, subject, description, screenshot_path)
  values(p_request_id, actor, p_category, trim(p_subject), trim(p_description), p_screenshot_path)
  on conflict(id) do nothing returning * into ticket;

  if ticket.id is null then
    select * into ticket from public.support_tickets where id = p_request_id and user_id = actor;
    if ticket.id is null then raise exception 'Invalid request identifier.'; end if;
  end if;
  return ticket;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.update_vendor_personal_details(p_name text, p_about_me text DEFAULT NULL::text, p_preferred_contact_language text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare updated public.vendors;
begin
 perform eventra_security.require_actor('vendor');
  if auth.uid() is null then raise exception 'Please log in again.'; end if;
  if p_name is null or char_length(trim(p_name)) not between 1 and 100 then
    raise exception 'Name must contain between 1 and 100 characters.';
  end if;
  update public.vendors v set
    name = trim(p_name),
    about_me = nullif(trim(p_about_me), ''),
    preferred_contact_language = p_preferred_contact_language,
    updated_at = now()
  where v.id = auth.uid() and exists (
    select 1 from public.users u where u.id = v.id and u.role = 'vendor')
  returning v.* into updated;
  if updated.id is null then raise exception 'Vendor profile not found.'; end if;
  update public.users set name = updated.name where id = updated.id and role = 'vendor';
  return to_jsonb(updated);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.submit_business_verification(p_business_id uuid, p_path text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
 perform eventra_security.require_actor('vendor');
 perform 1 from public.businesses where id=p_business_id and vendor_id=auth.uid() for update;
 if not found then raise exception 'Not your business'; end if;
 if split_part(p_path,'/',1)<>auth.uid()::text or split_part(p_path,'/',2)<>p_business_id::text then raise exception 'Invalid document path'; end if;
 if not exists(select 1 from storage.objects where bucket_id='business-documents' and name=p_path) then raise exception 'Upload the document first'; end if;
 if exists(select 1 from public.business_verifications where business_id=p_business_id and status in ('pending','approved')) then raise exception 'Already submitted or approved'; end if;
 insert into public.business_verifications(business_id,status,document_path,submitted_at)
 values(p_business_id,'pending',p_path,now()) on conflict(business_id) do update
 set status='pending',document_path=excluded.document_path,submitted_at=now(),reviewed_at=null,review_note=null;
end $function$
;

CREATE OR REPLACE FUNCTION public.save_business_service(p_id uuid, p_business_id uuid, p_data jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare b public.businesses; category_id uuid;
begin
 perform eventra_security.require_actor('vendor');
 perform pg_advisory_xact_lock(hashtextextended(p_id::text,1));
 select * into b from public.businesses where id=p_business_id and vendor_id=auth.uid() for update;
 if not found then raise exception 'Not your business'; end if;
 if b.availability_status='archived' then raise exception 'Restore this business first'; end if;
 if exists(select 1 from public.services where id=p_id and (vendor_id<>auth.uid() or business_id is distinct from p_business_id)) then raise exception 'Not your service'; end if;
 category_id := (p_data->>'category_node_id')::uuid;
 if not exists(
  with recursive allowed(id) as (
   select category_node_id from public.business_category_nodes where business_id=p_business_id
   union select n.id from public.category_nodes n join allowed a on n.parent_id=a.id
  ) select 1 from allowed where id=category_id
 ) then raise exception 'Choose a category belonging to this business'; end if;
 if length(trim(coalesce(p_data->>'name','')))<2 or (p_data->>'price')::numeric is null or (p_data->>'price')::numeric<0 then raise exception 'Enter a name and a valid price'; end if;
 if jsonb_typeof(p_data->'gallery') is distinct from 'array' then raise exception 'Invalid gallery'; end if;
 insert into public.services(id,vendor_id,business_id,category_node_id,name,slug,description,price,gallery,is_active,vendor_enabled)
 values(p_id,auth.uid(),p_business_id,category_id,trim(p_data->>'name'),'service-'||p_id::text,p_data->>'description',(p_data->>'price')::numeric,p_data->'gallery',(p_data->>'vendor_enabled')::boolean,(p_data->>'vendor_enabled')::boolean)
 on conflict(id) do update set category_node_id=excluded.category_node_id,name=excluded.name,
 description=excluded.description,price=excluded.price,gallery=excluded.gallery,
 vendor_enabled=excluded.vendor_enabled,updated_at=now();
 update public.services set
 pricing_type=case when p_data ? 'pricing_type' then p_data->>'pricing_type' else pricing_type end,
 pricing_unit=case when p_data ? 'pricing_type' then
   case when p_data->>'pricing_type' in ('per_unit','per_duration') then trim(p_data->>'pricing_unit') else null end
   else pricing_unit end
 where id=p_id and vendor_id=auth.uid();

end $function$
;

CREATE OR REPLACE FUNCTION public.reply_customer_support_ticket(p_ticket_id uuid, p_body text)
 RETURNS support_messages
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare ticket public.support_tickets; message public.support_messages;
begin
 perform eventra_security.require_actor('customer');
  if auth.uid() is null then raise exception 'Please log in again.'; end if;
  if length(trim(coalesce(p_body,''))) not between 1 and 4000 then raise exception 'Enter a reply between 1 and 4000 characters.'; end if;
  select * into ticket from public.support_tickets where id=p_ticket_id and user_id=auth.uid() for update;
  if ticket.id is null then raise exception 'Support request not found.'; end if;
  if ticket.status='closed' then raise exception 'This request is closed. Create a new request for further help.'; end if;
  insert into public.support_messages(ticket_id,author_id,sender_role,body)
  values(p_ticket_id,auth.uid(),'customer',trim(p_body)) returning * into message;
  update public.support_tickets set status='open' where id=p_ticket_id;
  return message;
end $function$
;

CREATE OR REPLACE FUNCTION public.save_vendor_business(p_id uuid, p_data jsonb, p_categories uuid[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare b public.businesses; primary_id uuid; lat double precision; lng double precision;
begin
 perform eventra_security.require_actor('vendor');
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 -- Serialize retries for the same id; a network retry cannot create duplicates.
 perform pg_advisory_xact_lock(hashtextextended(p_id::text,0));
 select * into b from public.businesses where id=p_id for update;
 if found and b.vendor_id<>auth.uid() then raise exception 'Not your business'; end if;
 if length(trim(coalesce(p_data->>'name','')))<2 then raise exception 'Enter a business name'; end if;
 if coalesce(array_length(p_categories,1),0)=0 then raise exception 'Select at least one category'; end if;
 if exists(select 1 from unnest(p_categories) c where not exists(select 1 from public.category_nodes n where n.id=c)) then raise exception 'Invalid category'; end if;
 primary_id := (p_data->>'primary_category_id')::uuid;
 if primary_id is null or not primary_id=any(p_categories) then raise exception 'Select a primary category'; end if;
 lat := (p_data->>'latitude')::double precision; lng := (p_data->>'longitude')::double precision;
 if (lat is null)<>(lng is null) or lat not between -90 and 90 or lng not between -180 and 180 then raise exception 'Enter valid latitude and longitude together'; end if;
 if p_data->>'availability_status' not in ('active','unavailable','archived') then raise exception 'Invalid status'; end if;
 if (p_data->>'started_year')::integer not between 1900 and extract(year from current_date)::integer then raise exception 'Invalid started year'; end if;
 if jsonb_typeof(p_data->'portfolio') is distinct from 'array' or jsonb_array_length(p_data->'portfolio')>30 then raise exception 'Maximum 30 portfolio items'; end if;
 -- Existing service categories must still be covered, including child categories.
 if exists (
  with recursive allowed(id) as (
   select unnest(p_categories) union select n.id from public.category_nodes n join allowed a on n.parent_id=a.id
  ) select 1 from public.services s where s.business_id=p_id and s.category_node_id not in(select id from allowed)
 ) then raise exception 'A service uses a category you removed. Move that service first.'; end if;
 insert into public.businesses(id,vendor_id,name) values(p_id,auth.uid(),trim(p_data->>'name'))
 on conflict(id) do nothing;
 update public.businesses set
  name=trim(p_data->>'name'), description=nullif(trim(p_data->>'description'),''),
  logo_url=nullif(p_data->>'logo_url',''), banner_url=nullif(p_data->>'banner_url',''),
  phone=nullif(trim(p_data->>'phone'),''), whatsapp=nullif(trim(p_data->>'whatsapp'),''),
  email=nullif(trim(p_data->>'email'),''), address=nullif(trim(p_data->>'address'),''),
  latitude=lat, longitude=lng, started_year=(p_data->>'started_year')::integer,

  travels_to_customer=coalesce((p_data->>'travels_to_customer')::boolean,true),
  website_url=nullif(p_data->>'website_url',''), instagram_url=nullif(p_data->>'instagram_url',''),
  primary_category_id=primary_id, portfolio=p_data->'portfolio',
  availability_status=p_data->>'availability_status', updated_at=now()
 where id=p_id returning * into b;
 delete from public.business_category_nodes where business_id=p_id;
 insert into public.business_category_nodes(business_id,category_node_id)
 select p_id,c from (select distinct unnest(p_categories) c) x;
 return to_jsonb(b);
end $function$
;

-- Admin membership is not derived from user-editable signup metadata.
create or replace function public.eventra_is_admin() returns boolean language sql stable security definer set search_path='' as $$
 select eventra_security.live_account(auth.uid()) and exists(select 1 from public.admins where id=auth.uid() and is_active)
$$;
create or replace function public.eventra_admin_can_write() returns boolean language sql stable security definer set search_path='' as $$
 select eventra_security.live_account(auth.uid()) and exists(select 1 from public.admins where id=auth.uid() and is_active and access_level in ('owner','admin'))
$$;
create or replace function eventra_admin.require_access(p_write boolean default false) returns text
language plpgsql stable security definer set search_path='' as $$
declare level text;
begin
 select access_level into level from public.admins where id=auth.uid() and is_active;
 if not eventra_security.live_account(auth.uid()) or level is null or (p_write and level='viewer') then raise exception 'Admin permission required' using errcode='42501';end if;
 return level;
end $$;

-- Storage: replace broad old policies, preserve public reads for public media only.
create or replace function eventra_security.owns_object(bucket text,path text) returns boolean
language sql stable security definer set search_path='' as $$
 select eventra_security.actor_role() is not null and case
 when bucket='profile' then eventra_security.actor_role()='vendor' and split_part(path,'/',1)='vendors' and split_part(path,'/',2)=auth.uid()::text
 when bucket='profile-images' then eventra_security.actor_role()='customer' and split_part(path,'/',1)='customers' and split_part(path,'/',2)=auth.uid()::text
 when bucket='service-gallery' then eventra_security.actor_role()='vendor' and
 (split_part(path,'/',1)=auth.uid()::text or (split_part(path,'/',1)='services' and split_part(path,'/',2)=auth.uid()::text))
 when bucket in ('business-media','business-documents','vendor-verification-documents') then eventra_security.actor_role()='vendor' and split_part(path,'/',1)=auth.uid()::text
 when bucket='support-attachments' then split_part(path,'/',1)=auth.uid()::text
 else false end
$$;
do $$ declare r record;begin
 for r in select policyname from pg_policies where schemaname='storage' and tablename='objects' loop
 execute format('drop policy %I on storage.objects',r.policyname);
 end loop;
end $$;
create policy eventra_public_media_read on storage.objects for select to anon,authenticated using(bucket_id in ('profile','profile-images','banners','service-gallery','business-media','social-icons'));
create policy eventra_private_media_read on storage.objects for select to authenticated using(eventra_security.owns_object(bucket_id,name) or public.eventra_is_admin());
create policy eventra_owned_media_insert on storage.objects for insert to authenticated with check(eventra_security.owns_object(bucket_id,name));
create policy eventra_owned_media_update on storage.objects for update to authenticated using(eventra_security.owns_object(bucket_id,name)) with check(eventra_security.owns_object(bucket_id,name));
create policy eventra_owned_media_delete on storage.objects for delete to authenticated using(eventra_security.owns_object(bucket_id,name));
create policy eventra_admin_media_insert on storage.objects for insert to authenticated with check(public.eventra_admin_can_write() and (
 (bucket_id in ('banners','profile','service-gallery','business-media') and (split_part(name,'/',1)='admins' and split_part(name,'/',2)=auth.uid()::text or bucket_id='service-gallery' and split_part(name,'/',1)='services'))
 or (bucket_id='social-icons' and split_part(name,'/',1)='admins' and split_part(name,'/',2)=auth.uid()::text)));
create policy eventra_admin_media_delete on storage.objects for delete to authenticated using(public.eventra_admin_can_write() and (
 bucket_id in ('profile','profile-images','banners','service-gallery','vendor-verification-documents','support-attachments','business-media','business-documents')
 or (bucket_id='social-icons' and public.eventra_social_icon_can_delete(name))));
revoke insert,update,delete,truncate,references,trigger on storage.buckets from public,anon,authenticated;
revoke insert,update,delete,truncate,references,trigger on storage.objects from public,anon;
revoke truncate,references,trigger on storage.objects from authenticated;
update storage.buckets set file_size_limit=5242880,allowed_mime_types=array['image/jpeg','image/png','image/webp'] where id in ('profile','profile-images');

-- No execute access to trigger bodies or internal notification emitters through RPC.
revoke execute on all functions in schema public from public,anon,authenticated;
revoke execute on all functions in schema eventra_security from public,anon,authenticated;
revoke execute on all functions in schema eventra_admin from public,anon,authenticated;
revoke execute on all functions in schema eventra_feed from public,anon,authenticated;
grant execute on function eventra_security.actor_role(),eventra_security.owns_business(uuid),eventra_security.public_service(uuid),eventra_security.booked_service(uuid),eventra_security.booked_vendor(uuid),eventra_security.service_has_bookings(uuid),eventra_security.live_account(uuid),eventra_security.owns_object(text,text) to anon,authenticated;
grant execute on function public.eventra_is_admin() to anon,authenticated;
grant execute on function public.eventra_admin_can_write(),public.eventra_social_icon_can_delete(text) to authenticated;
grant execute on function public.get_vendor_booking_data(p_booking_id uuid, p_before_created timestamp with time zone, p_before_id uuid, p_limit integer) to authenticated;
grant execute on function public.get_vendor_booking_history(p_booking_id uuid) to authenticated;
grant execute on function public.get_vendor_booking_conflicts(p_booking_id uuid) to authenticated;
grant execute on function public.change_vendor_booking_status(p_booking_id uuid, p_expected_status text, p_status text, p_reason text, p_ack_overlap boolean) to authenticated;
grant execute on function public.save_vendor_booking_note(p_booking_id uuid, p_note text, p_expected_version integer) to authenticated;
grant execute on function public.get_booking_review_context(p_booking_id uuid) to authenticated;
grant execute on function public.submit_service_review(p_booking_id uuid, p_rating integer, p_text text, p_expected_version integer) to authenticated;
grant execute on function public.get_service_reviews(p_service_id uuid, p_business_id uuid, p_vendor_mode boolean, p_before_created timestamp with time zone, p_before_id uuid, p_limit integer) to anon,authenticated;
grant execute on function public.get_review_summary(p_service_id uuid, p_business_id uuid, p_vendor_id uuid) to anon,authenticated;
grant execute on function public.reply_service_review(p_review_id uuid, p_reply text, p_expected_version integer) to authenticated;
grant execute on function public.report_service_review(p_review_id uuid, p_reason text) to authenticated;
grant execute on function public.sync_vendor_announcements() to authenticated;
grant execute on function public.vendor_notification_unread_count() to authenticated;
grant execute on function public.admin_grant_access(p_email text, p_name text, p_access_level text) to authenticated;
grant execute on function public.mark_vendor_notifications_read(p_ids uuid[], p_before timestamp with time zone) to authenticated;
grant execute on function public.get_vendor_listing_metrics() to authenticated;
grant execute on function public.update_customer_contact_phone(p_phone text) to authenticated;
grant execute on function public.get_customer_account_security() to authenticated;
grant execute on function public.request_customer_account_deletion(p_reason text) to authenticated;
grant execute on function public.cancel_customer_account_deletion() to authenticated;
grant execute on function public.admin_home_feed_save(p_data jsonb, p_pins uuid[], p_id uuid, p_revision text, p_request_id uuid) to authenticated;
grant execute on function public.admin_home_feed_preview(p_id uuid, p_lat double precision, p_lng double precision) to authenticated;
grant execute on function public.admin_home_feed_choices(p_type text, p_search text, p_parent text) to authenticated;
grant execute on function public.get_my_account_role() to authenticated;
grant execute on function public.get_vendor_dashboard_overview(p_business_id uuid, p_unassigned boolean) to authenticated;
grant execute on function public.save_vendor_business_location(p_id uuid, p_data jsonb, p_categories uuid[]) to authenticated;
grant execute on function public.get_vendor_support_tickets(p_ticket_id uuid) to authenticated;
grant execute on function public.get_vendor_support_messages(p_ticket_id uuid) to authenticated;
grant execute on function public.reply_vendor_support_ticket(p_ticket_id uuid, p_body text) to authenticated;
grant execute on function public.get_vendor_account_security() to authenticated;
grant execute on function public.update_vendor_contact_phone(p_phone text) to authenticated;
grant execute on function public.request_vendor_account_deletion(p_reason text) to authenticated;
grant execute on function public.cancel_vendor_account_deletion() to authenticated;
grant execute on function public.home_feed_page(p_offset integer, p_limit integer, p_lat double precision, p_lng double precision) to anon,authenticated;
grant execute on function public.home_feed_items(p_section_id uuid, p_offset integer, p_limit integer, p_lat double precision, p_lng double precision) to anon,authenticated;
grant execute on function public.admin_home_feed_workspace() to authenticated;
grant execute on function public.create_vendor_support_ticket(p_request_id uuid, p_category text, p_subject text, p_description text, p_screenshot_path text) to authenticated;
grant execute on function public.admin_context() to authenticated;
grant execute on function public.home_feed_vendor_services(p_vendor_id uuid, p_offset integer) to anon,authenticated;
grant execute on function public.update_vendor_personal_details(p_name text, p_about_me text, p_preferred_contact_language text) to authenticated;
grant execute on function public.customer_search(p_query text, p_kind text, p_offset integer, p_limit integer) to anon,authenticated;
grant execute on function public.submit_business_verification(p_business_id uuid, p_path text) to authenticated;
grant execute on function public.save_business_service(p_id uuid, p_business_id uuid, p_data jsonb) to authenticated;
grant execute on function public.admin_catalog() to authenticated;
grant execute on function public.admin_record(p_module text, p_id text) to authenticated;
grant execute on function public.admin_records(p_module text, p_search text, p_offset integer, p_limit integer, p_filters jsonb) to authenticated;
grant execute on function public.admin_save(p_module text, p_data jsonb, p_id text, p_revision text, p_request_id uuid) to authenticated;
grant execute on function public.admin_overview() to authenticated;
grant execute on function public.admin_action(p_module text, p_id text, p_action text, p_revision text, p_values jsonb) to authenticated;
grant execute on function public.reply_customer_support_ticket(p_ticket_id uuid, p_body text) to authenticated;
grant execute on function public.save_vendor_business(p_id uuid, p_data jsonb, p_categories uuid[]) to authenticated;

-- Index ownership predicates used by high-frequency RLS checks.
create index if not exists eventra_security_bookings_customer_vendor_idx on public.bookings(customer_id,vendor_id);
create index if not exists eventra_security_bookings_service_idx on public.bookings(service_id);
create index if not exists eventra_security_business_vendor_idx on public.businesses(vendor_id);
create index if not exists eventra_security_services_vendor_idx on public.services(vendor_id);
grant execute on function public.delete_vendor_service(uuid) to authenticated;
notify pgrst,'reload schema';
commit;
