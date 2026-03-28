class PostOpChecklistItem {
  const PostOpChecklistItem({
    required this.id,
    required this.dayNumber,
    required this.itemText,
    required this.isCompleted,
  });

  final String id;
  final int dayNumber;
  final String itemText;
  final bool isCompleted;

  factory PostOpChecklistItem.fromJson(Map<String, dynamic> json) {
    return PostOpChecklistItem(
      id: (json['id'] ?? '').toString(),
      dayNumber: int.tryParse((json['day_number'] ?? 0).toString()) ?? 0,
      itemText: (json['item_text'] ?? '').toString(),
      isCompleted: json['is_completed'] == true,
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
      dayNumber: int.tryParse((json['day_number'] ?? 0).toString()) ?? 0,
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      isMilestone: json['is_milestone'] == true,
      status: (json['status'] ?? 'upcoming').toString(),
      checklistItems: items,
    );
  }
}

class PostOpJourney {
  const PostOpJourney({
    required this.id,
    required this.procedureName,
    required this.surgeryDate,
    required this.currentDay,
    required this.protocol,
  });

  final String id;
  final String procedureName;
  final DateTime surgeryDate;
  final int currentDay;
  final List<JourneyProtocolDay> protocol;

  factory PostOpJourney.fromJson(Map<String, dynamic> json) {
    final specialty = (json['specialty'] ?? <String, dynamic>{}) as Map<String, dynamic>;
    final protocol = (json['protocol'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(JourneyProtocolDay.fromJson)
        .toList();

    return PostOpJourney(
      id: (json['id'] ?? '').toString(),
      procedureName: (specialty['name'] ?? 'Procedimento').toString(),
      surgeryDate: DateTime.tryParse((json['surgery_date'] ?? '').toString()) ?? DateTime.now(),
      currentDay: int.tryParse((json['current_day'] ?? 1).toString()) ?? 1,
      protocol: protocol,
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
      dayNumber: int.tryParse((json['day_number'] ?? 0).toString()) ?? 0,
      photoUrl: (json['photo_url'] ?? '').toString(),
      uploadedAt: DateTime.tryParse((json['uploaded_at'] ?? '').toString()) ?? DateTime.now(),
      isAnonymous: json['is_anonymous'] == true,
    );
  }
}
