import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main/vendor_main_screen.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ==========================================================
  // SUPABASE INITIALIZATION
  // ==========================================================

  await Supabase.initialize(
    url: SupabaseConfig.url,

    // ignore: deprecated_member_use
    anonKey: SupabaseConfig.anonKey,
  );

  // ==========================================================
  // FIREBASE INITIALIZATION
  // ==========================================================

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ==========================================================
  // START APPLICATION
  // ==========================================================

  runApp(
    const EventraVendorApp(),
  );
}

// ============================================================
// EVENTRA VENDOR APP
// ============================================================

class EventraVendorApp extends StatelessWidget {
  const EventraVendorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Eventra Vendor',

      theme: ThemeData(
        useMaterial3: true,
      ),

      home: const VendorEntryScreen(),
    );
  }
}

// ============================================================
// VENDOR ENTRY SCREEN
// ============================================================

class VendorEntryScreen extends StatefulWidget {
  const VendorEntryScreen({super.key});

  @override
  State<VendorEntryScreen> createState() =>
      _VendorEntryScreenState();
}

class _VendorEntryScreenState
    extends State<VendorEntryScreen> {
  bool _notificationInitialized = false;

  @override
  void initState() {
    super.initState();

    _initializeNotifications();
  }

  // ==========================================================
  // INITIALIZE NOTIFICATIONS FOR LOGGED-IN VENDOR
  // ==========================================================

  Future<void> _initializeNotifications() async {
    if (_notificationInitialized) {
      return;
    }

    final session =
        Supabase.instance.client.auth.currentSession;

    // Vendor is not logged in.
    if (session == null) {
      return;
    }

    try {
      await NotificationService.instance.initialize();

      _notificationInitialized = true;
    } catch (e) {
      debugPrint(
        'Vendor notification initialization failed: $e',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final supabase =
        Supabase.instance.client;

    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session =
            supabase.auth.currentSession;

        // ======================================================
        // VENDOR LOGGED IN
        // ======================================================

        if (session != null) {
          // Make sure notification initialization
          // also happens after a fresh login.
          if (!_notificationInitialized) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) {
                _initializeNotifications();
              },
            );
          }

          return const VendorMainScreen();
        }

        // ======================================================
        // VENDOR NOT LOGGED IN
        // ======================================================

        return const LoginScreen();
      },
    );
  }
}