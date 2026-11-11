import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:eventor_customer/services/customer_access.dart';
import 'package:eventor_customer/widgets/auth/login_required_dialog.dart';
import 'package:eventor_customer/screens/auth/customer_auth_screen.dart';
import 'package:eventor_customer/screens/onboarding/customer_language_entry_screen.dart';
import 'package:eventor_customer/models/app_settings_model.dart';
import 'package:eventor_customer/models/app_language_pack.dart';
import 'package:eventor_customer/services/app_settings_controller.dart';
import 'package:eventor_customer/services/customer_localization.dart';
import 'package:eventor_customer/repositories/app_settings_repository.dart';
import 'package:eventor_customer/repositories/language_pack_repository.dart';
import 'package:eventor_customer/repositories/auth_repository.dart';
import 'package:eventor_customer/utils/customer_contact_phone.dart';

class AuthStub implements AuthRepository {
  int calls = 0;
  String? contact;
  @override
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    calls++;
    return AuthResponse();
  }

  @override
  Future<AuthResponse> signUp({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    calls++;
    contact = phone;
    return AuthResponse(
      user: User.fromJson({
        'id': 'test',
        'app_metadata': {},
        'user_metadata': {},
        'aud': 'authenticated',
        'created_at': '2026-11-11T00:00:00Z',
      }),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class SettingsStub extends AppSettingsRepository {
  int writes = 0;
  String? selected;
  @override
  Future<void> saveLanguage(String code) async {
    writes++;
    selected = code;
  }
}

class PackStub extends LanguagePackRepository {
  @override
  Future<AppLanguagePack?> cachedPack(String code) async => AppLanguagePack(
    option: AppLanguageOption(code: code, name: code, nativeName: code),
    messages: const {},
    content: '',
    checksum: '',
    direction: 'ltr',
  );
}

const captureAuthPreviews = bool.fromEnvironment('GUEST_AUTH_PREVIEWS');
Future<void> preview(WidgetTester tester, GlobalKey key, String name) async {
  if (!captureAuthPreviews) return;
  await tester.pump();
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary
        .toImage(pixelRatio: 2)
        .timeout(const Duration(seconds: 10));
    final bytes = await image
        .toByteData(format: ui.ImageByteFormat.png)
        .timeout(const Duration(seconds: 10));
    final folder = Directory(
      const String.fromEnvironment(
        'GUEST_AUTH_PREVIEW_DIR',
        defaultValue: 'build/auth_previews',
      ),
    );
    await folder.create(recursive: true);
    await File('${folder.path}/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    if (!captureAuthPreviews) return;
    final flutterRoot = const String.fromEnvironment('FLUTTER_ROOT');
    if (flutterRoot.isEmpty) return;
    for (final font in {
      'Roboto': 'roboto-regular.ttf',
      'MaterialIcons': 'materialicons-regular.otf',
    }.entries) {
      final loader = FontLoader(font.key);
      loader.addFont(
        File('$flutterRoot/bin/cache/artifacts/material_fonts/${font.value}')
            .readAsBytes()
            .then((bytes) => ByteData.sublistView(bytes)),
      );
      await loader.load();
    }
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('contact phones normalize without guessing an international prefix', () {
    expect(customerContactPhone('99999 99999'), '+919999999999');
    expect(customerContactPhone('919999999999'), '+919999999999');
    expect(customerContactPhone('+44 7911 123456'), '+447911123456');
    expect(customerContactPhone('123'), isNull);
  });
  testWidgets(
    'Maybe Later dismisses without authentication or continuing booking',
    (tester) async {
      var continued = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  if (await CustomerAccess.requireSignIn(
                    context,
                    authenticated: () => false,
                  )) {
                    continued++;
                  }
                },
                child: const Text('Book Now'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Book Now'));
      await tester.pumpAndSettle();
      expect(find.text('Login Required'), findsOneWidget);
      await tester.tap(find.text('Maybe Later'));
      await tester.pumpAndSettle();
      expect(continued, 0);
      expect(find.text('Login Required'), findsNothing);
    },
  );
  testWidgets('successful login resumes the protected action once', (
    tester,
  ) async {
    var signedIn = false, continued = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                if (await CustomerAccess.requireSignIn(
                  context,
                  authenticated: () => signedIn,
                  authBuilder: (signup) => Builder(
                    builder: (context) => Scaffold(
                      body: TextButton(
                        onPressed: () {
                          signedIn = true;
                          Navigator.pop(context, true);
                        },
                        child: Text(signup ? 'Finish signup' : 'Finish login'),
                      ),
                    ),
                  ),
                )) {
                  continued++;
                }
              },
              child: const Text('Book Now'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Book Now'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish login'));
    await tester.pumpAndSettle();
    expect(continued, 1);
  });
  testWidgets(
    'Create Account dialog option opens signup and Back preserves browsing',
    (tester) async {
      var signup = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => CustomerAccess.requireSignIn(
                  context,
                  authenticated: () => false,
                  authBuilder: (mode) {
                    signup = mode;
                    return const Scaffold(body: Text('Signup page'));
                  },
                ),
                child: const Text('Save service'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Save service'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();
      expect(signup, true);
      Navigator.of(tester.element(find.text('Signup page'))).pop();
      await tester.pumpAndSettle();
      expect(find.text('Save service'), findsOneWidget);
    },
  );
  testWidgets('language tap is staged until Next then persisted', (
    tester,
  ) async {
    final repo = SettingsStub();
    var completed = 0;
    final localization = CustomerLocalization(
      code: 'en',
      repository: PackStub(),
      options: const [
        AppLanguageOption.english,
        AppLanguageOption(
          code: 'ta',
          name: 'Tamil',
          nativeName: 'தமிழ்',
          version: 1,
        ),
      ],
    );
    final settings = AppSettingsController(
      initial: const AppSettingsModel(),
      repository: repo,
      localization: localization,
    );
    await tester.pumpWidget(
      AppSettingsScope(
        controller: settings,
        child: MaterialApp(
          home: CustomerLanguageEntryScreen(onComplete: () => completed++),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('entry-language-ta')));
    await tester.pumpAndSettle();
    expect(repo.writes, 0);
    expect(completed, 0);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(repo.selected, 'ta');
    expect(completed, 1);
    expect(
      (await SharedPreferences.getInstance()).getBool(
        CustomerLanguageEntryScreen.preferenceKey,
      ),
      true,
    );
    await tester.pumpWidget(const SizedBox());
    settings.dispose();
    localization.dispose();
  });
  testWidgets('reference auth screens validate and fit compact screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = AuthStub();
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(home: CustomerAuthScreen(repository: repo)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Resend verification email'), findsNothing);
    expect(find.text('Continue with Google'), findsNothing);
    expect(find.text('Continue with Apple'), findsNothing);
    await preview(tester, key, 'login');
    await tester.ensureVisible(find.text('Login').first);
    await tester.tap(find.text('Login').first);
    await tester.pumpAndSettle();
    expect(repo.calls, 0);
    expect(find.text('Enter a valid email'), findsOneWidget);
    await tester.ensureVisible(find.text('Sign Up'));
    await tester.tap(find.text('Sign Up'));
    await tester.pumpAndSettle();
    expect(find.text('Create Account'), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-phone')), findsOneWidget);
    await preview(tester, key, 'signup');
    expect(tester.takeException(), isNull);
  });
  testWidgets('login required dialog matches the reference without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => CustomerAccess.requireSignIn(
                    context,
                    authenticated: () => false,
                  ),
                  child: const Text('Book Now'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Book Now'));
    await tester.pumpAndSettle();
    await preview(tester, key, 'login_required');
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Maybe Later'));
    await tester.pumpAndSettle();
  });
  testWidgets('login prompt remains usable with large text on a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(1.6)),
          child: child!,
        ),
        home: const Scaffold(body: CustomerLoginDialog()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Maybe Later'));
    expect(find.text('Login Required'), findsOneWidget);
  });
}
