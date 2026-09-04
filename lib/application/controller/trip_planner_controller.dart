import 'dart:math';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart'; // ✅ use this for LatLng

import '../../data/datasources/google_place_data_source.dart';
import '../../data/datasources/location_data_source.dart';
import '../../data/datasources/trip_plan_data_source.dart';
import '../../data/datasources/trip_places_data_source.dart';
import '../../data/models/place_candidate.dart';
import '../../data/models/trip_plan.dart';

class RoutePreview {
  final List<ItineraryStop> stops;
  final double distanceKm;
  final int minutes;
  final List<LatLng> points; // ✅ now consistent

  const RoutePreview({
    required this.stops,
    required this.distanceKm,
    required this.minutes,
    required this.points,
  });
}

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

  // Load key from env/dev.json
  static Future<TripPlannerController> createProduction() async {
    try {
      final String jsonString = await rootBundle.loadString('env/dev.json');
      print('✅ Loaded JSON: $jsonString');
      final Map<String, dynamic> config = jsonDecode(jsonString);
      final String key = config['GOOGLE_PLACES_API_KEY'] ?? '';
      print('🔑 Key: $key');
      if (key.isEmpty) {
        throw const TripPlannerException(
          'Google Places API key is missing. Add it to env/dev.json.',
        );
      }
      return TripPlannerController(
        places: GooglePlacesDataSource(apiKey: key),
        location: LocationDataSource(),
        plans: TripPlanDataSource(),
        tripPlaces: TripPlacesDataSource(apiKey: key),
      );
    } catch (e) {
      print('❌ Error loading dev.json: $e');
      rethrow;
    }
  }

  Future<List<TripPlan>> loadMyPlans() => _plans.loadMyPlans();
  Future<TripPlan> savePlan(TripPlan plan) => _plans.savePlan(plan);
  Future<List<PlaceCandidate>> search(String query) => _tripPlaces.search(query);

  Future<List<PlaceCandidate>> exploreNearby() async {
    final position = await _location.getCurrentLocation();
    return _places.searchNearby(
      latitude: position.latitude,
      longitude: position.longitude,
      radiusMeters: 2500,
    );
  }

  // ✅ New async route planner using Directions API
  Future<RoutePreview> planEfficientRoute(List<ItineraryStop> stops) async {
    if (stops.length < 2) {
      throw const TripPlannerException('At least two valid destinations are required.');
    }

    final waypoints = stops.map((s) => LatLng(s.latitude, s.longitude)).toList();

    // Attempt to get real driving route
    List<LatLng> routePoints = await _tripPlaces.getDirections(waypoints);

    // If Directions API returns empty, fallback to straight‑line
    if (routePoints.isEmpty) {
      return _fallbackRoute(stops);
    }

    // Compute distance along the polyline
    double distance = 0;
    for (var i = 1; i < routePoints.length; i++) {
      distance += _haversine(routePoints[i - 1], routePoints[i]);
    }
    final minutes = max(1, (distance / 30 * 60).round());

    return RoutePreview(
      stops: stops,
      distanceKm: distance,
      minutes: minutes,
      points: routePoints,
    );
  }

  // ✅ Fallback: nearest‑neighbor with straight lines (for when Directions API fails)
  RoutePreview _fallbackRoute(List<ItineraryStop> stops) {
    final remaining = List<ItineraryStop>.from(stops);
    final ordered = <ItineraryStop>[remaining.removeAt(0)];
    while (remaining.isNotEmpty) {
      final previous = ordered.last;
      remaining.sort((a, b) => _km(previous, a).compareTo(_km(previous, b)));
      ordered.add(remaining.removeAt(0));
    }

    double distance = 0;
    final points = <LatLng>[];
    for (var i = 0; i < ordered.length; i++) {
      final stop = ordered[i];
      points.add(LatLng(stop.latitude, stop.longitude));
      if (i > 0) {
        distance += _km(ordered[i - 1], stop);
      }
    }

    return RoutePreview(
      stops: ordered,
      distanceKm: distance,
      minutes: max(1, (distance / 30 * 60).round()),
      points: points, // straight lines between stops
    );
  }

  // ✅ Haversine distance between two LatLng points (in km)
  double _haversine(LatLng a, LatLng b) {
    const earthRadius = 6371.0;
    double radians(double value) => value * pi / 180;
    final dLat = radians(b.latitude - a.latitude);
    final dLng = radians(b.longitude - a.longitude);
    final h = sin(dLat / 2) * sin(dLat / 2) +
        cos(radians(a.latitude)) * cos(radians(b.latitude)) *
            sin(dLng / 2) * sin(dLng / 2);
    return earthRadius * 2 * atan2(sqrt(h), sqrt(1 - h));
  }

  // ✅ Legacy distance between ItineraryStop (used in fallback)
  double _km(ItineraryStop a, ItineraryStop b) {
    return _haversine(LatLng(a.latitude, a.longitude), LatLng(b.latitude, b.longitude));
  }

  void dispose() {
    _places.dispose();
    _tripPlaces.dispose();
  }
}

class TripPlannerException implements Exception {
  final String message;
  const TripPlannerException(this.message);
  @override
  String toString() => message;
}