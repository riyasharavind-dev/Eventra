import 'services/app_live_data.dart';

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
    builder: (context, child) => AppLiveDataHost(
      client: Supabase.instance.client,
      child: child ?? const SizedBox.shrink(),
    ),
    title: 'Eventor Admin',
    initialRoute: '/',
    themeMode: ThemeMode.light,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF8F8FA),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFF0EDF0)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFF0EDF0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFF0EDF0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF80152C), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFF0EDF0)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF80152C),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF80152C),
          side: const BorderSide(color: Color(0xFFF0EDF0)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Color(0xFF17171B),
        ),
        iconTheme: IconThemeData(color: Color(0xFF17171B)),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dataTableTheme: const DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(Color(0xFFF8F8FA)),
        headingTextStyle: TextStyle(
          fontWeight: FontWeight.w700,
          color: Color(0xFF17171B),
          fontSize: 13,
        ),
        dataRowMinHeight: 64,
        dataRowMaxHeight: 76,
        dividerThickness: 0.5,
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF80152C),
        primary: const Color(0xFF80152C),
        brightness: Brightness.light,
      ),
    ),
    home: AdminSessionGate(callbackUri: callbackUri),
  );
}
