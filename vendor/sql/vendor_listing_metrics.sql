begin;
create or replace function public.get_vendor_listing_metrics()
returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_object_agg(s.id::text,jsonb_build_object(
 'bookings',coalesce(b.total,0),'rating',r.average)), '{}'::jsonb)
 from public.services s
 left join (select service_id,count(*) total from public.bookings where vendor_id=auth.uid() group by service_id) b on b.service_id=s.id
 left join (select service_id,round(avg(rating)::numeric,1) average from public.service_reviews where vendor_id=auth.uid() and moderation_status='visible' group by service_id) r on r.service_id=s.id
 where s.vendor_id=auth.uid();
$$;
revoke all on function public.get_vendor_listing_metrics() from public,anon;
grant execute on function public.get_vendor_listing_metrics() to authenticated;
commit;
