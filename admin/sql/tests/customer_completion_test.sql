begin;
do $$
declare customer uuid:=gen_random_uuid(); outsider uuid:=gen_random_uuid(); svc record; bid uuid; before_count bigint; after_count bigint; blocked boolean; requested timestamptz; review jsonb;
begin
 insert into auth.users(id,email,raw_user_meta_data) values(customer,customer::text||'@example.invalid','{"role":"customer","name":"Completion test"}'),(outsider,outsider::text||'@example.invalid','{"role":"customer","name":"Other completion test"}');
 select id,vendor_id,business_id,price into svc from eventra_feed.eligible_services limit 1;
 select coalesce(completed_count,0) into before_count from eventra_feed.service_metrics where service_id=svc.id;
 before_count:=coalesce(before_count,0);
 insert into public.bookings(customer_id,vendor_id,service_id,business_id,event_date,event_start_time,price,status,location) values(customer,svc.vendor_id,svc.id,svc.business_id,current_date-1,'10:00',svc.price,'accepted','Rollback completion test') returning id into bid;
 blocked:=false;begin update public.bookings set status='completed' where id=bid;exception when others then blocked:=true;end;
 if not blocked then raise exception 'Completion bypass allowed'; end if;
 perform set_config('request.jwt.claim.sub',svc.vendor_id::text,true);
 execute 'set local role authenticated';
 perform public.change_vendor_booking_status(bid,'accepted','completed');
 select vendor_completed_at into requested from public.bookings where id=bid;
 if requested is null or (select status from public.bookings where id=bid)<>'accepted' then raise exception 'Vendor request prematurely completed booking'; end if;
 perform public.change_vendor_booking_status(bid,'accepted','completed');
 if (select vendor_completed_at from public.bookings where id=bid) is distinct from requested then raise exception 'Request is not idempotent'; end if;
 execute 'reset role';
 select coalesce(completed_count,0) into after_count from eventra_feed.service_metrics where service_id=svc.id;
 if after_count<>before_count then raise exception 'Completion metrics changed before acknowledgement'; end if;
 perform set_config('request.jwt.claim.sub',outsider::text,true);
 execute 'set local role authenticated';
 blocked:=false;begin perform public.customer_acknowledge_completion(bid);exception when others then blocked:=true;end;
 if not blocked then raise exception 'Another customer confirmed booking'; end if;
 perform set_config('request.jwt.claim.sub',customer::text,true);
 blocked:=false;begin perform public.submit_service_review(bid,5,'Premature',0);exception when others then blocked:=true;end;
 if not blocked then raise exception 'Review allowed before acknowledgement'; end if;
 perform public.customer_acknowledge_completion(bid);
 perform public.customer_acknowledge_completion(bid);
 if not(select status='completed' and vendor_completed_at is not null and customer_completed_at is not null from public.bookings where id=bid) then raise exception 'Both-sided completion missing'; end if;
 review:=public.submit_service_review(bid,5,'Completed by both sides',0);
 if review->>'rating'<>'5' then raise exception 'Review did not unlock'; end if;
 execute 'reset role';
 select coalesce(completed_count,0) into after_count from eventra_feed.service_metrics where service_id=svc.id;
 if after_count<>before_count+1 then raise exception 'Completed count not exactly once'; end if;
end $$;
do $$ declare s record; rating integer; payload jsonb; item jsonb; first_item jsonb; second_page jsonb;
begin
 for s in select id from eventra_feed.eligible_services limit 20 loop
  for rating in 1..5 loop
   payload:=public.get_service_reviews_filtered(s.id,rating,null,null,10);
   for item in select value from jsonb_array_elements(payload) loop
    if (item->>'rating')::integer<>rating or item->>'moderation_status'<>'visible' then raise exception 'Star filtering/moderation failed'; end if;
   end loop;
   first_item:=payload->0;
   if first_item is not null then
    second_page:=public.get_service_reviews_filtered(s.id,rating,(first_item->>'created_at')::timestamptz,(first_item->>'id')::uuid,1);
    if second_page->0->>'id'=first_item->>'id' then raise exception 'Repeated review on next page'; end if;
   end if;
  end loop;
 end loop;
end $$;
select 'PASS: both-side completion, owner-only acknowledgement, no premature counts/reviews, idempotency and star-filtered pagination; rolled back' result;
rollback;
