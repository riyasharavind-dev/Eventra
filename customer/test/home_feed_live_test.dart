import 'package:flutter_test/flutter_test.dart';
import 'package:eventor_customer/repositories/home_feed_repository.dart';

class FeedRepo implements HomeFeedRepository {
  final calls = <int>[];
  String prefix = 'Before';
  @override
  Future<Map<String, dynamic>?> location() async => null;
  @override
  Future<Map<String, dynamic>> page(
    int offset, {
    double? lat,
    double? lng,
  }) async {
    calls.add(offset);
    return {
      'sections': [
        for (var i = offset; i < offset + 3 && i < 6; i++)
          {
            'id': '$i',
            'title': '$prefix $i',
            'items': [
              {'id': 'service-$i', 'name': 'Service $i', 'type': 'services'},
            ],
          },
      ],
      'next_offset': offset + 3,
      'has_more': offset + 3 < 6,
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'Live refresh preserves the already-loaded home section window',
    () async {
      final repo = FeedRepo();
      final feed = HomeFeedController(repository: repo);
      await feed.refresh();
      await feed.loadMore();
      expect(feed.sections.length, 6);
      repo.prefix = 'After';
      await feed.refresh(keepWindow: true);
      expect(feed.sections.length, 6);
      expect(feed.sections.last.title, 'After 5');
      expect(repo.calls, [0, 3, 0, 3]);
      feed.dispose();
    },
  );
}
