import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:eventor_customer/models/about_eventor_model.dart';
import 'package:eventor_customer/models/legal_document_model.dart';
import 'package:eventor_customer/repositories/about_eventor_repository.dart';
import 'package:eventor_customer/repositories/legal_document_repository.dart';
import 'package:eventor_customer/screens/extended/about_eventor_screen.dart';
import 'package:eventor_customer/screens/extended/privacy_policy_screen.dart';
import 'package:eventor_customer/screens/extended/terms_and_conditions_screen.dart';

class PreviewAboutRepository extends AboutEventorRepository {
  PreviewAboutRepository(SupabaseClient client) : super(client: client);
  @override
  Future<AboutEventorModel?> getCustomerAbout({
    String languageCode = 'en',
  }) async => const AboutEventorModel(
    id: 'about',
    title: 'About Eventor',
    tagline: 'Plan your celebration',
    introduction: 'Customer content from the repository.',
    features: [
      AboutEventorFeature(
        title: 'Track bookings',
        description: 'Follow your requests.',
      ),
    ],
  );
}

class PreviewLegalRepository extends LegalDocumentRepository {
  PreviewLegalRepository(SupabaseClient client) : super(client: client);
  bool fail = false;
  LegalDocumentModel document(String type) => LegalDocumentModel(
    id: type,
    documentType: type,
    audience: 'customer',
    languageCode: 'en',
    version: 1,
    title: type == 'privacy_policy' ? 'Privacy Policy' : 'Terms & Conditions',
    contentMarkdown: '# Preview content\n\n**Customer preview text**\n\n- Booking information',
    effectiveAt: DateTime.utc(2026, 10, 27),
    publishedAt: DateTime.utc(2026, 10, 27),
  );
  @override
  Future<LegalDocumentModel?> getCustomerPrivacyPolicy({
    String languageCode = 'en',
  }) async {
    if (fail) throw Exception('Offline');
    return document('privacy_policy');
  }

  @override
  Future<LegalDocumentModel?> getCustomerTerms({
    String languageCode = 'en',
  }) async => document('terms_and_conditions');
}

void main() {
  late SupabaseClient client;
  setUp(
    () => client = SupabaseClient(
      'https://example.supabase.co',
      'preview-test-key',
    ),
  );
  tearDown(() => client.dispose());

  testWidgets('About shows customer repository content and policy navigation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AboutEventorScreen(repository: PreviewAboutRepository(client)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Customer content from the repository.'), findsOneWidget);
    expect(find.text('Track bookings'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Terms & Conditions'), findsOneWidget);
  });

  testWidgets('Both legal screens render customer content and Markdown', (
    tester,
  ) async {
    final repository = PreviewLegalRepository(client);
    for (final screen in <Widget>[
      PrivacyPolicyScreen(repository: repository),
      TermsAndConditionsScreen(repository: repository),
    ]) {
      await tester.pumpWidget(MaterialApp(home: screen));
      await tester.pumpAndSettle();
      expect(find.text('EVENTOR CUSTOMER'), findsOneWidget);
      expect(
        find.textContaining('Customer preview text', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('# Preview content'), findsNothing);
    }
  });

  testWidgets('Privacy policy retries after a loading failure', (tester) async {
    final repository = PreviewLegalRepository(client)..fail = true;
    await tester.pumpWidget(
      MaterialApp(home: PrivacyPolicyScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unable to load privacy policy'), findsOneWidget);
    repository.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('EVENTOR CUSTOMER'), findsOneWidget);
  });
}
