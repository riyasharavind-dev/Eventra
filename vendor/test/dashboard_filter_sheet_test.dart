import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eventor_vendor/widgets/listings/listing_filter_sheet.dart';

import 'package:eventor_vendor/services/app_settings_controller.dart';
import 'package:eventor_vendor/models/app_settings_model.dart';

void main() {
  testWidgets(
    'Dashboard filter hides unrelated fields and applies reset defaults',
    (tester) async {
      final settings = AppSettingsController(initial: const AppSettingsModel());
      addTearDown(settings.dispose);
      ListingFilterSelection? result;
      await tester.pumpWidget(
        AppSettingsScope(
          controller: settings,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await showModalBottomSheet<ListingFilterSelection>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => const ListingFilterSheet(
                        selection: ListingFilterSelection(
                          business: 'b',
                          sort: 'oldest',
                        ),
                        businessOptions: {
                          'all': 'All businesses',
                          'b': 'Decor',
                        },
                        categoryOptions: {'all': 'All categories'},
                        showCategory: false,
                        showStatus: false,
                        sortOptions: {
                          'newest': 'Newest first',
                          'oldest': 'Oldest first',
                        },
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Category'), findsNothing);
      expect(find.text('Status'), findsNothing);
      expect(find.text('Decor'), findsOneWidget);
      expect(find.text('Oldest first'), findsOneWidget);
      await tester.tap(find.text('Apply Filters'));
      await tester.pumpAndSettle();
      expect(result?.business, 'b');
      expect(result?.sort, 'oldest');
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply Filters'));
      await tester.pumpAndSettle();
      expect(result?.business, 'all');
      expect(result?.sort, 'newest');
    },
  );
}
