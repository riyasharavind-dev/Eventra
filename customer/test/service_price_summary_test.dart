import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eventor_customer/models/service_model.dart';
import 'package:eventor_customer/widgets/service_details/service_price_summary.dart';
void main() {
  const service = ServiceModel(id: 'test', vendorId: 'v', categoryNodeId: 'c', name: 'Service', slug: 'service', price: 1000, gallery: [], isActive: true);
  testWidgets('price changes distinguish increase, decrease and unit change', (tester) async {
    Future<void> show(Map<String,dynamic> data) => tester.pumpWidget(MaterialApp(home: Scaffold(body: ServicePriceSummary(service: service, overview: data))));
    await show({'price': 800, 'previous_price': 1000, 'pricing_type': 'fixed', 'previous_pricing_type': 'fixed'});
    expect(find.text('20.0% decrease'), findsOneWidget);
    await show({'price': 1200, 'previous_price': 1000, 'pricing_type': 'fixed', 'previous_pricing_type': 'fixed'});
    expect(find.text('20.0% increase'), findsOneWidget);
    await show({'price': 25, 'previous_price': 1000, 'pricing_type': 'per_unit', 'pricing_unit': 'chair', 'previous_pricing_type': 'fixed'});
    expect(find.text('Pricing basis changed'), findsOneWidget);
    await show({'price': 20, 'previous_price': 0, 'pricing_type': 'fixed', 'previous_pricing_type': 'fixed'});
    expect(find.text('Price updated'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
