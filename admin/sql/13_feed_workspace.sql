begin;
create or replace function public.admin_home_feed_workspace() returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 perform eventra_admin.require_access(false);
 return jsonb_build_object('sections',(select coalesce(jsonb_agg(to_jsonb(s)||jsonb_build_object('_revision',md5(to_jsonb(s)::text),'pins',(select coalesce(jsonb_agg(jsonb_build_object('id',coalesce(p.service_id,p.vendor_id),'name',coalesce((select name from public.services where id=p.service_id),(select name from public.vendors where id=p.vendor_id),'Unavailable item')) order by p.sort_order,p.id),'[]') from public.home_feed_pinned_items p where p.section_id=s.id)) order by s.sort_order,s.id),'[]') from public.home_feed_sections s),
  'categories',(select coalesce(jsonb_agg(jsonb_build_object('id',c.id,'name',c.name,'parent_id',c.parent_id) order by c.name),'[]') from public.category_nodes c),
  'events',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name) order by name),'[]') from public.event_types where is_active),
  'states',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name) order by name),'[]') from public.administrative_regions where level='state' and is_active));
end $$;
commit;