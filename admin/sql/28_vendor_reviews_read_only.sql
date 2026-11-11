-- Reviews are readable/reportable by vendors; replies are disabled.
begin;
create or replace function public.reply_service_review(p_review_id uuid,p_reply text,p_expected_version integer)
returns void language plpgsql security definer set search_path='' as $$
begin
 raise exception 'Vendor review replies are disabled' using errcode='42501';
end $$;
revoke all on function public.reply_service_review(uuid,text,integer) from public,anon,authenticated,service_role;
do $$ declare f record; definition text; begin
 for f in select oid from pg_proc where pronamespace='public'::regnamespace and proname='get_service_reviews' loop
  definition:=pg_get_functiondef(f.oid);
  if position('''can_reply'',coalesce(r.vendor_id=auth.uid(),false)' in definition)>0 then
   execute replace(definition,'''can_reply'',coalesce(r.vendor_id=auth.uid(),false)','''can_reply'',false');
  elsif position('''can_reply'',false' in definition)=0 then
   raise exception 'Unexpected review capability definition';
  end if;
 end loop;
end $$;
commit;
