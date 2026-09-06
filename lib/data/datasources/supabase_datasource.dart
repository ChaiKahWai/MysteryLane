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

  Future<Map<String, int>>
  buyBlindBoxChance() {
    return buyBlindBoxChances(
      quantity: 1,
    );
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

      const pageSize = 500;
      final history = <Map<String, dynamic>>[];
      for (var from = 0; ; from += pageSize) {
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
            .range(from, from + pageSize - 1);
        final page = (response as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList(growable: false);
        history.addAll(page);
        if (page.length < pageSize) return history;
      }
    } on SupabaseDataException {
      rethrow;
    } catch (error) {
      throw SupabaseDataException('Failed to load Blind Box history: $error');
    }
  }

  Future<void> savePuzzleLocation({
    required String destinationId,
    required String locationSource,
  }) async {
    final user = _requireUser();
    await _client.from('user_puzzle_locations').upsert({
      'user_id': user.id,
      'destination_id': destinationId,
      'location_source': locationSource,
      'selected_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id,destination_id,location_source');
  }

  Future<List<Map<String, dynamic>>> getSavedPuzzleLocations({
    required String locationSource,
  }) async {
    final user = _requireUser();
    final response = await _client
        .from('user_puzzle_locations')
        .select('''
          destination_id,
          selected_at,
          blind_box_destinations (
            destination_id,
            name,
            category,
            image_url,
            address
          )
        ''')
        .eq('user_id', user.id)
        .eq('location_source', locationSource)
        .order('selected_at', ascending: false);
    return (response as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
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

  Future<Map<String, int>>
  getBlindBoxPurchaseStatus() async {
    try {
      _requireUser();

      final response = await _client.rpc(
        'get_blind_box_purchase_status',
      );

      if (response is! Map) {
        throw const SupabaseDataException(
          'Unexpected response while loading '
              'Blind Box purchase status.',
        );
      }

      final data =
      Map<String, dynamic>.from(response);

      return {
        'exploration_points':
        _toInt(data['exploration_points']),
        'blind_box_chances':
        _toInt(data['blind_box_chances']),
        'purchased_today':
        _toInt(data['purchased_today']),
        'daily_remaining':
        _toInt(data['daily_remaining']),
        'holding_remaining':
        _toInt(data['holding_remaining']),
        'daily_limit':
        _toInt(data['daily_limit']),
        'max_chances':
        _toInt(data['max_chances']),
        'chance_cost_ep':
        _toInt(data['chance_cost_ep']),
      };
    } on SupabaseDataException {
      rethrow;
    } catch (error) {
      throw SupabaseDataException(
        'Failed to load Blind Box '
            'purchase status: $error',
      );
    }
  }

  Future<Map<String, int>>
  buyBlindBoxChances({
    required int quantity,
  }) async {
    try {
      _requireUser();

      if (quantity < 1) {
        throw const SupabaseDataException(
          'Please select at least '
              '1 Blind Box Chance.',
        );
      }

      if (quantity > 10) {
        throw const SupabaseDataException(
          'You can select a maximum of '
              '10 Blind Box Chances.',
        );
      }

      final response =
      await _client.rpc(
        'buy_blind_box_chances',
        params: {
          'p_quantity': quantity,
        },
      );

      if (response is! Map) {
        throw const SupabaseDataException(
          'Unexpected response while buying '
              'Blind Box Chances.',
        );
      }

      final data =
      Map<String, dynamic>.from(response);

      return {
        'exploration_points':
        _toInt(data['exploration_points']),
        'blind_box_chances':
        _toInt(data['blind_box_chances']),
        'quantity_purchased':
        _toInt(data['quantity_purchased']),
        'points_spent':
        _toInt(data['points_spent']),
        'purchased_today':
        _toInt(data['purchased_today']),
        'daily_remaining':
        _toInt(data['daily_remaining']),
        'holding_remaining':
        _toInt(data['holding_remaining']),
        'daily_limit':
        _toInt(data['daily_limit']),
        'max_chances':
        _toInt(data['max_chances']),
        'chance_cost_ep':
        _toInt(data['chance_cost_ep']),
      };
    } on SupabaseDataException {
      rethrow;
    } catch (error) {
      throw SupabaseDataException(
        'Failed to buy Blind Box Chances: '
            '$error',
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

String _blindBoxPurchaseErrorMessage(
    Object error, {
      required String fallback,
    }) {
  final String message =
  error.toString();

  if (message.contains(
    'AUTH_REQUIRED',
  )) {
    return 'Please log in before using Blind Box.';
  }

  if (message.contains(
    'INVALID_QUANTITY',
  )) {
    return 'Please select a valid number '
        'of Blind Box Chances.';
  }

  if (message.contains(
    'MAX_CHANCES_REACHED',
  )) {
    return 'You already have the maximum '
        'of 10 Blind Box Chances.';
  }

  if (message.contains(
    'HOLDING_LIMIT_EXCEEDED',
  )) {
    return 'Your selected quantity would '
        'exceed the maximum of '
        '10 Blind Box Chances.';
  }

  if (message.contains(
    'DAILY_LIMIT_REACHED',
  )) {
    return 'You have already purchased '
        '10 Blind Box Chances today.';
  }

  if (message.contains(
    'DAILY_LIMIT_EXCEEDED',
  )) {
    return 'Your selected quantity would '
        'exceed today\'s limit of '
        '10 Blind Box Chances.';
  }

  if (message.contains(
    'INSUFFICIENT_EP',
  )) {
    return 'You do not have enough '
        'Exploration Points for '
        'this purchase.';
  }

  if (message.contains(
    'PROFILE_NOT_FOUND',
  )) {
    return 'Your user profile could '
        'not be found.';
  }

  return '$fallback $message';
}