begin;
insert into public.home_feed_sections(title,content_type,selection_mode,is_active,sort_order)
select 'Featured Vendors','vendors','manual',false,5 where not exists(select 1 from public.home_feed_sections where title='Featured Vendors');
with recursive ancestry(service_id,id,parent_id,name) as (
 select e.id,c.id,c.parent_id,c.name from eventra_feed.eligible_services e join public.category_nodes c on c.id=e.category_node_id
 union select a.service_id,c.id,c.parent_id,c.name from ancestry a join public.category_nodes c on c.id=a.parent_id
), roots as (select distinct id,name from ancestry where parent_id is null)
insert into public.home_feed_sections(title,rules,sort_by,is_active,sort_order)
select left(name,80)||' Services',jsonb_build_object('category_id',id),'bookings',true,40+row_number() over(order by name)::int from roots r
where not exists(select 1 from public.home_feed_sections s where s.rules->>'category_id'=r.id::text);
commit;
