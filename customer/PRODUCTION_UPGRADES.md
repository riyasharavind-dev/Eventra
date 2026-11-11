# Customer workflow upgrade — 10 November 2026

Implemented in the existing customer UI, with matching vendor approval controls.

- Per-unit and per-duration quantities are selected before checkout. The database calculates totals from current service prices and stores unit, rate and quantity snapshots. Duration bookings include an end date/time, retained when rescheduled.
- Starting-from bookings require a vendor final quote and explicit customer approval before acceptance. Version checks prevent approving an outdated quote.
- Customer cancellation/reschedule requests require vendor approval. Requests can be withdrawn; ownership, booking state and schedule conflicts are checked on the server.
- Booking Details includes owner-only vendor phone access with Call/WhatsApp actions and booking-linked support requests.
- Confirmation returns the booking IDs in a success receipt. Multi-service checkout remains atomic and retry-safe.
- Saved Services and Added Services use private account-owned database collections, a durable local mutation outbox and instant cached reads. Removals synchronize too. Live revisions refresh other signed-in devices without replacing the screen with a loader.
- Customer push messages now cover acceptance, rejection, cancellation, quote changes, completion requests/completion and approved reschedules. Notification taps load only the signed-in customer's booking. A private outbox, bounded retries, stale-event suppression and invalid-token cleanup protect delivery. The deployed handler ignores caller-supplied customer/token data.
- Customer text is registered in the existing admin Languages & Translations workflow: 397 keys with Tamil translations. Published, checksummed packs are cached locally and load offline. English remains the fallback for new/unregistered text.
- Back from a main tab returns Home; Home requires a second back press to exit.
- The five anniversary demo reviews and their five synthetic bookings were retired from active metrics, with recovery copies retained privately in eventra_feed.retired_demo_rows. Other pre-existing demo catalog content was not removed.

## Database and deployment

SQL 57 through 66 in admin/sql were applied to the linked project. The send-booking-status-notification edge function was deployed. Its existing gateway verification setting was preserved; recipients and content come exclusively from an inaccessible private event record. A two-minute retry job is active. Do not rerun already-applied migrations indiscriminately.

## Setup still required

- Customer recovery/resend screens are implemented, but email-code delivery is intentionally disabled until custom SMTP and the email templates are configured. The free default Supabase email provider rejected template customization. No SMTP credentials were supplied. Templates are in supabase/templates. After configuration and a real delivery test, build with CUSTOMER_EMAIL_CODE_READY=true.
- SMS OTP still needs the provider previously deferred by the owner.
- Public service-share links still need CUSTOMER_PUBLIC_URL and a deployed customer destination.
- Native push delivery, phone/WhatsApp launching and password recovery must be checked on a signed-in physical device before release. Automated checks do not prove delivery to a real handset/mailbox.
- Vendor and customer apps should be updated together for quote and request approval controls.

No Git commit, push, store upload or customer app deployment was performed in this task.

## Verification

- Full customer regression suite: 76 passing tests.
- Final affected checkout/settings/offline subset: 11 passing tests.
- Customer analyzer and changed vendor approval sources: no issues.
- Database rollback checks passed for quantities, invalid input, atomic/idempotent checkout, quote ownership/version approval, reschedule duration preservation, private collections, protected push claims, owner-only support, two-sided completion and review eligibility.
- Deployed handler smoke test ignored an unknown event ID without sending notifications.
