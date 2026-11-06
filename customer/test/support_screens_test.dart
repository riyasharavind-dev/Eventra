import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:customer/models/support_model.dart';
import 'package:customer/repositories/support_repository.dart';
import 'package:customer/screens/extended/help_support_screen.dart';
import 'package:customer/screens/extended/contact_support_screen.dart';

class FakeSupportRepository extends SupportRepository {
  FakeSupportRepository(SupabaseClient client) : super(client: client);
  int submissions = 0;
  String? submittedSubject;
  @override
  Future<List<SupportFaq>> getFaqs() async => const [
    SupportFaq(
      category: 'Bookings',
      question: 'Where is my booking?',
      answer: 'Open the Bookings tab.',
    ),
    SupportFaq(
      category: 'Account & Login',
      question: 'How do I update my name?',
      answer: 'Use Edit Profile.',
    ),
  ];
  @override
  Future<SupportSettings> getSettings() async => const SupportSettings();
  @override
  Future<List<SupportTicket>> getTickets({String? ticketId}) async => [];
  @override
  Future<SupportTicket> createTicket({
    required String requestId,
    required String category,
    required String subject,
    required String description,
    XFile? screenshot,
  }) async {
    submissions++;
    submittedSubject = subject;
    return SupportTicket(
      id: requestId,
      number: 42,
      category: category,
      subject: subject,
      description: description,
      status: 'open',
      createdAt: DateTime.utc(2026, 10, 27),
    );
  }
}

void main() {
  late SupabaseClient client;
  late FakeSupportRepository repository;
  setUp(() {
    client = SupabaseClient('https://example.supabase.co', 'preview-test-key');
    repository = FakeSupportRepository(client);
  });
  tearDown(() => client.dispose());

  testWidgets('Help shows customer FAQs and filters searches', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: HelpSupportScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(find.text('EVENTRA CUSTOMER SUPPORT'), findsOneWidget);
    expect(find.text('Where is my booking?'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'booking');
    await tester.pumpAndSettle();
    expect(find.text('How do I update my name?'), findsNothing);
    await tester.tap(find.text('Where is my booking?'));
    await tester.pumpAndSettle();
    expect(find.text('Open the Bookings tab.'), findsOneWidget);
  });

  testWidgets('Contact validates empty fields before submitting', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: ContactSupportScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    final submit = find.text('Submit request');
    await tester.scrollUntilVisible(
      submit,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(repository.submissions, 0);
    await tester.scrollUntilVisible(
      find.text('Enter a subject with at least 3 characters.'),
      -250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('Enter a subject with at least 3 characters.'),
      findsOneWidget,
    );
  });

  testWidgets('Contact sends a valid request and shows its reference', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ContactSupportScreen(repository: repository),
                ),
              ),
              child: const Text('Open contact'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open contact'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('support-subject')),
      'Booking question',
    );
    await tester.enterText(
      find.byKey(const Key('support-description')),
      'I need help checking my booking request.',
    );
    final submit = find.text('Submit request');
    await tester.scrollUntilVisible(
      submit,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(repository.submissions, 1);
    expect(repository.submittedSubject, 'Booking question');
    expect(find.text('Request EV-42 submitted.'), findsOneWidget);
  });
}
