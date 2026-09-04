/// ============================================================================
/// BLIND BOX MODELS
/// ============================================================================
///
/// This file contains the application models / DTOs used by the
/// Blind Box controller and service.
///
/// The filename is blind_box_history.dart as requested, but it also contains
/// the balance, draw result and exception classes so the Blind Box feature
/// stays separated into only three files.

/// User's Blind Box balance.
class BlindBoxBalance {
  final int explorationPoints;
  final int chances;

  const BlindBoxBalance({
    required this.explorationPoints,
    required this.chances,
  });
}

/// Result returned after a successful DRAW / REDRAW.
class BlindBoxResult {
  final String destinationId;
  final String placeId;
  final String name;
  final String formattedAddress;
  final double latitude;
  final double longitude;
  final String primaryType;
  final double distanceKm;
  final String? photoName;
  final String? imageUrl;
  final double? rating;
  final int? userRatingCount;
  final String? description;

  const BlindBoxResult({
    required this.destinationId,
    required this.placeId,
    required this.name,
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
    required this.primaryType,
    required this.distanceKm,
    this.photoName,
    this.imageUrl,
    this.rating,
    this.userRatingCount,
    this.description,
  });
}

/// One item shown in the Blind Box Draw History page.
class BlindBoxHistoryResult {
  final String historyId;
  final String destinationId;
  final String placeId;
  final String name;
  final String? description;
  final String category;
  final String? imageUrl;
  final double latitude;
  final double longitude;
  final String address;
  final double? rating;
  final int? userRatingCount;
  final double radiusKm;
  final String drawType;
  final DateTime drawnAt;

  const BlindBoxHistoryResult({
    required this.historyId,
    required this.destinationId,
    required this.placeId,
    required this.name,
    required this.description,
    required this.category,
    required this.imageUrl,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.rating,
    required this.userRatingCount,
    required this.radiusKm,
    required this.drawType,
    required this.drawnAt,
  });
}

/// Application exception displayed by the UI.
class BlindBoxException implements Exception {
  final String message;

  const BlindBoxException(this.message);

  @override
  String toString() => message;
}
