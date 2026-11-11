import 'package:flutter/material.dart';

import '../../models/customer_search_model.dart';
import '../home_feed_widgets.dart';

/// Reuses the customer feed's image-first service/vendor cards in search results.
class ResultCards extends StatelessWidget {
  const ResultCards({super.key, required this.results, required this.onOpen});
  final List<CustomerSearchResult> results;
  final ValueChanged<CustomerSearchResult> onOpen;
  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(
    builder: (context, constraints) {
      final columns = feedCardColumns(constraints.crossAxisExtent);
      return SliverList.builder(
        itemCount: (results.length / columns).ceil(),
        itemBuilder: (context, row) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var column = 0; column < columns; column++) ...[
                if (column > 0) const SizedBox(width: 12),
                Expanded(
                  child: row * columns + column < results.length
                      ? HomeFeedItemCard(
                          key: ValueKey(results[row * columns + column].id),
                          item: results[row * columns + column].feedItem,
                          onTap: () => onOpen(results[row * columns + column]),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
