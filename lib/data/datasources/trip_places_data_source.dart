import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:http/http.dart' as http;

import '../models/place_candidate.dart';

/// Trip Planner-owned Google Places text search. Kept separate so this module
/// does not change the existing Blind Box Google Places implementation.
class TripPlacesDataSource {
  static const _url = 'https://places.googleapis.com/v1/places:searchText';
  final String apiKey;
  final http.Client _client;

  TripPlacesDataSource({required this.apiKey, http.Client? client})
      : _client = client ?? http.Client();

  Future<List<LatLng>> getDirections(List<LatLng> waypoints) async {
    if (waypoints.length < 2) return [];

    final origin = waypoints.first;
    final destination = waypoints.last;
    final intermediates = waypoints.sublist(1, waypoints.length - 1);

    // Routes API endpoint (POST)
    final url = Uri.parse('https://routes.googleapis.com/directions/v2:computeRoutes');

    // Build the request body
    final body = {
      'origin': {'location': {'latLng': {'latitude': origin.latitude, 'longitude': origin.longitude}}},
      'destination': {'location': {'latLng': {'latitude': destination.latitude, 'longitude': destination.longitude}}},
      'intermediates': intermediates.map((w) {
        return {'location': {'latLng': {'latitude': w.latitude, 'longitude': w.longitude}}};
      }).toList(),
      'travelMode': 'DRIVE',
      'optimizeWaypointOrder': true,
      'polylineQuality': 'OVERVIEW',
    };

    final response = await _client.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask': 'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline,routes.optimized_intermediate_waypoint_index',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw TripPlacesException('Routes API failed: ${response.body}');
    }

    final data = jsonDecode(response.body);
    final routes = data['routes'] as List;
    if (routes.isEmpty) return [];

    final route = routes.first;
    final encodedPolyline = route['polyline']['encodedPolyline'] as String;

    // Decode polyline using flutter_polyline_points
    final points = PolylinePoints().decodePolyline(encodedPolyline);
    return points.map((p) => LatLng(p.latitude, p.longitude)).toList();
  }

  Future<List<PlaceCandidate>> search(String query) async {
    if (query.trim().isEmpty) return const [];
    final response = await _client.post(
      Uri.parse('https://places.googleapis.com/v1/places:searchText'),
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask': 'places.id,places.displayName,places.formattedAddress,places.location,places.primaryType,places.rating,places.userRatingCount',
      },
      body: jsonEncode({'textQuery': query.trim(), 'maxResultCount': 20}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TripPlacesException('Google Places search failed: ${response.body}');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final raw = decoded['places'];
    if (raw is! List) return const [];
    return raw.whereType<Map<String, dynamic>>().map(PlaceCandidate.fromGoogleJson)
        .where((place) => place.placeId.isNotEmpty && place.latitude != 0 && place.longitude != 0)
        .toList();
  }

  void dispose() => _client.close();
}

class TripPlacesException implements Exception {
  final String message;
  const TripPlacesException(this.message);
  @override
  String toString() => message;
}
