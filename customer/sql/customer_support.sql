-- Customer support uses the existing shared tickets, messages and storage.
begin;
do $$
declare c record;
begin
  for c in select conname from pg_constraint where conrelid='public.support_messages'::regclass and contype='c' and pg_get_constraintdef(oid) like '%sender_role%' loop
    execute format('alter table public.support_messages drop constraint %I',c.conname);
  end loop;
  alter table public.support_messages add constraint support_messages_sender_role_check check(sender_role in ('vendor','customer','support'));
end $$;
create or replace function public.reply_customer_support_ticket(p_ticket_id uuid,p_body text)
returns public.support_messages language plpgsql security definer set search_path='' as $$
declare ticket public.support_tickets; message public.support_messages;
begin
  if auth.uid() is null then raise exception 'Please log in again.'; end if;
  if length(trim(coalesce(p_body,''))) not between 1 and 4000 then raise exception 'Enter a reply between 1 and 4000 characters.'; end if;
  select * into ticket from public.support_tickets where id=p_ticket_id and user_id=auth.uid() for update;
  if ticket.id is null then raise exception 'Support request not found.'; end if;
  if ticket.status='closed' then raise exception 'This request is closed. Create a new request for further help.'; end if;
  insert into public.support_messages(ticket_id,author_id,sender_role,body)
  values(p_ticket_id,auth.uid(),'customer',trim(p_body)) returning * into message;
  update public.support_tickets set status='open' where id=p_ticket_id;
  return message;
end $$;
revoke all on function public.reply_customer_support_ticket(uuid,text) from public,anon;
grant execute on function public.reply_customer_support_ticket(uuid,text) to authenticated;
insert into public.support_settings(audience) values('customer') on conflict(audience) do nothing;
insert into public.support_faqs(slug,audience,category,question,answer,sort_order,is_published)
select v.slug,'customer',v.category,v.question,v.answer,v.sort_order,true
from (values
('customer-send-booking','Bookings','How do I send a booking request?','Open a service, tap Book Service, choose your event date, enter the guest count and requirements, then tap Confirm Booking.',1),
('customer-booking-status','Bookings','Where can I see my booking status?','Open Bookings in the customer app to view your requests and their latest status.',2),
('customer-update-profile','Account & Login','How do I update my profile?','Open Me and use Edit Profile to update your name and phone number. Tap your profile photo to choose a new image.',3),
('customer-contact-support','Other','How can I contact support?','Open Me, then Contact Support. Choose a category, enter a subject and describe the issue. You can attach a screenshot. Submit the request and track replies under Help & Support, My support requests.',4)
) v(slug,category,question,answer,sort_order)
where not exists(select 1 from public.support_faqs f where f.slug=v.slug and f.audience='customer');
update eventra_admin.modules set choices=jsonb_set(choices,'{sender_role}','["vendor","customer","support"]'::jsonb) where name='support_messages';
commit;