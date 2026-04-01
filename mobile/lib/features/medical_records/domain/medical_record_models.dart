import '../../../core/utils/api_media_url.dart';

class MedicalDocumentItem {
  const MedicalDocumentItem({
    required this.id,
    required this.title,
    required this.description,
    required this.fileUrl,
    required this.fileType,
    required this.uploadedBy,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String description;
  final String fileUrl;
  final String fileType;
  final String uploadedBy;
  final DateTime createdAt;

  factory MedicalDocumentItem.fromJson(Map<String, dynamic> json) {
    final createdRaw =
        (json['criado_em'] ?? json['created_at'] ?? '').toString();
    return MedicalDocumentItem(
      id: (json['id'] ?? '').toString(),
      title: (json['titulo'] ?? json['title'] ?? '').toString(),
      description: (json['descricao'] ?? '').toString(),
      fileUrl: resolveApiMediaUrl(
        (json['arquivo_url'] ?? json['file_url'] ?? '').toString(),
      ),
      fileType:
          (json['tipo_arquivo'] ?? json['document_type'] ?? 'pdf').toString(),
      uploadedBy: (json['uploaded_by'] ?? '').toString(),
      createdAt: DateTime.tryParse(createdRaw) ?? DateTime.now(),
    );
  }
}

class ProcedureImageItem {
  const ProcedureImageItem({
    required this.id,
    required this.imageUrl,
    required this.createdAt,
  });

  final String id;
  final String imageUrl;
  final DateTime createdAt;

  factory ProcedureImageItem.fromJson(Map<String, dynamic> json) {
    return ProcedureImageItem(
      id: (json['id'] ?? '').toString(),
      imageUrl: resolveApiMediaUrl((json['image_url'] ?? '').toString()),
      createdAt: DateTime.tryParse((json['criado_em'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

class ProcedureHistoryItem {
  const ProcedureHistoryItem({
    required this.id,
    required this.nomeProcedimento,
    required this.descricao,
    required this.dataProcedimento,
    required this.profissionalResponsavel,
    required this.observacoes,
    required this.images,
  });

  final String id;
  final String nomeProcedimento;
  final String descricao;
  final DateTime? dataProcedimento;
  final String profissionalResponsavel;
  final String observacoes;
  final List<ProcedureImageItem> images;

  factory ProcedureHistoryItem.fromJson(Map<String, dynamic> json) {
    final images = (json['images'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ProcedureImageItem.fromJson)
        .toList();
    final rawDate =
        (json['data_procedimento'] ?? json['appointment_date'] ?? '')
            .toString();
    return ProcedureHistoryItem(
      id: (json['id'] ?? '').toString(),
      nomeProcedimento: (json['nome_procedimento'] ??
              json['specialty_name'] ??
              json['appointment_type'] ??
              '')
          .toString(),
      descricao: (json['descricao'] ?? '').toString(),
      dataProcedimento: DateTime.tryParse(rawDate),
      profissionalResponsavel:
          (json['profissional_responsavel'] ?? json['professional_name'] ?? '')
              .toString(),
      observacoes: (json['observacoes'] ?? '').toString(),
      images: images,
    );
  }
}

class MedicationItem {
  const MedicationItem({
    required this.id,
    required this.nomeMedicamento,
    required this.dosagem,
    required this.frequencia,
    required this.viaAdministracao,
    required this.dataInicio,
    required this.dataFim,
    required this.emUso,
    required this.possuiAlergia,
    required this.descricao,
  });

  final String id;
  final String nomeMedicamento;
  final String dosagem;
  final String frequencia;
  final String viaAdministracao;
  final DateTime? dataInicio;
  final DateTime? dataFim;
  final bool emUso;
  final bool possuiAlergia;
  final String descricao;

  factory MedicationItem.fromJson(Map<String, dynamic> json) {
    return MedicationItem(
      id: (json['id'] ?? '').toString(),
      nomeMedicamento: (json['nome_medicamento'] ?? '').toString(),
      dosagem: (json['dosagem'] ?? '').toString(),
      frequencia: (json['frequencia'] ?? '').toString(),
      viaAdministracao: (json['via_administracao'] ?? '').toString(),
      dataInicio: DateTime.tryParse((json['data_inicio'] ?? '').toString()),
      dataFim: DateTime.tryParse((json['data_fim'] ?? '').toString()),
      emUso: json['em_uso'] == true,
      possuiAlergia: json['possui_alergia'] == true,
      descricao: (json['descricao'] ?? '').toString(),
    );
  }
}

class MedicalRecordSummary {
  const MedicalRecordSummary({
    required this.patientId,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.cpf,
    required this.avatarUrl,
    required this.dateOfBirth,
    required this.healthInsurance,
    required this.allergies,
    required this.previousSurgeries,
    required this.currentMedications,
    required this.medications,
    required this.procedureHistory,
    required this.documents,
  });

  final String patientId;
  final String fullName;
  final String email;
  final String phone;
  final String cpf;
  final String avatarUrl;
  final String dateOfBirth;
  final String healthInsurance;
  final String allergies;
  final String previousSurgeries;
  final String currentMedications;
  final List<MedicationItem> medications;
  final List<ProcedureHistoryItem> procedureHistory;
  final List<MedicalDocumentItem> documents;

  factory MedicalRecordSummary.fromJson(Map<String, dynamic> json) {
    final patient =
        (json['patient'] ?? <String, dynamic>{}) as Map<String, dynamic>;
    final documents = (json['documents'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(MedicalDocumentItem.fromJson)
        .toList();
    final procedures = (json['procedure_history'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ProcedureHistoryItem.fromJson)
        .toList();
    final medications = (json['medications'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(MedicationItem.fromJson)
        .toList();

    final currentMedications =
        (json['current_medications'] ?? '').toString().trim();

    return MedicalRecordSummary(
      patientId: (patient['id'] ?? '').toString(),
      fullName: (patient['full_name'] ?? '').toString(),
      email: (patient['email'] ?? '').toString(),
      phone: (patient['phone'] ?? '').toString(),
      cpf: (patient['cpf'] ?? '').toString(),
      avatarUrl: resolveApiMediaUrl((patient['avatar_url'] ?? '').toString()),
      dateOfBirth: (patient['date_of_birth'] ?? '').toString(),
      healthInsurance: (patient['health_insurance'] ?? '').toString(),
      allergies: (json['allergies'] ?? '').toString(),
      previousSurgeries: (json['previous_surgeries'] ?? '').toString(),
      currentMedications: currentMedications,
      medications: medications,
      procedureHistory: procedures,
      documents: documents,
    );
  }
}
