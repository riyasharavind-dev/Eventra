begin;
do $$
declare actor uuid; payload jsonb; first_result jsonb; retry_result jsonb; bad jsonb; before_count bigint; after_count bigint; blocked boolean;
begin
 select c.id into actor from public.customers c join public.users u on u.id=c.id join auth.users a on a.id=c.id where u.role='customer' and a.deleted_at is null and (a.banned_until is null or a.banned_until<=now()) limit 1;
 if actor is null then raise exception 'No customer test account'; end if;
 perform set_config('request.jwt.claim.sub',actor::text,true);
 select jsonb_agg(jsonb_build_object('id',q.id,'price',q.price,'pricing_type',q.pricing_type,'pricing_unit',q.pricing_unit)) into payload from (select s.id,s.price,s.pricing_type,s.pricing_unit from eventra_feed.eligible_services e join public.services s on s.id=e.id where e.vendor_id<>actor order by s.id limit 2) q;
 if jsonb_array_length(payload)<>2 then raise exception 'Two eligible services required'; end if;
 first_result:=public.customer_book_services(payload,current_date+10,10,'10:30'::time,'Rollback checkout test','rollback-cart-test-123456');
 retry_result:=public.customer_book_services(payload,current_date+10,10,'10:30'::time,'Rollback checkout test','rollback-cart-test-123456');
 if first_result is distinct from retry_result or jsonb_array_length(first_result->'booking_ids')<>2 then raise exception 'Idempotency failure'; end if;
 if (select count(*) from public.bookings where id in (select value::text::uuid from jsonb_array_elements_text(first_result->'booking_ids')))<>2 then raise exception 'Missing bookings'; end if;
 if exists(select 1 from public.bookings where id in(select value::text::uuid from jsonb_array_elements_text(first_result->'booking_ids')) and (event_start_time is distinct from '10:30'::time or location is distinct from 'Rollback checkout test')) then raise exception 'Event time/address not saved'; end if;
 select count(*) into before_count from public.bookings where customer_id=actor;
 bad:=jsonb_set(payload,'{1,price}',to_jsonb(((payload->1->>'price')::numeric)+1));
 blocked:=false;
 begin perform public.customer_book_services(bad,current_date+10,10,'10:30'::time,'Bad price','rollback-cart-badprice-123456'); exception when others then blocked:=true; end;
 if not blocked then raise exception 'Changed price accepted'; end if;
 select count(*) into after_count from public.bookings where customer_id=actor;
 if before_count<>after_count then raise exception 'Partial bookings persisted'; end if;
 blocked:=false;
 begin perform public.customer_book_services(jsonb_build_array(payload->0,payload->0),current_date+10,10,'10:30'::time,'Duplicate','rollback-cart-duplicate-123456'); exception when others then blocked:=true; end;
 if not blocked then raise exception 'Duplicate services accepted'; end if;
end $$;
select 'PASS: event time and address saved, checkout atomicity and retry safety; rolled back' result;
rollback;
