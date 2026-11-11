import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eventor_customer/models/home_feed.dart';
import 'package:eventor_customer/widgets/vendor_profile_card.dart';

void main() {
  testWidgets(
    'vendor profile has equal size for short and long names and shows facts',
    (tester) async {
      for (final scale in [1.0, 2.0]) {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final name in [
                        'Short business',
                        'A very long business name which must never resize the card',
                      ])
                        SizedBox(
                          width: 256,
                          child: VendorProfileCard(
                            item: HomeFeedItem({
                              'id': name,
                              'type': 'vendors',
                              'business_name': name,
                              'rating': 4.8,
                              'review_count': 230,
                              'location': 'Thanjavur',
                              'parent_category': 'Decoration',
                            }),
                            onTap: () {},
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byType(VendorProfileCard).first),
          tester.getSize(find.byType(VendorProfileCard).last),
        );
        expect(find.text('4.8 (230)'), findsNWidgets(2));
        expect(find.text('Decoration'), findsNWidgets(2));
      }
    },
  );
}
