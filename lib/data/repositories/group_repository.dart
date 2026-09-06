import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/travel_group_model.dart';

class GroupRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<TravelGroup?> findGroupByInvitationCode(String code) async {
    final response = await _client
        .from('travel_groups')
        .select()
        .eq('invitation_code', code)
        .maybeSingle();
    if (response == null) return null;
    return TravelGroup.fromJson(response);
  }

  Future<TravelGroup> createTeam({
    required String ownerId,
    required String teamName,
    required String teamType,
    String? preferredLanguage,
    int? maxCapacity,
    required String invitationCode,
  }) async {
    final response = await _client.from('travel_groups').insert({
      'owner_id': ownerId,
      'team_name': teamName,
      'team_type': teamType.toUpperCase(),
      'preferred_language': preferredLanguage,
      'max_capacity': maxCapacity ?? 5,
      'invitation_code': invitationCode,
      'group_status': 'ACTIVE',
    }).select().single();
    return TravelGroup.fromJson(response);
  }

  Future<void> addTeamMember({
    required String groupId,
    required String userId,
    required String role,
  }) async {
    await _client.from('travel_group_members').insert({
      'group_id': groupId,
      'user_id': userId,
      'member_role': role,
      'membership_status': 'ACTIVE',
    });
  }

  Future<void> insertJoinRequest({
    required String groupId,
    required String userId,
  }) async {
    await _client.from('team_join_requests').insert({
      'group_id': groupId,
      'user_id': userId,
      'request_status': 'PENDING',
    });
  }

  // ---- FIXED: fetchUserTeams filters only ACTIVE groups ----
  Future<List<Map<String, dynamic>>> fetchUserTeams(String userId) async {
    final response = await _client
        .from('travel_group_members')
        .select('''
          member_role,
          membership_status,
          travel_groups!inner (
            group_id,
            owner_id,
            team_name,
            team_type,
            preferred_language,
            invitation_code,
            max_capacity,
            group_status,
            created_at,
            updated_at
          )
        ''')
        .eq('user_id', userId)
        .eq('membership_status', 'ACTIVE')
        .eq('travel_groups.group_status', 'ACTIVE'); // Only ACTIVE groups

    final List<dynamic> data = response;
    final result = <Map<String, dynamic>>[];
    for (final row in data) {
      final map = Map<String, dynamic>.from(row);
      dynamic groupData = row['travel_groups'];
      if (groupData is List) {
        groupData = groupData.isNotEmpty ? groupData.first : null;
      }
      map['travel_groups'] = groupData as Map<String, dynamic>? ?? {};
      result.add(map);
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> fetchPublicTeams() async {
    final response = await _client
        .from('travel_groups')
        .select('''
          *,
          owner_profile:profiles!owner_id (
            full_name
          ),
          trip_plan:trip_plans!left (
            start_date,
            end_date,
            trip_plan_destinations!left (
              travel_day,
              sequence_order,
              blind_box_destinations!inner (
                name
              )
            )
          )
        ''')
        .eq('team_type', 'PUBLIC')
        .eq('group_status', 'ACTIVE')
        .order('created_at', ascending: false);

    final List<dynamic> data = response;
    final result = <Map<String, dynamic>>[];

    for (final row in data) {
      final rowMap = Map<String, dynamic>.from(row);
      final team = TravelGroup.fromJson(rowMap);

      dynamic ownerProfile = row['owner_profile'];
      if (ownerProfile is List) {
        ownerProfile = ownerProfile.isNotEmpty ? ownerProfile.first : null;
      }
      final ownerName = (ownerProfile as Map<String, dynamic>?)?['full_name'] as String? ?? 'Unknown Host';

      dynamic tripPlan = row['trip_plan'];
      if (tripPlan is List) {
        tripPlan = tripPlan.isNotEmpty ? tripPlan.first : null;
      }

      DateTime? tripStart;
      DateTime? tripEnd;
      String? firstStopName;

      if (tripPlan is Map<String, dynamic>) {
        if (tripPlan['start_date'] != null) {
          tripStart = DateTime.parse(tripPlan['start_date'] as String);
        }
        if (tripPlan['end_date'] != null) {
          tripEnd = DateTime.parse(tripPlan['end_date'] as String);
        }

        dynamic stopList = tripPlan['trip_plan_destinations'];
        if (stopList is List && stopList.isNotEmpty) {
          final firstStop = stopList.first;
          final dest = firstStop['blind_box_destinations'] as Map<String, dynamic>?;
          if (dest != null) {
            firstStopName = dest['name'] as String?;
          }
        }
      }

      final enrichedTeam = TravelGroup(
        groupId: team.groupId,
        ownerId: team.ownerId,
        teamName: team.teamName,
        teamType: team.teamType,
        preferredLanguage: team.preferredLanguage,
        invitationCode: team.invitationCode,
        maxCapacity: team.maxCapacity,
        groupStatus: team.groupStatus,
        createdAt: team.createdAt,
        updatedAt: team.updatedAt,
        tripStartDate: tripStart ?? team.tripStartDate,
        tripEndDate: tripEnd ?? team.tripEndDate,
      );

      result.add({
        'team': enrichedTeam,
        'ownerName': ownerName,
        'tripStart': tripStart,
        'tripEnd': tripEnd,
        'firstStopName': firstStopName,
      });
    }

    return result;
  }

  Future<TravelGroup?> fetchTeamInfo(String groupId) async {
    final response = await _client
        .from('travel_groups')
        .select()
        .eq('group_id', groupId)
        .maybeSingle();
    if (response == null) return null;
    return TravelGroup.fromJson(response);
  }

  Future<List<Map<String, dynamic>>> fetchTeamMembers(String groupId) async {
    final response = await _client
        .from('travel_group_members')
        .select('''
          user_id,
          member_role,
          membership_status,
          joined_at,
          profiles (
            id,
            full_name,
            profile_picture_url,
            language_preference,
            current_city
          )
        ''')
        .eq('group_id', groupId)
        .eq('membership_status', 'ACTIVE');

    final members = List<Map<String, dynamic>>.from(response);
    for (var m in members) {
      dynamic p = m['profiles'];
      if (p is List) {
        m['profiles'] = p.isNotEmpty ? p.first : null;
      }
    }
    return members;
  }

  Future<List<Map<String, dynamic>>> getProfiles(List<String> userIds) async {
    if (userIds.isEmpty) return [];
    final response = await _client
        .from('profiles')
        .select('id, full_name, profile_picture_url, language_preference, current_city')
        .inFilter('id', userIds);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> fetchPendingRequests(String groupId) async {
    final response = await _client
        .from('team_join_requests')
        .select('request_id, user_id, requested_at')
        .eq('group_id', groupId)
        .eq('request_status', 'PENDING');
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> handleJoinRequest({required String requestId, required bool approve}) async {
    final status = approve ? 'APPROVED' : 'REJECTED';
    await _client
        .from('team_join_requests')
        .update({'request_status': status, 'responded_at': DateTime.now().toIso8601String()})
        .eq('request_id', requestId);

    if (approve) {
      final request = await _client
          .from('team_join_requests')
          .select('group_id, user_id')
          .eq('request_id', requestId)
          .single();
      await addTeamMember(
        groupId: request['group_id'],
        userId: request['user_id'],
        role: 'MEMBER',
      );
    }
  }

  Future<void> leaveTeam({required String groupId, required String userId}) async {
    await _client
        .from('travel_group_members')
        .update({'membership_status': 'LEFT'})
        .eq('group_id', groupId)
        .eq('user_id', userId);
  }

  Future<void> disbandTeam({required String groupId, required String ownerId}) async {
    // Verify owner
    final group = await fetchTeamInfo(groupId);
    if (group?.ownerId != ownerId) {
      throw Exception('Only the owner can disband the team.');
    }
    // Close the group
    await _client
        .from('travel_groups')
        .update({'group_status': 'CLOSED'})
        .eq('group_id', groupId);
  }

  Future<void> transferOwnershipAndLeave({
    required String groupId,
    required String currentOwnerId,
    required String newOwnerId,
  }) async {
    await _client
        .from('travel_groups')
        .update({'owner_id': newOwnerId})
        .eq('group_id', groupId);
    await _client
        .from('travel_group_members')
        .update({'member_role': 'MEMBER'})
        .eq('group_id', groupId)
        .eq('user_id', currentOwnerId);
    await _client
        .from('travel_group_members')
        .update({'member_role': 'OWNER'})
        .eq('group_id', groupId)
        .eq('user_id', newOwnerId);
    await leaveTeam(groupId: groupId, userId: currentOwnerId);
  }

  Future<void> removeTeamMember({required String groupId, required String userId}) async {
    await _client
        .from('travel_group_members')
        .update({'membership_status': 'REMOVED'})
        .eq('group_id', groupId)
        .eq('user_id', userId);
  }
}