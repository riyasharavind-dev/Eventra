begin;
create table if not exists eventra_feed.save_requests(request_id uuid primary key,actor_id uuid not null,payload jsonb not null,result jsonb not null);
create or replace function public.admin_home_feed_save(p_data jsonb,p_pins uuid[] default '{}',p_id uuid default null,p_revision text default null,p_request_id uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare saved jsonb; sid uuid; kind text; pid uuid; n int:=0; previous_pins jsonb; cached jsonb; request_payload jsonb:=jsonb_build_object('data',p_data,'pins',p_pins);
begin
 perform eventra_admin.require_access(true);
 if p_id is null and p_request_id is not null then
  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text,610));
  select result into cached from eventra_feed.save_requests where request_id=p_request_id and actor_id=auth.uid() and payload=request_payload;
  if found then return cached; end if;
  if exists(select 1 from eventra_feed.save_requests where request_id=p_request_id) then raise exception 'This creation request already completed. Reload Home Feed before editing.'; end if;
 end if;
 if coalesce(array_length(p_pins,1),0)>100 then raise exception 'Maximum 100 pinned items'; end if;
 saved:=public.admin_save('home_feed_sections',p_data,p_id::text,p_revision,p_request_id);
 sid:=(saved->>'id')::uuid;
 select content_type into kind from public.home_feed_sections where id=sid for update;
 select coalesce(jsonb_agg(to_jsonb(p) order by p.sort_order,p.id),'[]') into previous_pins from public.home_feed_pinned_items p where section_id=sid;
 delete from public.home_feed_pinned_items where section_id=sid;
 foreach pid in array p_pins loop
  if kind='services' and not exists(select 1 from public.services where id=pid) or kind='vendors' and not exists(select 1 from public.vendors where id=pid) then raise exception 'Pinned item not found'; end if;
  insert into public.home_feed_pinned_items(section_id,service_id,vendor_id,sort_order) values(sid,case when kind='services' then pid end,case when kind='vendors' then pid end,n) on conflict do nothing;
  n:=n+1;
 end loop;
 insert into public.admin_audit_log(actor_id,module,record_id,action,before_data,after_data) values(auth.uid(),'home_feed_sections',sid::text,'update_pins',previous_pins,jsonb_build_object('pins',p_pins));
 if p_id is null and p_request_id is not null then insert into eventra_feed.save_requests values(p_request_id,auth.uid(),request_payload,saved); end if;
 return saved;
end $$;
commit;