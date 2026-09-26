import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
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

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ======================================================
  // RUN APP
  // ======================================================

  runApp(
    const EventraCustomerApp(),
  );
}

// ========================================================
// EVENTRA CUSTOMER APP
// ========================================================

class EventraCustomerApp extends StatelessWidget {
  const EventraCustomerApp({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Eventra Customer',

      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.red,
      ),

      home: const CustomerEntryScreen(),
    );
  }
}

// ========================================================
// CUSTOMER ENTRY SCREEN
// ========================================================
//
// This screen is the AUTH GATE.
//
// Logged in     → CustomerMainScreen
// Logged out   → LoginScreen
//
// IMPORTANT:
// Do NOT navigate manually from here after logout.
// Supabase auth state controls the screen.
// ========================================================

class CustomerEntryScreen extends StatefulWidget {
  const CustomerEntryScreen({
    super.key,
  });

  @override
  State<CustomerEntryScreen> createState() =>
      _CustomerEntryScreenState();
}

class _CustomerEntryScreenState
    extends State<CustomerEntryScreen> {
  // ======================================================
  // AUTH SUBSCRIPTION
  // ======================================================

  StreamSubscription<AuthState>? _authSubscription;

  // ======================================================
  // NOTIFICATION STATE
  // ======================================================

  bool _notificationInitialized = false;

  // ======================================================
  // INIT
  // ======================================================

  @override
  void initState() {
    super.initState();

    _listenToAuthChanges();

    _initializeNotificationsIfLoggedIn();
  }

  // ======================================================
  // AUTH STATE LISTENER
  // ======================================================

  void _listenToAuthChanges() {
    _authSubscription = Supabase
        .instance
        .client
        .auth
        .onAuthStateChange
        .listen(
      (AuthState authState) async {
        final Session? session = authState.session;

        // ==================================================
        // USER LOGGED IN
        // ==================================================

        if (session != null) {
          await _initializeNotifications();

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

          if (!mounted) {
            return;
          }

          // ------------------------------------------------
          // IMPORTANT
          //
          // We DON'T navigate here.
          //
          // build() checks currentSession and automatically
          // returns LoginScreen.
          // ------------------------------------------------

          setState(() {});
        }
      },
      onError: (Object error) {
        debugPrint(
          'EVENTRA AUTH STATE ERROR: $error',
        );
      },
    );
  }

  // ======================================================
  // INITIALIZE NOTIFICATIONS IF ALREADY LOGGED IN
  // ======================================================

  Future<void> _initializeNotificationsIfLoggedIn() async {
    final Session? session = Supabase
        .instance
        .client
        .auth
        .currentSession;

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

    final Session? session = Supabase
        .instance
        .client
        .auth
        .currentSession;

    if (session == null) {
      return;
    }

    try {
      await NotificationService
          .instance
          .initialize();

      _notificationInitialized = true;

      debugPrint(
        'EVENTRA: Notification service initialized.',
      );
    } catch (e) {
      debugPrint(
        'EVENTRA: Notification initialization failed: $e',
      );
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
    final Session? session = Supabase
        .instance
        .client
        .auth
        .currentSession;

    // ====================================================
    // USER LOGGED IN
    // ====================================================

    if (session != null) {
      return const CustomerMainScreen();
    }

    // ====================================================
    // USER LOGGED OUT
    // ====================================================
    //
    // Always go to LOGIN.
    //
    // No Signup redirect here.
    // ====================================================

    return const LoginScreen();
  }
}