do $$
declare anchor record; payload jsonb; item jsonb; expected record; ids text[];
begin
 for anchor in select id,vendor_id from eventra_feed.eligible_services order by id limit 20 loop
  payload:=public.customer_related_vendors(anchor.id,0,12);
  if jsonb_array_length(payload->'items')>12 then raise exception 'Page limit exceeded'; end if;
  ids:='{}';
  for item in select value from jsonb_array_elements(payload->'items') loop
   if item->>'id'=anchor.vendor_id::text or item->>'id'=any(ids) then raise exception 'Current or duplicate vendor'; end if;
   ids:=array_append(ids,item->>'id');
   if not exists(select 1 from eventra_feed.eligible_services e where e.vendor_id::text=item->>'id') then raise exception 'Ineligible vendor'; end if;
   select coalesce(sum(m.review_count),0) review_count,case when coalesce(sum(m.review_count),0)>0 then round(sum(m.rating_sum)::numeric/sum(m.review_count),1) end rating into expected from public.services s left join eventra_feed.service_metrics m on m.service_id=s.id where s.vendor_id::text=item->>'id';
   if (item->>'review_count')::bigint is distinct from expected.review_count or (item->>'rating')::numeric is distinct from expected.rating then raise exception 'Incorrect vendor aggregate'; end if;
  end loop;
 end loop;
 if jsonb_array_length(public.customer_related_vendors('00000000-0000-0000-0000-000000000000')->'items')<>0 then raise exception 'Invalid anchor returned vendors'; end if;
end $$;
select 'PASS: vendor eligibility, deduplication, current vendor exclusion, aggregate ratings and page bounds' result;
