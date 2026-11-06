# Eventra

Event service marketplace with separate Flutter applications for vendors, customers, and administrators, backed by Supabase and Firebase Cloud Messaging.

## Applications

- **vendor/**: dashboard, multiple businesses, service listings and pricing, booking decisions and details, calendar history, reviews, profile, settings, legal content, and support. Includes image cropping and shimmer loading.
- **customer/**: configurable home feeds, Explore category navigation, service and vendor discovery, dedicated search with recent searches, booking, reviews, saved services, profile, settings, and support.
- **admin/**: role-based management, catalog and account workflows, content and support management, social icon uploads, and customer home-feed rules and previews.
- **supabase/**: local configuration and booking notification Edge Functions.

## Development

Install Flutter with the Dart version required by each app's `pubspec.yaml`. Install Node.js when using the root Supabase CLI dependency.

```sh
git clone https://github.com/riyasharavind-dev/Eventra.git
cd Eventra/vendor
flutter pub get
flutter run
```

Use the same commands from `customer/` or `admin/` to run those applications. For the admin web app, use `flutter run -d chrome`.

Each application has its own `lib/models`, repositories, screens, widgets, dependencies, and tests. Supabase client configuration lives in each app's `lib/core/config/supabase_config.dart`; Firebase client configuration is included where used. Public client keys are not administrative credentials. Configure the corresponding backend projects and platform application identifiers for another deployment.

## Database and backend

Versioned SQL changes are stored in `admin/sql/`, with additional app-specific SQL in `vendor/sql/` and `customer/sql/`. These scripts describe updates to the existing Eventra database; they are not a complete, independently bootstrappable schema dump. Review prerequisites before applying scripts to a new database. Existing application-table development RLS settings require a separate production review.

The notification Edge Functions read Supabase service credentials and Firebase service-account values from server environment variables. Configure those secrets in the backend; never add their values to source control. Local Supabase link/cache files, environment secrets, signing keys, dependency directories, and build outputs are excluded.

See `admin/ADMIN_MANAGEMENT.md`, `customer/CUSTOMER_ME.md`, and `vendor/VENDOR_NOTIFICATIONS.md` for module-specific details.

## Validation

Run from each application directory:

```sh
flutter analyze --no-pub
flutter test --no-pub
```

## Android release builds

For smaller architecture-specific vendor APKs:

```sh
cd vendor
flutter build apk --release --split-per-abi --target-platform android-arm,android-arm64
```

The current ARM64 release APK is approximately 36 MB. Installed storage and user data vary by device and usage. APK files are generated locally and are not committed. Configure a production signing key before store distribution; the current vendor release build uses the development signing configuration.

Maps currently differ between applications: vendor shop selection uses OpenStreetMap through `flutter_map`, while the customer app retains Mappls integration. Payments and subscriptions are not complete production integrations.
