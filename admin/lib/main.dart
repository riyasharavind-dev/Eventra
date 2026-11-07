import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'screens/extended/admin_session_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final callbackUri = kIsWeb ? Uri.base : null;
  await Supabase.initialize(
    url: SupabaseConfig.url,
    // ignore: deprecated_member_use
    anonKey: SupabaseConfig.anonKey,
    authOptions: FlutterAuthClientOptions(detectSessionInUri: !kIsWeb),
  );
  runApp(EventorAdminApp(callbackUri: callbackUri));
}

class EventorAdminApp extends StatelessWidget {
  final Uri? callbackUri;
  const EventorAdminApp({super.key, this.callbackUri});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Eventor Admin',
    initialRoute: '/',
    themeMode: ThemeMode.light,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF9F0101),
        brightness: Brightness.light,
      ),
    ),
    home: AdminSessionGate(callbackUri: callbackUri),
  );
}
