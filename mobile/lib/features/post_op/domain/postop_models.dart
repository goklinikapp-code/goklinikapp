import '../../../core/utils/api_media_url.dart';

class PostOpChecklistItem {
  const PostOpChecklistItem({
    required this.id,
    required this.dayNumber,
    required this.itemText,
    required this.isCompleted,
    this.completedAt,
  });

  final String id;
  final int dayNumber;
  final String itemText;
  final bool isCompleted;
  final DateTime? completedAt;

  factory PostOpChecklistItem.fromJson(Map<String, dynamic> json) {
    return PostOpChecklistItem(
      id: (json['id'] ?? '').toString(),
      dayNumber:
          int.tryParse((json['day_number'] ?? json['day'] ?? 0).toString()) ??
              0,
      itemText: (json['item_text'] ?? json['title'] ?? '').toString(),
      isCompleted: json['is_completed'] == true || json['completed'] == true,
      completedAt: DateTime.tryParse((json['completed_at'] ?? '').toString()),
    );
  }

  PostOpChecklistItem copyWith({
    bool? isCompleted,
    DateTime? completedAt,
  }) {
    return PostOpChecklistItem(
      id: id,
      dayNumber: dayNumber,
      itemText: itemText,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

class JourneyProtocolDay {
  const JourneyProtocolDay({
    required this.dayNumber,
    required this.title,
    required this.description,
    required this.isMilestone,
    required this.status,
    required this.checklistItems,
  });

  final int dayNumber;
  final String title;
  final String description;
  final bool isMilestone;
  final String status;
  final List<PostOpChecklistItem> checklistItems;

  bool get isToday => status == 'today';

  factory JourneyProtocolDay.fromJson(Map<String, dynamic> json) {
    final items = (json['checklist_items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(PostOpChecklistItem.fromJson)
        .toList();

    return JourneyProtocolDay(
      dayNumber:
          int.tryParse((json['day_number'] ?? json['day'] ?? 0).toString()) ??
              0,
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      isMilestone: json['is_milestone'] == true,
      status: (json['status'] ?? 'upcoming').toString(),
      checklistItems: items,
    );
  }
}

class PostOperatoryCheckin {
  const PostOperatoryCheckin({
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
  final DateTime createdAt;

  factory PostOperatoryCheckin.fromJson(Map<String, dynamic> json) {
    return PostOperatoryCheckin(
      id: (json['id'] ?? '').toString(),
      day: int.tryParse((json['day'] ?? 0).toString()) ?? 0,
      painLevel: int.tryParse((json['pain_level'] ?? 0).toString()) ?? 0,
      hasFever: json['has_fever'] == true,
      notes: (json['notes'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

class PostOperatoryHistoryItem {
  const PostOperatoryHistoryItem({
    required this.day,
    required this.title,
    required this.status,
    required this.hasCheckin,
    required this.checklistCompleted,
  });

  final int day;
  final String title;
  final String status;
  final bool hasCheckin;
  final bool checklistCompleted;

  factory PostOperatoryHistoryItem.fromJson(Map<String, dynamic> json) {
    return PostOperatoryHistoryItem(
      day: int.tryParse((json['day'] ?? 0).toString()) ?? 0,
      title: (json['title'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      hasCheckin: json['has_checkin'] == true,
      checklistCompleted: json['checklist_completed'] == true,
    );
  }
}

class PostOpJourney {
  const PostOpJourney({
    required this.id,
    required this.procedureName,
    required this.surgeryDate,
    required this.currentDay,
    required this.totalDays,
    required this.status,
    required this.protocol,
    required this.todayChecklist,
    required this.checkinSubmittedToday,
    required this.checkins,
    required this.photos,
    required this.history,
    this.startDate,
    this.endDate,
    this.todayCheckin,
  });

  final String id;
  final String procedureName;
  final DateTime surgeryDate;
  final DateTime? startDate;
  final DateTime? endDate;
  final int currentDay;
  final int totalDays;
  final String status;
  final List<JourneyProtocolDay> protocol;
  final List<PostOpChecklistItem> todayChecklist;
  final bool checkinSubmittedToday;
  final PostOperatoryCheckin? todayCheckin;
  final List<PostOperatoryCheckin> checkins;
  final List<EvolutionPhotoItem> photos;
  final List<PostOperatoryHistoryItem> history;

  bool get isActive => status == 'active';

  factory PostOpJourney.fromJson(Map<String, dynamic> json) {
    final specialty =
        (json['specialty'] ?? <String, dynamic>{}) as Map<String, dynamic>;
    final protocol = (json['protocol'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(JourneyProtocolDay.fromJson)
        .toList();
    final todayChecklist =
        (json['today_checklist'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(PostOpChecklistItem.fromJson)
            .toList();
    final checkins = (json['checkins'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(PostOperatoryCheckin.fromJson)
        .toList();
    final photos = (json['photos'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(EvolutionPhotoItem.fromJson)
        .toList();
    final history = (json['history'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(PostOperatoryHistoryItem.fromJson)
        .toList();

    final int currentDay =
        int.tryParse((json['current_day'] ?? 1).toString()) ?? 1;
    final int totalDaysRaw =
        int.tryParse((json['total_days'] ?? currentDay).toString()) ??
            currentDay;

    return PostOpJourney(
      id: (json['id'] ?? '').toString(),
      procedureName: (specialty['name'] ?? 'Procedimento').toString(),
      surgeryDate: DateTime.tryParse((json['surgery_date'] ?? '').toString()) ??
          DateTime.now(),
      startDate: DateTime.tryParse((json['start_date'] ?? '').toString()),
      endDate: DateTime.tryParse((json['end_date'] ?? '').toString()),
      currentDay: currentDay,
      totalDays: totalDaysRaw < currentDay ? currentDay : totalDaysRaw,
      status: (json['status'] ?? 'active').toString(),
      protocol: protocol,
      todayChecklist: todayChecklist,
      checkinSubmittedToday: json['checkin_submitted_today'] == true,
      todayCheckin: json['today_checkin'] is Map<String, dynamic>
          ? PostOperatoryCheckin.fromJson(
              json['today_checkin'] as Map<String, dynamic>,
            )
          : null,
      checkins: checkins,
      photos: photos,
      history: history,
    );
  }
}

class CareCenterData {
  const CareCenterData({
    required this.faqs,
    required this.medications,
    required this.guidanceLinks,
  });

  final List<Map<String, String>> faqs;
  final List<Map<String, String>> medications;
  final List<String> guidanceLinks;

  factory CareCenterData.fromJson(Map<String, dynamic> json) {
    final faqs = (json['faqs'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((item) => {
              'question': (item['question'] ?? '').toString(),
              'answer': (item['answer'] ?? '').toString(),
            })
        .toList();

    final meds = (json['medications'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((item) => {
              'name': (item['name'] ?? '').toString(),
              'dosage': (item['dosage'] ?? '').toString(),
              'schedule': (item['schedule'] ?? '').toString(),
            })
        .toList();

    final links = (json['guidance_links'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toList();

    return CareCenterData(faqs: faqs, medications: meds, guidanceLinks: links);
  }
}

class EvolutionPhotoItem {
  const EvolutionPhotoItem({
    required this.id,
    required this.dayNumber,
    required this.photoUrl,
    required this.uploadedAt,
    required this.isAnonymous,
  });

  final String id;
  final int dayNumber;
  final String photoUrl;
  final DateTime uploadedAt;
  final bool isAnonymous;

  factory EvolutionPhotoItem.fromJson(Map<String, dynamic> json) {
    return EvolutionPhotoItem(
      id: (json['id'] ?? '').toString(),
      dayNumber:
          int.tryParse((json['day_number'] ?? json['day'] ?? 0).toString()) ??
              0,
      photoUrl: resolveApiMediaUrl(
        (json['photo_url'] ?? json['image'] ?? '').toString(),
      ),
      uploadedAt: DateTime.tryParse(
            (json['uploaded_at'] ?? json['created_at'] ?? '').toString(),
          ) ??
          DateTime.now(),
      isAnonymous: json['is_anonymous'] == true,
    );
  }
}

class UrgentMedicalRequest {
  const UrgentMedicalRequest({
    required this.id,
    required this.status,
    required this.question,
    required this.answer,
    required this.createdAt,
    this.answeredAt,
  });

  final String id;
  final String status;
  final String question;
  final String answer;
  final DateTime createdAt;
  final DateTime? answeredAt;

  bool get isAnswered => status == 'answered';

  factory UrgentMedicalRequest.fromJson(Map<String, dynamic> json) {
    return UrgentMedicalRequest(
      id: (json['id'] ?? '').toString(),
      status: (json['status'] ?? 'open').toString(),
      question: (json['question'] ?? '').toString(),
      answer: (json['answer'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
      answeredAt: DateTime.tryParse((json['answered_at'] ?? '').toString()),
    );
  }
}

class UrgentTicket {
  const UrgentTicket({
    required this.id,
    required this.message,
    required this.images,
    required this.severity,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String message;
  final List<String> images;
  final String severity;
  final String status;
  final DateTime createdAt;

  factory UrgentTicket.fromJson(Map<String, dynamic> json) {
    final rawImages = (json['images'] as List<dynamic>? ?? const [])
        .map((item) => resolveApiMediaUrl(item.toString()))
        .where((item) => item.trim().isNotEmpty)
        .toList();

    return UrgentTicket(
      id: (json['id'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      images: rawImages,
      severity: (json['severity'] ?? 'high').toString(),
      status: (json['status'] ?? 'open').toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}
