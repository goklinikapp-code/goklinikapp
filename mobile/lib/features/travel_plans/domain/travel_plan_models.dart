class FlightInfo {
  const FlightInfo({
    required this.id,
    required this.direction,
    required this.flightNumber,
    required this.flightDate,
    required this.flightTime,
    required this.airport,
    required this.airline,
    required this.observations,
  });

  final String id;
  final String direction;
  final String flightNumber;
  final DateTime flightDate;
  final String flightTime;
  final String airport;
  final String airline;
  final String observations;

  DateTime get dateTime => _combineDateAndTime(flightDate, flightTime);

  factory FlightInfo.fromJson(Map<String, dynamic> json) {
    return FlightInfo(
      id: (json['id'] ?? '').toString(),
      direction: (json['direction'] ?? '').toString(),
      flightNumber: (json['flight_number'] ?? '').toString(),
      flightDate:
          DateTime.tryParse((json['flight_date'] ?? '').toString()) ??
              DateTime.now(),
      flightTime: (json['flight_time'] ?? '').toString(),
      airport: (json['airport'] ?? '').toString(),
      airline: (json['airline'] ?? '').toString(),
      observations: (json['observations'] ?? '').toString(),
    );
  }
}

class HotelInfo {
  const HotelInfo({
    required this.id,
    required this.hotelName,
    required this.address,
    required this.checkinDate,
    required this.checkinTime,
    required this.checkoutDate,
    required this.checkoutTime,
    required this.roomNumber,
    required this.hotelPhone,
    required this.locationLink,
    required this.observations,
  });

  final String id;
  final String hotelName;
  final String address;
  final DateTime checkinDate;
  final String checkinTime;
  final DateTime checkoutDate;
  final String checkoutTime;
  final String roomNumber;
  final String hotelPhone;
  final String locationLink;
  final String observations;

  DateTime get checkinDateTime => _combineDateAndTime(checkinDate, checkinTime);
  DateTime get checkoutDateTime => _combineDateAndTime(checkoutDate, checkoutTime);

  factory HotelInfo.fromJson(Map<String, dynamic> json) {
    return HotelInfo(
      id: (json['id'] ?? '').toString(),
      hotelName: (json['hotel_name'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      checkinDate:
          DateTime.tryParse((json['checkin_date'] ?? '').toString()) ??
              DateTime.now(),
      checkinTime: (json['checkin_time'] ?? '').toString(),
      checkoutDate:
          DateTime.tryParse((json['checkout_date'] ?? '').toString()) ??
              DateTime.now(),
      checkoutTime: (json['checkout_time'] ?? '').toString(),
      roomNumber: (json['room_number'] ?? '').toString(),
      hotelPhone: (json['hotel_phone'] ?? '').toString(),
      locationLink: (json['location_link'] ?? '').toString(),
      observations: (json['observations'] ?? '').toString(),
    );
  }
}

class TransferItem {
  const TransferItem({
    required this.id,
    required this.title,
    required this.transferDate,
    required this.transferTime,
    required this.origin,
    required this.destination,
    required this.observations,
    required this.status,
    required this.confirmedByPatient,
    required this.confirmedAt,
    required this.displayOrder,
  });

  final String id;
  final String title;
  final DateTime transferDate;
  final String transferTime;
  final String origin;
  final String destination;
  final String observations;
  final String status;
  final bool confirmedByPatient;
  final DateTime? confirmedAt;
  final int displayOrder;

  DateTime get dateTime => _combineDateAndTime(transferDate, transferTime);

  bool get canConfirmRead => status == 'confirmed' && !confirmedByPatient;

  factory TransferItem.fromJson(Map<String, dynamic> json) {
    return TransferItem(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      transferDate:
          DateTime.tryParse((json['transfer_date'] ?? '').toString()) ??
              DateTime.now(),
      transferTime: (json['transfer_time'] ?? '').toString(),
      origin: (json['origin'] ?? '').toString(),
      destination: (json['destination'] ?? '').toString(),
      observations: (json['observations'] ?? '').toString(),
      status: (json['status'] ?? 'scheduled').toString(),
      confirmedByPatient: json['confirmed_by_patient'] == true,
      confirmedAt: DateTime.tryParse((json['confirmed_at'] ?? '').toString()),
      displayOrder: int.tryParse((json['display_order'] ?? '').toString()) ?? 0,
    );
  }
}

class TravelPlanModel {
  const TravelPlanModel({
    required this.id,
    required this.passportNumber,
    required this.arrivalFlight,
    required this.departureFlight,
    required this.hotel,
    required this.transfers,
  });

  final String id;
  final String passportNumber;
  final FlightInfo? arrivalFlight;
  final FlightInfo? departureFlight;
  final HotelInfo? hotel;
  final List<TransferItem> transfers;

  DateTime? get tripStartDate {
    final candidates = <DateTime>[];
    if (arrivalFlight != null) candidates.add(arrivalFlight!.dateTime);
    if (hotel != null) candidates.add(hotel!.checkinDateTime);
    if (transfers.isNotEmpty) candidates.add(transfers.first.dateTime);
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => a.compareTo(b));
    return candidates.first;
  }

  DateTime? get tripEndDate {
    final candidates = <DateTime>[];
    if (departureFlight != null) candidates.add(departureFlight!.dateTime);
    if (hotel != null) candidates.add(hotel!.checkoutDateTime);
    if (transfers.isNotEmpty) candidates.add(transfers.last.dateTime);
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => a.compareTo(b));
    return candidates.last;
  }

  TransferItem? nextTransferWithinHours({
    int hours = 24,
    DateTime? reference,
  }) {
    final now = reference ?? DateTime.now();
    final end = now.add(Duration(hours: hours));

    final sortedTransfers = [...transfers]
      ..sort((a, b) {
        if (a.displayOrder != b.displayOrder) {
          return a.displayOrder.compareTo(b.displayOrder);
        }
        return a.dateTime.compareTo(b.dateTime);
      });

    for (final transfer in sortedTransfers) {
      if (transfer.status == 'cancelled' || transfer.status == 'completed') {
        continue;
      }
      if (transfer.dateTime.isBefore(now) || transfer.dateTime.isAfter(end)) {
        continue;
      }
      return transfer;
    }

    return null;
  }

  factory TravelPlanModel.fromJson(Map<String, dynamic> json) {
    final transfersRaw = (json['transfers'] as List<dynamic>? ?? const []);
    final transfers = transfersRaw
        .whereType<Map<String, dynamic>>()
        .map(TransferItem.fromJson)
        .toList()
      ..sort((a, b) {
        if (a.displayOrder != b.displayOrder) {
          return a.displayOrder.compareTo(b.displayOrder);
        }
        return a.dateTime.compareTo(b.dateTime);
      });

    return TravelPlanModel(
      id: (json['id'] ?? '').toString(),
      passportNumber: (json['passport_number'] ?? '').toString(),
      arrivalFlight: json['arrival_flight'] is Map<String, dynamic>
          ? FlightInfo.fromJson(json['arrival_flight'] as Map<String, dynamic>)
          : null,
      departureFlight: json['departure_flight'] is Map<String, dynamic>
          ? FlightInfo.fromJson(json['departure_flight'] as Map<String, dynamic>)
          : null,
      hotel: json['hotel'] is Map<String, dynamic>
          ? HotelInfo.fromJson(json['hotel'] as Map<String, dynamic>)
          : null,
      transfers: transfers,
    );
  }
}

DateTime _combineDateAndTime(DateTime date, String timeValue) {
  final chunks = timeValue.split(':');
  final hour = chunks.isNotEmpty ? int.tryParse(chunks[0]) ?? 0 : 0;
  final minute = chunks.length > 1 ? int.tryParse(chunks[1]) ?? 0 : 0;
  final second = chunks.length > 2 ? int.tryParse(chunks[2]) ?? 0 : 0;
  return DateTime(date.year, date.month, date.day, hour, minute, second);
}
