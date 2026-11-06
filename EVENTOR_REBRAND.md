# Eventor rename

## Application identities

| Application | Dart package | Android / Apple identifier | Display name |
| --- | --- | --- | --- |
| Vendor | `eventor_vendor` | `com.eventor.vendor` | Eventor Vendor |
| Customer | `eventor_customer` | `com.eventor.customer` | Eventor Customer |
| Admin | `eventor_admin` | `com.eventor.admin` | Eventor Admin |

Source class names, file imports, About screens, calendar/splash filenames, platform titles, web manifests, notification channels, preference/cache keys, desktop metadata, documentation and branding assets use Eventor. New package IDs install as separate applications from the former `com.example.*` packages; sign in again to access the same backend account data.

Four new Firebase apps were registered with explicit user approval for the vendor/customer Android and Apple identifiers. Matching Android JSON, Apple plist and Flutter FirebaseOptions are included. The existing Firebase project, other registrations, public web app registrations and Supabase database remain connected.

## Compatibility identifiers intentionally retained

The Firebase project ID `eventra-push-notification`, its generated domains/bucket, and the existing GitHub remote `riyasharavind-dev/Eventra` are external resource identities. Renaming local strings does not rename those resources. They are retained to keep existing integrations working.

Deployed database identifiers such as `eventra_admin`, `eventra_feed`, `eventra_security`, `about_eventra_content`, `published_about_eventra_content` and SQL functions/policies with the legacy prefix remain unchanged. RLS and admin RPC behavior are preserved. Existing user-entered business names, published legal document versions and server-managed content are not rewritten by a source-code rebrand; review their display copy through the admin content modules.

## Map provider and platform follow-up

With user approval, the customer location picker now uses OpenStreetMap through `flutter_map`, matching the vendor app. Mappls dependency and obsolete package/certificate-bound SDK configuration files were removed. The picker retains GPS permissions, manual address and latitude/longitude/address return values, and adds accurate map-tap/drag selection. The tile endpoint is configurable through `EVENTOR_MAP_TILE_URL`; OpenStreetMap attribution remains visible.

The customer location picker currently has no caller in the application; the prior booking map selection remains removed. This migration does not reintroduce that field or change the booking form.

Apple release signing and APNs capabilities must be configured for the new bundle identifiers in the developer account before distributing an Apple build.

## Brand artwork

Project assets: `vendor/assets/images/eventor_logo.png` and `vendor/assets/splash/eventor_splash.png`. Launcher icons were regenerated from the updated logo. The old frame images embedded EVENTRA; they were replaced with an Eventor splash image and a fade while preserving the 3.8-second handoff duration.

These two raster edits used the built-in `image_gen` tool via the imagegen skill. Prompts:

1. Logo: “Replace only the large word EVENTRA at bottom with EVENTOR, spelled exactly E V E N T O R. Preserve the same playful thick rounded maroon lettering, the three smiling glossy balloons, gold swoosh, off-white background, palette, layout, and dimensions. No other changes.”
2. Splash: “Replace the large gold serif word EVENTRA with EVENTOR, spelled exactly E V E N T O R, at the same location and size. Preserve the EV gold calendar/check monogram, rich maroon background and gradients, gold colors, spacing, portrait dimensions and the small tagline ‘Namma Events. Namma Services.’ exactly.”
