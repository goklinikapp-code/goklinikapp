import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../utils/api_media_url.dart';

class GKAvatar extends StatelessWidget {
  const GKAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.radius = 22,
  });

  final String name;
  final String? imageUrl;
  final double radius;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'GK';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final normalizedImageUrl =
        imageUrl == null ? '' : resolveApiMediaUrl(imageUrl!);
    if (normalizedImageUrl.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: normalizedImageUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          placeholder: (_, __) => _fallbackAvatar(colorScheme),
          errorWidget: (_, __, ___) => _fallbackAvatar(colorScheme),
        ),
      );
    }

    return _fallbackAvatar(colorScheme);
  }

  CircleAvatar _fallbackAvatar(ColorScheme colorScheme) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: colorScheme.primary.withValues(alpha: 0.14),
      child: Text(
        initials,
        style:
            TextStyle(fontWeight: FontWeight.w700, color: colorScheme.primary),
      ),
    );
  }
}
