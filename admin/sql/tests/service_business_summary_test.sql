do $$
declare e record; actual jsonb; expected record; service_bookings bigint; checked integer := 0;
begin
 for e in select id,business_id from eventra_feed.eligible_services limit 20 loop
  actual := public.customer_service_overview(e.id);
  select count(*) service_count,coalesce(sum(m.completed_count),0) completed_count,coalesce(sum(m.review_count),0) review_count,
  case when coalesce(sum(m.review_count),0)>0 then round(sum(m.rating_sum)::numeric/sum(m.review_count),1) end rating
  into expected from public.services s left join eventra_feed.service_metrics m on m.service_id=s.id where s.business_id=e.business_id;
  select count(*) into service_bookings from public.bookings where service_id=e.id;
  if (actual->'business_summary'->>'service_count')::bigint is distinct from expected.service_count
    or (actual->'business_summary'->>'completed_count')::bigint is distinct from expected.completed_count
    or (actual->'business_summary'->>'review_count')::bigint is distinct from expected.review_count
    or (actual->'business_summary'->>'rating')::numeric is distinct from expected.rating
    or (actual->>'booking_count')::bigint is distinct from service_bookings then raise exception 'Service/business aggregation mismatch'; end if;
  checked := checked + 1;
 end loop;
 if checked=0 then raise exception 'No eligible services for validation'; end if;
end $$;
select 'PASS: business aggregates and service booking counts match independently' result;
