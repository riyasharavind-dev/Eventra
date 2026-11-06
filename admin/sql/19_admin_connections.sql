begin;
-- Keep application workflows separate from infrastructure browsing.
update eventra_admin.modules set section=case
 when name in ('users','vendors','customers','admins','account_deletion_requests') then 'Accounts & Access'
 when name in ('businesses','services','business_category_nodes') then 'Businesses & Services'
 when name in ('category_nodes','event_types','administrative_regions') then 'Catalog & Locations'
 when name in ('bookings','booking_status_history','booking_vendor_notes') then 'Bookings & History'
 when name in ('service_reviews','service_review_reports','vendor_verifications','business_verifications','verification_documents','vendor_identity_verifications') then 'Trust & Moderation'
 when name in ('home_feed_sections','home_feed_pinned_items','banners') then 'Customer Experience'
 when name in ('legal_documents','about_eventra_content','social_links') then 'Content & Settings'
 when name in ('support_tickets','support_messages','support_faqs','support_settings') then 'Support'
 when name in ('vendor_announcements','vendor_notifications','fcm_tokens') then 'Notifications'
 when name in ('admin_audit_log','admin_storage_cleanup') then 'Platform Operations'
 else 'Published Content' end;
insert into eventra_admin.modules(name,label,section,pk,can_create,sort_column)
values('home_feed_pinned_items','Feed Pinned Items','Customer Experience','id',false,'sort_order')
on conflict(name) do update set label=excluded.label,section=excluded.section,can_create=false,editable='{}',actions='{}';
update eventra_admin.modules set editable=array(select distinct x from unnest(editable||array['pricing_type','pricing_unit']) x),
choices=choices||'{"pricing_type":["fixed","starting_from","per_unit","per_duration"],"pricing_unit":["hour","day","week","month"]}'::jsonb where name='services';
-- Unit names for per-unit pricing remain free text, not a duration-only choice list.
update eventra_admin.modules set choices=choices-'pricing_unit' where name='services';
update eventra_admin.modules set editable=array(select distinct x from unnest(editable||array['shop_address','shop_state_id','shop_district_id','shop_subdistrict_id','latitude','longitude']) x) where name='businesses';

create or replace function public.admin_connections_inventory() returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare sources jsonb:='[]';r record;cnt bigint;
begin
 perform eventra_admin.require_access(false);
 for r in select n.nspname,c.relname,c.relkind,c.relrowsecurity,m.name as module,m.label,m.section,
 c.reloptions from pg_class c join pg_namespace n on n.oid=c.relnamespace
 left join eventra_admin.modules m on n.nspname='public' and m.name=c.relname
 where n.nspname in ('public','eventra_admin','eventra_feed') and c.relkind in ('r','v') order by n.nspname,c.relname loop
  execute format('select count(*) from %I.%I',r.nspname,r.relname) into cnt;
  sources:=sources||jsonb_build_array(jsonb_build_object('schema',r.nspname,'name',r.relname,'kind',case when r.relkind='v' then 'view' else 'table' end,
   'rls',r.relrowsecurity,'rows',cnt,'module',r.module,'label',coalesce(r.label,initcap(replace(r.relname,'_',' '))),
   'section',coalesce(r.section,'System Internals'),'invoker',coalesce(r.reloptions,'{}')@>array['security_invoker=true']));
 end loop;
 return jsonb_build_object('sources',sources,'buckets',(select coalesce(jsonb_agg(jsonb_build_object(
 'id',b.id,'public',b.public,'max_bytes',b.file_size_limit,'mime_types',b.allowed_mime_types,
 'objects',(select count(*) from storage.objects o where o.bucket_id=b.id),
 'bytes',(select coalesce(sum(case when o.metadata->>'size' ~ '^[0-9]+$' then (o.metadata->>'size')::bigint else 0 end),0) from storage.objects o where o.bucket_id=b.id)
 ) order by b.id),'[]'::jsonb) from storage.buckets b),
 'relationships',(select coalesce(jsonb_agg(jsonb_build_object('source',c.relname,'column',a.attname,'target',rc.relname,'target_schema',rn.nspname,'target_column',ra.attname)),'[]')
 from pg_constraint k join pg_class c on c.oid=k.conrelid join pg_namespace n on n.oid=c.relnamespace
 join pg_class rc on rc.oid=k.confrelid join pg_namespace rn on rn.oid=rc.relnamespace
 join pg_attribute a on a.attrelid=k.conrelid and a.attnum=k.conkey[1]
 join pg_attribute ra on ra.attrelid=k.confrelid and ra.attnum=k.confkey[1]
 where k.contype='f' and n.nspname='public'),'checked_at',now());
end $$;

create or replace function public.admin_storage_objects(p_bucket text,p_query text default '',p_offset integer default 0,p_limit integer default 30) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare rows jsonb;total bigint;
begin
 perform eventra_admin.require_access(false);
 if p_offset is null or p_offset<0 or p_limit is null or p_limit not between 1 and 100 or length(coalesce(p_query,''))>200 then raise exception 'Invalid storage page';end if;
 if not exists(select 1 from storage.buckets where id=p_bucket) then raise exception 'Bucket not found';end if;
 select count(*) into total from storage.objects where bucket_id=p_bucket and position(lower(coalesce(p_query,'')) in lower(name))>0;
 select coalesce(jsonb_agg(to_jsonb(x)),'[]') into rows from (
 select id,name,created_at,updated_at,metadata->>'mimetype' as mime_type,
 case when metadata->>'size' ~ '^[0-9]+$' then (metadata->>'size')::bigint else null end as bytes
 from storage.objects where bucket_id=p_bucket and position(lower(coalesce(p_query,'')) in lower(name))>0
 order by created_at desc,id limit p_limit offset p_offset) x;
 return jsonb_build_object('total',total,'rows',rows);
end $$;

create or replace function public.admin_system_records(p_source text,p_offset integer default 0,p_limit integer default 30) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare query text;rows jsonb;total bigint;
begin
 perform eventra_admin.require_access(false);
 if p_offset is null or p_offset<0 or p_limit is null or p_limit not between 1 and 100 then raise exception 'Invalid system page';end if;
 query:=case p_source
 when 'eventra_admin.modules' then 'select name,label,section,can_create,editable,actions from eventra_admin.modules order by section,name'
 when 'eventra_admin.mutation_requests' then 'select request_id,actor_id,module,created_at from eventra_admin.mutation_requests order by created_at desc,request_id'
 when 'eventra_feed.save_requests' then 'select request_id,actor_id from eventra_feed.save_requests order by request_id'
 when 'eventra_feed.service_metrics' then 'select * from eventra_feed.service_metrics order by service_id'
 when 'eventra_feed.eligible_services' then 'select id as service_id,vendor_id,business_id,name as service_name from eventra_feed.eligible_services order by id'
 else null end;
 if query is null then raise exception 'System source is not allowlisted' using errcode='42501';end if;
 execute 'select count(*) from ('||query||') x' into total;
 execute 'select coalesce(jsonb_agg(to_jsonb(x)),''[]''::jsonb) from ('||query||' limit $1 offset $2) x' into rows using p_limit,p_offset;
 return jsonb_build_object('total',total,'rows',rows);
end $$;
revoke all on function public.admin_connections_inventory(),public.admin_storage_objects(text,text,integer,integer),public.admin_system_records(text,integer,integer) from public,anon;
grant execute on function public.admin_connections_inventory(),public.admin_storage_objects(text,text,integer,integer),public.admin_system_records(text,integer,integer) to authenticated;
notify pgrst,'reload schema';
commit;
