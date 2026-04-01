import 'package:flutter/material.dart';

import '../../../core/utils/api_media_url.dart';

class TenantBranding {
  const TenantBranding({
    required this.name,
    required this.slug,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.clinicAddresses,
    this.logoUrl,
    this.faviconUrl,
  });

  static const defaultBranding = TenantBranding(
    name: 'GoKlinik Demo',
    slug: 'goklinik-demo',
    primaryColor: Color(0xFF0D5C73),
    secondaryColor: Color(0xFF4A7C59),
    accentColor: Color(0xFFC8992E),
    clinicAddresses: ['Unidade principal da clínica'],
  );

  final String name;
  final String slug;
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;
  final List<String> clinicAddresses;
  final String? logoUrl;
  final String? faviconUrl;

  TenantBranding copyWith({
    String? name,
    String? slug,
    Color? primaryColor,
    Color? secondaryColor,
    Color? accentColor,
    List<String>? clinicAddresses,
    String? logoUrl,
    String? faviconUrl,
  }) {
    return TenantBranding(
      name: name ?? this.name,
      slug: slug ?? this.slug,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      accentColor: accentColor ?? this.accentColor,
      clinicAddresses: clinicAddresses ?? this.clinicAddresses,
      logoUrl: logoUrl ?? this.logoUrl,
      faviconUrl: faviconUrl ?? this.faviconUrl,
    );
  }

  factory TenantBranding.fromJson(Map<String, dynamic> json) {
    return TenantBranding(
      name: (json['name'] ?? defaultBranding.name).toString(),
      slug: (json['slug'] ?? defaultBranding.slug).toString(),
      primaryColor: _parseHexColor(
        (json['primary_color'] ?? '').toString(),
        defaultBranding.primaryColor,
      ),
      secondaryColor: _parseHexColor(
        (json['secondary_color'] ?? '').toString(),
        defaultBranding.secondaryColor,
      ),
      accentColor: _parseHexColor(
        (json['accent_color'] ?? '').toString(),
        defaultBranding.accentColor,
      ),
      clinicAddresses: _parseAddresses(json['clinic_addresses']),
      logoUrl: _normalizeUrl(json['logo_url']),
      faviconUrl: _normalizeUrl(json['favicon_url']),
    );
  }

  static String? _normalizeUrl(dynamic value) {
    final text = (value ?? '').toString().trim();
    return text.isEmpty ? null : resolveApiMediaUrl(text);
  }

  static List<String> _parseAddresses(dynamic value) {
    final rawList = value is List ? value : const [];
    final parsed = rawList
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
    return parsed.isNotEmpty ? parsed : defaultBranding.clinicAddresses;
  }
}

Color _parseHexColor(String rawHex, Color fallback) {
  final hex = rawHex.trim().replaceAll('#', '');
  if (hex.length != 6) {
    return fallback;
  }
  final parsed = int.tryParse(hex, radix: 16);
  if (parsed == null) {
    return fallback;
  }
  return Color(0xFF000000 | parsed);
}
