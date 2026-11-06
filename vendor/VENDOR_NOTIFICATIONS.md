# Vendor notification inbox

The dashboard bell opens `NotificationsScreen`. Models, database operations, row widgets and destination routing are separate files.

- Activity is newest first, grouped by local date. Filters include All, Unread, Bookings, Payments, Reviews, Offers and Updates (account/support).
- Notification read state is stored on the server. The dashboard badge counts unread activity across all businesses.
- Database Realtime updates the open feed and badge. Opening/resuming and a 45-second reconciliation also recover missed changes and scheduled offers. Live refresh retains already-loaded older pages.
- Tapping a booking opens its current booking details; reviews open service reviews; support replies open the ticket conversation; verification updates open the relevant account/business screen. Offers and standalone updates show their full message and optional reference.

## Database

Apply `sql/vendor_notification_inbox.sql` after the existing admin/booking/review/support schema. It adds `vendor_notifications`, `vendor_announcements`, owner-only RLS, read-state RPCs, notification triggers and Realtime publication.

Booking creation/status changes, visible customer reviews, support replies and account/business verification changes automatically create inbox activity. Recent existing bookings and reviews (90 days) are backfilled as read history. Updating vendor replies does not generate a duplicate customer-review notification. No fake activity is seeded.

Clients cannot insert notification events or edit another vendor's feed. A customer account cannot read the vendor inbox. Only trusted server/admin operations can publish messages.

## Offers and other updates

The existing admin catalog automatically exposes **Content > Vendor Offers & Announcements** and **Operations > Vendor Notification History** after reload. There is no new admin application build requirement.

Create an announcement with a title and body. Leave recipient empty for all vendors, or select a vendor for a targeted message. Start with `is_active = false`, review the content, then activate it. `starts_at` and optional `expires_at` control visibility. Deactivating hides the announcement from the vendor inbox. New vendors also receive currently active announcements. Editing an announcement does not reset its read state.

Kinds are `offer`, `account` and `payment`. **Payment messages require a specific recipient. There is currently no payment transaction table/gateway in this project, so payment alerts can be published by an admin but are not automatically generated from transactions.** Connect trusted transaction callbacks to the inbox when the payment system is implemented. A booking price is never treated as money received.

This feature creates the persistent in-app inbox. Existing booking FCM delivery remains in place; it does not add push delivery for every new inbox type.

## Validation

Widget tests cover date groups, readable errors/retry, read-on-open, filters, mark all read, incoming activity and pagination. Rolled-back DB tests cover event generation, announcement deduplication, read persistence, vendor/customer isolation, blocked client event insertion, admin draft/publish and unpublish visibility. Test records are not retained.
