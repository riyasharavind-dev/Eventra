import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eventor_customer/models/service_recommendations.dart';
import 'package:eventor_customer/repositories/recommendation_repository.dart';
import 'package:eventor_customer/widgets/recommendations/service_recommendations_section.dart';

RecommendationPage makePage(List<String> ids, {int next = 12, bool more = false}) =>
    RecommendationPage({
      'items': [
        for (final id in ids)
          {
            'id': id,
            'name': id,
            'type': 'services',
            'price': 25,
            'pricing_type': 'per_unit',
            'pricing_unit': 'chair',
            'service': {'id': id},
          },
      ],
      'next_offset': next,
      'has_more': more,
      'personalized': true,
    });

class FakeRecommendations implements RecommendationRepository {
  final calls = <int>[];
  final pending = <Completer<RecommendationPage>>[];
  bool delayed = false, fail = false;
  RecommendationPage value = makePage(['One']);
  @override
  Future<RecommendationPage> page({String? serviceId, int offset = 0}) async {
    calls.add(offset);
    if (fail) throw StateError('Offline');
    if (!delayed) return value;
    final c = Completer<RecommendationPage>();
    pending.add(c);
    return c.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('Pagination deduplicates and stops on a non-advancing cursor', () async {
    final repo = FakeRecommendations()..value = makePage(['A', 'B'], more: true);
    final c = RecommendationController(repository: repo);
    await c.refresh();
    repo.value = makePage(['B', 'C'], next: 12, more: true);
    await c.loadMore();
    expect(c.items.map((e) => e.id), ['A', 'B', 'C']);
    expect(c.hasMore, false);
    await c.loadMore();
    expect(repo.calls, [0, 12]);
    c.dispose();
  });
  test(
    'Refresh supersedes stale in-flight results and dispose is safe',
    () async {
      final repo = FakeRecommendations()..delayed = true;
      final c = RecommendationController(repository: repo);
      final old = c.refresh(), fresh = c.refresh();
      repo.pending[1].complete(makePage(['New']));
      await fresh;
      repo.pending[0].complete(makePage(['Old']));
      await old;
      expect(c.items.single.id, 'New');
      final last = c.refresh();
      c.dispose();
      repo.pending[2].complete(makePage(['Ignored']));
      await last;
    },
  );
  test('Failed refresh retains content and a retry replaces it', () async {
    final repo = FakeRecommendations()..value = makePage(['Old']);
    final c = RecommendationController(repository: repo);
    await c.refresh();
    repo.fail = true;
    await c.refresh();
    expect(c.items.single.id, 'Old');
    expect(c.error, isNotNull);
    repo.fail = false;
    repo.value = makePage(['New']);
    await c.loadMore();
    expect(c.items.single.id, 'New');
    expect(c.error, isNull);
    c.dispose();
  });
  testWidgets('Related shelf fits a narrow viewport and keeps unit pricing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = RecommendationController(
      repository: FakeRecommendations(),
      serviceId: 'anchor',
    );
    await c.refresh();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ServiceRecommendationsSection(controller: c),
          ),
        ),
      ),
    );
    expect(find.text('Related services'), findsOneWidget);
    expect(find.textContaining('/ chair'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    c.dispose();
  });
  testWidgets('Offline shelf has retry and loads without blocking the page', (
    tester,
  ) async {
    final repo = FakeRecommendations()..fail = true;
    final c = RecommendationController(repository: repo);
    await c.refresh();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ServiceRecommendationsSection(controller: c),
          ),
        ),
      ),
    );
    expect(find.text('Recommendations unavailable. Retry'), findsOneWidget);
    repo.fail = false;
    await tester.tap(find.text('Recommendations unavailable. Retry'));
    await tester.pumpAndSettle();
    expect(find.text('One'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    c.dispose();
  });
}
