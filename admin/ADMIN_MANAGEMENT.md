# Eventra admin management

Sign in with a Supabase Auth account listed as active in public.admins. Passwords are managed by Supabase Auth and are never stored in the admins table or application source.

The panel discovers 34 allowlisted modules: users, vendors, customers, businesses, categories, services, bookings/history, verification and private proof documents, reviews/reports, support/conversations, banners, FAQs, legal versions, About Eventra, social links, account deletion requests, device registrations, published views, admin accounts, activity log and storage cleanup.

Owner: manages admin access and reviewed account deletion requests. Admin: content and operational workflows. Viewer: read-only access. All management RPCs independently enforce permissions. Audit logs record changes; revision checks reject stale writes.

Legal documents are edited as drafts and published as versions. Published text stays immutable. Account deletion requires owner access, an in-review request, matching typed email and no active bookings; storage cleanup is queued and retryable. Customer review stars/text cannot be changed by admin moderation.

Database migrations are in sql/01_admin_core.sql, sql/02_admin_workflows.sql and sql/03_admin_catalog.sql (apply in order). They have already been applied to the linked Eventra project. Existing application-table RLS settings were preserved; admin authority/audit tables are protected. These admin controls do not replace a full production RLS rollout for vendor/customer tables.

Validation: full Dart analysis; release web build; four tests covering invalid numeric input, booking transitions, owner deletion actions and mobile read-only layout; transaction rollback checks covering every module, content saves, stale updates, denied access and synthetic account deletion. No real customer account was deleted during validation.

Run: flutter pub get; flutter run -d chrome.

Payments and subscriptions have no existing backing tables and are not presented as working financial modules. Deployment was not performed.
## Customer Me screen management

Use the Customer App sidebar shortcut to manage customer About Eventra, Privacy Policy, Terms & Conditions, Help FAQs, support contacts, customer social links and shared social links. The support inbox and conversations remain shared operational queues for customer and vendor accounts. A ticket's requester card identifies the account type; customer/vendor profiles link to their own support tickets.

Module lists now offer App audience, language, document type, sender role, publication/active state and category filters where those fields exist. Both apps is the actual `all` audience value, distinct from the Any filter. Create forms inherit audience/document filters. Published views link back to their editable source modules.

Customer data uses the existing admin catalog, permission-checked save/action RPCs, revision checks and audit history. No additional live schema or permission migration was needed for this admin UI update. Keep the sender_role choice list in 03_admin_catalog.sql aligned with customer, vendor and support messages.

Customer support email and WhatsApp contacts are currently unconfigured. Set them under Customer App > Contact Support settings. WhatsApp numbers are validated with a country code and saved as digits for wa.me links. Legal preview content can be replaced using Create new draft version, edit and Publish draft; published versions remain immutable.

Validation for this update: complete admin Dart analysis, eight passing admin tests, and seven live database integration checks run inside a rolled-back transaction. Checks cover catalog access, About/FAQ/contact/social saves, legal draft publication and customer ticket/admin reply/customer reply visibility. Test content and messages were not committed.