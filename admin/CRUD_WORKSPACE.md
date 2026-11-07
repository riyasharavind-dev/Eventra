# Eventor admin control centre

The admin landing page is **All Modules**. Modules are grouped into workspaces and searchable by label, table name or description. An operation filter shows Create, Edit, Delete, Workflow or Read-only modules. Cards and list headers show the operations available to the current user. The desktop table and mobile record cards share the same live data, search, filters, pagination and detail editor.

Owners also have shortcuts to **Database & system tables**, **Storage buckets** and **Team & Access**. The existing inventory connects all 35 public tables, four published views, eight private system sources and nine storage buckets. Private system rows are read through sanitized owner-only endpoints; staff access is based on assigned app modules.

## Record operations

- New records and edits use `admin_save`, preserving existing validation, revision checks and audit logging.
- Businesses can now be created for an existing vendor. Selecting a main category creates its business-category link. An existing business cannot be moved to a different vendor; use Manage categories for later category assignments.
- Support tickets can now be created for an existing customer/vendor. The database supplies the case ID and its existing identity-based ticket number. Existing cases cannot be reassigned to a different user. Replies and status transitions continue through the support workflow.
- Thirteen mutable modules expose owner-only deletion: categories, event types, administrative regions, businesses, services, banners, social links, FAQs, support settings, About content, draft legal documents, announcements and home-feed sections.
- Delete requires a reason, the exact record ID and a matching revision. The database locks the target and checks incoming foreign-key relationships, including CASCADE and SET NULL references, before deletion. Linked historical records block deletion. A business's own category mapping and a service's derived feed metrics may be removed with their otherwise unlinked parent.
- Uploaded media is retained after record deletion because a file can be shared by other records. Review usage in Storage Buckets before deleting media.

## Protected lifecycles

CRUD does not mean arbitrary fabrication or deletion of historical records. The UI names the applicable workflow:

| Records | Management route |
|---|---|
| Admin/staff identities | Team & Access invitations, role changes and suspension |
| Vendor/customer identities | Profile edits, owner-only Suspend/Restore with reasons, and reviewed account-deletion requests; admin accounts use Team & Access |
| Bookings | Event-detail edits and Accept/Reject/Complete/Cancel transitions |
| Reviews/reports | Moderation and report resolution; customer ratings are preserved |
| Verification documents | Proof review and verification decisions |
| Support conversations | Replies from the ticket workflow; existing conversation history is retained |
| Business category links | Manage categories on the business record |
| Feed pins | Home Feed editor |
| Published legal versions | New draft/version, Publish and Archive; published history is never deleted |
| Published views | Edit the source content module |
| Audit, status history and notification inbox | Read-only system history |
| Device tokens/storage cleanup | Guarded revocation/cleanup operations |

Permission enforcement happens in database RPCs as well as the UI. The catalog marks fields/create/delete operations according to the caller's effective rights. MFA, owner restrictions, RLS, existing account security and public-app read policies remain enforced.

## Implementation and checks

- `sql/21_admin_crud_workspace.sql`: capability metadata, caller-specific catalog, business/support creation guards and `admin_delete_record`.
- `lib/screens/extended/admin_workspace_screen.dart`: responsive module directory.
- `lib/widgets/admin_module_card.dart`: reusable module cards and capability badges.
- Existing module lists, record details and editors provide the actual operations.
- `sql/tests/crud_workspace_test.sql`: existing access tests plus create/delete/audit/stale-revision/ownership/reference checks. Fixture data rolls back.
- `test/admin_workspace_test.dart`: mobile search/navigation, owner confirmation and non-owner delete restrictions.

Render builds the source from GitHub. The live bundle must contain **Manage Eventor** and **Delete permanently** before the refreshed control centre is considered deployed. Existing data is not deleted by the migration.
