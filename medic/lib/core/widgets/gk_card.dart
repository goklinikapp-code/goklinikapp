import 'package:flutter/material.dart';

class GKCard extends StatelessWidget {
  const GKCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: isDark
            ? Border.all(
                color: const Color(0xFF2E364C),
                width: 1,
              )
            : null,
        boxShadow: isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x140F172A),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
      ),
      child: child,
    );
  }
}
