import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/trip_plan.dart';

class TripPlanDataSource {
  final SupabaseClient _client;

  TripPlanDataSource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<List<TripPlan>> loadMyPlans() async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];

    final planRows = await _client
        .from('trip_plans')
        .select('trip_id, trip_name, start_date, end_date, route_status, estimated_travel_minutes')
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    print('📊 Found ${planRows.length} plan rows');

    final plans = <TripPlan>[];
    for (final planRow in planRows) {
      final planId = planRow['trip_id'] as String;
      print('🔍 Processing plan: $planId (${planRow['trip_name']})');

      final stopRows = await _client
          .from('trip_plan_destinations')
          .select('destination_id, travel_day, sequence_order, source')
          .eq('trip_id', planId)
          .order('travel_day', ascending: true)
          .order('sequence_order', ascending: true);

      print('  📦 Found ${stopRows.length} stop rows');

      final stops = <ItineraryStop>[];
      for (final stopRow in stopRows) {
        final destId = stopRow['destination_id'];
        print('    🛑 Dest ID: $destId');
        final destRow = await _client
            .from('blind_box_destinations')
            .select('google_place_id, name, address, latitude, longitude')
            .eq('destination_id', destId)
            .maybeSingle();

        if (destRow != null) {
          print('    ✅ Found destination: ${destRow['name']}');
          stops.add(ItineraryStop(
            placeId: destRow['google_place_id'] as String? ?? destId.toString(),
            name: destRow['name'] as String,
            address: destRow['address'] as String? ?? '',
            latitude: (destRow['latitude'] as num).toDouble(),
            longitude: (destRow['longitude'] as num).toDouble(),
            dayNumber: stopRow['travel_day'] as int? ?? 1,
            sortOrder: stopRow['sequence_order'] as int? ?? 0,
            source: stopRow['source'] as String? ?? 'SEARCH',
          ));
        } else {
          print('    ❌ Destination NOT found for ID $destId');
        }
      }

      plans.add(TripPlan(
        id: planId,
        name: planRow['trip_name'] as String,
        startDate: DateTime.parse(planRow['start_date'] as String),
        endDate: DateTime.parse(planRow['end_date'] as String),
        mode: 'solo',
        visibility: 'private',
        inviteCode: null,
        routeAccepted: planRow['route_status'] == 'ACCEPTED' || planRow['route_status'] == 'GENERATED',
        estimatedTravelMinutes: planRow['estimated_travel_minutes'], // <--- ADDED THIS
        stops: stops,
      ));
    }

    print('📋 Loaded ${plans.length} plans');
    for (final plan in plans) {
      print('  ${plan.name}: ${plan.stops.length} stops');
    }
    return plans;
  }

  Future<TripPlan> savePlan(TripPlan plan) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const TripPlanDataException('Please log in first.');

    // Create the base data map (without the ID first, to handle new vs. existing plans)
    Map<String, dynamic> planData = {
      'user_id': user.id,
      'trip_name': plan.name,
      'start_date': _date(plan.startDate),
      'end_date': _date(plan.endDate),
      'route_status': plan.routeAccepted ? 'ACCEPTED' : 'NOT_PLANNED',
      'estimated_travel_minutes': plan.estimatedTravelMinutes,
      'status': 'ACTIVE',
    };

    dynamic planRow;

    // 1. If the plan is NEW (ID is empty), use insert() and let Supabase generate the UUID
    if (plan.id.isEmpty) {
      planRow = await _client
          .from('trip_plans')
          .insert(planData)
          .select()
          .single();
    }
    // 2. If the plan EXISTS (ID is valid), use upsert() to update it
    else {
      planData['trip_id'] = plan.id; // Add the valid ID
      planRow = await _client
          .from('trip_plans')
          .upsert(planData, onConflict: 'trip_id')
          .select()
          .single();
    }

    final planId = planRow['trip_id'] as String;

    if (plan.stops.isNotEmpty) {
      // ⚠️ REMOVED the delete().eq('trip_id', planId) line entirely!

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

      // ⚠️ REPLACED insert with upsert using the composite key!
      await _client.from('trip_plan_destinations').upsert(
          rows,
          onConflict: 'trip_id,destination_id'
      );
      print('✅ Upserted ${rows.length} destinations for plan $planId');
    }

    // RETURN: Make sure estimatedTravelMinutes is passed back!
    return TripPlan(
      id: planId,
      name: plan.name,
      startDate: plan.startDate,
      endDate: plan.endDate,
      mode: plan.mode,
      visibility: plan.visibility,
      inviteCode: plan.inviteCode,
      routeAccepted: plan.routeAccepted,
      estimatedTravelMinutes: plan.estimatedTravelMinutes, // <--- ADDED THIS
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
