import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/place_candidate.dart';

class SupabaseDataSource {
  final SupabaseClient _client;

  SupabaseDataSource({
    SupabaseClient? client,
  }) : _client = client ?? Supabase.instance.client;

  Future<String> saveBlindBoxDestination({
    required PlaceCandidate place,
    String? imageUrl,
    String? description,
  }) async {
    try {
      final response = await _client
          .from('blind_box_destinations')
          .upsert(
        {
          'google_place_id': place.placeId,
          'name': place.name,
          'category': place.primaryType,
          'latitude': place.latitude,
          'longitude': place.longitude,
          'address': place.formattedAddress,

          // Not available yet from our current Places request.
          'description': description,
          'image_url': imageUrl,
          'rating': place.rating,
          'user_rating_count': place.userRatingCount,
          'popularity_classification': null,

          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },

        onConflict: 'google_place_id',
      )
          .select('destination_id')
          .single();

      return response['destination_id'] as String;
    } catch (error) {
      throw SupabaseDataException(
        'Failed to save Blind Box destination: $error',
      );
    }
  }

  Future<void> saveBlindBoxHistory({
    required String destinationId,
    required double radiusKm,
    required String drawType,
  }) async {
    try {
      final user = _client.auth.currentUser;

      await _client
          .from('blind_box_history')
          .insert({
        'user_id': user?.id,

        'destination_id': destinationId,

        'radius_km': radiusKm,

        'draw_type': drawType,
      });
    } catch (error) {
      throw SupabaseDataException(
        'Failed to save Blind Box history: $error',
      );
    }
  }

  Future<List<Map<String, dynamic>>> getBlindBoxHistory() async {
    try {
      final user = _client.auth.currentUser;

      var query = _client
          .from('blind_box_history')
          .select('''
          history_id,
          user_id,
          destination_id,
          radius_km,
          draw_type,
          drawn_at,
          blind_box_destinations (
            destination_id,
            google_place_id,
            name,
            description,
            category,
            image_url,
            latitude,
            longitude,
            address,
            rating,
            user_rating_count,
            popularity_classification
          )
        ''');

      if (user != null) {
        query = query.eq(
          'user_id',
          user.id,
        );
      }

      final response =
      await query.order(
        'drawn_at',
        ascending: false,
      );

      return List<Map<String, dynamic>>.from(
        response,
      );
    } catch (error) {
      throw SupabaseDataException(
        'Failed to load Blind Box history: $error',
      );
    }
  }
}

class SupabaseDataException implements Exception {
  final String message;

  const SupabaseDataException(this.message);

  @override
  String toString() => message;
}