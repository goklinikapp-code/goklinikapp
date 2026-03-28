import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class GKLoadingShimmer extends StatelessWidget {
  const GKLoadingShimmer({super.key, this.height = 72});

  final double height;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
      highlightColor:
          isDark ? const Color(0xFF334155) : const Color(0xFFF8FAFC),
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
