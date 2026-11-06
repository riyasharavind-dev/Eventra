begin;
do $migration$
declare definition text;
begin
 select pg_get_functiondef('public.handle_new_user()'::regprocedure) into definition;
 definition := replace(definition, 'declare requested_role text;', 'declare requested_role text; signup_phone text;');
 definition := replace(definition, 'requested_role:=new.raw_user_meta_data', E'signup_phone := nullif(trim(new.raw_user_meta_data->>''phone''), '''');\n if signup_phone is not null and signup_phone !~ ''^[+][1-9][0-9]{6,14}$'' then raise exception ''Enter a valid phone number with country code''; end if;\n requested_role:=new.raw_user_meta_data');
 definition := replace(definition, 'insert into public.vendors(id,name,email) values(new.id,coalesce(new.raw_user_meta_data->>''name'',''''),new.email)', 'insert into public.vendors(id,name,email,phone) values(new.id,coalesce(new.raw_user_meta_data->>''name'',''''),new.email,signup_phone)');
 execute definition;
end $migration$;
commit;
