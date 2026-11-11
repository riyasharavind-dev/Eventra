do $$
declare biz record; payload jsonb; entry jsonb; year_value integer; expected integer;
begin
 for biz in select distinct business_id from eventra_feed.eligible_services limit 10 loop
  payload := public.customer_business_services(biz.business_id,0);
  if jsonb_array_length(payload->'items')>20 then raise exception 'Page exceeds limit'; end if;
  for entry in select value from jsonb_array_elements(payload->'items') loop
   if not exists(select 1 from eventra_feed.eligible_services e where e.id::text=entry->>'id' and e.business_id=biz.business_id) then raise exception 'Cross-business or ineligible service'; end if;
  end loop;
  select extract(year from created_at)::integer into expected from public.businesses where id=biz.business_id;
  select (public.customer_service_overview(id)->'business_summary'->>'since_year')::integer into year_value from eventra_feed.eligible_services where business_id=biz.business_id limit 1;
  if year_value is distinct from expected then raise exception 'Incorrect business year'; end if;
 end loop;
end $$;
select 'PASS: business-only eligible services, page limit and Since year' result;
