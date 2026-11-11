# Vendor introduction and live app tour

On first launch the flow is Splash → Language selection → three-slide introduction → sign-in. A valid saved language choice (including an explicit English selection) skips the language picker on subsequent launches; existing selections are preserved. English works offline. Other languages must finish downloading and saving before continuing. Failed downloads keep the picker open, and language can later be changed in Settings. The three-slide introduction still runs once per installation. After validated login, pending/in-progress guide metadata offers a short optional walkthrough. Me > Help & Information > App Guide / Restart Tour restarts it. Intro persistence, private vendor-only progress, setup checklist RPCs and migration 27 are unchanged.

## Live flow

The old simulated App Guide screen has been replaced. screens/trial/vendor_trial_screen.dart is now only an entry point into VendorTourController. No duplicate dashboard, sample business form or fake tab navigation is shown in the guide.

Six checkpoints: actual Dashboard/Listings tab; actual Listings + button; actual Add a business menu item; actual Add Business category field/form explanation; actual Bookings calendar and real date/history viewing; actual Me/Language settings. Users operate the original widgets and navigation callbacks. Mini floating tip cards show progress, Back, Skip and contextual continue/Finish controls. The original floating navbar remains visible. A root overlay supports tips/tooltips above both the Navigator and navbar. TourAnchor wraps controls without changing their appearance or underlying business logic.

The dim mask has a touch-through cutout. Four hit-test barriers block non-target actions; the highlighted control receives the original touch. The tour never auto-fills/saves a business, creates a service, accepts/rejects/completes a booking, uploads files or sends messages. The editable form is explained but its Save button is outside the cutout. Going to Bookings closes the form through normal guarded navigation. Dropdown dialogs retain normal interactions. Calendar taps change only the viewed date. A user explicitly selecting a language changes the actual preference; Finish works without changing it.

## Lifecycle and recovery

Tip geometry follows real controls, auto-scrolls to off-screen targets and adapts to narrow/Tamil/large-text layouts. Position checks run only while the tour is active. Missing/loading targets leave Back/Skip available; editable-form and calendar steps can continue without forced writes. Menu dismissal and hardware Back do not synthesize actions or bypass existing PopScope/in-flight guards. The menu's reverse animation finishes before the original Add Business callback opens its form.

Guide state remains vendor/account scoped, with expected UID validation, local offline caching and reconnect/resume synchronization. A changed account or removal of the authenticated navigation owner stops the overlay. Completed progress is monotonic except explicit replay. Resume from menu/form checkpoints restarts at the real + click path, rather than reopening an editable form automatically. Finishing/skipping does not complete actual profile/business/service checklist items.

The isolated BookingPracticeScreen and SampleBookingCard remain separate learning components; they are not used to impersonate real screens in the live walkthrough.

## Validation

Tests cover original navbar and animated-menu tap callbacks, real Navigator route transitions, calendar touches, blocking the real Save control during guidance, finishing without a language mutation, Skip, account changes, small-screen Tamil tips, introduction persistence, offline progress and existing navigation guards. No additional database migration is required for this tour UI change.
