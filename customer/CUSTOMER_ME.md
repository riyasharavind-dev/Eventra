# Customer Me screen

The Me screen mirrors the vendor menu style with search, profile, My Activity, App Settings, Account & Security, Support, About & Legal, Follow Us and centered wine-red logout.

My Activity contains Saved Services and My Reviews. My Bookings is deliberately absent; bookings remain in the existing bottom navigation tab.

Saved services use per-account local device storage. The service-details heart persists the service snapshot; opening a saved service checks the current active service in Supabase. Saved items do not sync between devices.

Reviews use existing completed-booking review RPCs and their ownership, version and moderation checks. Customers can submit/edit ratings and text and see vendor replies.

Notifications and English/Tamil selection persist on the device. Me and settings labels respond to the selected language, Material controls use the locale, and legal/About content requests the selected language with English fallback. Existing unrelated app screens retain their current translations.

Account security uses Supabase Auth for password/email changes with password confirmation. The customer_account_security.sql migration adds customer-scoped counterparts of existing vendor account functions. Phone updates affect the customer contact number. Delete Account creates an admin-reviewed deletion request and supports cancellation while pending; it does not immediately delete an account.

Validation: full customer Dart analysis, twelve passing tests, four transaction-rollback database checks (account/phone, deletion/cancel/admin visibility, review submission and anonymous-access denial), and Android debug APK build. No real account password, email, phone or deletion state was changed by validation.
Code structure: domain models live in lib/models; profile persistence is in lib/repositories/profile_repository.dart; reusable forms, legal rendering and support tiles live in lib/widgets/profile, reviews, legal and support. Support request history and detail pages each have their own file in lib/screens/extended. AuthRepository delegates its existing profile API to ProfileRepository for compatibility.
