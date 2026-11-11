-- Enable category icon writes through the existing audited admin module.
update eventra_admin.modules
set editable = array_append(editable, 'icon_url')
where name = 'category_nodes' and not ('icon_url' = any(editable));
