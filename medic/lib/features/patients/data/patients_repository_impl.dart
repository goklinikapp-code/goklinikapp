import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import '../domain/patient_models.dart';
import '../domain/patients_repository.dart';

class PatientsRepositoryImpl implements PatientsRepository {
  PatientsRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<List<MedicPatient>> getMyPatients({String? professionalId}) async {
    dynamic data;
    try {
      final response = await _dio.get<dynamic>(
        ApiEndpoints.patientsMyPatients,
        queryParameters: (professionalId != null && professionalId.isNotEmpty)
            ? {'professional_id': professionalId}
            : null,
      );
      data = response.data;
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      if (statusCode != 403 && statusCode != 404) rethrow;

      // Backward compatible fallback if the backend does not expose /my-patients.
      final fallbackResponse = await _dio.get<dynamic>(
        ApiEndpoints.patients,
        queryParameters: (professionalId != null && professionalId.isNotEmpty)
            ? {'professional': professionalId}
            : null,
      );
      data = fallbackResponse.data;
    }

    final list = _extractList(data);
    return list.map(MedicPatient.fromJson).toList();
  }

  @override
  Future<MedicPatient> getPatientDetail(String patientId) async {
    final response =
        await _dio.get<dynamic>(ApiEndpoints.patientDetail(patientId));
    return MedicPatient.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<MedicPatient> updatePatientStatus({
    required String patientId,
    required MedicPatientStatus status,
    required String currentNotes,
  }) async {
    final payload = buildPatientStatusPayload(
      status: status,
      existingNotes: currentNotes,
    );
    final response = await _dio.patch<dynamic>(
      ApiEndpoints.patientDetail(patientId),
      data: payload,
    );
    return MedicPatient.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<MedicPatient> updatePatientNotes({
    required String patientId,
    required String notes,
  }) async {
    final response = await _dio.patch<dynamic>(
      ApiEndpoints.patientDetail(patientId),
      data: {'notes': notes},
    );
    return MedicPatient.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<List<PatientTimelineItem>> getPatientHistory(String patientId) async {
    final completedAppointmentsResponse = await _dio.get<dynamic>(
      ApiEndpoints.appointments,
      queryParameters: {
        'patient': patientId,
        'status': 'completed',
      },
    );
    final appointments =
        _extractList(completedAppointmentsResponse.data).map((item) {
      final date =
          DateTime.tryParse((item['appointment_date'] ?? '').toString());
      final time = (item['appointment_time'] ?? '').toString();
      final dateTime = _mergeDateAndTime(date, time);
      return PatientTimelineItem(
        id: (item['id'] ?? '').toString(),
        title: (item['specialty_name'] ?? 'Procedimento').toString(),
        description: (item['notes'] ?? '').toString(),
        date: dateTime,
        category: 'appointment',
      );
    }).toList();

    final docs = await getPatientDocuments(patientId);
    final docsTimeline = docs
        .map(
          (doc) => PatientTimelineItem(
            id: doc.id,
            title: doc.title,
            description: doc.documentType,
            date: doc.uploadedAt,
            category: 'document',
          ),
        )
        .toList();

    final merged = [...appointments, ...docsTimeline]..sort((a, b) {
        final aDate = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
    return merged;
  }

  @override
  Future<List<MedicalDocumentItem>> getPatientDocuments(
      String patientId) async {
    final response = await _dio.get<dynamic>(
      ApiEndpoints.medicalRecordDocuments(patientId),
    );
    final list = _extractList(response.data);
    return list.map(MedicalDocumentItem.fromJson).toList();
  }

  @override
  Future<List<ProntuarioMedicationItem>> getPatientProntuarioMedications(
      String patientId) async {
    final response = await _dio.get<dynamic>(
      ApiEndpoints.medicalRecordProntuarioMedications(patientId),
    );
    final list = _extractList(response.data);
    return list.map(ProntuarioMedicationItem.fromJson).toList();
  }

  @override
  Future<ProntuarioMedicationItem> createPatientProntuarioMedication({
    required String patientId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _dio.post<dynamic>(
      ApiEndpoints.medicalRecordProntuarioMedications(patientId),
      data: payload,
    );
    return ProntuarioMedicationItem.fromJson(
        _extractMap(response.data) ?? <String, dynamic>{});
  }

  @override
  Future<ProntuarioMedicationItem> updatePatientProntuarioMedication({
    required String patientId,
    required String medicationId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _dio.patch<dynamic>(
      ApiEndpoints.medicalRecordProntuarioMedicationDetail(
          patientId, medicationId),
      data: payload,
    );
    return ProntuarioMedicationItem.fromJson(
        _extractMap(response.data) ?? <String, dynamic>{});
  }

  @override
  Future<void> deactivatePatientProntuarioMedication({
    required String patientId,
    required String medicationId,
  }) async {
    await _dio.delete<dynamic>(
      ApiEndpoints.medicalRecordProntuarioMedicationDetail(
          patientId, medicationId),
    );
  }

  @override
  Future<List<ProntuarioProcedureItem>> getPatientProntuarioProcedures(
      String patientId) async {
    final response = await _dio.get<dynamic>(
      ApiEndpoints.medicalRecordProntuarioProcedures(patientId),
    );
    final list = _extractList(response.data);
    return list.map(ProntuarioProcedureItem.fromJson).toList();
  }

  @override
  Future<ProntuarioProcedureItem> createPatientProntuarioProcedure({
    required String patientId,
    required Map<String, dynamic> payload,
    required List<File> images,
  }) async {
    final formData = await _buildProcedureFormData(payload, images);
    final response = await _dio.post<dynamic>(
      ApiEndpoints.medicalRecordProntuarioProcedures(patientId),
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return ProntuarioProcedureItem.fromJson(
        _extractMap(response.data) ?? <String, dynamic>{});
  }

  @override
  Future<ProntuarioProcedureItem> updatePatientProntuarioProcedure({
    required String patientId,
    required String procedureId,
    required Map<String, dynamic> payload,
    required List<File> images,
  }) async {
    final formData = await _buildProcedureFormData(payload, images);
    final response = await _dio.patch<dynamic>(
      ApiEndpoints.medicalRecordProntuarioProcedureDetail(
          patientId, procedureId),
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return ProntuarioProcedureItem.fromJson(
        _extractMap(response.data) ?? <String, dynamic>{});
  }

  @override
  Future<void> deletePatientProntuarioProcedureImage({
    required String patientId,
    required String procedureId,
    required String imageId,
  }) async {
    await _dio.delete<dynamic>(
      ApiEndpoints.medicalRecordProntuarioProcedureImageDetail(
        patientId,
        procedureId,
        imageId,
      ),
    );
  }

  @override
  Future<void> deletePatientProntuarioProcedure({
    required String patientId,
    required String procedureId,
  }) async {
    await _dio.delete<dynamic>(
      ApiEndpoints.medicalRecordProntuarioProcedureDetail(
          patientId, procedureId),
    );
  }

  @override
  Future<List<ProntuarioDocumentItem>> getPatientProntuarioDocuments(
      String patientId) async {
    final response = await _dio.get<dynamic>(
      ApiEndpoints.medicalRecordProntuarioDocuments(patientId),
    );
    final list = _extractList(response.data);
    return list.map(ProntuarioDocumentItem.fromJson).toList();
  }

  @override
  Future<ProntuarioDocumentItem> createPatientProntuarioDocument({
    required String patientId,
    required Map<String, dynamic> payload,
    File? file,
  }) async {
    final formData = await _buildDocumentFormData(payload, file);
    final response = await _dio.post<dynamic>(
      ApiEndpoints.medicalRecordProntuarioDocuments(patientId),
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return ProntuarioDocumentItem.fromJson(
        _extractMap(response.data) ?? <String, dynamic>{});
  }

  @override
  Future<ProntuarioDocumentItem> updatePatientProntuarioDocument({
    required String patientId,
    required String documentId,
    required Map<String, dynamic> payload,
    File? file,
  }) async {
    final formData = await _buildDocumentFormData(payload, file);
    final response = await _dio.patch<dynamic>(
      ApiEndpoints.medicalRecordProntuarioDocumentDetail(patientId, documentId),
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return ProntuarioDocumentItem.fromJson(
        _extractMap(response.data) ?? <String, dynamic>{});
  }

  @override
  Future<void> deletePatientProntuarioDocument({
    required String patientId,
    required String documentId,
  }) async {
    await _dio.delete<dynamic>(
      ApiEndpoints.medicalRecordProntuarioDocumentDetail(patientId, documentId),
    );
  }

  @override
  Future<PostOpJourneySummary?> getActiveJourneyForPatient(
      String patientId) async {
    final response = await _dio.get<dynamic>(ApiEndpoints.postOpAdminJourneys);
    final list =
        _extractList(response.data).map(PostOpJourneySummary.fromJson).toList();
    for (final journey in list) {
      if (journey.patientId == patientId) {
        return journey;
      }
    }
    return null;
  }

  @override
  Future<List<EvolutionPhotoItem>> getJourneyPhotos(String journeyId) async {
    final response =
        await _dio.get<dynamic>(ApiEndpoints.postOpPhotosByJourney(journeyId));
    final list = _extractList(response.data);
    return list.map(EvolutionPhotoItem.fromJson).toList();
  }

  @override
  Future<EvolutionPhotoItem> uploadJourneyPhoto({
    required String journeyId,
    required int dayNumber,
    required File file,
  }) async {
    final formData = FormData.fromMap({
      'journey_id': journeyId,
      'day_number': dayNumber,
      'photo': await MultipartFile.fromFile(file.path),
    });
    final response = await _dio.post<dynamic>(
      ApiEndpoints.postOpPhotos,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return EvolutionPhotoItem.fromJson(response.data as Map<String, dynamic>);
  }

  DateTime? _mergeDateAndTime(DateTime? date, String timeRaw) {
    if (date == null) return null;
    final parts = timeRaw.split(':');
    if (parts.length < 2) return date;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  List<Map<String, dynamic>> _extractList(dynamic data) {
    if (data is List<dynamic>) {
      return data.whereType<Map<String, dynamic>>().toList();
    }
    if (data is Map) {
      final results = data['results'];
      if (results is List<dynamic>) {
        return results.whereType<Map<String, dynamic>>().toList();
      }
    }
    return const [];
  }

  Map<String, dynamic>? _extractMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  Future<FormData> _buildProcedureFormData(
    Map<String, dynamic> payload,
    List<File> images,
  ) async {
    final formMap = <String, dynamic>{...payload};
    if (images.isNotEmpty) {
      formMap['images'] = [
        for (final image in images) await MultipartFile.fromFile(image.path)
      ];
    }
    return FormData.fromMap(formMap);
  }

  Future<FormData> _buildDocumentFormData(
    Map<String, dynamic> payload,
    File? file,
  ) async {
    final formMap = <String, dynamic>{...payload};
    if (file != null) {
      formMap['file'] = await MultipartFile.fromFile(file.path);
    }
    return FormData.fromMap(formMap);
  }
}

final patientsRepositoryProvider = Provider<PatientsRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return PatientsRepositoryImpl(dio);
});
