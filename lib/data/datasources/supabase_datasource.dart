import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/place_candidate.dart';

class SupabaseDataSource {
  final SupabaseClient _client;

  SupabaseDataSource({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  User _requireUser() {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw const SupabaseDataException(
        'Please log in before using Blind Box.',
      );
    }

    return user;
  }

  Future<Map<String, int>> getBlindBoxBalance() async {
    try {
      final user = _requireUser();

      final response = await _client
          .from('profiles')
          .select('exploration_points, blind_box_chances')
          .eq('id', user.id)
          .single();

      return {
        'exploration_points': _toInt(response['exploration_points']),
        'blind_box_chances': _toInt(response['blind_box_chances']),
      };
    } on SupabaseDataException {
      rethrow;
    } catch (error) {
      throw SupabaseDataException('Failed to load Blind Box balance: $error');
    }
  }

  Future<Map<String, int>> buyBlindBoxChance() async {
    try {
      _requireUser();

      final response = await _client.rpc('buy_blind_box_chance');

      if (response is! Map) {
        throw const SupabaseDataException(
          'Unexpected response while buying Blind Box chance.',
        );
      }

      final data = Map<String, dynamic>.from(response);

      return {
        'exploration_points': _toInt(data['exploration_points']),
        'blind_box_chances': _toInt(data['blind_box_chances']),
      };
    } on SupabaseDataException {
      rethrow;
    } catch (error) {
      throw SupabaseDataException('Failed to buy Blind Box chance: $error');
    }
  }

  Future<String> saveBlindBoxDestination({
    required PlaceCandidate place,
    String? imageUrl,
    String? description,
  }) async {
    try {
      _requireUser();

      final response = await _client
          .from('blind_box_destinations')
          .upsert({
            'google_place_id': place.placeId,
            'name': place.name,
            'description': description,
            'category': place.primaryType,
            'image_url': imageUrl,
            'latitude': place.latitude,
            'longitude': place.longitude,
            'address': place.formattedAddress,
            'rating': place.rating,
            'user_rating_count': place.userRatingCount,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }, onConflict: 'google_place_id')
          .select('destination_id')
          .single();

      final destinationId = response['destination_id']?.toString();

      if (destinationId == null || destinationId.isEmpty) {
        throw const SupabaseDataException(
          'Destination ID was not returned by Supabase.',
        );
      }

      return destinationId;
    } on SupabaseDataException {
      rethrow;
    } catch (error) {
      throw SupabaseDataException(
        'Failed to save Blind Box destination: $error',
      );
    }
  }

  Future<int> recordBlindBoxDraw({
    required String destinationId,
    required double radiusKm,
    required String drawType,
  }) async {
    try {
      _requireUser();

      final response = await _client.rpc(
        'record_blind_box_draw',
        params: {
          'p_destination_id': destinationId,
          'p_radius_km': radiusKm,
          'p_draw_type': drawType,
        },
      );

      // Start server-side preparation for every text category. The endpoint
      // acknowledges immediately while the shared question banks grow.
      try {
        await _client.functions.invoke(
          'generate-destination-questions',
          body: {'destination_id': destinationId, 'prepare_all': true},
        );
      } on FunctionException {
        // Preserve the successful draw. The existing destination bank remains
        // available and generation can be retried on a later draw.
      } catch (_) {
        // Preserve the successful draw during temporary network failures.
      }

      return _toInt(response);
    } on SupabaseDataException {
      rethrow;
    } catch (error) {
      throw SupabaseDataException('Failed to record Blind Box draw: $error');
    }
  }

  Future<List<Map<String, dynamic>>> getBlindBoxHistory() async {
    try {
      final user = _requireUser();

      final response = await _client
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
          ''')
          .eq('user_id', user.id)
          .order('drawn_at', ascending: false)
          .limit(50);

      return (response as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList(growable: false);
    } on SupabaseDataException {
      rethrow;
    } catch (error) {
      throw SupabaseDataException('Failed to load Blind Box history: $error');
    }
  }

  int _toInt(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString()) ?? 0;
  }
}

class SupabaseDataException implements Exception {
  final String message;

  const SupabaseDataException(this.message);

  @override
  String toString() => message;
}
