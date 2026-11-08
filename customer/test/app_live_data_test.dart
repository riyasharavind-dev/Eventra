import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eventor_customer/services/app_live_data.dart';

class Probe extends StatefulWidget {
  const Probe({super.key});
  @override
  State<Probe> createState() => _ProbeState();
}

class _ProbeState extends State<Probe> with LiveDataState<Probe> {
  final text = TextEditingController();
  int count = 0;
  @override
  Set<String> get liveDatasets => {'probe'};
  @override
  Future<void> onLiveData(Set<String> changed) async {
    setState(() => count++);
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        Text('Count $count'),
        TextField(controller: text),
        TextButton(
          onPressed: () => Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) => const Scaffold(body: Text('Cover')),
            ),
          ),
          child: const Text('Open cover'),
        ),
      ],
    ),
  );
}

void main() {
  testWidgets('Continuous changes still refresh within a bounded window', (
    t,
  ) async {
    var calls = 0;
    final b = LiveDataBinding({'services'}, (d) async {
      calls++;
    });
    b.setActive(true);
    b.invalidate({'services'});
    await t.pump(const Duration(milliseconds: 200));
    b.invalidate({'services'});
    await t.pump(const Duration(milliseconds: 150));
    expect(calls, 1);
    b.dispose();
  });

  testWidgets('Bursts coalesce and unrelated datasets do not fetch', (t) async {
    final calls = <Set<String>>[];
    final b = LiveDataBinding({'services', 'reviews'}, (d) async {
      calls.add(d);
    });
    b.setActive(true);
    for (var i = 0; i < 50; i++) {
      b.invalidate({'services'});
    }
    b.invalidate({'other'});
    b.invalidate({'reviews'});
    await t.pump(const Duration(milliseconds: 350));
    expect(calls.length, 1);
    expect(calls.single, {'services', 'reviews'});
    b.dispose();
  });
  testWidgets('Hidden pages retain one dirty refresh until activated', (
    t,
  ) async {
    var calls = 0;
    final b = LiveDataBinding({'services'}, (d) async {
      calls++;
    });
    b.invalidate({'services'});
    await t.pump(const Duration(seconds: 1));
    expect(calls, 0);
    b.setActive(true);
    await t.pump(const Duration(milliseconds: 350));
    expect(calls, 1);
    b.dispose();
  });
  testWidgets('Refreshes serialize and changes during a request are not lost', (
    t,
  ) async {
    var calls = 0;
    final pending = Completer<void>();
    final b = LiveDataBinding({'services'}, (d) async {
      calls++;
      if (calls == 1) await pending.future;
    });
    b.setActive(true);
    b.invalidate({'services'});
    await t.pump(const Duration(milliseconds: 350));
    for (var i = 0; i < 20; i++) {
      b.invalidate({'services'});
    }
    await t.pump(const Duration(seconds: 1));
    expect(calls, 1);
    pending.complete();
    await t.pump();
    await t.pump(const Duration(milliseconds: 350));
    expect(calls, 2);
    b.dispose();
  });
  testWidgets('Disposal cancels pending updates', (t) async {
    var calls = 0;
    final b = LiveDataBinding({'services'}, (d) async {
      calls++;
    });
    b.setActive(true);
    b.invalidate({'services'});
    b.dispose();
    await t.pump(const Duration(seconds: 1));
    expect(calls, 0);
  });
  testWidgets('Background apps defer work until resume', (t) async {
    var calls = 0;
    final b = LiveDataBinding({'services'}, (d) async {
      calls++;
    });
    b.setActive(true);
    b.setForeground(false);
    b.invalidate({'services'});
    await t.pump(const Duration(seconds: 1));
    expect(calls, 0);
    b.setForeground(true);
    await t.pump(const Duration(milliseconds: 350));
    expect(calls, 1);
    b.dispose();
  });
  testWidgets('A failed background request can recover on the next change', (
    t,
  ) async {
    var calls = 0;
    final b = LiveDataBinding({'services'}, (d) async {
      calls++;
      if (calls == 1) throw StateError('Offline');
    });
    b.setActive(true);
    b.invalidate({'services'});
    await t.pump(const Duration(milliseconds: 350));
    b.invalidate({'services'});
    await t.pump(const Duration(milliseconds: 350));
    expect(calls, 2);
    expect(t.takeException(), isNull);
    b.dispose();
  });
  testWidgets('Live updates retain form text and defer covered routes', (
    t,
  ) async {
    await t.pumpWidget(const MaterialApp(home: Probe()));
    await t.enterText(find.byType(TextField), 'Unsaved input');
    AppLiveData.instance.invalidate({'probe'});
    await t.pump(const Duration(milliseconds: 350));
    expect(find.text('Count 1'), findsOneWidget);
    expect(find.text('Unsaved input'), findsOneWidget);
    await t.tap(find.text('Open cover'));
    await t.pumpAndSettle();
    AppLiveData.instance.invalidate({'probe'});
    await t.pump(const Duration(milliseconds: 350));
    expect(find.text('Count 2', skipOffstage: false), findsNothing);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    await t.pump(const Duration(milliseconds: 350));
    expect(find.text('Count 2'), findsOneWidget);
    expect(find.text('Unsaved input'), findsOneWidget);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
    expect(t.takeException(), isNull);
  });
  testWidgets('TickerMode pauses inactive retained tabs', (t) async {
    final active = ValueNotifier(true);
    await t.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: active,
          builder: (c, v, _) => TickerMode(enabled: v, child: const Probe()),
        ),
      ),
    );
    active.value = false;
    await t.pump();
    AppLiveData.instance.invalidate({'probe'});
    await t.pump(const Duration(milliseconds: 350));
    expect(find.text('Count 0'), findsOneWidget);
    active.value = true;
    await t.pump();
    await t.pump(const Duration(milliseconds: 350));
    expect(find.text('Count 1'), findsOneWidget);
    await t.pumpWidget(const SizedBox.shrink());
    active.dispose();
  });
}
