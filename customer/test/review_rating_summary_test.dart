import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eventor_customer/models/service_review_model.dart';
import 'package:eventor_customer/widgets/reviews/review_rating_summary.dart';

void main() {
  testWidgets(
    'rating breakdown reflects public counts and handles no reviews',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 288,
              child: ReviewRatingSummary(
                summary: ReviewSummary(
                  count: 6,
                  average: 4.7,
                  stars: {5: 4, 4: 2},
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('4.7'), findsOneWidget);
      expect(find.text('6 public reviews'), findsOneWidget);
      final bars = tester
          .widgetList<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator),
          )
          .toList();
      expect(bars.first.value, closeTo(4 / 6, .001));
      expect(bars[1].value, closeTo(2 / 6, .001));
      expect(bars.last.value, 0);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: const Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  width: 288,
                  child: ReviewRatingSummary(summary: ReviewSummary(count: 0)),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('0 public reviews'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
