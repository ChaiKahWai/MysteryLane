class PlaceCandidate {
  final String placeId;
  final String name;
  final String formattedAddress;
  final double latitude;
  final double longitude;
  final String primaryType;

  /// Google Places photo resource name.
  ///
  /// Example:
  /// places/PLACE_ID/photos/PHOTO_RESOURCE
  ///
  /// Do not permanently store/cache this value because Google photo resource
  /// names can expire. Fetch it again from Places when needed.
  final String? photoName;

  /// Calculated by the Application Layer using the user's current location.
  final double? distanceKm;

  const PlaceCandidate({
    required this.placeId,
    required this.name,
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
    required this.primaryType,
    this.photoName,
    this.distanceKm,
  });

  factory PlaceCandidate.fromGoogleJson(Map<String, dynamic> json) {
    final displayName =
        json['displayName'] as Map<String, dynamic>? ?? const {};

    final location =
        json['location'] as Map<String, dynamic>? ?? const {};

    final photos = json['photos'] as List<dynamic>?;

    String? firstPhotoName;

    if (photos != null && photos.isNotEmpty) {
      final firstPhoto = photos.first;

      if (firstPhoto is Map<String, dynamic>) {
        firstPhotoName = firstPhoto['name'] as String?;
      }
    }

    return PlaceCandidate(
      placeId: (json['id'] as String?) ?? '',
      name: (displayName['text'] as String?) ?? 'Unknown Destination',
      formattedAddress: (json['formattedAddress'] as String?) ?? '',
      latitude: ((location['latitude'] as num?) ?? 0).toDouble(),
      longitude: ((location['longitude'] as num?) ?? 0).toDouble(),
      primaryType: (json['primaryType'] as String?) ?? 'unknown',
      photoName: firstPhotoName,
    );
  }

  PlaceCandidate copyWith({
    String? placeId,
    String? name,
    String? formattedAddress,
    double? latitude,
    double? longitude,
    String? primaryType,
    String? photoName,
    double? distanceKm,
  }) {
    return PlaceCandidate(
      placeId: placeId ?? this.placeId,
      name: name ?? this.name,
      formattedAddress: formattedAddress ?? this.formattedAddress,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      primaryType: primaryType ?? this.primaryType,
      photoName: photoName ?? this.photoName,
      distanceKm: distanceKm ?? this.distanceKm,
    );
  }

  @override
  String toString() {
    return 'PlaceCandidate('
        'placeId: $placeId, '
        'name: $name, '
        'primaryType: $primaryType, '
        'distanceKm: $distanceKm'
        ')';
  }
}
