import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/trip_plan.dart';

class TripPlanDataSource {
  final SupabaseClient _client;

  TripPlanDataSource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<List<TripPlan>> loadMyPlans() async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];

    final rows = await _client
        .from('trip_plans')
        .select('''
          trip_id, trip_name, start_date, end_date, route_status,
          trip_plan_destinations (
            destination_id, travel_day, sequence_order,
            blind_box_destinations (
              google_place_id, name, address, latitude, longitude
            )
          )
        ''')
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(rows)
        .map(_planFromRow)
        .toList();
  }

  Future<TripPlan> savePlan(TripPlan plan) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const TripPlanDataException('Please log in first.');

    final planRow = await _client
        .from('trip_plans')
        .insert({
      'user_id': user.id,
      'trip_name': plan.name,
      'start_date': _date(plan.startDate),
      'end_date': _date(plan.endDate),
      'route_status': plan.routeAccepted ? 'ACCEPTED' : 'NOT_PLANNED',
      'status': 'ACTIVE',
    })
        .select()
        .single();

    final planId = planRow['trip_id'] as String;
    if (plan.stops.isNotEmpty) {
      final rows = <Map<String, dynamic>>[];
      for (final stop in plan.stops) {
        var destination = await _client
            .from('blind_box_destinations')
            .select('destination_id')
            .eq('google_place_id', stop.placeId)
            .maybeSingle();

        destination ??= await _client
            .from('blind_box_destinations')
            .insert({
              'google_place_id': stop.placeId,
              'name': stop.name,
              'address': stop.address,
              'latitude': stop.latitude,
              'longitude': stop.longitude,
              'destination_source': 'GOOGLE',
            })
            .select('destination_id')
            .single();

        rows.add({
          'trip_id': planId,
          'destination_id': destination['destination_id'],
          'travel_day': stop.dayNumber,
          'sequence_order': stop.sortOrder,
          'source': 'SEARCH',
        });
      }
      await _client.from('trip_plan_destinations').insert(rows);
    }
    return TripPlan(
      id: planId,
      name: plan.name,
      startDate: plan.startDate,
      endDate: plan.endDate,
      mode: plan.mode,
      visibility: plan.visibility,
      inviteCode: plan.inviteCode,
      routeAccepted: plan.routeAccepted,
      stops: plan.stops,
    );
  }

  TripPlan _planFromRow(Map<String, dynamic> row) {
    final rawStops = List<Map<String, dynamic>>.from(
      row['trip_plan_destinations'] ?? [],
    )..sort((a, b) {
      // Fix the comparator – compare ints correctly
      final dayA = (a['travel_day'] as int?) ?? 0;
      final dayB = (b['travel_day'] as int?) ?? 0;
      if (dayA != dayB) return dayA.compareTo(dayB);
      final seqA = (a['sequence_order'] as int?) ?? 0;
      final seqB = (b['sequence_order'] as int?) ?? 0;
      return seqA.compareTo(seqB);
    });

    return TripPlan(
      id: row['trip_id'] as String,
      name: row['trip_name'] as String,
      startDate: DateTime.parse(row['start_date'] as String),
      endDate: DateTime.parse(row['end_date'] as String),
      mode: 'solo',
      visibility: 'private',
      inviteCode: null,
      routeAccepted: row['route_status'] == 'ACCEPTED' || row['route_status'] == 'GENERATED',
      stops: rawStops.map((stop) {
        final dest = stop['blind_box_destinations'] as Map<String, dynamic>;
        return ItineraryStop(
          placeId: dest['google_place_id'] as String? ?? stop['destination_id'].toString(),
          name: dest['name'] as String,
          address: dest['address'] as String? ?? '',
          latitude: (dest['latitude'] as num).toDouble(),
          longitude: (dest['longitude'] as num).toDouble(),
          dayNumber: stop['travel_day'] as int? ?? 1,
          sortOrder: stop['sequence_order'] as int? ?? 0,
          // Add the source field (if needed)
          source: 'GOOGLE',   // or read from stop['source'] if stored
        );
      }).toList(),
    );
  }

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

class TripPlanDataException implements Exception {
  final String message;
  const TripPlanDataException(this.message);
  @override
  String toString() => message;
}
