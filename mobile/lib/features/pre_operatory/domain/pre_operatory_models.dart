import '../../../core/utils/api_media_url.dart';

class PreOperatoryFileItem {
  const PreOperatoryFileItem({
    required this.id,
    required this.fileUrl,
    required this.type,
    required this.createdAt,
  });

  final String id;
  final String fileUrl;
  final String type;
  final DateTime createdAt;

  bool get isPhoto => type == 'photo';
  bool get isDocument => type == 'document';

  factory PreOperatoryFileItem.fromJson(Map<String, dynamic> json) {
    return PreOperatoryFileItem(
      id: (json['id'] ?? '').toString(),
      fileUrl: resolveApiMediaUrl((json['file_url'] ?? '').toString()),
      type: (json['type'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

class PreOperatoryRecord {
  const PreOperatoryRecord({
    required this.id,
    required this.status,
    required this.allergies,
    required this.medications,
    required this.previousSurgeries,
    required this.diseases,
    required this.smoking,
    required this.alcohol,
    required this.height,
    required this.weight,
    required this.files,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String status;
  final String allergies;
  final String medications;
  final String previousSurgeries;
  final String diseases;
  final bool smoking;
  final bool alcohol;
  final double? height;
  final double? weight;
  final List<PreOperatoryFileItem> files;
  final DateTime createdAt;
  final DateTime updatedAt;

  List<PreOperatoryFileItem> get photos =>
      files.where((item) => item.isPhoto).toList();
  List<PreOperatoryFileItem> get documents =>
      files.where((item) => item.isDocument).toList();

  factory PreOperatoryRecord.fromJson(Map<String, dynamic> json) {
    final files = (json['files'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(PreOperatoryFileItem.fromJson)
        .toList();

    return PreOperatoryRecord(
      id: (json['id'] ?? '').toString(),
      status: (json['status'] ?? 'pending').toString(),
      allergies: (json['allergies'] ?? '').toString(),
      medications: (json['medications'] ?? '').toString(),
      previousSurgeries: (json['previous_surgeries'] ?? '').toString(),
      diseases: (json['diseases'] ?? '').toString(),
      smoking: json['smoking'] == true,
      alcohol: json['alcohol'] == true,
      height: double.tryParse((json['height'] ?? '').toString()),
      weight: double.tryParse((json['weight'] ?? '').toString()),
      files: files,
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
      updatedAt: DateTime.tryParse((json['updated_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

class PreOperatoryUpsertPayload {
  const PreOperatoryUpsertPayload({
    required this.allergies,
    required this.medications,
    required this.previousSurgeries,
    required this.diseases,
    required this.smoking,
    required this.alcohol,
    required this.height,
    required this.weight,
    required this.photoPaths,
    required this.documentPaths,
  });

  final String allergies;
  final String medications;
  final String previousSurgeries;
  final String diseases;
  final bool smoking;
  final bool alcohol;
  final double? height;
  final double? weight;
  final List<String> photoPaths;
  final List<String> documentPaths;
}
