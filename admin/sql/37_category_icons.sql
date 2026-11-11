alter table public.category_nodes add column if not exists icon_url text;
grant select (icon_url) on public.category_nodes to anon, authenticated;
comment on column public.category_nodes.icon_url is 'Public image URL for category icons uploaded through the admin catalog editor.';
notify pgrst, 'reload schema';
