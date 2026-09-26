import 'package:flutter/material.dart';

class ListingDescriptionSection extends StatelessWidget {
  final String? description;

  const ListingDescriptionSection({
    super.key,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    final hasDescription =
        description != null &&
        description!.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(
        18,
        18,
        18,
        20,
      ),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'About this service',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            hasDescription
                ? description!.trim()
                : 'No description has been added for this service.',
            style: TextStyle(
              fontSize: 14,
              height: 1.55,
              color: hasDescription
                  ? Colors.grey.shade800
                  : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}