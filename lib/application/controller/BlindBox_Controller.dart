import 'dart:math';

import '../../data/datasources/google_place_data_source.dart';
import '../../data/datasources/location_data_source.dart';
import '../../data/models/place_candidate.dart';

/// ============================================================================
/// APPLICATION / LOGIC LAYER
/// ============================================================================
///
/// Dependency direction used by the Blind Box module:
///
/// Presentation (BlindBox_Screen.dart)
///             ↓
/// Application (this controller)
///             ↓
/// Data (LocationDataSource + GooglePlacesDataSource)
///
/// The Presentation layer never calls GPS or Google Places directly.
/// The Data layer never decides which place should win the Blind Box draw.
/// All application rules stay here.
class BlindBoxController {
  static const double minRadiusKm = 5;
  static const double maxRadiusKm = 20;

  final GooglePlacesDataSource _placesDataSource;
  final LocationDataSource _locationDataSource;
  final Random _random;

  BlindBoxController({
    required GooglePlacesDataSource placesDataSource,
    required LocationDataSource locationDataSource,
    Random? random,
  })  : _placesDataSource = placesDataSource,
        _locationDataSource = locationDataSource,
        _random = random ?? Random();

  /// Convenience factory for the current development stage.
  ///
  /// It keeps Data Layer construction outside the UI. The API key is read from
  /// --dart-define instead of being hard-coded in BlindBox_Screen.dart.
  ///
  /// Run with:
  /// flutter run --dart-define=GOOGLE_PLACES_API_KEY=YOUR_KEY
  factory BlindBoxController.production() {
    const apiKey = String.fromEnvironment('GOOGLE_PLACES_API_KEY');

    return BlindBoxController(
      placesDataSource: GooglePlacesDataSource(apiKey: apiKey),
      locationDataSource: LocationDataSource(),
    );
  }

  /// First Blind Box draw.
  ///
  /// [recentPlaceIds] will later come from Supabase history. For a new user it
  /// should be an empty set, so every returned place is eligible.
  Future<BlindBoxResult> drawBlindBox({
    required double radiusKm,
    Set<String> recentPlaceIds = const <String>{},
  }) async {
    _validateRadius(radiusKm);

    // DATA LAYER: obtain current device GPS position.
    final position = await _locationDataSource.getCurrentLocation();

    // DATA LAYER: request nearby Google Places candidates.
    final candidates = await _loadCandidates(
      latitude: position.latitude,
      longitude: position.longitude,
      radiusKm: radiusKm,
    );

    // APPLICATION RULE: do not show a recently drawn place again.
    final available = candidates.where((place) {
      return !recentPlaceIds.contains(place.placeId);
    }).toList();

    if (available.isEmpty) {
      throw const BlindBoxException(
        'No new destination was found within the selected radius. '
            'Try increasing the radius.',
      );
    }

    // APPLICATION RULE: randomly pick exactly one eligible destination.
    return _toResult(_randomPick(available));
  }

  /// Redraw logic.
  ///
  /// The currently revealed destination is excluded, and any IDs supplied in
  /// [recentPlaceIds] are also excluded.
  Future<BlindBoxResult> redrawBlindBox({
    required double radiusKm,
    required String currentPlaceId,
    Set<String> recentPlaceIds = const <String>{},
  }) async {
    _validateRadius(radiusKm);

    final position = await _locationDataSource.getCurrentLocation();

    final candidates = await _loadCandidates(
      latitude: position.latitude,
      longitude: position.longitude,
      radiusKm: radiusKm,
    );

    final available = candidates.where((place) {
      final isCurrentPlace = place.placeId == currentPlaceId;
      final wasDrawnBefore = recentPlaceIds.contains(place.placeId);
      return !isCurrentPlace && !wasDrawnBefore;
    }).toList();

    if (available.isEmpty) {
      throw const BlindBoxException(
        'No other destination is available within the selected radius. '
            'Try increasing the radius.',
      );
    }

    return _toResult(_randomPick(available));
  }

  Future<List<PlaceCandidate>> _loadCandidates({
    required double latitude,
    required double longitude,
    required double radiusKm,
  }) async {
    final radiusMeters = radiusKm * 1000;

    final places = await _placesDataSource.searchNearby(
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
      includedTypes: const [
        'tourist_attraction',
        'museum',
        'park',
      ],
      maxResultCount: 20,
      includePhotos: true,
    );

    // Google already restricts Nearby Search to the requested circle.
    // We calculate distance again because the UI needs a readable distance and
    // this also gives us a defensive application-side radius check.
    return places.map((place) {
      final distanceKm = _calculateDistanceKm(
        latitude,
        longitude,
        place.latitude,
        place.longitude,
      );

      return place.copyWith(distanceKm: distanceKm);
    }).where((place) {
      final distance = place.distanceKm;
      return distance != null && distance <= radiusKm;
    }).toList();
  }

  PlaceCandidate _randomPick(List<PlaceCandidate> places) {
    return places[_random.nextInt(places.length)];
  }

  BlindBoxResult _toResult(PlaceCandidate place) {
    return BlindBoxResult(
      placeId: place.placeId,
      name: place.name,
      formattedAddress: place.formattedAddress,
      latitude: place.latitude,
      longitude: place.longitude,
      primaryType: place.primaryType,
      distanceKm: place.distanceKm ?? 0,
      photoName: place.photoName,
    );
  }

  void _validateRadius(double radiusKm) {
    if (radiusKm < minRadiusKm || radiusKm > maxRadiusKm) {
      throw const BlindBoxException(
        'Blind Box radius must be between 5 KM and 20 KM.',
      );
    }
  }

  /// Haversine formula: straight-line distance between two GPS coordinates.
  double _calculateDistanceKm(
      double lat1,
      double lon1,
      double lat2,
      double lon2,
      ) {
    const earthRadiusKm = 6371.0;

    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);
    final lat1Rad = _degreesToRadians(lat1);
    final lat2Rad = _degreesToRadians(lat2);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1Rad) *
            cos(lat2Rad) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  void dispose() {
    _placesDataSource.dispose();
  }
}

/// Application-layer result DTO.
///
/// This prevents BlindBox_Screen.dart from importing PlaceCandidate from the
/// Data layer. The UI only knows this Logic/Application-layer object.
class BlindBoxResult {
  final String placeId;
  final String name;
  final String formattedAddress;
  final double latitude;
  final double longitude;
  final String primaryType;
  final double distanceKm;
  final String? photoName;

  const BlindBoxResult({
    required this.placeId,
    required this.name,
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
    required this.primaryType,
    required this.distanceKm,
    this.photoName,
  });
}

class BlindBoxException implements Exception {
  final String message;

  const BlindBoxException(this.message);

  @override
  String toString() => message;
}
