begin;
do $$
declare actor uuid; svc record; bid uuid; pending_id uuid; result jsonb; path text; blocked boolean;
begin
 select c.id into actor from public.customers c join public.users u on u.id=c.id join auth.users a on a.id=c.id where u.role='customer' and a.deleted_at is null and (a.banned_until is null or a.banned_until<=now()) limit 1;
 select e.id,e.vendor_id,e.business_id,e.price into svc from eventra_feed.eligible_services e where e.vendor_id<>actor limit 1;
 if actor is null or svc.id is null then raise exception 'Missing test fixtures'; end if;
 insert into public.bookings(customer_id,vendor_id,service_id,business_id,event_date,price,status,location) values(actor,svc.vendor_id,svc.id,svc.business_id,current_date,svc.price,'completed','Rollback review test') returning id into bid;
 insert into public.bookings(customer_id,vendor_id,service_id,business_id,event_date,price,status,location) values(actor,svc.vendor_id,svc.id,svc.business_id,current_date,svc.price,'pending','Rollback review test') returning id into pending_id;
 perform set_config('request.jwt.claim.sub',actor::text,true);
 result:=public.submit_service_review_with_photos(bid,5,'Rollback test',0,'{}');
 if result->>'photo_paths'<>'[]' then raise exception 'Empty photos not supported'; end if;
 blocked:=false; begin perform public.submit_service_review_with_photos(pending_id,5,'Forbidden',0,'{}'); exception when others then blocked:=true; end;
 if not blocked then raise exception 'Pending booking review permitted'; end if;
 blocked:=false; begin perform public.submit_service_review_with_photos(bid,5,'Foreign',1,array['foreign/booking/photo.jpg']); exception when others then blocked:=true; end;
 if not blocked then raise exception 'Foreign attachment accepted'; end if;
 blocked:=false; begin perform public.submit_service_review_with_photos(bid,5,'Too many',1,array_fill('bad'::text,array[6])); exception when others then blocked:=true; end;
 if not blocked then raise exception 'Photo limit missing'; end if;
 path:=actor::text||'/'||bid::text||'/test.jpg';
 update public.service_reviews set photo_paths=array[path] where id=(result->>'id')::uuid;
 if not public.can_read_review_photo(path) or public.can_delete_review_photo(path) then raise exception 'Attached photo read/delete guard failed'; end if;
 update public.service_reviews set moderation_status='hidden' where id=(result->>'id')::uuid;
 perform set_config('request.jwt.claim.sub','',true);
 if public.can_read_review_photo(path) then raise exception 'Hidden photo public read allowed'; end if;
 if (select public from storage.buckets where id='review-photos') then raise exception 'Review bucket must be private'; end if;
end $$;
select 'PASS: completed-booking gate, attachment ownership, photo limit, attached-file deletion protection, private bucket and moderation; rolled back' result;
rollback;
