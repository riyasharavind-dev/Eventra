import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eventor_customer/models/home_feed.dart';
import 'package:eventor_customer/widgets/home_feed_widgets.dart';

void main() {
  testWidgets('service cards fit narrow widths and large text with equal heights', (tester) async {
    for (final width in [140.0, 164.0, 180.0]) {
      for (final scale in [1.0, 1.5, 2.0]) {
        await tester.pumpWidget(MaterialApp(home: MediaQuery(data: MediaQueryData(textScaler: TextScaler.linear(scale)), child: Scaffold(body: Row(children: [
          for (final name in ['Short', 'A very long service title that must stay on one line']) SizedBox(width: width, child: HomeFeedItemCard(item: HomeFeedItem({'id': name, 'type': 'services', 'name': name, 'price': 25000, 'location': 'A long sub-district name'}), onTap: () {})),
        ])))));
        expect(tester.takeException(), isNull, reason: 'width=$width textScale=$scale');
        final cards = tester.getSize(find.byType(HomeFeedItemCard).first);
        expect(cards.height, tester.getSize(find.byType(HomeFeedItemCard).last).height);
      }
    }
  });
}
