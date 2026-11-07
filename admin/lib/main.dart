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
      scaffoldBackgroundColor: const Color(0xFFF5F6FA),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE8EAF0)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE1E4EC)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE1E4EC)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dataTableTheme: const DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(Color(0xFFF2F3F8)),
        headingTextStyle: TextStyle(
          fontWeight: FontWeight.w700,
          color: Color(0xFF252936),
        ),
        dataRowMinHeight: 64,
        dataRowMaxHeight: 76,
        dividerThickness: 0.5,
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF9F0101),
        brightness: Brightness.light,
      ),
    ),
    home: AdminSessionGate(callbackUri: callbackUri),
  );
}
