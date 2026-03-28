import 'package:flutter/material.dart';

enum GKButtonVariant { primary, secondary, accent }

class GKButton extends StatelessWidget {
  const GKButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = GKButtonVariant.primary,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final GKButtonVariant variant;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final style = switch (variant) {
      GKButtonVariant.primary => ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
      GKButtonVariant.secondary => OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.primary),
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
      GKButtonVariant.accent => ElevatedButton.styleFrom(
          backgroundColor: colorScheme.tertiary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
    };

    final child = isLoading
        ? const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                icon!,
                const SizedBox(width: 8),
              ],
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          );

    return switch (variant) {
      GKButtonVariant.secondary => OutlinedButton(onPressed: isLoading ? null : onPressed, style: style, child: child),
      _ => ElevatedButton(onPressed: isLoading ? null : onPressed, style: style, child: child),
    };
  }
}
