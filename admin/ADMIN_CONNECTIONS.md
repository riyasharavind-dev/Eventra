# Eventra admin modules and connections

The admin app connects all 35 application tables and four published views through 39 management modules. Separate Database Connections and Storage Buckets pages expose coverage, record counts, storage limits and the relevant management routes. All data requests continue through guarded admin RPCs; the public client never receives a service-role key.

## Business modules

| Section | Database connections / modules |
| --- | --- |
| Accounts & Access | `users`, `vendors`, `customers`, `admins`, `account_deletion_requests` |
| Businesses & Services | `businesses`, `services`, `business_category_nodes` |
| Catalog & Locations | `category_nodes`, `event_types`, `administrative_regions` |
| Bookings & History | `bookings`, `booking_status_history`, `booking_vendor_notes` |
| Trust & Moderation | `service_reviews`, `service_review_reports`, `vendor_verifications`, `business_verifications`, `verification_documents`, `vendor_identity_verifications` |
| Customer Experience | `home_feed_sections`, `home_feed_pinned_items`, `banners` |
| Content & Settings | `legal_documents`, `about_eventra_content`, `social_links` |
| Support | `support_tickets`, `support_messages`, `support_faqs`, `support_settings` |
| Notifications | `vendor_announcements`, `vendor_notifications`, `fcm_tokens` |
| Platform Operations | `admin_audit_log`, `admin_storage_cleanup` |
| Published Content | `current_legal_documents`, `published_about_eventra_content`, `published_support_faqs`, `active_social_links` |

Existing record screens connect related records through foreign-key labels and module links. Services now include the four pricing modes and their unit; businesses include shop address and administrative location fields. Feed pinned items are separately inspectable, with changes made in the Home Feed editor to retain its validation, revisions and audit behavior.

## Storage modules

| Bucket | Purpose | Connected module | Access |
| --- | --- | --- | --- |
| `profile` | Vendor profile photos | Vendors | Public images; owner/admin writes |
| `profile-images` | Customer profile photos | Customers | Public images; owner/admin writes |
| `business-media` | Business logos/banners | Businesses | Public images; owner/admin writes |
| `service-gallery` | Service photos | Services | Public images; owner/admin writes |
| `banners` | Promotional banners | Banners | Public images; admin uploads |
| `social-icons` | Follow Us icons | Follow Us Links | Public images; admin uploads |
| `vendor-verification-documents` | Vendor proof | Verification Documents | Private |
| `business-documents` | Business proof | Business Verification | Private |
| `support-attachments` | Support screenshots | Support Tickets | Private |

Each bucket shows actual file counts, metadata-reported storage usage, upload limit and allowed MIME types. File browsing supports path search and 30-item pagination. Preview uses five-minute signed URLs, including private documents. Record editors retain existing upload workflows; reviewed account deletion cleanup remains in its dedicated queue. Bucket visibility and access policies are not editable in the file browser.

## System internals

The Database Connections screen also exposes five read-only sources:

- `eventra_admin.modules`: module configuration.
- `eventra_admin.mutation_requests`: request ID, actor, module, creation time only.
- `eventra_feed.save_requests`: request ID and actor only.
- `eventra_feed.service_metrics`: per-service aggregates.
- `eventra_feed.eligible_services`: service/vendor/business identifiers and service names only.

Cached responses, mutation payloads, backend credentials and Auth internals are not exposed. These sources do not offer arbitrary CRUD. Authentication accounts remain managed through guarded account/admin workflows.

## Source connections

| Layer | File / API |
| --- | --- |
| Models | `lib/models/admin_connections_model.dart` |
| Repository | `lib/repositories/admin_connections_repository.dart` |
| Screens | `lib/screens/management/admin_connections_screen.dart` |
| Navigation | `lib/screens/main/admin_main_screen.dart` |
| Existing module CRUD | `AdminRepository` → `admin_catalog`, `admin_records`, `admin_record`, `admin_save`, `admin_action` |
| Coverage / buckets | `admin_connections_inventory()` |
| Storage file pages | `admin_storage_objects(bucket, query, offset, limit)` |
| Internal pages | `admin_system_records(source, offset, limit)` |
| Live migration | `sql/19_admin_connections.sql` (after access security migration 18) |

All three new RPCs require active admin access. Non-admins and anonymous requests are denied. Viewer accounts can inspect; existing mutations independently enforce owner/admin permissions. Public table RLS and Storage access policies are preserved.

Validation: 71 rolled-back database assertions, including all 39 module list/detail endpoints, nine bucket listings, five system sources, pricing fields and role denials. Admin widget tests cover module routing, mobile file browsing, private document preview and pagination alongside the existing admin suite.
