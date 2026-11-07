import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:eventor_admin/widgets/admin_authenticator_setup_card.dart';

void main() {
  const testKey = 'DUMMYSETUPKEYFORWIDGETTESTONLY1234567890';
  const testSvg =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><path d="M0 0h100v100H0z" fill="black"/></svg>';
  testWidgets(
    'Enrollment QR appears above the selectable manual key on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: AdminAuthenticatorSetupCard(
                qrSvg: testSvg,
                secret: testKey,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final qr = find.byKey(const ValueKey('authenticator-setup-qr'));
      final key = find.byKey(const ValueKey('authenticator-manual-key'));
      expect(find.byType(SvgPicture), findsOneWidget);
      expect(find.text(testKey), findsOneWidget);
      expect(
        tester.getTopLeft(key).dy,
        greaterThan(tester.getBottomLeft(qr).dy),
      );
      expect(find.text('Copy setup key'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Copy uses the full enrollment key without formatting or truncation',
    (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AdminAuthenticatorSetupCard(
                qrSvg: testSvg,
                secret: testKey,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Copy setup key'));
      await tester.tap(find.text('Copy setup key'));
      await tester.pump();
      expect(copied, testKey);
      expect(find.text('Setup key copied.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
