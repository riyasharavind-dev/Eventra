begin;
do $$
declare original public.services%rowtype; changed public.services%rowtype;
begin
 select * into original from public.services order by id limit 1 for update;
 if original.id is null then raise exception 'No service available for rollback test'; end if;
 update public.services set price=original.price+1 where id=original.id;
 select * into changed from public.services where id=original.id;
 if changed.previous_price is distinct from original.price or changed.price_changed_at is null then raise exception 'Previous price not tracked'; end if;
 update public.services set name=name where id=original.id;
 if (select previous_price from public.services where id=original.id) is distinct from original.price then raise exception 'Unrelated edit replaced previous price'; end if;
 update public.services set price=original.price+2 where id=original.id;
 if (select previous_price from public.services where id=original.id) is distinct from original.price+1 then raise exception 'Latest previous price not retained'; end if;
end $$;
select 'PASS: price tracking, unrelated edits, successive changes; all rolled back' as result;
rollback;
