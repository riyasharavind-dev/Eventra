# Guest entry and reference authentication UI

First installation opens language selection. Choosing a card changes only the pending selection; Next saves the language and the installation-level completion flag, then opens browsing. Subsequent launches open browsing directly.

Home, Explore, search, service/business pages and public reviews remain available without an account. No Supabase anonymous account is created. Book Now, Add Service, saved items, booking history and personal notifications show the reusable Login Required dialog. Login/Create Account continues the same pending action after successful authentication; Maybe Later, close and Back leave browsing available. Guest Me exposes language and legal information plus explicit sign-in options. Logout removes private visited-tab state and returns to browsing.

Login, signup and the dialog use the reference wine/pink palette, rounded fields/buttons, illustrated icon area and bottom waves. The customer app retains its current Eventor name. UI components are separated into widgets/auth, screens/auth and screens/onboarding.

Signup collects name, email, contact phone and password. A local Indian number is normalized to +91; explicit international numbers retain their prefix. SQL 67 stores the contact number on the customer profile without marking it as a verified login phone or creating a vendor record. SQL 68 registers the new UI text in the existing admin-managed English/Tamil release workflow.

## Configuration boundaries

Email/password authentication uses the existing repository and customer-role checks. Google/Apple buttons, social-login separators, callbacks and provider flags were removed at the owner’s request. Signup contact numbers remain separate from phone OTP authentication.

The previously deferred SMTP/email-code recovery setup remains pending. No OAuth app registrations, provider credentials, email settings or broad RLS changes were made.

## Verification

- Customer regression suite: 83 tests passed.
- Final guest/auth subset: 8 tests passed, including dismissal, resuming the pending action, signup routing, staged language selection, phone normalization, reference rendering and enlarged text on a small screen.
- Customer analyzer: clean.
- Database rollback test: anonymous feed/recommendation browsing succeeded, anonymous booking remained denied, signup phone persisted without phone verification or vendor account creation.

Run a hot restart to load the new startup flow. UI previews were rendered locally; no signed-in physical-device OAuth or SMS verification was performed. No Git push or app deployment was performed.

## Password reset resend

The login screen has no standalone resend-verification action. Forgot Password requests the first recovery email; only then is Resend Email offered, with a 60-second cooldown and missing/expired-email guidance. Resend requests a password-recovery email, not signup verification. Only a valid recovery code unlocks the new-password form. SMTP/email-code setup remains deferred as previously requested.
