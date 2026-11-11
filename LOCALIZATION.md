# Vendor language workflow

English is the bundled safety fallback. Tamil is the initial database-managed language (885 entries); no Tamil translation dictionary is shipped in vendor/lib. Business names, reviews, customer messages and other user content are not automatically translated.

## Admin workflow

Open **Localization → Languages & Translations**. Owner/admin accounts retain authenticator verification. Staff need that module's read/write permissions; publishing separately requires **Language Publishing** write permission.

1. Add a language using its code (for example hi or fr), English name, native name and text direction. New languages start disabled and unpublished.
2. Search the word catalog by key, English text or translation. Filter by app section or missing translations. Edit drafts, or export JSON, translate its messages and import it back. Keep every named placeholder such as {count} unchanged.
3. Validate. Invalid placeholders block publication. Missing translations require explicit approval to use English fallback.
4. Publish an immutable numbered release, then enable the language in Language settings. Publication and draft editing use revision checks to prevent overwriting another editor's work.
5. Version history can restore a previous release into the draft. Validate and publish again to roll back; existing release snapshots remain unchanged.

New languages do not require an app release when translating existing catalog keys. Disabling a language stops new downloads/listing; installed devices retain their working offline selection.

## Vendor behavior

First launch asks for a language before onboarding/sign-in. A saved explicit choice skips this prompt on later launches. Settings → Language displays published options and native names. First selection downloads and validates a complete pack before saving the preference. Later selections and app startup use the local copy without waiting for the network. Background refresh runs on startup/resume and publication hints; successful checks are throttled to 15 minutes. A failed download/checksum or invalid placeholder keeps the working pack. A fresh install needs connectivity once to download Tamil; English always works offline.

Snapshots are SHA-256 checked and limited to 2 MB. The cache retains at most five packs while protecting the selected language. Unknown keys fall back safely. Plural entries support zero/one/two/few/many/other; framework locale and RTL direction are applied separately.

## Developer additions

Use stable keys and named placeholders; never derive keys from mutable database content. Register new UI source words in admin/data/vendor_translation_catalog.json, keeping existing keys stable. Run `python admin/tools/build_translation_catalog.py`, format the generated Dart fallback, apply the generated catalog SQL after schema 29, and publish updated language releases. The seed is idempotent: it preserves administrator edits and existing published snapshots. Admin language additions require no source changes.

Schema: admin/sql/29_language_workflow.sql. Initial catalog: admin/sql/30_vendor_translation_catalog.sql. Tables have RLS and no direct client access; public RPCs expose enabled published packs only. Drafts, exports and publication remain permission-checked. Database regression tests run inside a rollback transaction.

## Deployment

The schema and initial English/Tamil releases are applied to the linked Supabase project. Vendor clients need the updated application. The deployed admin site needs a new build/deploy of this source before the language workspace appears. This work does not automatically deploy Render or push GitHub.

Archive controls are registered by admin/sql/32_archive_translation_labels.sql. It extends the current English/Tamil published snapshots with only the new keys, preserving unrelated draft work.

The shared photo editor labels are added by admin/sql/33_crop_editor_translation_labels.sql. Profile/logo crops remain 1:1, banners 16:9, and service photos support original, square, landscape and portrait. Crop output is JPEG (quality 88, bounded dimensions), with no upload until the caller accepts the result.
