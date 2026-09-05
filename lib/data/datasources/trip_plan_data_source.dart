import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/trip_plan.dart';

class TripPlanDataSource {
  final SupabaseClient _client;

  TripPlanDataSource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<List<TripPlan>> loadMyPlans() async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];

    // 1. Find all teams the user belongs to (as owner OR joined member)
    final memberTeams = <Map<String, dynamic>>[];
    try {
      final memberships = await _client
          .from('travel_group_members')
          .select('group_id, travel_groups(group_id, owner_id, team_name, team_type, invitation_code, group_status)')
          .eq('user_id', user.id)
          .eq('membership_status', 'ACTIVE');

      for (final m in memberships) {
        if (m['travel_groups'] != null) {
          memberTeams.add(m['travel_groups'] as Map<String, dynamic>);
        }
      }
    } catch (e) {
      print('Note: Error fetching member teams: $e');
    }

    // 2. Fetch plans created by this user
    final myPlanRows = await _client
        .from('trip_plans')
        .select('trip_id, user_id, trip_name, start_date, end_date, route_status, ai_travel_story, created_at')
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    final allPlanRows = <Map<String, dynamic>>[...myPlanRows];
    final fetchedTripIds = myPlanRows.map((r) => r['trip_id'] as String).toSet();

    // 3. For any joined squads where the user is NOT the owner, fetch the host's team plan!
    for (final team in memberTeams) {
      final ownerId = team['owner_id'] as String?;
      final code = team['invitation_code'] as String?;

      if (ownerId != null && ownerId != user.id && code != null && code.isNotEmpty) {
        try {
          // Search for the host's trip plan matching this team's invitation code
          final hostPlans = await _client
              .from('trip_plans')
              .select('trip_id, user_id, trip_name, start_date, end_date, route_status, ai_travel_story, created_at')
              .eq('user_id', ownerId)
              .ilike('ai_travel_story', '%CODE:$code%');

          for (final hp in hostPlans) {
            final tid = hp['trip_id'] as String;
            if (!fetchedTripIds.contains(tid)) {
              fetchedTripIds.add(tid);
              allPlanRows.add(hp);
            }
          }
        } catch (e) {
          print('Note: Error fetching joined squad plan for code $code: $e');
        }
      }
    }

    print('📊 Total plans to load (own + joined): ${allPlanRows.length}');

    // 4. Map rows to TripPlan models with stops
    final plans = <TripPlan>[];
    for (final planRow in allPlanRows) {
      final planId = planRow['trip_id'] as String;

      final stopRows = await _client
          .from('trip_plan_destinations')
          .select('destination_id, travel_day, sequence_order, source')
          .eq('trip_id', planId)
          .order('travel_day', ascending: true)
          .order('sequence_order', ascending: true);

      final stops = <ItineraryStop>[];
      for (final stopRow in stopRows) {
        final destId = stopRow['destination_id'];
        final destRow = await _client
            .from('blind_box_destinations')
            .select('google_place_id, name, address, latitude, longitude')
            .eq('destination_id', destId)
            .maybeSingle();

        if (destRow != null) {
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
        }
      }

      // Parse Expedition Mode & Invite Code
      final story = (planRow['ai_travel_story'] as String?) ?? '';
      String planMode = 'solo';
      String? inviteCode;
      String visibility = 'private';

      if (story.contains('MODE:team')) {
        planMode = 'team';
        final matchCode = RegExp(r'CODE:([A-Za-z0-9_-]+)').firstMatch(story);
        if (matchCode != null && matchCode.group(1)!.isNotEmpty) {
          inviteCode = matchCode.group(1);
        }

        final matchVis = RegExp(r'VIS:([a-z]+)').firstMatch(story);
        if (matchVis != null) {
          visibility = matchVis.group(1)!;
        }
      } else {
        // Check if this plan matches any team the user joined
        for (final t in memberTeams) {
          final tCode = t['invitation_code'] as String?;
          if (tCode != null && story.contains(tCode)) {
            planMode = 'team';
            inviteCode = tCode;
            visibility = (t['team_type'] == 'PUBLIC') ? 'public' : 'private';
            break;
          }
        }
      }

      plans.add(TripPlan(
        id: planId,
        name: planRow['trip_name'] as String,
        startDate: DateTime.parse(planRow['start_date'] as String),
        endDate: DateTime.parse(planRow['end_date'] as String),
        mode: planMode,
        visibility: visibility,
        inviteCode: inviteCode,
        routeAccepted: planRow['route_status'] == 'ACCEPTED' ||
            planRow['route_status'] == 'GENERATED',
        stops: stops,
      ));
    }

    return plans;
  }

  Future<TripPlan> savePlan(TripPlan plan) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const TripPlanDataException('Please log in first.');

    // Encode mode, invite code, and visibility into metadata
    final metadataString = plan.mode == 'team'
        ? 'MODE:team|CODE:${plan.inviteCode ?? ''}|VIS:${plan.visibility}'
        : 'MODE:solo';

    final planRow = await _client
        .from('trip_plans')
        .insert({
      'user_id': user.id,
      'trip_name': plan.name,
      'start_date': _date(plan.startDate),
      'end_date': _date(plan.endDate),
      'route_status': plan.routeAccepted ? 'ACCEPTED' : 'NOT_PLANNED',
      'status': 'ACTIVE',
      'ai_travel_story': metadataString,
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
      print('✅ Inserted ${rows.length} destinations for plan $planId');
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

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

class TripPlanDataException implements Exception {
  final String message;
  const TripPlanDataException(this.message);
  @override
  String toString() => message;
}