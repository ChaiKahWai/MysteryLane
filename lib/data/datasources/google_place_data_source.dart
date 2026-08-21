import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/place_candidate.dart';

class GooglePlacesDataSource {
  static const String _nearbySearchUrl =
      'https://places.googleapis.com/v1/places:searchNearby';

  final String apiKey;
  final http.Client _client;

  GooglePlacesDataSource({
    required this.apiKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Calls Google Places Nearby Search (New).
  ///
  /// Data Layer responsibility only:
  /// - sends HTTP request
  /// - converts Google JSON into PlaceCandidate objects
  /// - does NOT perform random selection
  /// - does NOT check blind-box chances
  /// - does NOT save to Supabase
  Future<List<PlaceCandidate>> searchNearby({
    required double latitude,
    required double longitude,
    required double radiusMeters,
    List<String> includedTypes = const [
      'tourist_attraction',
      'museum',
      'park',
    ],
    int maxResultCount = 20,
    bool includePhotos = true,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw const GooglePlacesException(
        'Google Places API key is missing.',
      );
    }

    if (radiusMeters <= 0) {
      throw const GooglePlacesException(
        'Radius must be greater than 0 metres.',
      );
    }

    if (maxResultCount < 1 || maxResultCount > 20) {
      throw const GooglePlacesException(
        'maxResultCount must be between 1 and 20.',
      );
    }

    final fieldMask = <String>[
      'places.id',
      'places.displayName',
      'places.formattedAddress',
      'places.location',
      'places.primaryType',
      if (includePhotos) 'places.photos',
    ].join(',');

    final requestBody = <String, dynamic>{
      'includedTypes': includedTypes,
      'maxResultCount': maxResultCount,
      'locationRestriction': {
        'circle': {
          'center': {
            'latitude': latitude,
            'longitude': longitude,
          },
          'radius': radiusMeters,
        },
      },
      'rankPreference': 'POPULARITY',
    };

    final response = await _client.post(
      Uri.parse(_nearbySearchUrl),
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask': fieldMask,
      },
      body: jsonEncode(requestBody),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GooglePlacesException(
        _extractGoogleErrorMessage(response.body) ??
            'Google Places request failed '
                '(HTTP ${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw const GooglePlacesException(
        'Unexpected Google Places response format.',
      );
    }

    final rawPlaces = decoded['places'];

    if (rawPlaces == null) {
      return const [];
    }

    if (rawPlaces is! List) {
      throw const GooglePlacesException(
        'Google Places "places" field is not a list.',
      );
    }

    return rawPlaces
        .whereType<Map<String, dynamic>>()
        .map(PlaceCandidate.fromGoogleJson)
        .where((place) {
      return place.placeId.isNotEmpty &&
          place.name != 'Unknown Destination' &&
          place.latitude != 0 &&
          place.longitude != 0;
    })
        .toList();
  }

  String? _extractGoogleErrorMessage(String responseBody) {
    try {
      final decoded = jsonDecode(responseBody);

      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];

        if (error is Map<String, dynamic>) {
          return error['message'] as String?;
        }
      }
    } catch (_) {
      // If parsing fails, return null and use the generic error.
    }

    return null;
  }

  void dispose() {
    _client.close();
  }
}

class GooglePlacesException implements Exception {
  final String message;
  final int? statusCode;

  const GooglePlacesException(
      this.message, {
        this.statusCode,
      });

  @override
  String toString() {
    if (statusCode == null) {
      return 'GooglePlacesException: $message';
    }

    return 'GooglePlacesException($statusCode): $message';
  }
}
