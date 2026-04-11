import '../../../core/utils/api_media_url.dart';

enum MedicPatientStatus {
  scheduled,
  preOp,
  recovering,
  recovered,
  specialCase,
  inactive,
}

enum PreOperatoryStatus {
  pending,
  inReview,
  approved,
  rejected,
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
    required this.preOperatoryProcedureName,
    required this.dateJoined,
    required this.dateOfBirth,
    required this.avatarUrl,
    required this.bloodType,
    required this.allergies,
    required this.currentMedications,
    required this.notes,
    required this.assignedDoctor,
    required this.preOperatoryStatus,
    required this.hasActiveAppointment,
    required this.hasCompletedSurgery,
  });

  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String rawStatus;
  final MedicPatientStatus medicStatus;
  final String specialtyName;
  final String preOperatoryProcedureName;
  final DateTime? dateJoined;
  final DateTime? dateOfBirth;
  final String avatarUrl;
  final String bloodType;
  final List<String> allergies;
  final List<String> currentMedications;
  final String notes;
  final AssignedDoctorInfo? assignedDoctor;
  final PreOperatoryStatus? preOperatoryStatus;
  final bool hasActiveAppointment;
  final bool hasCompletedSurgery;

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
    final preOperatoryStatus = parsePreOperatoryStatus(
      (json['pre_operatory_status'] ?? '').toString(),
    );
    final hasActiveAppointment = json['has_active_appointment'] == true;
    final hasCompletedSurgery = json['has_completed_surgery'] == true;

    return MedicPatient(
      id: (json['id'] ?? '').toString(),
      fullName: (json['full_name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      rawStatus: rawStatus,
      medicStatus: resolveMedicStatus(
        rawStatus,
        notes,
        hasActiveAppointment: hasActiveAppointment,
        hasCompletedSurgery: hasCompletedSurgery,
        preOperatoryStatus: preOperatoryStatus,
      ),
      specialtyName: (json['specialty_name'] ?? '').toString(),
      preOperatoryProcedureName:
          (json['pre_operatory_procedure_name'] ?? '').toString(),
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
      preOperatoryStatus: preOperatoryStatus,
      hasActiveAppointment: hasActiveAppointment,
      hasCompletedSurgery: hasCompletedSurgery,
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

class PreOperatoryAttachmentItem {
  const PreOperatoryAttachmentItem({
    required this.id,
    required this.fileUrl,
    required this.type,
    required this.createdAt,
  });

  final String id;
  final String fileUrl;
  final String type;
  final DateTime? createdAt;

  bool get isPhoto => type == 'photo';
  bool get isDocument => type == 'document';

  factory PreOperatoryAttachmentItem.fromJson(Map<String, dynamic> json) {
    return PreOperatoryAttachmentItem(
      id: (json['id'] ?? '').toString(),
      fileUrl: resolveApiMediaUrl((json['file_url'] ?? '').toString()),
      type: (json['type'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
    );
  }
}

class PatientPreOperatoryRecord {
  const PatientPreOperatoryRecord({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.patientAvatarUrl,
    required this.status,
    required this.allergies,
    required this.medications,
    required this.previousSurgeries,
    required this.diseases,
    required this.procedureName,
    required this.procedureDescription,
    required this.height,
    required this.weight,
    required this.smokes,
    required this.drinksAlcohol,
    required this.notes,
    required this.assignedDoctorId,
    required this.assignedDoctorName,
    required this.photos,
    required this.documents,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String patientId;
  final String patientName;
  final String patientAvatarUrl;
  final PreOperatoryStatus status;
  final String allergies;
  final String medications;
  final String previousSurgeries;
  final String diseases;
  final String procedureName;
  final String procedureDescription;
  final double? height;
  final double? weight;
  final bool smokes;
  final bool drinksAlcohol;
  final String notes;
  final String? assignedDoctorId;
  final String? assignedDoctorName;
  final List<PreOperatoryAttachmentItem> photos;
  final List<PreOperatoryAttachmentItem> documents;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static List<PreOperatoryAttachmentItem> _extractAttachments(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(PreOperatoryAttachmentItem.fromJson)
        .toList();
  }

  factory PatientPreOperatoryRecord.fromJson(Map<String, dynamic> json) {
    final allFiles = _extractAttachments(json['files']);
    final photoItems = _extractAttachments(json['photos']);
    final documentItems = _extractAttachments(json['documents']);
    final photos = photoItems.isNotEmpty
        ? photoItems
        : allFiles.where((f) => f.isPhoto).toList();
    final documents = documentItems.isNotEmpty
        ? documentItems
        : allFiles.where((f) => f.isDocument).toList();

    return PatientPreOperatoryRecord(
      id: (json['id'] ?? '').toString(),
      patientId: (json['patient'] ?? '').toString(),
      patientName: (json['patient_name'] ?? '').toString(),
      patientAvatarUrl:
          resolveApiMediaUrl((json['patient_avatar_url'] ?? '').toString()),
      status: parsePreOperatoryStatus((json['status'] ?? '').toString()) ??
          PreOperatoryStatus.pending,
      allergies: (json['allergies'] ?? '').toString(),
      medications: (json['medications'] ?? '').toString(),
      previousSurgeries: (json['previous_surgeries'] ?? '').toString(),
      diseases: (json['diseases'] ?? '').toString(),
      procedureName: (json['procedure_name'] ?? '').toString(),
      procedureDescription: (json['procedure_description'] ?? '').toString(),
      height: double.tryParse((json['height'] ?? '').toString()),
      weight: double.tryParse((json['weight'] ?? '').toString()),
      smokes: json['smokes'] == true || json['smoking'] == true,
      drinksAlcohol: json['drinks_alcohol'] == true || json['alcohol'] == true,
      notes: (json['notes'] ?? '').toString(),
      assignedDoctorId:
          (json['assigned_doctor'] ?? '').toString().trim().isEmpty
              ? null
              : (json['assigned_doctor'] ?? '').toString(),
      assignedDoctorName:
          (json['assigned_doctor_name'] ?? '').toString().trim().isEmpty
              ? null
              : (json['assigned_doctor_name'] ?? '').toString(),
      photos: photos,
      documents: documents,
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
      updatedAt: DateTime.tryParse((json['updated_at'] ?? '').toString()),
    );
  }
}

enum PostOperatoryClinicalStatus {
  ok,
  delayed,
  risk,
}

enum PostOperatoryJourneyStatus {
  active,
  completed,
  cancelled,
}

class UrgentTicketItem {
  const UrgentTicketItem({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.message,
    required this.status,
    required this.severity,
    required this.createdAt,
    required this.images,
  });

  final String id;
  final String patientId;
  final String patientName;
  final String message;
  final String status;
  final String severity;
  final DateTime? createdAt;
  final List<String> images;

  bool get isOpen => status == 'open';
  bool get isViewed => status == 'viewed';
  bool get isResolved => status == 'resolved';

  factory UrgentTicketItem.fromJson(Map<String, dynamic> json) {
    final imageItems = (json['images'] as List<dynamic>? ?? const [])
        .map((item) => resolveApiMediaUrl(item.toString()))
        .where((item) => item.trim().isNotEmpty)
        .toList();

    return UrgentTicketItem(
      id: (json['id'] ?? '').toString(),
      patientId: (json['patient'] ?? '').toString(),
      patientName: (json['patient_name'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      status: (json['status'] ?? 'open').toString(),
      severity: (json['severity'] ?? 'high').toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
      images: imageItems,
    );
  }
}

class PatientPostOperatoryCheckin {
  const PatientPostOperatoryCheckin({
    required this.id,
    required this.day,
    required this.painLevel,
    required this.hasFever,
    required this.notes,
    required this.createdAt,
  });

  final String id;
  final int day;
  final int painLevel;
  final bool hasFever;
  final String notes;
  final DateTime? createdAt;

  factory PatientPostOperatoryCheckin.fromJson(Map<String, dynamic> json) {
    return PatientPostOperatoryCheckin(
      id: (json['id'] ?? '').toString(),
      day: int.tryParse((json['day'] ?? '').toString()) ?? 0,
      painLevel: int.tryParse((json['pain_level'] ?? '').toString()) ?? 0,
      hasFever: json['has_fever'] == true,
      notes: (json['notes'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
    );
  }
}

class PatientPostOperatoryPhoto {
  const PatientPostOperatoryPhoto({
    required this.id,
    required this.day,
    required this.imageUrl,
    required this.createdAt,
  });

  final String id;
  final int day;
  final String imageUrl;
  final DateTime? createdAt;

  factory PatientPostOperatoryPhoto.fromJson(Map<String, dynamic> json) {
    return PatientPostOperatoryPhoto(
      id: (json['id'] ?? '').toString(),
      day: int.tryParse((json['day'] ?? '').toString()) ?? 0,
      imageUrl: resolveApiMediaUrl(
        (json['image'] ?? json['photo_url'] ?? '').toString(),
      ),
      createdAt: DateTime.tryParse(
        (json['created_at'] ?? json['uploaded_at'] ?? '').toString(),
      ),
    );
  }
}

class PatientPostOperatoryObservation {
  const PatientPostOperatoryObservation({
    required this.day,
    required this.notes,
    required this.createdAt,
  });

  final int day;
  final String notes;
  final DateTime? createdAt;

  factory PatientPostOperatoryObservation.fromJson(Map<String, dynamic> json) {
    return PatientPostOperatoryObservation(
      day: int.tryParse((json['day'] ?? '').toString()) ?? 0,
      notes: (json['notes'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
    );
  }
}

class PatientPostOperatoryRecord {
  const PatientPostOperatoryRecord({
    required this.journeyId,
    required this.patientId,
    required this.patientName,
    required this.status,
    required this.currentDay,
    required this.totalDays,
    required this.surgeryDate,
    required this.lastCheckinDate,
    required this.lastPainLevel,
    required this.daysWithoutCheckin,
    required this.clinicalStatus,
    required this.checkins,
    required this.photos,
    required this.observations,
  });

  final String journeyId;
  final String patientId;
  final String patientName;
  final PostOperatoryJourneyStatus status;
  final int currentDay;
  final int totalDays;
  final DateTime? surgeryDate;
  final DateTime? lastCheckinDate;
  final int? lastPainLevel;
  final int daysWithoutCheckin;
  final PostOperatoryClinicalStatus clinicalStatus;
  final List<PatientPostOperatoryCheckin> checkins;
  final List<PatientPostOperatoryPhoto> photos;
  final List<PatientPostOperatoryObservation> observations;

  PatientPostOperatoryCheckin? get latestCheckin =>
      checkins.isEmpty ? null : checkins.first;

  bool get requiresAttention {
    final latest = latestCheckin;
    final noCheckin = latest == null || daysWithoutCheckin > 0;
    final highPain = (latest?.painLevel ?? (lastPainLevel ?? 0)) >= 8;
    final fever = latest?.hasFever == true;
    return noCheckin || highPain || fever;
  }

  static List<T> _extractList<T>(
    dynamic raw,
    T Function(Map<String, dynamic>) parser,
  ) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(parser)
        .toList(growable: false);
  }

  factory PatientPostOperatoryRecord.fromJson(Map<String, dynamic> json) {
    return PatientPostOperatoryRecord(
      journeyId: (json['journey_id'] ?? '').toString(),
      patientId: (json['patient_id'] ?? '').toString(),
      patientName: (json['patient_name'] ?? '').toString(),
      status: parsePostOperatoryJourneyStatus(
        (json['status'] ?? '').toString(),
      ),
      currentDay: int.tryParse((json['current_day'] ?? '').toString()) ?? 1,
      totalDays: int.tryParse((json['total_days'] ?? '').toString()) ?? 1,
      surgeryDate: DateTime.tryParse((json['surgery_date'] ?? '').toString()),
      lastCheckinDate:
          DateTime.tryParse((json['last_checkin_date'] ?? '').toString()),
      lastPainLevel: int.tryParse((json['last_pain_level'] ?? '').toString()),
      daysWithoutCheckin:
          int.tryParse((json['days_without_checkin'] ?? '').toString()) ?? 0,
      clinicalStatus: parsePostOperatoryClinicalStatus(
        (json['clinical_status'] ?? '').toString(),
      ),
      checkins: _extractList(
        json['checkins'],
        PatientPostOperatoryCheckin.fromJson,
      ),
      photos: _extractList(
        json['photos'],
        PatientPostOperatoryPhoto.fromJson,
      ),
      observations: _extractList(
        json['observations'],
        PatientPostOperatoryObservation.fromJson,
      ),
    );
  }
}

PostOperatoryJourneyStatus parsePostOperatoryJourneyStatus(String rawStatus) {
  switch (rawStatus.trim().toLowerCase()) {
    case 'completed':
      return PostOperatoryJourneyStatus.completed;
    case 'cancelled':
      return PostOperatoryJourneyStatus.cancelled;
    default:
      return PostOperatoryJourneyStatus.active;
  }
}

PostOperatoryClinicalStatus parsePostOperatoryClinicalStatus(String rawStatus) {
  switch (rawStatus.trim().toLowerCase()) {
    case 'risk':
      return PostOperatoryClinicalStatus.risk;
    case 'delayed':
      return PostOperatoryClinicalStatus.delayed;
    default:
      return PostOperatoryClinicalStatus.ok;
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

PreOperatoryStatus? parsePreOperatoryStatus(String rawStatus) {
  switch (rawStatus.trim().toLowerCase()) {
    case 'pending':
      return PreOperatoryStatus.pending;
    case 'in_review':
      return PreOperatoryStatus.inReview;
    case 'approved':
      return PreOperatoryStatus.approved;
    case 'rejected':
      return PreOperatoryStatus.rejected;
    default:
      return null;
  }
}

String preOperatoryStatusApiValue(PreOperatoryStatus status) {
  switch (status) {
    case PreOperatoryStatus.pending:
      return 'pending';
    case PreOperatoryStatus.inReview:
      return 'in_review';
    case PreOperatoryStatus.approved:
      return 'approved';
    case PreOperatoryStatus.rejected:
      return 'rejected';
  }
}

MedicPatientStatus resolveMedicStatus(
  String rawStatus,
  String notes, {
  required bool hasActiveAppointment,
  required bool hasCompletedSurgery,
  required PreOperatoryStatus? preOperatoryStatus,
}) {
  final normalizedRaw = rawStatus.trim().toLowerCase();
  final normalizedNotes = notes.toLowerCase();

  final tagLine =
      notes.split('\n').map((line) => line.trim().toLowerCase()).firstWhere(
            (line) => line.startsWith(_statusTagPrefix),
            orElse: () => '',
          );

  final tag = tagLine.replaceFirst(_statusTagPrefix, '').trim();
  if (tag == 'scheduled' && hasActiveAppointment && !hasCompletedSurgery) {
    return MedicPatientStatus.scheduled;
  }
  switch (tag) {
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
  if (hasCompletedSurgery) return MedicPatientStatus.recovering;
  if (hasActiveAppointment) return MedicPatientStatus.scheduled;
  if (preOperatoryStatus != null) return MedicPatientStatus.preOp;
  if (normalizedRaw == 'lead') return MedicPatientStatus.preOp;
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
