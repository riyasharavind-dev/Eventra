import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eventor_customer/models/service_model.dart';
import 'package:eventor_customer/models/service_pricing.dart';
import 'package:eventor_customer/models/app_language_pack.dart';
import 'package:eventor_customer/repositories/language_pack_repository.dart';
import 'package:eventor_customer/repositories/customer_collection_sync.dart';
import 'package:eventor_customer/services/customer_localization.dart';
import 'package:eventor_customer/widgets/bookings/booking_quantity_field.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'unit quantities reject fractional/zero inputs and report the selected amount',
    (tester) async {
      final form = GlobalKey<FormState>();
      var quantity = 1;
      const service = ServiceModel(
        id: 's',
        vendorId: 'v',
        categoryNodeId: 'c',
        name: 'Chairs',
        slug: 'chairs',
        price: 25,
        gallery: [],
        isActive: true,
        pricing: ServicePricing(
          type: ServicePricingType.perUnit,
          unit: 'chair',
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: form,
              child: BookingQuantityField(
                service: service,
                onChanged: (n) => quantity = n,
              ),
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField), '0');
      expect(form.currentState!.validate(), false);
      await tester.enterText(find.byType(TextFormField), '1.5');
      expect(form.currentState!.validate(), false);
      await tester.enterText(find.byType(TextFormField), '40');
      expect(form.currentState!.validate(), true);
      expect(quantity, 40);
    },
  );
  test(
    'offline collection removals persist as account-scoped tombstones',
    () async {
      await CustomerCollectionSync.change('first', 'added', 'service', true);
      await CustomerCollectionSync.change('first', 'added', 'service', false);
      await CustomerCollectionSync.change('second', 'saved', 'service', true);
      final p = await SharedPreferences.getInstance();
      expect(
        (jsonDecode(p.getString('eventor.collections.outbox.first')!)
            as Map)['added:service']['present'],
        false,
      );
      expect(
        (jsonDecode(p.getString('eventor.collections.outbox.second')!)
            as Map)['saved:service']['present'],
        true,
      );
    },
  );
  test(
    'validated language snapshots load offline and reject corrupted content',
    () async {
      final content = jsonEncode({
        'schema': 1,
        'app': 'vendor',
        'code': 'ta',
        'version': 1,
        'direction': 'ltr',
        'messages': {'customer.continue.31fa18bf': 'தொடரவும்'},
      });
      final checksum = sha256.convert(utf8.encode(content)).toString();
      final option = AppLanguageOption(
        code: 'ta',
        name: 'Tamil',
        nativeName: 'தமிழ்',
        version: 1,
        checksum: checksum,
      );
      final pack = AppLanguagePack.parse({
        'content': content,
        'sha256': checksum,
      }, option);
      final repo = LanguagePackRepository();
      await repo.storePack(pack, preserveCode: 'ta');
      final localization = await CustomerLocalization.loadLocal(
        'ta',
        repository: repo,
      );
      expect(localization.code, 'ta');
      expect(localization.tr('customer.continue.31fa18bf'), 'தொடரவும்');
      localization.dispose();
      expect(
        () => AppLanguagePack.parse({
          'content': '$content ',
          'sha256': checksum,
        }, option),
        throwsFormatException,
      );
    },
  );
}
