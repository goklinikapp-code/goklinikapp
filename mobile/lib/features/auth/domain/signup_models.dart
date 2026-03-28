class SignupClinic {
  const SignupClinic({
    required this.id,
    required this.name,
    required this.slug,
  });

  final String id;
  final String name;
  final String slug;

  factory SignupClinic.fromJson(Map<String, dynamic> json) {
    return SignupClinic(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
    );
  }
}

class ReferralLookupResult {
  const ReferralLookupResult({
    required this.code,
    required this.clinicId,
    required this.clinicName,
  });

  final String code;
  final String clinicId;
  final String clinicName;

  factory ReferralLookupResult.fromJson(Map<String, dynamic> json) {
    return ReferralLookupResult(
      code: (json['codigo'] ?? '').toString(),
      clinicId: (json['clinica_id'] ?? '').toString(),
      clinicName: (json['clinica_nome'] ?? '').toString(),
    );
  }
}
