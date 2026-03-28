class TenantInfo {
  const TenantInfo({required this.id, required this.name, required this.slug});

  final String id;
  final String name;
  final String slug;

  factory TenantInfo.fromJson(Map<String, dynamic> json) {
    return TenantInfo(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'slug': slug};
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.phone,
    required this.avatarUrl,
    this.tenant,
  });

  final String id;
  final String email;
  final String fullName;
  final String role;
  final String phone;
  final String avatarUrl;
  final TenantInfo? tenant;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final firstName = (json['first_name'] ?? '').toString();
    final lastName = (json['last_name'] ?? '').toString();
    final fullNameRaw = (json['full_name'] ?? '').toString();
    final fullName = fullNameRaw.isNotEmpty
        ? fullNameRaw
        : '$firstName $lastName'.trim().isEmpty
            ? (json['email'] ?? '').toString()
            : '$firstName $lastName'.trim();

    return AuthUser(
      id: (json['id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      fullName: fullName,
      role: (json['role'] ?? 'patient').toString(),
      phone: (json['phone'] ?? '').toString(),
      avatarUrl: (json['avatar_url'] ?? '').toString(),
      tenant: json['tenant'] is Map<String, dynamic>
          ? TenantInfo.fromJson(json['tenant'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'full_name': fullName,
        'role': role,
        'phone': phone,
        'avatar_url': avatarUrl,
        'tenant': tenant?.toJson(),
      };
}
