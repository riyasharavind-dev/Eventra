import 'core/theme/app_icon_colors.dart';
import 'services/customer_localization.dart';
import 'services/customer_notification_router.dart';
import 'screens/extended/shared_service_screen.dart';
import 'services/app_live_data.dart';
import 'repositories/auth_repository.dart';
import 'widgets/account_role_gate.dart';

import 'package:flutter_localizations/flutter_localizations.dart';

import 'repositories/app_settings_repository.dart';
import 'services/app_settings_controller.dart';

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'firebase_options.dart';
import 'screens/onboarding/customer_language_entry_screen.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'screens/main/customer_main_screen.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ======================================================
  // SUPABASE INITIALIZATION
  // ======================================================

  await Supabase.initialize(
    url: SupabaseConfig.url,

    // ignore: deprecated_member_use
    anonKey: SupabaseConfig.anonKey,
  );

  // ======================================================
  // FIREBASE INITIALIZATION
  // ======================================================

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ======================================================
  // RUN APP
  // ======================================================

  final initialSettings = await AppSettingsRepository().load();
  final localization = await CustomerLocalization.loadLocal(
    initialSettings.languageCode,
  );
  runApp(
    EventorCustomerApp(
      languageChosen:
          (await SharedPreferences.getInstance()).getBool(
            CustomerLanguageEntryScreen.preferenceKey,
          ) ??
          false,
      settings: AppSettingsController(
        initial: initialSettings,
        localization: localization,
      ),
    ),
  );
}

// ========================================================
// EVENTOR CUSTOMER APP
// ========================================================

class EventorCustomerApp extends StatelessWidget {
  const EventorCustomerApp({
    super.key,
    required this.settings,
    this.languageChosen = true,
  });
  final bool languageChosen;
  final AppSettingsController settings;
  @override
  Widget build(BuildContext context) => AppSettingsScope(
    controller: settings,
    child: AnimatedBuilder(
      animation: Listenable.merge([
        settings,
        if (settings.localization != null) settings.localization!,
      ]),
      builder: (context, _) => MaterialApp(
        navigatorKey: CustomerNotificationRouter.navigatorKey,
        scaffoldMessengerKey: CustomerNotificationRouter.messengerKey,
        debugShowCheckedModeBanner: false,
        builder: (context, child) => AppLiveDataHost(
          client: Supabase.instance.client,
          child: settings.localization == null
              ? child ?? const SizedBox.shrink()
              : CustomerLocalizationSync(
                  localization: settings.localization!,
                  child: child ?? const SizedBox.shrink(),
                ),
        ),
        title: 'Eventor Customer',
        locale:
            settings.localization?.frameworkLocale ??
            Locale(settings.value.languageCode),
        supportedLocales:
            settings.localization?.frameworkLocales ??
            const [Locale('en'), Locale('ta')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: ThemeData(
          useMaterial3: true,
          iconTheme: const IconThemeData(color: AppIconColors.standard),
          iconButtonTheme: IconButtonThemeData(
            style: IconButton.styleFrom(
              foregroundColor: AppIconColors.standard,
            ),
          ),
          listTileTheme: const ListTileThemeData(
            iconColor: AppIconColors.standard,
          ),
          popupMenuTheme: const PopupMenuThemeData(
            iconColor: AppIconColors.standard,
          ),
          expansionTileTheme: const ExpansionTileThemeData(
            iconColor: AppIconColors.standard,
            collapsedIconColor: AppIconColors.standard,
          ),
          inputDecorationTheme: InputDecorationTheme(
            prefixIconColor: AppIconColors.standard,
            suffixIconColor: AppIconColors.standard,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFF0EDF0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFF0EDF0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF80152C), width: 1.5),
            ),
          ),
          scaffoldBackgroundColor: const Color(0xFFF8F8FA),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF80152C),
            primary: const Color(0xFF80152C),
            secondary: const Color(0xFFFFCB48),
            surface: Colors.white,
            brightness: Brightness.light,
          ),
          appBarTheme: const AppBarTheme(
            iconTheme: IconThemeData(color: AppIconColors.standard),
            actionsIconTheme: IconThemeData(color: AppIconColors.standard),
            backgroundColor: Color(0xFFF8F8FA),
            foregroundColor: Color(0xFF17171B),
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: true,
            titleTextStyle: TextStyle(
              color: Color(0xFF17171B),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          cardTheme: CardThemeData(
            color: Colors.white,
            elevation: 0,
            shadowColor: const Color(0xFF80152C).withValues(alpha: 0.06),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0xFFF0EDF0)),
            ),
          ),
          dialogTheme: DialogThemeData(
            backgroundColor: Colors.white,
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          bottomSheetTheme: const BottomSheetThemeData(
            backgroundColor: Colors.white,
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF80152C),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF80152C),
              side: const BorderSide(color: Color(0xFF80152C)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
        onGenerateRoute: (settings) {
          final path =
              Uri.tryParse(settings.name ?? '')?.pathSegments ?? <String>[];
          if (path.length == 2 &&
              path.first == 'service' &&
              RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(path[1])) {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => SharedServiceScreen(serviceId: path[1]),
            );
          }
          return null;
        },
        home: CustomerEntryScreen(languageChosen: languageChosen),
      ),
    ),
  );
}
// ========================================================
// CUSTOMER ENTRY SCREEN
// ========================================================
//
// Language-first entry, followed by public browsing.
//
// Signed in     → Browse with account-role validation.
// Guest         → Browse; personal actions request sign-in.
//
// IMPORTANT:
// Do NOT navigate manually from here after logout.
// Supabase auth state controls the screen.
// ========================================================

class CustomerEntryScreen extends StatefulWidget {
  const CustomerEntryScreen({super.key, this.languageChosen = true});
  final bool languageChosen;

  @override
  State<CustomerEntryScreen> createState() => _CustomerEntryScreenState();
}

class _CustomerEntryScreenState extends State<CustomerEntryScreen> {
  // ======================================================
  // AUTH SUBSCRIPTION
  // ======================================================

  StreamSubscription<AuthState>? _authSubscription;

  // ======================================================
  // NOTIFICATION STATE
  // ======================================================

  bool _notificationInitialized = false;
  late bool _languageChosen = widget.languageChosen;

  // ======================================================
  // INIT
  // ======================================================

  @override
  void initState() {
    super.initState();

    _listenToAuthChanges();

    if (_languageChosen) _initializeNotificationsIfLoggedIn();
  }

  // ======================================================
  // AUTH STATE LISTENER
  // ======================================================

  void _listenToAuthChanges() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (AuthState authState) async {
        final Session? session = authState.session;

        // ==================================================
        // USER LOGGED IN
        // ==================================================

        if (session != null) {
          if (_languageChosen) unawaited(_initializeNotifications());

          if (!mounted) {
            return;
          }

          setState(() {});
        }
        // ==================================================
        // USER LOGGED OUT
        // ==================================================
        else {
          // Notification service can initialize again
          // after the next login.
          _notificationInitialized = false;
          unawaited(NotificationService.instance.removeToken());

          if (!mounted) {
            return;
          }

          // ------------------------------------------------
          // IMPORTANT
          //
          // We DON'T navigate here.
          //
          // build() checks currentSession and automatically
          // returns the guest browsing experience.
          // ------------------------------------------------

          setState(() {});
        }
      },
      onError: (Object error) {
        debugPrint('EVENTOR AUTH STATE ERROR: $error');
      },
    );
  }

  // ======================================================
  // INITIALIZE NOTIFICATIONS IF ALREADY LOGGED IN
  // ======================================================

  Future<void> _initializeNotificationsIfLoggedIn() async {
    final Session? session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      return;
    }

    await _initializeNotifications();
  }

  // ======================================================
  // INITIALIZE NOTIFICATIONS
  // ======================================================

  Future<void> _initializeNotifications() async {
    if (_notificationInitialized) {
      return;
    }

    final Session? session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      return;
    }

    try {
      await AuthRepository().validateAccountRole();
      _notificationInitialized = await NotificationService.instance
          .initialize();

      debugPrint('EVENTOR: Notification service initialized.');
    } catch (e) {
      debugPrint('EVENTOR: Notification initialization failed: $e');
    }
  }

  // ======================================================
  // DISPOSE
  // ======================================================

  @override
  void dispose() {
    _authSubscription?.cancel();

    super.dispose();
  }

  // ======================================================
  // BUILD
  // ======================================================

  @override
  Widget build(BuildContext context) {
    if (!_languageChosen) {
      return CustomerLanguageEntryScreen(
        onComplete: () {
          setState(() => _languageChosen = true);
          unawaited(_initializeNotificationsIfLoggedIn());
        },
      );
    }
    return AccountRoleGate(
      allowGuest: true,
      accountId: Supabase.instance.client.auth.currentUser?.id,
      child: CustomerMainScreen(
        accountId: Supabase.instance.client.auth.currentUser?.id,
      ),
    );
  }
}
