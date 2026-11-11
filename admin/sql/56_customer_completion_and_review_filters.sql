begin;
alter table public.bookings add column if not exists vendor_completed_at timestamptz;
alter table public.bookings add column if not exists customer_completed_at timestamptz;
create or replace function public.booking_completion_confirmation_guard() returns trigger language plpgsql set search_path='' as $$
begin
 if new.status='completed' and old.status<>'completed' and (new.vendor_completed_at is null or new.customer_completed_at is null) then raise exception 'Both vendor completion and customer acknowledgement are required'; end if;
 return new;
end $$;
revoke all on function public.booking_completion_confirmation_guard() from public;
create trigger require_both_completion_confirmations before update on public.bookings for each row execute function public.booking_completion_confirmation_guard();
do $$ declare definition text; needle text:=$n$update public.bookings set status=p_status,status_reason=nullif(trim(p_reason),'') where id=b.id;$n$;
begin
 select pg_get_functiondef(oid) into definition from pg_proc where pronamespace='public'::regnamespace and proname='change_vendor_booking_status';
 if position(needle in definition)=0 then raise exception 'Unexpected vendor status function'; end if;
 definition:=replace(definition,needle,$n$
 if p_status='completed' then
  if b.vendor_completed_at is null then
   update public.bookings set vendor_completed_at=clock_timestamp() where id=b.id;
  end if;
  return;
 end if;
 update public.bookings set status=p_status,status_reason=nullif(trim(p_reason),'') where id=b.id;
 $n$);
 execute definition;
end $$;
create or replace function public.customer_acknowledge_completion(p_booking_id uuid) returns void
language plpgsql security definer set search_path='' as $$
declare b public.bookings%rowtype;
begin
 perform eventra_security.require_actor('customer');
 select * into b from public.bookings where id=p_booking_id and customer_id=auth.uid() for update;
 if not found then raise exception 'Booking not found' using errcode='42501'; end if;
 if b.status='completed' and b.customer_completed_at is not null then return; end if;
 if b.status<>'accepted' or b.vendor_completed_at is null then raise exception 'The vendor has not requested completion confirmation'; end if;
 update public.bookings set status='completed',customer_completed_at=clock_timestamp() where id=b.id;
end $$;
revoke all on function public.customer_acknowledge_completion(uuid) from public,anon;
grant execute on function public.customer_acknowledge_completion(uuid) to authenticated;
create or replace function public.get_service_reviews_filtered(p_service_id uuid,p_rating integer,p_before_created timestamptz default null,p_before_id uuid default null,p_limit integer default 10) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if p_rating is null or p_rating not between 1 and 5 then raise exception 'Choose a star rating'; end if;
 if not exists(select 1 from eventra_feed.eligible_services where id=p_service_id) then return '[]'::jsonb; end if;
 return coalesce((select jsonb_agg(data order by created_at desc,id desc) from (
  select r.id,r.created_at,jsonb_build_object('id',r.id,'service_id',r.service_id,'vendor_id',r.vendor_id,'business_id',r.business_id,'service_name',s.name,'customer_name',c.name,'rating',r.rating,'review_text',r.review_text,'photo_paths',r.photo_paths,'created_at',r.created_at,'updated_at',r.updated_at,'version',r.version,'moderation_status',r.moderation_status,'is_mine',coalesce(r.customer_id=auth.uid(),false),'can_reply',false,'reported',false) data
  from public.service_reviews r join public.customers c on c.id=r.customer_id join public.services s on s.id=r.service_id
  where r.service_id=p_service_id and r.rating=p_rating and r.moderation_status='visible'
   and (p_before_created is null or (r.created_at,r.id)<(p_before_created,p_before_id))
  order by r.created_at desc,r.id desc limit greatest(1,least(coalesce(p_limit,10),50))
 ) page),'[]'::jsonb);
end $$;
revoke all on function public.get_service_reviews_filtered(uuid,integer,timestamptz,uuid,integer) from public;
grant execute on function public.get_service_reviews_filtered(uuid,integer,timestamptz,uuid,integer) to anon,authenticated;
notify pgrst,'reload schema';
commit;
