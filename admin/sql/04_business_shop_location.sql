begin;
create table if not exists public.service_cities (
 id uuid primary key default gen_random_uuid(), name text not null check(length(trim(name))>0),
 state text not null, country_code text not null default 'IN',
 latitude double precision, longitude double precision,
 is_active boolean not null default true, sort_order integer not null default 0,
 created_at timestamptz not null default now(),
 unique(name,state,country_code),
 check((latitude is null and longitude is null) or (latitude between -90 and 90 and longitude between -180 and 180))
);
-- City centroids only help frame the map. They are never saved as the shop pin.
insert into public.service_cities(name,state,latitude,longitude) values
 ('Chennai','Tamil Nadu',13.083,80.271),('Coimbatore','Tamil Nadu',11.017,76.956),
 ('Madurai','Tamil Nadu',9.925,78.120),('Tiruchirappalli','Tamil Nadu',10.790,78.705),
 ('Salem','Tamil Nadu',11.664,78.146),('Tirunelveli','Tamil Nadu',8.714,77.756),
 ('Tiruppur','Tamil Nadu',11.108,77.341),('Erode','Tamil Nadu',11.342,77.728),
 ('Vellore','Tamil Nadu',12.916,79.133),('Thoothukudi','Tamil Nadu',8.765,78.134),
 ('Dindigul','Tamil Nadu',10.367,77.980),('Thanjavur','Tamil Nadu',10.787,79.137),
 ('Nagercoil','Tamil Nadu',8.183,77.411),('Kanchipuram','Tamil Nadu',12.834,79.703),
 ('Chengalpattu','Tamil Nadu',12.691,79.977),('Tiruvallur','Tamil Nadu',13.144,79.909),
 ('Cuddalore','Tamil Nadu',11.749,79.772),('Villupuram','Tamil Nadu',11.940,79.487),
 ('Kallakurichi','Tamil Nadu',11.739,78.960),('Tiruvannamalai','Tamil Nadu',12.226,79.074),
 ('Ranipet','Tamil Nadu',12.923,79.333),('Tirupathur','Tamil Nadu',12.496,78.568),
 ('Krishnagiri','Tamil Nadu',12.518,78.214),('Dharmapuri','Tamil Nadu',12.121,78.158),
 ('Namakkal','Tamil Nadu',11.219,78.167),('Karur','Tamil Nadu',10.960,78.077),
 ('Perambalur','Tamil Nadu',11.234,78.881),('Ariyalur','Tamil Nadu',11.140,79.079),
 ('Pudukkottai','Tamil Nadu',10.383,78.821),('Sivaganga','Tamil Nadu',9.844,78.481),
 ('Ramanathapuram','Tamil Nadu',9.371,78.831),('Virudhunagar','Tamil Nadu',9.586,77.958),
 ('Theni','Tamil Nadu',10.011,77.477),('Tenkasi','Tamil Nadu',8.960,77.315),
 ('Nagapattinam','Tamil Nadu',10.766,79.843),('Tiruvarur','Tamil Nadu',10.773,79.636),
 ('Mayiladuthurai','Tamil Nadu',11.103,79.655),('Udhagamandalam','Tamil Nadu',11.407,76.694),
 ('Hosur','Tamil Nadu',12.740,77.825),('Kumbakonam','Tamil Nadu',10.961,79.388),
 ('Puducherry','Puducherry',11.942,79.808),('Bengaluru','Karnataka',12.972,77.595),
 ('Hyderabad','Telangana',17.385,78.487),('Kochi','Kerala',9.931,76.267),
 ('Thiruvananthapuram','Kerala',8.524,76.937),('Mumbai','Maharashtra',19.076,72.878),
 ('Pune','Maharashtra',18.520,73.857),('New Delhi','Delhi',28.614,77.209)
on conflict(name,state,country_code) do nothing;
-- Vendor/customer RLS rollout remains separate. This public directory is read-only.
alter table public.service_cities enable row level security;
revoke all on public.service_cities from anon,authenticated;
grant select on public.service_cities to anon,authenticated;
drop policy if exists service_cities_read on public.service_cities;
create policy service_cities_read on public.service_cities for select to anon,authenticated using(is_active or public.eventra_is_admin());

alter table public.businesses add column if not exists shop_address text;
alter table public.businesses add column if not exists shop_city_id uuid references public.service_cities(id) on delete restrict;
alter table public.businesses add column if not exists service_city_ids uuid[] not null default '{}';
update public.businesses set shop_address=address where shop_address is null and address is not null;
create index if not exists business_shop_city on public.businesses(shop_city_id);
create index if not exists business_service_cities on public.businesses using gin(service_city_ids);
comment on column public.businesses.address is 'Compatibility copy of shop_address for existing clients.';
comment on column public.businesses.service_areas is 'Compatibility city labels. New business form selects service_city_ids.';
comment on column public.businesses.travels_to_customer is 'Legacy field; removed from vendor business UI. Preserved for existing clients.';
comment on column public.businesses.started_year is 'Legacy experience field; removed from vendor business UI.';
comment on column public.businesses.portfolio is 'Legacy portfolio preserved; service listings are the active portfolio.';
comment on column public.businesses.availability_status is 'Internal visibility state; vendor availability controls removed. Existing service visibility rules preserved.';

create or replace function public.eventra_sync_shop_address() returns trigger language plpgsql set search_path='' as $$
begin
 if tg_op='INSERT' then new.shop_address:=coalesce(new.shop_address,new.address);new.address:=new.shop_address;
 elsif new.shop_address is distinct from old.shop_address then new.address:=new.shop_address;
 elsif new.address is distinct from old.address then new.shop_address:=new.address;end if;
 if (new.latitude is null)<>(new.longitude is null) or new.latitude not between -90 and 90 or new.longitude not between -180 and 180 then raise exception 'Select a valid shop location';end if;
 return new;
end $$;
drop trigger if exists eventra_sync_shop_address on public.businesses;
create trigger eventra_sync_shop_address before insert or update on public.businesses for each row execute function public.eventra_sync_shop_address();

create or replace function public.save_vendor_business_location(p_id uuid,p_data jsonb,p_categories uuid[]) returns jsonb
language plpgsql security definer set search_path='' as $$
declare old_b public.businesses; city uuid; cities uuid[]; labels text[]; payload jsonb; result jsonb; lat double precision; lng double precision;
begin
 if auth.uid() is null then raise exception 'Sign in required';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_id::text,0));
 select * into old_b from public.businesses where id=p_id for update;
 if found and old_b.vendor_id<>auth.uid() then raise exception 'Not your business';end if;
 if length(trim(coalesce(p_data->>'shop_address','')))<5 then raise exception 'Enter your shop address';end if;
 city:=(p_data->>'shop_city_id')::uuid;
 if city is null or not exists(select 1 from public.service_cities where id=city and is_active) then raise exception 'Select your shop city';end if;
 lat:=(p_data->>'latitude')::double precision;lng:=(p_data->>'longitude')::double precision;
 if lat is null or lng is null or lat not between -90 and 90 or lng not between -180 and 180 then raise exception 'Mark the exact shop location on the map';end if;
 if jsonb_typeof(p_data->'service_city_ids') is distinct from 'array' then raise exception 'Select service cities';end if;
 select array_agg(distinct x::uuid) into cities from jsonb_array_elements_text(p_data->'service_city_ids') x;
 if coalesce(cardinality(cities),0) not between 1 and 100 then raise exception 'Select between 1 and 100 service cities';end if;
 if exists(select 1 from unnest(cities) x where x is null or not exists(select 1 from public.service_cities where id=x and is_active)) then raise exception 'A selected city is unavailable. Select it again.';end if;
 select array_agg(name||', '||state order by name) into labels from public.service_cities where id=any(cities);
 payload:=p_data||jsonb_build_object('address',trim(p_data->>'shop_address'),'service_areas',to_jsonb(labels),
 'portfolio',coalesce(old_b.portfolio,'[]'::jsonb),'availability_status',coalesce(old_b.availability_status,'active'),
 'started_year',old_b.started_year,'website_url',old_b.website_url,'instagram_url',old_b.instagram_url,
 'travels_to_customer',coalesce(old_b.travels_to_customer,true));
 -- Reuse established ownership, category and linked-service checks atomically.
 perform public.save_vendor_business(p_id,payload,p_categories);
 update public.businesses set shop_city_id=city,service_city_ids=cities,shop_address=trim(p_data->>'shop_address') where id=p_id returning to_jsonb(businesses.*) into result;
 return result;
end $$;
revoke all on function public.save_vendor_business_location(uuid,jsonb,uuid[]) from public,anon;
grant execute on function public.save_vendor_business_location(uuid,jsonb,uuid[]) to authenticated;

insert into eventra_admin.modules(name,label,section,pk,can_create,editable,choices,actions,sort_column)
values('service_cities','Service Cities','Marketplace','id',true,array['name','state','country_code','latitude','longitude','is_active','sort_order'],'{}','{}','sort_order')
on conflict(name) do update set editable=excluded.editable;
update eventra_admin.modules set editable=array['name','description','logo_url','banner_url','phone','email','whatsapp','shop_address','shop_city_id','latitude','longitude'] where name='businesses';
commit;
