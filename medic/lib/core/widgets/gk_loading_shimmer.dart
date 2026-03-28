import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class GKLoadingShimmer extends StatelessWidget {
  const GKLoadingShimmer({super.key, this.height = 72});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE2E8F0),
      highlightColor: const Color(0xFFF8FAFC),
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
