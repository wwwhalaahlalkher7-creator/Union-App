import 'package:flutter/material.dart';
import 'responsive_content.dart';

class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ResponsiveContent(
      padding: const EdgeInsetsDirectional.fromSTEB(14.72, 11.04, 14.72, 29.44),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ShimmerBox(width: double.infinity, height: 50, radius: 15),
          const SizedBox(height: 16),
          for (var i = 0; i < count; i++) ...[
            const ShimmerBox(width: double.infinity, height: 96, radius: 18),
            if (i != count - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}
