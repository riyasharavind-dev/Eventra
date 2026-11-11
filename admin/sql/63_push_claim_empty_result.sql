begin;
do $$ declare definition text;begin
 select pg_get_functiondef(oid) into definition from pg_proc where pronamespace='public'::regnamespace and proname='claim_booking_push';
 definition:=replace(definition,'return to_jsonb(row);','if row.id is null then return null; end if; return to_jsonb(row);');
 execute definition;
end $$;
commit;
