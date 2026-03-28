import 'package:flutter/material.dart';

class GKTextField extends StatelessWidget {
  const GKTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.suffix,
    this.maxLines = 1,
    this.readOnly = false,
    this.onTap,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffix;
  final int maxLines;
  final bool readOnly;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final inputTextColor = colorScheme.onSurface;
    final secondaryTextColor = colorScheme.onSurfaceVariant;

    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
      cursorColor: colorScheme.primary,
      style: TextStyle(
        color: inputTextColor,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: secondaryTextColor),
        floatingLabelStyle: TextStyle(color: colorScheme.primary),
        hintText: hint,
        hintStyle: TextStyle(color: secondaryTextColor),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: secondaryTextColor)
            : null,
        suffixIcon: suffix,
      ),
    );
  }
}
