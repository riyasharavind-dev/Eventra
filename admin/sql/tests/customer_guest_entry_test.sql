begin;
do $$ declare uid uuid:=gen_random_uuid(); blocked boolean;begin
 insert into auth.users(id,email,raw_user_meta_data) values(uid,uid::text||'@example.invalid',jsonb_build_object('role','customer','name','Guest signup test','phone','+919999999999'));
 if not exists(select 1 from public.customers where id=uid and phone='+919999999999') then raise exception 'Signup contact phone was not stored';end if;
 if exists(select 1 from public.vendors where id=uid) or exists(select 1 from auth.users where id=uid and (phone is not null or phone_confirmed_at is not null)) then raise exception 'Contact phone changed account type or phone verification';end if;
 execute 'set local role anon';
 perform public.home_feed_page(0,3,null,null);
 perform public.customer_recommendations(null,0,12);
 blocked:=false;begin perform public.customer_book_services('[]'::jsonb,current_date+1,10,'10:00','Guest test venue','guest-blocked-booking-01');exception when insufficient_privilege then blocked:=true;end;
 if not blocked then raise exception 'Guest booking was allowed';end if;
 execute 'reset role';
end $$;
select 'PASS: public feed/recommendations browse without login; booking remains protected; signup contact persists without phone verification or vendor account creation; rolled back' result;
rollback;
