import 'repositories/auth_repository.dart';
import 'services/vendor_navigation_controller.dart';
import 'widgets/vendor_navigation_host.dart';
import 'widgets/account_role_gate.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'firebase_options.dart';
import 'repositories/app_settings_repository.dart';
import 'services/app_settings_controller.dart';
import 'services/notification_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main/vendor_main_screen.dart';
import 'screens/splash/eventor_splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    // ignore: deprecated_member_use
    anonKey: SupabaseConfig.anonKey,
  );
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final initial = await AppSettingsRepository().load();
  runApp(EventorVendorApp(settings: AppSettingsController(initial: initial)));
}

class EventorVendorApp extends StatelessWidget {
  const EventorVendorApp({super.key, required this.settings});
  final AppSettingsController settings;

  @override
  Widget build(BuildContext context) => AppSettingsScope(
    controller: settings,
    child: AnimatedBuilder(
      animation: settings,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Eventor Vendor',
        navigatorKey: VendorNavigationController.instance.navigatorKey,
        navigatorObservers: [VendorNavigationController.instance.observer],
        builder: (context, child) => VendorNavigationHost(
          controller: VendorNavigationController.instance,
          child: child ?? const SizedBox.shrink(),
        ),
        locale: Locale(settings.value.languageCode),
        supportedLocales: const [Locale('en'), Locale('ta')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF9F0101),
            brightness: Brightness.light,
          ),
        ),
        themeMode: ThemeMode.light,
        home: const EventorSplashScreen(nextScreen: VendorEntryScreen()),
      ),
    ),
  );
}

class VendorEntryScreen extends StatefulWidget {
  const VendorEntryScreen({super.key});
  @override
  State<VendorEntryScreen> createState() => _VendorEntryScreenState();
}

class _VendorEntryScreenState extends State<VendorEntryScreen> {
  bool _notificationInitialized = false;
  bool _initializingNotifications = false;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    if (_notificationInitialized ||
        _initializingNotifications ||
        Supabase.instance.client.auth.currentSession == null) {
      return;
    }
    _initializingNotifications = true;
    try {
      // OFF preferences and blocked OS permissions never register a new token.
      await AuthRepository().validateAccountRole();
      final initialized = await NotificationService.instance.initialize();
      if (mounted) _notificationInitialized = initialized;
    } catch (error) {
      debugPrint('Notification initialization failed: $error');
    } finally {
      _initializingNotifications = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Supabase.instance.client.auth;
    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (auth.currentSession != null) {
          if (!_notificationInitialized && !_initializingNotifications) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _initializeNotifications();
            });
          }
          return const AccountRoleGate(child: VendorMainScreen());
        }
        _notificationInitialized = false;
        return const LoginScreen();
      },
    );
  }
}
