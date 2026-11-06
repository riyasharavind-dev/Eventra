import 'package:flutter/material.dart';

import 'app_shimmer.dart';

class AppLoading extends StatelessWidget {
  const AppLoading({super.key, this.message});
  final String? message;
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      const AppContentSkeleton(),
      if (message != null && message!.trim().isNotEmpty)
        Positioned(
          bottom: 20,
          left: 18,
          right: 18,
          child: Text(message!, textAlign: TextAlign.center),
        ),
    ],
  );
}
