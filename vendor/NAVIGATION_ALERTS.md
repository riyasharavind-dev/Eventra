# Vendor navigation and alert images

- Home avatar remains visible but no longer opens the Me/profile screen.
- Home and Listings share `VendorFilterButton`, including icon, outline, colors and active-filter badge. Existing filter/sort selections and business logic are unchanged.
- One `VendorNavigationHost` renders the existing floating navbar above authenticated full-screen routes. There are no duplicate per-page navbars. Selecting a tab closes detail routes and selects the main tab, while existing unsaved-change/in-flight PopScopes can stop the transition.
- `VendorPageScaffold` reserves the shared nav's space using Scaffold footer geometry, keeping forms, maps, floating actions and snackbars above it while painting the normal page background. Main tab spacing remains unchanged.
- Login/splash and modal dialogs do not show the authenticated navbar. Keyboard display hides it. Removing the authenticated main screen hides the navbar and closes private detail routes. Existing main-tab back-to-dashboard/double-back-to-exit behavior remains.
- A full hot restart is needed after installing this navigation change; hot reload does not rerun the existing main screen's `initState` registration.

## Notification screen

`VendorNotification` reads `image_url`, with a fallback for existing `data.image_url` payloads. Alert tiles use a bounded thumbnail decode size, shimmer loading and a category icon if no usable image exists. Read/unread changes retain the image. No new image-cache dependency or external QR/image service was introduced.

`admin/sql/22_vendor_notification_images.sql` adds optional announcement/inbox image URLs. A trusted trigger snapshots the related service image for booking/review alerts, business logo for business alerts, vendor profile image for verification alerts, or the admin announcement image. Cross-vendor lookups are restricted. Existing alerts are backfilled when an image is available.

Owners can open **Vendor Announcements** in the admin panel, upload an Image URL using its existing uploader, save and activate/schedule the announcement. Refresh admin permissions/catalog if the new field is not yet visible. Announcement image updates/removal synchronize without resetting read state or repeatedly updating unchanged rows. RLS and inbox write restrictions are preserved.

This change adds images to the in-app notification screen. Native Android/iOS push-notification image delivery was not changed.

## Validation

- Vendor tests cover persistent detail navigation, safe action spacing, guarded tab changes, logout cleanup, notification image parsing/read state and existing app regressions.
- The notification-image SQL test combines the existing access fixtures with image derivation, isolation, read-state preservation and idempotent synchronization checks. All fixture writes roll back.
- Vendor static analysis and release web compilation pass. No physical-device UI run or new Android APK build is included in this change.
