import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../data/datasources/google_place_data_source.dart';
import '../../data/datasources/location_data_source.dart';
import '../../data/datasources/trip_plan_data_source.dart';
import '../../data/datasources/trip_places_data_source.dart';

import '../../data/models/place_candidate.dart';
import '../../data/models/trip_plan.dart';
import '../../data/models/blind_box_history.dart';

// BlindBoxController is in the SAME controller folder
import 'BlindBox_Controller.dart';

/// ============================================================================
/// ROUTE PREVIEW MODEL
/// ============================================================================
class RoutePreview {
  final List<ItineraryStop> stops;
  final double distanceKm;
  final int minutes;
  final List<LatLng> points;

  const RoutePreview({
    required this.stops,
    required this.distanceKm,
    required this.minutes,
    required this.points,
  });
}

/// ============================================================================
/// TRIP PLANNER CONTROLLER
/// ============================================================================
class TripPlannerController {
  final GooglePlacesDataSource _places;
  final LocationDataSource _location;
  final TripPlanDataSource _plans;
  final TripPlacesDataSource _tripPlaces;

  TripPlannerController({
    required GooglePlacesDataSource places,
    required LocationDataSource location,
    required TripPlanDataSource plans,
    required TripPlacesDataSource tripPlaces,
  })  : _places = places,
        _location = location,
        _plans = plans,
        _tripPlaces = tripPlaces;

  /// ==========================================================================
  /// CREATE PRODUCTION CONTROLLER
  /// ==========================================================================
  ///
  /// Loads Google Places API key from:
  ///
  /// env/dev.json
  ///
  static Future<TripPlannerController> createProduction() async {
    try {
      final String jsonString =
      await rootBundle.loadString('env/dev.json');

      print('✅ Loaded JSON: $jsonString');

      final Map<String, dynamic> config =
      jsonDecode(jsonString);

      final String key =
          config['GOOGLE_PLACES_API_KEY']?.toString() ?? '';

      print('🔑 Google Places API key loaded');

      if (key.isEmpty) {
        throw const TripPlannerException(
          'Google Places API key is missing. '
              'Add it to env/dev.json.',
        );
      }

      return TripPlannerController(
        places: GooglePlacesDataSource(
          apiKey: key,
        ),
        location: LocationDataSource(),
        plans: TripPlanDataSource(),
        tripPlaces: TripPlacesDataSource(
          apiKey: key,
        ),
      );
    } catch (error) {
      print(
        '❌ Error loading env/dev.json: $error',
      );

      rethrow;
    }
  }

  /// ==========================================================================
  /// LOAD MY TRIP PLANS
  /// ==========================================================================

  Future<List<TripPlan>> loadMyPlans() {
    return _plans.loadMyPlans();
  }

  /// ==========================================================================
  /// SAVE TRIP PLAN
  /// ==========================================================================

  Future<TripPlan> savePlan(
      TripPlan plan,
      ) {
    return _plans.savePlan(plan);
  }

  /// ==========================================================================
  /// SEARCH PLACES
  /// ==========================================================================

  Future<List<PlaceCandidate>> search(
      String query,
      ) {
    return _tripPlaces.search(query);
  }

  /// ==========================================================================
  /// EXPLORE NEARBY
  /// ==========================================================================

  Future<List<PlaceCandidate>> exploreNearby() async {
    final position =
    await _location.getCurrentLocation();

    return _places.searchNearby(
      latitude: position.latitude,
      longitude: position.longitude,
      radiusMeters: 5000,
      maxResultCount: 15,
    );
  }

  /// ==========================================================================
  /// GET BLIND BOX HISTORY
  /// ==========================================================================
  ///
  /// Trip Planner can use destinations previously generated from Blind Box.
  ///
  Future<List<BlindBoxHistoryResult>>
  getBlindBoxHistory() async {
    final BlindBoxController controller =
    BlindBoxController.production();

    try {
      return await controller.loadBlindBoxHistory();
    } finally {
      controller.dispose();
    }
  }

  /// ==========================================================================
  /// GET CURRENT LOCATION
  /// ==========================================================================

  Future<LatLng> getCurrentLocation() async {
    final position =
    await _location.getCurrentLocation();

    return LatLng(
      position.latitude,
      position.longitude,
    );
  }

  /// ==========================================================================
  /// PLAN EFFICIENT ROUTE
  /// ==========================================================================
  ///
  /// Uses Google Directions.
  ///
  /// If Directions API fails or returns no route,
  /// nearest-neighbour straight-line fallback is used.
  ///
  Future<RoutePreview> planEfficientRoute(
      List<ItineraryStop> stops,
      ) async {
    if (stops.length < 2) {
      throw const TripPlannerException(
        'At least two valid destinations are required.',
      );
    }

    final List<LatLng> waypoints = stops
        .map(
          (stop) => LatLng(
        stop.latitude,
        stop.longitude,
      ),
    )
        .toList();

    /// Try Google Directions first.
    final List<LatLng> routePoints =
    await _tripPlaces.getDirections(
      waypoints,
    );

    /// If Directions API gives no result,
    /// use nearest-neighbour fallback.
    if (routePoints.isEmpty) {
      return _fallbackRoute(stops);
    }

    /// Calculate total distance along route polyline.
    double distance = 0;

    for (int i = 1;
    i < routePoints.length;
    i++) {
      distance += _haversine(
        routePoints[i - 1],
        routePoints[i],
      );
    }

    /// Approximate duration using average speed:
    ///
    /// 30 km/h
    ///
    final int minutes =
    max(
      1,
      (distance / 30 * 60).round(),
    );

    return RoutePreview(
      stops: stops,
      distanceKm: distance,
      minutes: minutes,
      points: routePoints,
    );
  }

  /// ==========================================================================
  /// FALLBACK ROUTE
  /// ==========================================================================
  ///
  /// Nearest-neighbour algorithm.
  ///
  /// Used if Google Directions fails.
  ///
  RoutePreview _fallbackRoute(
      List<ItineraryStop> stops,
      ) {
    final List<ItineraryStop> remaining =
    List<ItineraryStop>.from(stops);

    final List<ItineraryStop> ordered =
    <ItineraryStop>[
      remaining.removeAt(0),
    ];

    while (remaining.isNotEmpty) {
      final ItineraryStop previous =
          ordered.last;

      remaining.sort(
            (a, b) => _km(
          previous,
          a,
        ).compareTo(
          _km(
            previous,
            b,
          ),
        ),
      );

      ordered.add(
        remaining.removeAt(0),
      );
    }

    double distance = 0;

    final List<LatLng> points =
    <LatLng>[];

    for (int i = 0;
    i < ordered.length;
    i++) {
      final ItineraryStop stop =
      ordered[i];

      points.add(
        LatLng(
          stop.latitude,
          stop.longitude,
        ),
      );

      if (i > 0) {
        distance += _km(
          ordered[i - 1],
          stop,
        );
      }
    }

    final int minutes =
    max(
      1,
      (distance / 30 * 60).round(),
    );

    return RoutePreview(
      stops: ordered,
      distanceKm: distance,
      minutes: minutes,
      points: points,
    );
  }

  /// ==========================================================================
  /// HAVERSINE DISTANCE
  /// ==========================================================================
  ///
  /// Calculates distance between two coordinates in KM.
  ///
  double _haversine(
      LatLng a,
      LatLng b,
      ) {
    const double earthRadiusKm =
    6371.0;

    double radians(
        double value,
        ) {
      return value * pi / 180;
    }

    final double dLat =
    radians(
      b.latitude - a.latitude,
    );

    final double dLng =
    radians(
      b.longitude - a.longitude,
    );

    final double lat1 =
    radians(a.latitude);

    final double lat2 =
    radians(b.latitude);

    final double h =
        sin(dLat / 2) *
            sin(dLat / 2) +
            cos(lat1) *
                cos(lat2) *
                sin(dLng / 2) *
                sin(dLng / 2);

    final double c =
        2 *
            atan2(
              sqrt(h),
              sqrt(1 - h),
            );

    return earthRadiusKm * c;
  }

  /// ==========================================================================
  /// DISTANCE BETWEEN ITINERARY STOPS
  /// ==========================================================================

  double _km(
      ItineraryStop a,
      ItineraryStop b,
      ) {
    return _haversine(
      LatLng(
        a.latitude,
        a.longitude,
      ),
      LatLng(
        b.latitude,
        b.longitude,
      ),
    );
  }

  /// ==========================================================================
  /// DISPOSE
  /// ==========================================================================

  void dispose() {
    _places.dispose();
    _tripPlaces.dispose();
  }
}

/// ============================================================================
/// TRIP PLANNER EXCEPTION
/// ============================================================================
class TripPlannerException implements Exception {
  final String message;

  const TripPlannerException(
      this.message,
      );

  @override
  String toString() {
    return message;
  }
}