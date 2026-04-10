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

class PreOperatoryProcedureOption {
  const PreOperatoryProcedureOption({
    required this.id,
    required this.name,
    required this.description,
  });

  final String id;
  final String name;
  final String description;

  factory PreOperatoryProcedureOption.fromJson(Map<String, dynamic> json) {
    return PreOperatoryProcedureOption(
      id: (json['id'] ?? '').toString(),
      name: (json['specialty_name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
    );
  }
}

class PreOperatoryRecord {
  const PreOperatoryRecord({
    required this.id,
    required this.status,
    required this.notes,
    required this.allergies,
    required this.medications,
    required this.previousSurgeries,
    required this.diseases,
    required this.smoking,
    required this.alcohol,
    required this.height,
    required this.weight,
    required this.procedureId,
    required this.procedureName,
    required this.procedureDescription,
    required this.files,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String status;
  final String notes;
  final String allergies;
  final String medications;
  final String previousSurgeries;
  final String diseases;
  final bool smoking;
  final bool alcohol;
  final double? height;
  final double? weight;
  final String? procedureId;
  final String? procedureName;
  final String procedureDescription;
  final List<PreOperatoryFileItem> files;
  final DateTime createdAt;
  final DateTime updatedAt;

  List<PreOperatoryFileItem> get photos =>
      files.where((item) => item.isPhoto).toList();
  List<PreOperatoryFileItem> get documents =>
      files.where((item) => item.isDocument).toList();

  static List<PreOperatoryFileItem> _readFiles(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(PreOperatoryFileItem.fromJson)
        .toList();
  }

  factory PreOperatoryRecord.fromJson(Map<String, dynamic> json) {
    final directFiles = _readFiles(json['files']);
    final photoFiles = _readFiles(json['photos']);
    final documentFiles = _readFiles(json['documents']);
    final files = directFiles.isNotEmpty
        ? directFiles
        : <PreOperatoryFileItem>[
            ...photoFiles,
            ...documentFiles,
          ];

    return PreOperatoryRecord(
      id: (json['id'] ?? '').toString(),
      status: (json['status'] ?? 'pending').toString(),
      notes: (json['notes'] ?? '').toString(),
      allergies: (json['allergies'] ?? '').toString(),
      medications: (json['medications'] ?? '').toString(),
      previousSurgeries: (json['previous_surgeries'] ?? '').toString(),
      diseases: (json['diseases'] ?? '').toString(),
      smoking: json['smoking'] == true,
      alcohol: json['alcohol'] == true,
      height: double.tryParse((json['height'] ?? '').toString()),
      weight: double.tryParse((json['weight'] ?? '').toString()),
      procedureId: (json['procedure'] ?? '').toString().trim().isEmpty
          ? null
          : (json['procedure'] ?? '').toString(),
      procedureName: (json['procedure_name'] ?? '').toString().trim().isEmpty
          ? null
          : (json['procedure_name'] ?? '').toString(),
      procedureDescription: (json['procedure_description'] ?? '').toString(),
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
    required this.procedureId,
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
  final String? procedureId;
  final List<String> photoPaths;
  final List<String> documentPaths;
}
