import 'package:flutter/material.dart';
import 'responsive_content.dart';

class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ResponsiveContent(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ShimmerBox(width: double.infinity, height: 54, radius: 17),
          const SizedBox(height: 16),
          for (var i = 0; i < count; i++) ...[
            const ShimmerBox(width: double.infinity, height: 104, radius: 20),
            if (i != count - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}
