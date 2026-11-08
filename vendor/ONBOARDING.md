# Vendor introduction and learning guide

## Entry points

After the splash, the three-slide introduction runs once per installation (vendor_introduction_v1 in SharedPreferences). Skip and Get Started persist the same completion flag. The introduction does not sign the user out or create an account. It appears before the normal account entry screen on an installation that has not completed it.

After a validated vendor login, a pending/in-progress version-1 guide prompts once during that main-screen session. Start/Resume is optional; Later or dismissal persists skipped. Existing vendors also get this one-time offer. Me > Help & Information > App Guide / Restart Tour explicitly restarts it. The existing Me search finds the guide too.

The guide is a separate, clearly labelled practice preview, NOT a spotlight over live editable forms. Six interactive steps cover Dashboard, Listings, +, adding a business, booking decisions and Me/settings. Users tap highlighted controls, go Back, Skip, resume a partial guide, or replay. The booking exercise reuses VendorBookingCard with generated local sample data. Its details, confirmation, accept/reject, completion and reset actions never call booking/business/service repositories, upload images, send SMS/push, contact customers or create real records. Only learning progress is stored remotely. The real navbar is temporarily hidden during the guide and its child routes to prevent accidental navigation away from the practice environment.

## Real account setup

The dashboard checklist separately reads get_vendor_setup_checklist. Profile completion means a nonblank vendor name and contact phone; a contact phone is not claimed to be OTP verified. Business/service completion means at least one owned record exists (including an unpublished listing); it is not a claim of publication, approval, payment eligibility or verification. Tapping an unfinished row opens the real form. If no business exists, the service row leads to Add Business first. The checklist refreshes on return and relevant realtime changes, preserves previous data on transient failure, and disappears when all three are complete. Tour completion cannot tick it.

## Database / privacy

Apply admin/sql/27_vendor_onboarding.sql after migrations 18 and 25. public.vendor_guide_progress has RLS, an owned vendor read policy and no direct app write permission. The progress and checklist RPCs require an active vendor plus an explicit p_account_id matching auth.uid(); the client cannot pick another owner or change role. Only guide version 1 and steps 0–6 are accepted. Completed progress cannot be overwritten by a late skip/partial save; only an explicit restart resets it. Guide rows are not directly published; the existing private revision mechanism receives change hints. This learning metadata is not a generic admin CRUD module.

Introduction preference is device-wide; guide progress/cache is keyed by vendor UID and guide version. Offline progress is retained locally and synchronized on guide load, later interactions, or the main screen's existing reconnect/resume realtime catch-up. Old responses cannot overwrite a newer cached step. New sign-ins never inherit another UID's progress. No OTP, provider configuration or billing changes are included.

## Files / validation

Screens live in screens/onboarding and screens/trial. Shared slide, spotlight, instruction, sample-card and checklist widgets live in widgets/onboarding and widgets/trial. Typed guide/setup models and OnboardingRepository live in their usual folders. English/Tamil text follows the current app language; long content scrolls and narrow/large-text layouts wrap.

Regression coverage: first-install completion/skip, six-step tour, sample accept/reject/reset, Back/Skip/Resume/Restart, real checklist independence, 320px Tamil/large-text layout, offline synchronization, account-scoped caches and late-response handling. Database tests in admin/sql/tests/vendor_onboarding_test.sql run entirely inside a rolled-back transaction.
