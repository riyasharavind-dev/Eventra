begin;
create extension if not exists postgis with schema extensions;
create table if not exists public.administrative_region_boundaries (
 region_id text primary key references public.administrative_regions(id) on delete cascade,
 geometry jsonb not null check(geometry->>'type' in ('Polygon','MultiPolygon')),
 geom extensions.geometry(Geometry,4326) generated always as
  (extensions.st_makevalid(extensions.st_setsrid(extensions.st_geomfromgeojson(geometry::text),4326))) stored,
 source_url text not null, source_shape_id text not null, source_year int not null,
 imported_at timestamptz not null default now()
);
alter table public.administrative_region_boundaries enable row level security;
revoke all on public.administrative_region_boundaries from public,anon,authenticated;
create index if not exists administrative_boundary_geom on public.administrative_region_boundaries using gist(geom);

create or replace function public.get_shop_region_boundary(p_region_id text) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 perform eventra_security.require_actor('vendor');
 select jsonb_build_object('id',r.id,'name',r.name,'geometry',b.geometry,
   'center',jsonb_build_array(extensions.st_y(extensions.st_pointonsurface(b.geom)),extensions.st_x(extensions.st_pointonsurface(b.geom))),
   'source_url',b.source_url,'source_year',b.source_year)
 into result from public.administrative_regions r join public.administrative_region_boundaries b on b.region_id=r.id
 where r.id=p_region_id and r.level='subdistrict' and r.is_active;
 if result is null then raise exception 'Boundary not available for this sub-district yet. Select the correct area or contact support.' using errcode='22023'; end if;
 return result;
end $$;
revoke all on function public.get_shop_region_boundary(text) from public,anon;
grant execute on function public.get_shop_region_boundary(text) to authenticated;

-- Normalize legacy child links without discarding or moving any service.
create or replace function eventra_security.business_root(p_id uuid) returns uuid
language plpgsql stable set search_path='' as $$
declare current_id uuid:=p_id; parent uuid; visited uuid[]:='{}';
begin
 while current_id is not null loop
  if current_id=any(visited) then raise exception 'Invalid category hierarchy';end if;
  visited:=array_append(visited,current_id);
  select parent_id into parent from public.category_nodes where id=current_id;
  if not found then raise exception 'Category not found';end if;
  if parent is null then return current_id;end if;
  current_id:=parent;
 end loop;
 return null;
end $$;
revoke all on function eventra_security.business_root(uuid) from public,anon,authenticated;
do $$ declare b record; chosen uuid; roots uuid[];
begin
 for b in select * from public.businesses loop
  select array_agg(distinct eventra_security.business_root(category_node_id)) into roots from public.business_category_nodes where business_id=b.id;
  chosen:=coalesce(eventra_security.business_root(b.primary_category_id),roots[1]);
  if chosen is null then
   select eventra_security.business_root(category_node_id) into chosen from public.services where business_id=b.id order by created_at,id limit 1;
  end if;
  if exists(select 1 from public.services where business_id=b.id and eventra_security.business_root(category_node_id) is distinct from chosen) then
   raise exception 'Business % has services across parent categories. Move those services before category migration.',b.id;
  end if;
  if chosen is not null then
   update public.businesses set primary_category_id=chosen where id=b.id;
   delete from public.business_category_nodes where business_id=b.id;
   insert into public.business_category_nodes(business_id,category_node_id) values(b.id,chosen);
  end if;
 end loop;
end $$;
create unique index if not exists business_one_parent_category on public.business_category_nodes(business_id);
create or replace function eventra_security.guard_business_parent() returns trigger language plpgsql security definer set search_path='' as $$
declare category_id uuid;
begin
 category_id:=(to_jsonb(new)->>case when tg_table_name='businesses' then 'primary_category_id' else 'category_node_id' end)::uuid;
 if category_id is not null and not exists(select 1 from public.category_nodes where id=category_id and parent_id is null) then
  raise exception 'Choose one parent category for this business' using errcode='22023';
 end if;
 return new;
end $$;
revoke all on function eventra_security.guard_business_parent() from public,anon,authenticated;
drop trigger if exists business_parent_category on public.businesses;
create trigger business_parent_category before insert or update of primary_category_id on public.businesses for each row execute function eventra_security.guard_business_parent();
drop trigger if exists business_link_parent_category on public.business_category_nodes;
create trigger business_link_parent_category before insert or update of category_node_id on public.business_category_nodes for each row execute function eventra_security.guard_business_parent();

-- Patch the current secured RPCs in place; retain all ownership/service guards.
do $$ declare definition text; marker text:='perform eventra_security.require_actor(''vendor'');';
begin
 definition:=pg_get_functiondef('public.save_vendor_business(uuid,jsonb,uuid[])'::regprocedure);
 if position('Select exactly one parent category' in definition)=0 then
  if position(marker in definition)=0 then raise exception 'Business RPC guard not found';end if;
  definition:=replace(definition,marker,marker||$patch$
 if coalesce(cardinality(p_categories),0)<>1 or p_categories[1] is null or not exists(select 1 from public.category_nodes where id=p_categories[1] and parent_id is null) then
  raise exception 'Select exactly one parent category' using errcode='22023';
 end if;
$patch$);
  execute definition;
 end if;
 definition:=pg_get_functiondef('public.save_vendor_business_location(uuid,jsonb,uuid[])'::regprocedure);
 if position('Shop pin is outside' in definition)=0 then
  marker:='payload:=p_data';
  if position(marker in definition)=0 then raise exception 'Location RPC validation marker not found';end if;
  definition:=replace(definition,marker,$patch$
 -- Legacy pins are preserved during non-location edits. Any new/moved pin
 -- must be verified against the exact stored polygon, including holes/islands.
 if old_b.id is null or old_b.shop_subdistrict_id is distinct from subdistrict
    or old_b.latitude is distinct from lat or old_b.longitude is distinct from lng then
  if not exists(select 1 from public.administrative_region_boundaries where region_id=subdistrict) then
   raise exception 'Sub-district boundary unavailable. Open Shop on map or contact support.' using errcode='22023';
  end if;
  if not exists(select 1 from public.administrative_region_boundaries where region_id=subdistrict
     and extensions.st_covers(geom,extensions.st_setsrid(extensions.st_makepoint(lng,lat),4326))) then
   raise exception 'Shop pin is outside the selected sub-district. Select a point inside the border.' using errcode='22023';
  end if;
 end if;
 payload:=p_data$patch$);
  execute definition;
 end if;
end $$;
commit;
