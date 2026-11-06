-- Customer-only preview content. Existing records are preserved on reruns.
begin;
insert into public.about_eventra_content(audience,language_code,title,tagline,introduction,features,is_published)
values ('customer','en','About Eventra','Your event, brought together.',
'PREVIEW CONTENT: This sample introduction is for checking the customer app layout. Eventra helps you explore event services, send booking requests, and keep your event plans together. Replace this introduction with your approved brand content before launch.',
'[{"title":"Discover event services","description":"Explore services for your celebration and view their details before sending a request."},{"title":"Book with your event in mind","description":"Choose an event date, add your guest count, and share your requirements with the vendor."},{"title":"Track your bookings","description":"View booking requests and their latest status from the customer app."}]'::jsonb,true)
on conflict (audience,language_code) do nothing;
insert into public.legal_documents(document_type,audience,language_code,version,title,content_markdown,status,effective_at)
select 'privacy_policy','customer','en',1,'Privacy Policy',
$privacy$# Preview content
**This is dummy content for app preview only. It is not the final Eventra Privacy Policy.**

## Profile information
This section will explain how customer profile details, such as name, email, phone number, and profile photo, are handled.

## Booking information
This section will explain how event dates, guest counts, requirements, and booking status are used to support booking requests.

## Notifications and permissions
This section will describe optional notifications and device permissions used by the customer app.

## Your choices and support
This section will explain available account controls and provide the approved privacy contact details.

## Before launch
Replace this sample text with the approved customer privacy policy.$privacy$,
'published',now()
where not exists (select 1 from public.legal_documents where audience='customer' and language_code='en' and document_type='privacy_policy');
insert into public.legal_documents(document_type,audience,language_code,version,title,content_markdown,status,effective_at)
select 'terms_and_conditions','customer','en',1,'Terms & Conditions',
$terms$# Preview content
**This is dummy content for app preview only. It is not the final Eventra Terms & Conditions.**

## Using Eventra
This section will describe the customer account and the purpose of the event service marketplace.

## Booking requests
This section will explain how a customer sends a booking request and how vendor acceptance or rejection is shown.

## Service details and pricing
This section will explain the approved process for confirming requirements, prices, and service arrangements with a vendor.

## Changes and cancellations
This section will contain the approved booking change, cancellation, and refund terms.

## Before launch
Replace this sample text with the approved customer terms and support details.$terms$,
'published',now()
where not exists (select 1 from public.legal_documents where audience='customer' and language_code='en' and document_type='terms_and_conditions');
commit;