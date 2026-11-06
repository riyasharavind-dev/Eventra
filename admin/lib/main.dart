import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main/admin_main_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    // ignore: deprecated_member_use
    anonKey: SupabaseConfig.anonKey,
  );
  runApp(const EventraAdminApp());
}

class EventraAdminApp extends StatelessWidget {
  const EventraAdminApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Eventra Admin',
    themeMode: ThemeMode.light,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF9F0101),
        brightness: Brightness.light,
      ),
    ),
    home: const _AdminSessionGate(),
  );
}

class _AdminSessionGate extends StatelessWidget {
  const _AdminSessionGate();
  @override
  Widget build(BuildContext context) {
    final auth = Supabase.instance.client.auth;
    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (c, s) => auth.currentSession == null
          ? const LoginScreen()
          : const AdminMainScreen(),
    );
  }
}
