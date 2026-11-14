begin;

create table public.event_type_categories (
  event_type_id uuid not null references public.event_types(id) on delete restrict,
  category_node_id uuid not null references public.category_nodes(id) on delete restrict,
  sort_order integer not null check (sort_order >= 0),
  primary key (event_type_id, category_node_id)
);
create index event_type_categories_category_idx
  on public.event_type_categories(category_node_id);
alter table public.event_type_categories enable row level security;
revoke all on public.event_type_categories from public, anon, authenticated;

create function eventra_admin.guard_linked_category_parent() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if old.parent_id is null and new.parent_id is not null and exists (
    select 1 from public.event_type_categories where category_node_id=old.id
  ) then
    raise exception 'Remove this category from its linked events before changing its parent.';
  end if;
  return new;
end $$;
revoke all on function eventra_admin.guard_linked_category_parent() from public,anon,authenticated;
create trigger guard_linked_category_parent before update of parent_id on public.category_nodes
for each row execute function eventra_admin.guard_linked_category_parent();

create function public.admin_event_categories(
  p_event_id uuid,
  p_category_ids uuid[] default null,
  p_revision text default null
) returns jsonb
language plpgsql security definer set search_path='' as $$
declare
  category_id uuid;
  before_links jsonb;
  saved_links jsonb;
begin
  perform eventra_admin.require_module('event_types',p_category_ids is not null);
  perform eventra_admin.require_module('category_nodes',false);

  if p_category_ids is not null then
    perform 1 from public.event_types where id=p_event_id for update;
  else
    perform 1 from public.event_types where id=p_event_id;
  end if;
  if not found then raise exception 'Event type not found.'; end if;

  select coalesce(jsonb_agg(category_node_id order by sort_order,category_node_id),'[]')
  into before_links from public.event_type_categories where event_type_id=p_event_id;

  if p_category_ids is not null then
    if md5(before_links::text) is distinct from p_revision then
      raise exception 'Linked categories changed. Reload before saving.' using errcode='40001';
    end if;
    if cardinality(p_category_ids)>200 or cardinality(p_category_ids)<>(
      select count(distinct id) from unnest(p_category_ids) as ids(id)
    ) then
      raise exception 'Select up to 200 distinct parent categories.';
    end if;

    for category_id in select id from unnest(p_category_ids) as ids(id) order by id loop
      perform 1 from public.category_nodes where id=category_id and parent_id is null for share;
      if not found then raise exception 'Only existing parent categories can be linked.'; end if;
    end loop;

    saved_links:=to_jsonb(p_category_ids);
    if saved_links<>before_links then
      delete from public.event_type_categories where event_type_id=p_event_id;
      insert into public.event_type_categories(event_type_id,category_node_id,sort_order)
      select p_event_id,id,(ordinality-1)::integer
      from unnest(p_category_ids) with ordinality as ids(id,ordinality);
      insert into public.admin_audit_log(actor_id,module,record_id,action,before_data,after_data)
      values(auth.uid(),'event_types',p_event_id::text,'update_linked_categories',
        jsonb_build_object('category_ids',before_links),jsonb_build_object('category_ids',saved_links));
      perform eventra_security.touch_app_revision('public','event_types');
      perform eventra_security.touch_app_revision('admin','event_types');
    end if;
  else
    saved_links:=before_links;
  end if;

  return jsonb_build_object(
    'revision',md5(saved_links::text),
    'linked_ids',saved_links,
    'categories',coalesce((
      select jsonb_agg(jsonb_build_object('id',id,'name',name) order by lower(name),id)
      from public.category_nodes where parent_id is null
    ),'[]'::jsonb)
  );
end $$;
revoke all on function public.admin_event_categories(uuid,uuid[],text) from public,anon;
grant execute on function public.admin_event_categories(uuid,uuid[],text) to authenticated;

create or replace function public.customer_search_filtered(p_query text,p_kind text default 'all',p_sort text default 'relevance',p_offset integer default 0,p_limit integer default 20)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare q text:=lower(trim(regexp_replace(coalesce(p_query,''),'\s+',' ','g'))); result jsonb;
begin
 if p_sort is null or p_sort not in ('relevance','price_low','price_high','rating','newest') then raise exception 'Invalid search sort' using errcode='22023';end if;
 if p_kind not in ('all','services','vendors') or p_kind is null or p_offset is null or p_limit is null or p_offset<0 or p_offset>10000 or p_limit<1 or p_limit>30 then raise exception 'Invalid search options'; end if;
 if length(q)<2 then return jsonb_build_object('items','[]'::jsonb,'has_more',false); end if;
 if length(q)>80 then raise exception 'Search must be 80 characters or fewer'; end if;
 with recursive category_path(id,node_id,parent_id,names,visited) as (
   select id,id,parent_id,name,array[id] from public.category_nodes
   union all
   select p.id,c.id,c.parent_id,p.names||' '||c.name,p.visited||c.id from category_path p join public.category_nodes c on c.id=p.parent_id where not c.id=any(p.visited)
 ), category_names as (
   select distinct on(id) id,names from category_path order by id,cardinality(visited) desc
 ), matched_events as (
   select e.id,e.name,term.value,
     trim(substr(q,length(term.value)+1)) remainder
   from public.event_types e
   cross join lateral (
     select value from (values (lower(trim(e.name))),(lower(replace(e.slug,'-',' ')))) terms(value)
     where value<>'' and (q=value or starts_with(q,value||' '))
     order by length(value) desc,value limit 1
   ) term
   where e.is_active
 ), selected_events as (
   select * from matched_events where length(value)=(select max(length(value)) from matched_events)
 ), base as (
   select e.*,s.pricing_type,s.pricing_unit,lower(concat_ws(' ',e.name,left(e.description,2000),e.vendor_name,e.business_name,c.names,et.name)) search_text
   from eventra_feed.eligible_services e join public.services s on s.id=e.id
   left join category_names c on c.id=e.category_node_id
   left join public.event_types et on et.id=e.event_type_id and et.is_active
 ), scored as (
   select b.*,case when exists(select 1 from selected_events) then case
     when b.event_type_id in (select id from selected_events) then 0
     else mapping.sort_order::bigint + 1
   end else 0 end event_rank
   from base b
   left join lateral (
     select min(l.sort_order) sort_order
     from selected_events event
     join public.event_type_categories l on l.event_type_id=event.id
     join category_path p on p.node_id=l.category_node_id and p.id=b.category_node_id
     where p.parent_id is null and b.event_type_id is null
   ) mapping on true
   where case when exists(select 1 from selected_events) then exists (
     select 1 from selected_events event
     where (b.event_type_id=event.id or (b.event_type_id is null and exists (
       select 1 from public.event_type_categories l
       join category_path p on p.node_id=l.category_node_id and p.id=b.category_node_id
       where l.event_type_id=event.id and p.parent_id is null
     )))
     and (event.remainder='' or not exists (
       select 1 from unnest(regexp_split_to_array(event.remainder,'\s+')) word
       where position(word in b.search_text)=0
     ))
   ) else not exists (
     select 1 from unnest(regexp_split_to_array(q,'\s+')) word
     where position(word in b.search_text)=0
   ) end
 ), matched as (
   select * from scored
 ), vendor_totals as (
   select s.vendor_id,coalesce(sum(m.completed_count),0) completed_count,coalesce(sum(m.review_count),0) review_count,coalesce(sum(m.rating_sum),0) rating_sum from public.services s left join eventra_feed.service_metrics m on m.service_id=s.id where s.vendor_id in (select vendor_id from matched) group by s.vendor_id
 ), candidates as (
   select m.id,'services'::text kind,m.name,
     case when lower(m.name)=q then 0 when starts_with(lower(m.name),q) then 1 when position(q in lower(m.name))>0 then 2 else 3 end rank, m.event_rank,
     jsonb_build_object('id',m.id,'type','services','name',m.name,'description',m.description,'image_url',m.gallery->>0,'price',m.price,
       'pricing_type',m.pricing_type,'pricing_unit',m.pricing_unit,'review_count',m.review_count,'rating',case when m.review_count>0 then round(m.rating_sum::numeric/m.review_count,1) end,
       'category_name',m.category_name,'vendor_name',m.vendor_name,
       'service',jsonb_build_object('id',m.id,'vendor_id',m.vendor_id,'business_id',m.business_id,'category_node_id',m.category_node_id,'event_type_id',m.event_type_id,'name',m.name,'slug',m.slug,'description',m.description,'price',m.price,'pricing_type',m.pricing_type,'pricing_unit',m.pricing_unit,'gallery',m.gallery,'is_active',true,'created_at',m.created_at,
         'category_nodes',jsonb_build_object('id',m.category_node_id,'name',m.category_name,'slug',m.category_slug,'parent_id',m.category_parent_id))) payload
   from matched m where p_kind in ('all','services')
   union all
   select m.vendor_id,'vendors',m.vendor_name,
     case when lower(m.vendor_name)=q then 0 when starts_with(lower(m.vendor_name),q) then 1 when position(q in lower(m.vendor_name))>0 then 2 else 4 end,min(m.event_rank),
     jsonb_build_object('id',m.vendor_id,'type','vendors','name',m.vendor_name,'description',m.about_me,'image_url',m.profile_image_url,'verified',m.verified,'created_at',max(m.created_at),'price',min(m.price),'completed_count',t.completed_count,'review_count',t.review_count,'rating',case when t.review_count>0 then round(t.rating_sum::numeric/t.review_count,1) end)
   from matched m join vendor_totals t on t.vendor_id=m.vendor_id where p_kind in ('all','vendors')
   group by m.vendor_id,m.vendor_name,m.about_me,m.profile_image_url,m.verified,t.completed_count,t.review_count,t.rating_sum
 ), page as (
   select * from candidates order by case when p_sort='relevance' then event_rank end,case when p_sort='relevance' then rank end,case when p_sort='price_low' then (payload->>'price')::numeric end asc nulls last,case when p_sort='price_high' then (payload->>'price')::numeric end desc nulls last,case when p_sort='rating' then (payload->>'rating')::numeric end desc nulls last,case when p_sort='newest' then coalesce(payload#>>'{service,created_at}',payload->>'created_at')::timestamptz end desc nulls last,rank,lower(name),kind,id offset p_offset limit p_limit+1
 ), numbered as (select *,row_number() over(order by case when p_sort='relevance' then event_rank end,case when p_sort='relevance' then rank end,case when p_sort='price_low' then (payload->>'price')::numeric end asc nulls last,case when p_sort='price_high' then (payload->>'price')::numeric end desc nulls last,case when p_sort='rating' then (payload->>'rating')::numeric end desc nulls last,case when p_sort='newest' then coalesce(payload#>>'{service,created_at}',payload->>'created_at')::timestamptz end desc nulls last,rank,lower(name),kind,id) n from page)
 select jsonb_build_object('items',coalesce(jsonb_agg(payload order by n) filter(where n<=p_limit),'[]'::jsonb),'has_more',count(*)>p_limit,'event_names',
   coalesce((select jsonb_agg(distinct name order by name) from selected_events),'[]'::jsonb)) into result from numbered;
 return result;
end $$;
revoke all on function public.customer_search_filtered(text,text,text,integer,integer) from public;
grant execute on function public.customer_search_filtered(text,text,text,integer,integer) to anon,authenticated;

create or replace function public.customer_search(
  p_query text,p_kind text default 'all',p_offset integer default 0,p_limit integer default 20
) returns jsonb language sql stable set search_path='' as $$
  select public.customer_search_filtered(p_query,p_kind,'relevance',p_offset,p_limit);
$$;

commit;
