class ItineraryStop {
  final String placeId;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final int dayNumber;
  final int sortOrder;
  final String source;

  const ItineraryStop({
    required this.placeId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.dayNumber,
    required this.sortOrder,
    required this.source,
  });

  ItineraryStop copyWith({
    String? name,
    int? dayNumber,
    int? sortOrder,
  }) => ItineraryStop(
    placeId: placeId,
    name: name ?? this.name,
    address: address,
    latitude: latitude,
    longitude: longitude,
    dayNumber: dayNumber ?? this.dayNumber,
    sortOrder: sortOrder ?? this.sortOrder,
    source: source ?? this.source,
  );
}

class TripPlan {
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final String mode;
  final String visibility;
  final String? inviteCode;
  final bool routeAccepted;
  final int? estimatedTravelMinutes;
  final List<ItineraryStop> stops;

  const TripPlan({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.mode,
    required this.visibility,
    required this.inviteCode,
    required this.routeAccepted,
    this.estimatedTravelMinutes,
    required this.stops,
  });

  int get totalDays => endDate.difference(startDate).inDays + 1;
}
