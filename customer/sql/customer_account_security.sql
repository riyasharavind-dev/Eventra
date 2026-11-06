-- Customer equivalents of the existing owner-scoped vendor account functions.
-- Original vendor functions and existing tables are unchanged.
begin;
do $$
declare name text; definition text; signature text;
begin
 foreach name in array array['get_vendor_account_security','update_vendor_contact_phone','request_vendor_account_deletion','cancel_vendor_account_deletion'] loop
   select pg_get_functiondef(p.oid) into strict definition from pg_proc p where p.pronamespace='public'::regnamespace and p.proname=name;
   definition:=replace(replace(definition,'vendor','customer'),'Vendor','Customer');
   execute definition;
 end loop;
 foreach signature in array array['get_customer_account_security()','update_customer_contact_phone(text)','request_customer_account_deletion(text)','cancel_customer_account_deletion()'] loop
   execute format('revoke all on function public.%s from public,anon',signature);
   execute format('grant execute on function public.%s to authenticated',signature);
 end loop;
end $$;
commit;