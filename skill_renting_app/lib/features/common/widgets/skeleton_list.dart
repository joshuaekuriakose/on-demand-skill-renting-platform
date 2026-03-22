import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class SkeletonList extends StatelessWidget {
  final int itemCount;

  const SkeletonList({
    super.key,
    this.itemCount = 6,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.surfaceVariant;
    final highlight = scheme.surfaceContainerHighest;

    return ListView.builder(
      itemCount: itemCount,
      padding: const EdgeInsets.all(12),
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: base,
          highlightColor: highlight,
          child: Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              height: 90,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [

                  // Avatar placeholder
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Text placeholders
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        Container(
                          height: 14,
                          width: double.infinity,
                          color: scheme.surfaceContainerHighest,
                        ),

                        const SizedBox(height: 8),

                        Container(
                          height: 12,
                          width: 150,
                          color: scheme.surfaceContainerHighest,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}