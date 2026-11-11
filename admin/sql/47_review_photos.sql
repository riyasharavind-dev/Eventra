begin;
alter table public.service_reviews add column if not exists photo_paths text[] not null default '{}';
alter table public.service_reviews add constraint service_review_photo_limit check(cardinality(photo_paths)<=5);
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('review-photos','review-photos',false,5242880,array['image/jpeg','image/png','image/webp']) on conflict(id) do nothing;
create policy review_photo_upload on storage.objects for insert to authenticated with check(bucket_id='review-photos' and (storage.foldername(name))[1]=auth.uid()::text and exists(select 1 from public.bookings b where b.id::text=(storage.foldername(name))[2] and b.customer_id=auth.uid() and b.status='completed'));
create or replace function public.can_read_review_photo(p_path text) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.service_reviews r where p_path=any(r.photo_paths) and (r.moderation_status='visible' or r.customer_id=auth.uid()));
$$;
revoke all on function public.can_read_review_photo(text) from public;
grant execute on function public.can_read_review_photo(text) to anon,authenticated;
create policy review_photo_read on storage.objects for select to anon,authenticated using(bucket_id='review-photos' and public.can_read_review_photo(name));
create or replace function public.can_delete_review_photo(p_path text) returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and split_part(p_path,'/',1)=auth.uid()::text and not exists(select 1 from public.service_reviews r where p_path=any(r.photo_paths));
$$;
revoke all on function public.can_delete_review_photo(text) from public;
grant execute on function public.can_delete_review_photo(text) to authenticated;
create policy review_photo_cleanup on storage.objects for delete to authenticated using(bucket_id='review-photos' and public.can_delete_review_photo(name));
create or replace function public.submit_service_review_with_photos(p_booking_id uuid,p_rating integer,p_text text,p_expected_version integer,p_photo_paths text[]) returns jsonb
language plpgsql security definer set search_path='' as $$
declare path text; result jsonb;
begin
 perform eventra_security.require_actor('customer');
 if p_photo_paths is null or cardinality(p_photo_paths)>5 or (select count(distinct x) from unnest(p_photo_paths) x)<>cardinality(p_photo_paths) then raise exception 'Choose up to 5 photos'; end if;
 foreach path in array p_photo_paths loop
  if path is null or split_part(path,'/',1)<>auth.uid()::text or split_part(path,'/',2)<>p_booking_id::text or not exists(select 1 from storage.objects where bucket_id='review-photos' and name=path) then raise exception 'Invalid review photo'; end if;
 end loop;
 result:=public.submit_service_review(p_booking_id,p_rating,p_text,p_expected_version);
 update public.service_reviews set photo_paths=p_photo_paths where id=(result->>'id')::uuid;
 return result||jsonb_build_object('photo_paths',p_photo_paths);
end $$;
revoke all on function public.submit_service_review_with_photos(uuid,integer,text,integer,text[]) from public,anon;
grant execute on function public.submit_service_review_with_photos(uuid,integer,text,integer,text[]) to authenticated;
do $$ declare definition text; begin
 select pg_get_functiondef(oid) into definition from pg_proc where pronamespace='public'::regnamespace and proname='get_service_reviews';
 if position('photo_paths' in definition)=0 then
  definition:=replace(definition,$old$'rating',r.rating,$old$,$new$'rating',r.rating,'photo_paths',r.photo_paths,$new$);
  if position('photo_paths' in definition)=0 then raise exception 'Unexpected review reader'; end if;
  execute definition;
 end if;
end $$;
notify pgrst,'reload schema';
commit;
