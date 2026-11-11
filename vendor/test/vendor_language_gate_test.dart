import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eventor_vendor/models/app_settings_model.dart';
import 'package:eventor_vendor/models/app_language_pack.dart';
import 'package:eventor_vendor/repositories/app_settings_repository.dart';
import 'package:eventor_vendor/repositories/language_pack_repository.dart';
import 'package:eventor_vendor/services/app_settings_controller.dart';
import 'package:eventor_vendor/services/vendor_localization.dart';
import 'package:eventor_vendor/screens/onboarding/vendor_language_gate.dart';
import 'package:eventor_vendor/screens/extended/language_screen.dart';

class OfflineLanguages extends LanguagePackRepository {
  @override
  Future<List<AppLanguageOption>> fetchManifest() async =>
      throw StateError('offline');
  @override
  Future<AppLanguagePack> download(AppLanguageOption option) async =>
      throw StateError('offline');
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  AppSettingsController settings() => AppSettingsController(
    initial: const AppSettingsModel(),
    localization: VendorLocalization(
      code: 'en',
      repository: OfflineLanguages(),
      options: const [
        AppLanguageOption.english,
        AppLanguageOption(
          code: 'ta',
          name: 'Tamil',
          nativeName: 'Tamil',
          version: 1,
        ),
      ],
    ),
  );
  Widget page(AppSettingsController controller) => AppSettingsScope(
    controller: controller,
    child: const MaterialApp(
      home: VendorLanguageGate(
        child: Scaffold(body: Text('Continue to onboarding/login')),
      ),
    ),
  );
  testWidgets(
    'first launch asks once, including explicit English choice offline',
    (tester) async {
      final controller = settings();
      await tester.pumpWidget(page(controller));
      await tester.pumpAndSettle();
      expect(find.byType(LanguageScreen), findsOneWidget);
      expect(find.text('Continue to onboarding/login'), findsNothing);
      expect(await AppSettingsRepository().hasSelectedLanguage(), false);
      await tester.tap(find.byKey(const ValueKey('language-option-en')));
      await tester.pumpAndSettle();
      expect(find.byType(LanguageScreen), findsOneWidget);
      expect(await AppSettingsRepository().hasSelectedLanguage(), false);
      await tester.tap(find.byKey(const ValueKey('language-next')));
      await tester.pumpAndSettle();
      expect(find.text('Continue to onboarding/login'), findsOneWidget);
      expect(await AppSettingsRepository().hasSelectedLanguage(), true);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.pumpWidget(page(controller));
      await tester.pumpAndSettle();
      expect(find.byType(LanguageScreen), findsNothing);
      expect(find.text('Continue to onboarding/login'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
  testWidgets(
    'failed Tamil download keeps first-choice page and does not mark complete',
    (tester) async {
      final controller = settings();
      await tester.pumpWidget(page(controller));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('language-option-ta')));
      await tester.pumpAndSettle();
      expect(await AppSettingsRepository().hasSelectedLanguage(), false);
      expect(controller.value.languageCode, 'en');
      await tester.tap(find.byKey(const ValueKey('language-next')));
      await tester.pumpAndSettle();
      expect(find.byType(LanguageScreen), findsOneWidget);
      expect(controller.value.languageCode, 'en');
      expect(await AppSettingsRepository().hasSelectedLanguage(), false);
      await tester.tap(find.byKey(const ValueKey('language-option-en')));
      await tester.pumpAndSettle();
      expect(find.byType(LanguageScreen), findsOneWidget);
      expect(await AppSettingsRepository().hasSelectedLanguage(), false);
      await tester.tap(find.byKey(const ValueKey('language-next')));
      await tester.pumpAndSettle();
      expect(find.text('Continue to onboarding/login'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
  testWidgets(
    'existing saved language skips selection without changing preference',
    (tester) async {
      await AppSettingsRepository().saveLanguage('ta');
      final controller = settings();
      await tester.pumpWidget(page(controller));
      await tester.pumpAndSettle();
      expect(find.byType(LanguageScreen), findsNothing);
      expect((await AppSettingsRepository().load()).languageCode, 'ta');
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
}
