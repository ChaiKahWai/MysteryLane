import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trip_plan.dart';

class TripPlanDataSource {
  final SupabaseClient _client;

  TripPlanDataSource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<List<TripPlan>> loadMyPlans() async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];

    // 1. Fetch active teams the user currently belongs to
    final activeGroupIds = <String>{};
    final activeInviteCodes = <String>{};
    final groupDetails = <String, Map<String, dynamic>>{}; // <-- NEW map

    try {
      final memberRows = await _client
          .from('travel_group_members')
          .select('group_id, membership_status, travel_groups(group_id, group_status, invitation_code, team_type)')
          .eq('user_id', user.id)
          .eq('membership_status', 'ACTIVE');

      for (final m in (memberRows as List? ?? [])) {
        final g = m['travel_groups'] as Map<String, dynamic>?;
        if (g != null && g['group_status'] == 'ACTIVE') {
          final gid = g['group_id']?.toString();
          final code = g['invitation_code']?.toString();
          final teamType = g['team_type']?.toString();
          if (gid != null && gid.isNotEmpty) {
            activeGroupIds.add(gid);
            groupDetails[gid] = {
              'invitation_code': code,
              'team_type': teamType,
            };
          }
          if (code != null && code.isNotEmpty) {
            activeInviteCodes.add(code.toUpperCase());
          }
        }
      }
    } catch (e) {
      print('Notice: Error fetching active user groups: $e');
    }

    // 2. Fetch all plans created by the user
    final myPlanRows = await _client
        .from('trip_plans')
        .select('trip_id, trip_name, start_date, end_date, route_status, group_id, status, ai_travel_story')
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    final allPlanRows = <Map<String, dynamic>>[];
    final seenTripIds = <String>{};

    for (final r in (myPlanRows as List? ?? [])) {
      final tid = r['trip_id']?.toString();
      if (tid != null && seenTripIds.add(tid)) {
        allPlanRows.add(Map<String, dynamic>.from(r));
      }
    }

    // Also fetch team plans from active groups (these will have group_id)
    if (activeGroupIds.isNotEmpty) {
      try {
        final teamPlanRows = await _client
            .from('trip_plans')
            .select('trip_id, trip_name, start_date, end_date, route_status, group_id, status, ai_travel_story')
            .inFilter('group_id', activeGroupIds.toList())
            .order('created_at', ascending: false);

        for (final r in (teamPlanRows as List? ?? [])) {
          final tid = r['trip_id']?.toString();
          if (tid != null && seenTripIds.add(tid)) {
            allPlanRows.add(Map<String, dynamic>.from(r));
          }
        }
      } catch (e) {
        print('Notice: Error fetching team group plans: $e');
      }
    }

    // 3. Filter plans:
    // - Skip if status is INACTIVE / CLOSED / DELETED
    // - If a plan has group_id, it's a team plan → only show if group_id is in activeGroupIds
    // - If no group_id, but has MODE:team in story → fallback to invite-code check
    final eligibleRows = <Map<String, dynamic>>[];
    for (final row in allPlanRows) {
      final status = row['status']?.toString();
      if (status == 'INACTIVE' || status == 'CLOSED' || status == 'DELETED') continue;

      final groupId = row['group_id']?.toString();

      // CASE 1: Plan is explicitly linked to a group
      if (groupId != null && groupId.isNotEmpty) {
        // Only keep if user is still an active member of that group
        if (activeGroupIds.contains(groupId)) {
          eligibleRows.add(row);
        }
        // else: skip (user left the team)
        continue;
      }

      // CASE 2: Plan has no group_id → check metadata for team mode (legacy)
      final story = row['ai_travel_story']?.toString() ?? '';
      final isTeamPlan = story.contains('MODE:team');

      if (isTeamPlan) {
        // Extract invite code from story
        final match = RegExp(r'CODE:([A-Za-z0-9]+)').firstMatch(story);
        final planCode = match?.group(1)?.toUpperCase();
        if (planCode != null && activeInviteCodes.contains(planCode)) {
          eligibleRows.add(row);
        }
        // else: skip (user no longer has a team with that code)
      } else {
        // Solo plan – always visible
        eligibleRows.add(row);
      }
    }

    print('📊 Found ${eligibleRows.length} eligible plan rows');

    // 4. Map rows to TripPlan models with stops
    final plans = <TripPlan>[];
    for (final planRow in eligibleRows) {
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

      // --------------------------
      // Determine mode, visibility, inviteCode
      // --------------------------
      final groupId = planRow['group_id']?.toString();
      String mode = 'solo';
      String? inviteCode;
      String visibility = 'private';

      if (groupId != null && groupId.isNotEmpty) {
        // Plan linked to a group – derive from groupDetails
        final details = groupDetails[groupId];
        if (details != null) {
          mode = 'team';
          inviteCode = details['invitation_code'];
          visibility = (details['team_type'] == 'PUBLIC') ? 'public' : 'private';
        } else {
          // The group might be inactive or user left – we already filtered, but fallback to solo
          mode = 'solo';
        }
      } else {
        // No group_id – maybe a legacy team plan stored in ai_travel_story?
        final story = planRow['ai_travel_story'] as String? ?? '';
        if (story.contains('MODE:team')) {
          mode = 'team';
          final matchCode = RegExp(r'CODE:([A-Za-z0-9_-]+)').firstMatch(story);
          if (matchCode != null && matchCode.group(1)!.isNotEmpty) {
            inviteCode = matchCode.group(1);
          }
          final matchVis = RegExp(r'VIS:([a-z]+)').firstMatch(story);
          if (matchVis != null) {
            visibility = matchVis.group(1)!;
          }
        }
        // else solo, stays as default
      }

      plans.add(TripPlan(
        id: planId,
        name: planRow['trip_name'] as String,
        startDate: DateTime.parse(planRow['start_date'] as String),
        endDate: DateTime.parse(planRow['end_date'] as String),
        mode: mode,
        visibility: visibility,
        inviteCode: inviteCode,
        groupId: groupId,
        routeAccepted: planRow['route_status'] == 'ACCEPTED' ||
            planRow['route_status'] == 'GENERATED',
        stops: stops,
      ));
    }

    return plans;
  }

  // --------------------------------------------------------------------------
  // SAVE PLAN (ai_travel_story set to null)
  // --------------------------------------------------------------------------
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
      'ai_travel_story': null, // ✅ null – metadata is now derived from group_id
      'group_id': plan.groupId,
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
      groupId: plan.groupId,
      routeAccepted: plan.routeAccepted,
      stops: plan.stops,
    );
  }

  // Helper to format date
  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

class TripPlanDataException implements Exception {
  final String message;
  const TripPlanDataException(this.message);
  @override
  String toString() => message;
}