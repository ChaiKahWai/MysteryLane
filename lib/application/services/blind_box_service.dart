import 'dart:math';

import '../../data/datasources/google_place_data_source.dart';
import '../../data/datasources/location_data_source.dart';
import '../../data/datasources/supabase_datasource.dart';
import '../../data/models/place_candidate.dart';
import '../../data/models/blind_box_history.dart';


class BlindBoxService {
  static const double minRadiusKm = 5;
  static const double maxRadiusKm = 20;
  static const int maxBlindBoxChances = 10;
  static const int maxDailyBlindBoxPurchases = 10;
  static const int blindBoxChanceCostEp = 200;

  final GooglePlacesDataSource _placesDataSource;
  final LocationDataSource _locationDataSource;
  final SupabaseDataSource _supabaseDataSource;
  final Random _random;

  BlindBoxService({
    required GooglePlacesDataSource placesDataSource,
    required LocationDataSource locationDataSource,
    required SupabaseDataSource supabaseDataSource,
    Random? random,
  })  : _placesDataSource = placesDataSource,
        _locationDataSource = locationDataSource,
        _supabaseDataSource = supabaseDataSource,
        _random = random ?? Random();

  /// Run Flutter with:
  ///
  /// flutter run --dart-define=GOOGLE_PLACES_API_KEY=YOUR_KEY
  factory BlindBoxService.production() {
    const apiKey = String.fromEnvironment(
      'GOOGLE_PLACES_API_KEY',
    );

    if (apiKey.isEmpty) {
      throw const BlindBoxException(
        'Google Places API key is missing. '
            'Run Flutter with '
            '--dart-define=GOOGLE_PLACES_API_KEY=YOUR_KEY',
      );
    }

    return BlindBoxService(
      placesDataSource: GooglePlacesDataSource(
        apiKey: apiKey,
      ),
      locationDataSource: LocationDataSource(),
      supabaseDataSource: SupabaseDataSource(),
    );
  }

  // ===========================================================================
  // BALANCE
  // ===========================================================================

  Future<BlindBoxBalance> loadBlindBoxBalance() async {
    final data =
    await _supabaseDataSource.getBlindBoxBalance();

    return BlindBoxBalance(
      explorationPoints:
      data['exploration_points'] ?? 0,
      chances:
      data['blind_box_chances'] ?? 0,
    );
  }

  // ===========================================================================
  // PURCHASE STATUS
  // ===========================================================================

  /// Loads everything required by the purchase dialog:
  ///
  /// exploration_points
  /// blind_box_chances
  /// purchased_today
  /// daily_remaining
  /// holding_remaining
  /// daily_limit
  /// max_chances
  /// chance_cost_ep
  Future<Map<String, int>>
  loadBlindBoxPurchaseStatus() async {
    final data =
    await _supabaseDataSource
        .getBlindBoxPurchaseStatus();

    return data;
  }

  // ===========================================================================
  // BUY MULTIPLE CHANCES
  // ===========================================================================

  Future<BlindBoxBalance> buyBlindBoxChances({
    required int quantity,
  }) async {
    // Basic application-level validation.
    // Supabase RPC performs the final secure validation again.

    if (quantity < 1) {
      throw const BlindBoxException(
        'Please select at least '
            '1 Blind Box Chance.',
      );
    }

    if (quantity >
        maxDailyBlindBoxPurchases) {
      throw const BlindBoxException(
        'You can select a maximum of '
            '10 Blind Box Chances.',
      );
    }

    final data =
    await _supabaseDataSource
        .buyBlindBoxChances(
      quantity: quantity,
    );

    return BlindBoxBalance(
      explorationPoints:
      data['exploration_points'] ?? 0,
      chances:
      data['blind_box_chances'] ?? 0,
    );
  }

  /// Legacy method.
  ///
  /// Existing code that still calls buyBlindBoxChance()
  /// will continue to work.
  Future<BlindBoxBalance> buyBlindBoxChance() {
    return buyBlindBoxChances(
      quantity: 1,
    );
  }

  // ===========================================================================
  // CHECK CHANCE BEFORE DRAW / REDRAW
  // ===========================================================================

  Future<void> _ensureChanceAvailable() async {
    final balance =
    await loadBlindBoxBalance();

    if (balance.chances <= 0) {
      throw const BlindBoxException(
        'No Blind Box chances remaining. '
            'Get additional chances using '
            '200 Exploration Points each.',
      );
    }
  }

  // ===========================================================================
  // FIRST DRAW
  // ===========================================================================

  Future<BlindBoxResult> drawBlindBox({
    required double radiusKm,
    Set<String> recentPlaceIds =
    const <String>{},
  }) async {
    _validateRadius(radiusKm);

    await _ensureChanceAvailable();

    final position =
    await _locationDataSource
        .getCurrentLocation();

    final candidates =
    await _loadCandidates(
      latitude: position.latitude,
      longitude: position.longitude,
      radiusKm: radiusKm,
    );

    final available =
    candidates.where((place) {
      return !recentPlaceIds.contains(
        place.placeId,
      );
    }).toList();

    if (available.isEmpty) {
      throw const BlindBoxException(
        'No new destination was found within '
            'the selected radius. '
            'Try increasing the radius.',
      );
    }

    final selectedPlace =
    _randomPick(available);

    return _prepareSelectedDestination(
      selectedPlace: selectedPlace,
      radiusKm: radiusKm,
      drawType: 'DRAW',
    );
  }

  // ===========================================================================
  // REDRAW
  // ===========================================================================

  Future<BlindBoxResult> redrawBlindBox({
    required double radiusKm,
    required String currentPlaceId,
    Set<String> recentPlaceIds =
    const <String>{},
  }) async {
    _validateRadius(radiusKm);

    await _ensureChanceAvailable();

    final position =
    await _locationDataSource
        .getCurrentLocation();

    final candidates =
    await _loadCandidates(
      latitude: position.latitude,
      longitude: position.longitude,
      radiusKm: radiusKm,
    );

    final available =
    candidates.where((place) {
      final isCurrentPlace =
          place.placeId ==
              currentPlaceId;

      final wasDrawnBefore =
      recentPlaceIds.contains(
        place.placeId,
      );

      return !isCurrentPlace &&
          !wasDrawnBefore;
    }).toList();

    if (available.isEmpty) {
      throw const BlindBoxException(
        'No other destination is available '
            'within the selected radius. '
            'Try increasing the radius.',
      );
    }

    final selectedPlace =
    _randomPick(available);

    return _prepareSelectedDestination(
      selectedPlace: selectedPlace,
      radiusKm: radiusKm,
      drawType: 'REDRAW',
    );
  }

  // ===========================================================================
  // PREPARE SELECTED DESTINATION
  // ===========================================================================

  /// Only the randomly selected destination gets
  /// Place Details / Photo calls.
  Future<BlindBoxResult>
  _prepareSelectedDestination({
    required PlaceCandidate selectedPlace,
    required double radiusKm,
    required String drawType,
  }) async {
    String? imageUrl;

    // -------------------------------------------------------------------------
    // PHOTO
    // -------------------------------------------------------------------------

    try {
      imageUrl =
      await _placesDataSource
          .getPhotoUrl(
        photoName:
        selectedPlace.photoName,
      );
    } catch (error) {
      _debugLog(
        '[BLIND BOX] Photo error: $error',
      );
    }

    // -------------------------------------------------------------------------
    // DESCRIPTION
    // -------------------------------------------------------------------------

    String? description;

    try {
      description =
      await _placesDataSource
          .getPlaceDescription(
        placeId:
        selectedPlace.placeId,
      );
    } catch (error) {
      _debugLog(
        '[BLIND BOX] '
            'Place description error: $error',
      );
    }

    if (description == null ||
        description.trim().isEmpty) {
      description =
          _buildFallbackDescription(
            selectedPlace,
          );
    }

    // -------------------------------------------------------------------------
    // SAVE DESTINATION MASTER RECORD
    // -------------------------------------------------------------------------

    final destinationId =
    await _supabaseDataSource
        .saveBlindBoxDestination(
      place: selectedPlace,
      imageUrl: imageUrl,
      description: description,
    );

    // -------------------------------------------------------------------------
    // ATOMIC DRAW / REDRAW
    //
    // Supabase:
    // 1. checks user has a chance
    // 2. deducts exactly 1 chance
    // 3. inserts Draw History
    // -------------------------------------------------------------------------

    final remainingChances =
    await _supabaseDataSource
        .recordBlindBoxDraw(
      destinationId: destinationId,
      radiusKm: radiusKm,
      drawType: drawType,
    );

    _debugLog(
      '[BLIND BOX] Remaining chances: '
          '$remainingChances',
    );

    _debugLog(
      '[BLIND BOX] '
          '$drawType saved. '
          'destinationId=$destinationId, '
          'placeId=${selectedPlace.placeId}',
    );

    return _toResult(
      selectedPlace,
      destinationId:
      destinationId,
      imageUrl:
      imageUrl,
      description:
      description,
    );
  }

  // ===========================================================================
  // LOAD HISTORY
  // ===========================================================================

  Future<List<BlindBoxHistoryResult>>
  loadBlindBoxHistory() async {
    final rows =
    await _supabaseDataSource
        .getBlindBoxHistory();

    final history =
    <BlindBoxHistoryResult>[];

    for (final row in rows) {
      final destinationRaw =
      row['blind_box_destinations'];

      if (destinationRaw is! Map) {
        continue;
      }

      final destination =
      Map<String, dynamic>.from(
        destinationRaw,
      );

      final drawnAt =
          DateTime.tryParse(
            row['drawn_at']
                ?.toString() ??
                '',
          ) ??
              DateTime.now().toUtc();

      history.add(
        BlindBoxHistoryResult(
          historyId:
          row['history_id']
              ?.toString() ??
              '',

          destinationId:
          row['destination_id']
              ?.toString() ??
              '',

          placeId:
          destination[
          'google_place_id']
              ?.toString() ??
              '',

          name:
          destination['name']
              ?.toString() ??
              'Unknown Destination',

          description:
          destination[
          'description']
              ?.toString(),

          category:
          destination['category']
              ?.toString() ??
              'unknown',

          imageUrl:
          destination[
          'image_url']
              ?.toString(),

          latitude:
          _toDouble(
            destination[
            'latitude'],
          ) ??
              0,

          longitude:
          _toDouble(
            destination[
            'longitude'],
          ) ??
              0,

          address:
          destination['address']
              ?.toString() ??
              '',

          rating:
          _toDouble(
            destination['rating'],
          ),

          userRatingCount:
          _toInt(
            destination[
            'user_rating_count'],
          ),

          radiusKm:
          _toDouble(
            row['radius_km'],
          ) ??
              0,

          drawType:
          row['draw_type']
              ?.toString() ??
              'DRAW',

          drawnAt:
          drawnAt,
        ),
      );
    }

    return history;
  }

  // ===========================================================================
  // LOAD NEARBY CANDIDATES
  // ===========================================================================

  Future<List<PlaceCandidate>>
  _loadCandidates({
    required double latitude,
    required double longitude,
    required double radiusKm,
  }) async {
    final radiusMeters =
        radiusKm * 1000;

    final places =
    await _placesDataSource
        .searchNearby(
      latitude: latitude,
      longitude: longitude,
      radiusMeters:
      radiusMeters,

      includedTypes: const [
        'tourist_attraction',
        'museum',
        'park',
      ],

      maxResultCount: 20,
      includePhotos: true,
    );

    return places.map((place) {
      final distanceKm =
      _calculateDistanceKm(
        latitude,
        longitude,
        place.latitude,
        place.longitude,
      );

      return place.copyWith(
        distanceKm:
        distanceKm,
      );
    }).where((place) {
      final distance =
          place.distanceKm;

      return distance != null &&
          distance <= radiusKm;
    }).toList();
  }

  // ===========================================================================
  // RANDOM PICK
  // ===========================================================================

  PlaceCandidate _randomPick(
      List<PlaceCandidate> places,
      ) {
    return places[
    _random.nextInt(
      places.length,
    )];
  }

  // ===========================================================================
  // MAP PLACE -> RESULT
  // ===========================================================================

  BlindBoxResult _toResult(
      PlaceCandidate place, {
        required String destinationId,
        String? imageUrl,
        String? description,
      }) {
    return BlindBoxResult(
      destinationId:
      destinationId,

      placeId:
      place.placeId,

      name:
      place.name,

      formattedAddress:
      place.formattedAddress,

      latitude:
      place.latitude,

      longitude:
      place.longitude,

      primaryType:
      place.primaryType,

      distanceKm:
      place.distanceKm ?? 0,

      photoName:
      place.photoName,

      imageUrl:
      imageUrl,

      rating:
      place.rating,

      userRatingCount:
      place.userRatingCount,

      description:
      description,
    );
  }

  // ===========================================================================
  // FALLBACK DESCRIPTION
  // ===========================================================================

  String _buildFallbackDescription(
      PlaceCandidate place,
      ) {
    final category =
    _formatCategory(
      place.primaryType,
    );

    if (place.formattedAddress
        .trim()
        .isNotEmpty) {
      return '${place.name} is a '
          '$category located at '
          '${place.formattedAddress}.';
    }

    return '${place.name} is a '
        '$category waiting '
        'for you to discover.';
  }

  String _formatCategory(
      String category,
      ) {
    if (category.trim().isEmpty ||
        category == 'unknown') {
      return 'destination';
    }

    return category
        .replaceAll('_', ' ')
        .toLowerCase();
  }

  // ===========================================================================
  // RADIUS VALIDATION
  // ===========================================================================

  void _validateRadius(
      double radiusKm,
      ) {
    if (radiusKm <
        minRadiusKm ||
        radiusKm >
            maxRadiusKm) {
      throw const BlindBoxException(
        'Blind Box radius must be between '
            '5 KM and 20 KM.',
      );
    }
  }

  // ===========================================================================
  // DISTANCE
  // ===========================================================================

  double _calculateDistanceKm(
      double lat1,
      double lon1,
      double lat2,
      double lon2,
      ) {
    const earthRadiusKm =
    6371.0;

    final dLat =
    _degreesToRadians(
      lat2 - lat1,
    );

    final dLon =
    _degreesToRadians(
      lon2 - lon1,
    );

    final lat1Rad =
    _degreesToRadians(
      lat1,
    );

    final lat2Rad =
    _degreesToRadians(
      lat2,
    );

    final a =
        sin(dLat / 2) *
            sin(dLat / 2) +
            cos(lat1Rad) *
                cos(lat2Rad) *
                sin(dLon / 2) *
                sin(dLon / 2);

    final c =
        2 *
            atan2(
              sqrt(a),
              sqrt(1 - a),
            );

    return earthRadiusKm * c;
  }

  double _degreesToRadians(
      double degrees,
      ) {
    return degrees *
        pi /
        180;
  }

  // ===========================================================================
  // CONVERSION HELPERS
  // ===========================================================================

  double? _toDouble(
      dynamic value,
      ) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString(),
    );
  }

  int? _toInt(
      dynamic value,
      ) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value.toString(),
    );
  }

  void _debugLog(
      String message,
      ) {
    print(message);
  }

  void dispose() {
    _placesDataSource.dispose();
  }
}