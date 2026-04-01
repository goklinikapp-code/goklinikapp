import '../../../core/utils/api_media_url.dart';

enum MedicPatientStatus {
  scheduled,
  preOp,
  recovering,
  recovered,
  specialCase,
  inactive,
}

class AssignedDoctorInfo {
  const AssignedDoctorInfo({
    required this.id,
    required this.name,
    required this.phone,
    required this.specialty,
  });

  final String id;
  final String name;
  final String phone;
  final String specialty;

  factory AssignedDoctorInfo.fromJson(Map<String, dynamic> json) {
    return AssignedDoctorInfo(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      specialty: (json['specialty'] ?? '').toString(),
    );
  }
}

class MedicPatient {
  const MedicPatient({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.rawStatus,
    required this.medicStatus,
    required this.specialtyName,
    required this.dateJoined,
    required this.dateOfBirth,
    required this.avatarUrl,
    required this.bloodType,
    required this.allergies,
    required this.currentMedications,
    required this.notes,
    required this.assignedDoctor,
  });

  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String rawStatus;
  final MedicPatientStatus medicStatus;
  final String specialtyName;
  final DateTime? dateJoined;
  final DateTime? dateOfBirth;
  final String avatarUrl;
  final String bloodType;
  final List<String> allergies;
  final List<String> currentMedications;
  final String notes;
  final AssignedDoctorInfo? assignedDoctor;

  int? get age {
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    var years = now.year - dateOfBirth!.year;
    final hasBirthdayPassed = now.month > dateOfBirth!.month ||
        (now.month == dateOfBirth!.month && now.day >= dateOfBirth!.day);
    if (!hasBirthdayPassed) years -= 1;
    return years < 0 ? null : years;
  }

  factory MedicPatient.fromJson(Map<String, dynamic> json) {
    final notes = (json['notes'] ?? '').toString();
    final rawStatus = (json['status'] ?? 'lead').toString();
    return MedicPatient(
      id: (json['id'] ?? '').toString(),
      fullName: (json['full_name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      rawStatus: rawStatus,
      medicStatus: resolveMedicStatus(rawStatus, notes),
      specialtyName: (json['specialty_name'] ?? '').toString(),
      dateJoined: DateTime.tryParse((json['date_joined'] ?? '').toString()),
      dateOfBirth: DateTime.tryParse((json['date_of_birth'] ?? '').toString()),
      avatarUrl: resolveApiMediaUrl((json['avatar_url'] ?? '').toString()),
      bloodType: (json['blood_type'] ?? '').toString(),
      allergies: _splitCsv((json['allergies'] ?? '').toString()),
      currentMedications:
          _splitCsv((json['current_medications'] ?? '').toString()),
      notes: notes,
      assignedDoctor: json['assigned_doctor'] is Map<String, dynamic>
          ? AssignedDoctorInfo.fromJson(
              json['assigned_doctor'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  static List<String> _splitCsv(String raw) {
    return raw
        .split(RegExp(r'[\n,;]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
}

class PatientTimelineItem {
  const PatientTimelineItem({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.category,
  });

  final String id;
  final String title;
  final String description;
  final DateTime? date;
  final String category;
}

class MedicalDocumentItem {
  const MedicalDocumentItem({
    required this.id,
    required this.title,
    required this.documentType,
    required this.fileUrl,
    required this.uploadedAt,
  });

  final String id;
  final String title;
  final String documentType;
  final String fileUrl;
  final DateTime? uploadedAt;

  factory MedicalDocumentItem.fromJson(Map<String, dynamic> json) {
    return MedicalDocumentItem(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      documentType: (json['document_type'] ?? '').toString(),
      fileUrl: resolveApiMediaUrl((json['file_url'] ?? '').toString()),
      uploadedAt: DateTime.tryParse((json['uploaded_at'] ?? '').toString()),
    );
  }
}

class PostOpJourneySummary {
  const PostOpJourneySummary({
    required this.id,
    required this.patientId,
  });

  final String id;
  final String patientId;

  factory PostOpJourneySummary.fromJson(Map<String, dynamic> json) {
    return PostOpJourneySummary(
      id: (json['id'] ?? '').toString(),
      patientId: (json['patient_id'] ?? '').toString(),
    );
  }
}

class EvolutionPhotoItem {
  const EvolutionPhotoItem({
    required this.id,
    required this.dayNumber,
    required this.photoUrl,
    required this.uploadedAt,
  });

  final String id;
  final int dayNumber;
  final String photoUrl;
  final DateTime? uploadedAt;

  factory EvolutionPhotoItem.fromJson(Map<String, dynamic> json) {
    return EvolutionPhotoItem(
      id: (json['id'] ?? '').toString(),
      dayNumber: int.tryParse((json['day_number'] ?? 0).toString()) ?? 0,
      photoUrl: resolveApiMediaUrl((json['photo_url'] ?? '').toString()),
      uploadedAt: DateTime.tryParse((json['uploaded_at'] ?? '').toString()),
    );
  }
}

class ProntuarioMedicationItem {
  const ProntuarioMedicationItem({
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
    required this.criadoEm,
    required this.atualizadoEm,
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
  final DateTime? criadoEm;
  final DateTime? atualizadoEm;

  factory ProntuarioMedicationItem.fromJson(Map<String, dynamic> json) {
    return ProntuarioMedicationItem(
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
      criadoEm: DateTime.tryParse((json['criado_em'] ?? '').toString()),
      atualizadoEm: DateTime.tryParse((json['atualizado_em'] ?? '').toString()),
    );
  }
}

class ProntuarioProcedureImageItem {
  const ProntuarioProcedureImageItem({
    required this.id,
    required this.imageUrl,
    required this.criadoEm,
  });

  final String id;
  final String imageUrl;
  final DateTime? criadoEm;

  factory ProntuarioProcedureImageItem.fromJson(Map<String, dynamic> json) {
    return ProntuarioProcedureImageItem(
      id: (json['id'] ?? '').toString(),
      imageUrl: resolveApiMediaUrl((json['image_url'] ?? '').toString()),
      criadoEm: DateTime.tryParse((json['criado_em'] ?? '').toString()),
    );
  }
}

class ProntuarioProcedureItem {
  const ProntuarioProcedureItem({
    required this.id,
    required this.nomeProcedimento,
    required this.descricao,
    required this.dataProcedimento,
    required this.profissionalResponsavel,
    required this.observacoes,
    required this.images,
    required this.criadoEm,
    required this.atualizadoEm,
  });

  final String id;
  final String nomeProcedimento;
  final String descricao;
  final DateTime? dataProcedimento;
  final String profissionalResponsavel;
  final String observacoes;
  final List<ProntuarioProcedureImageItem> images;
  final DateTime? criadoEm;
  final DateTime? atualizadoEm;

  factory ProntuarioProcedureItem.fromJson(Map<String, dynamic> json) {
    final images = (json['images'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ProntuarioProcedureImageItem.fromJson)
        .toList();
    return ProntuarioProcedureItem(
      id: (json['id'] ?? '').toString(),
      nomeProcedimento: (json['nome_procedimento'] ?? '').toString(),
      descricao: (json['descricao'] ?? '').toString(),
      dataProcedimento:
          DateTime.tryParse((json['data_procedimento'] ?? '').toString()),
      profissionalResponsavel:
          (json['profissional_responsavel'] ?? '').toString(),
      observacoes: (json['observacoes'] ?? '').toString(),
      images: images,
      criadoEm: DateTime.tryParse((json['criado_em'] ?? '').toString()),
      atualizadoEm: DateTime.tryParse((json['atualizado_em'] ?? '').toString()),
    );
  }
}

class ProntuarioDocumentItem {
  const ProntuarioDocumentItem({
    required this.id,
    required this.titulo,
    required this.descricao,
    required this.arquivoUrl,
    required this.tipoArquivo,
    required this.uploadedBy,
    required this.criadoEm,
  });

  final String id;
  final String titulo;
  final String descricao;
  final String arquivoUrl;
  final String tipoArquivo;
  final String uploadedBy;
  final DateTime? criadoEm;

  factory ProntuarioDocumentItem.fromJson(Map<String, dynamic> json) {
    return ProntuarioDocumentItem(
      id: (json['id'] ?? '').toString(),
      titulo: (json['titulo'] ?? '').toString(),
      descricao: (json['descricao'] ?? '').toString(),
      arquivoUrl: resolveApiMediaUrl((json['arquivo_url'] ?? '').toString()),
      tipoArquivo: (json['tipo_arquivo'] ?? '').toString(),
      uploadedBy: (json['uploaded_by'] ?? '').toString(),
      criadoEm: DateTime.tryParse((json['criado_em'] ?? '').toString()),
    );
  }
}

const _statusTagPrefix = '#medic_status:';

MedicPatientStatus resolveMedicStatus(String rawStatus, String notes) {
  final normalizedRaw = rawStatus.trim().toLowerCase();
  final normalizedNotes = notes.toLowerCase();

  final tagLine =
      notes.split('\n').map((line) => line.trim().toLowerCase()).firstWhere(
            (line) => line.startsWith(_statusTagPrefix),
            orElse: () => '',
          );

  final tag = tagLine.replaceFirst(_statusTagPrefix, '').trim();
  switch (tag) {
    case 'scheduled':
      return MedicPatientStatus.scheduled;
    case 'pre_op':
      return MedicPatientStatus.preOp;
    case 'recovering':
      return MedicPatientStatus.recovering;
    case 'recovered':
      return MedicPatientStatus.recovered;
    case 'special_case':
      return MedicPatientStatus.specialCase;
    case 'inactive':
      return MedicPatientStatus.inactive;
  }

  if (normalizedRaw == 'inactive') return MedicPatientStatus.inactive;
  if (normalizedNotes.contains('caso especial') ||
      normalizedNotes.contains('special case')) {
    return MedicPatientStatus.specialCase;
  }
  if (normalizedRaw == 'lead') return MedicPatientStatus.scheduled;
  return MedicPatientStatus.recovering;
}

Map<String, String> buildPatientStatusPayload({
  required MedicPatientStatus status,
  required String existingNotes,
}) {
  final cleanedNotes = existingNotes
      .split('\n')
      .where((line) => !line.trim().toLowerCase().startsWith(_statusTagPrefix))
      .join('\n')
      .trim();

  final statusTag = switch (status) {
    MedicPatientStatus.scheduled => 'scheduled',
    MedicPatientStatus.preOp => 'pre_op',
    MedicPatientStatus.recovering => 'recovering',
    MedicPatientStatus.recovered => 'recovered',
    MedicPatientStatus.specialCase => 'special_case',
    MedicPatientStatus.inactive => 'inactive',
  };

  final rawStatus = switch (status) {
    MedicPatientStatus.scheduled => 'lead',
    MedicPatientStatus.preOp => 'lead',
    MedicPatientStatus.recovering => 'active',
    MedicPatientStatus.recovered => 'active',
    MedicPatientStatus.specialCase => 'active',
    MedicPatientStatus.inactive => 'inactive',
  };

  final notes = StringBuffer('#medic_status:$statusTag');
  if (cleanedNotes.isNotEmpty) {
    notes.writeln();
    notes.write(cleanedNotes);
  }

  return {
    'status': rawStatus,
    'notes': notes.toString(),
  };
}
