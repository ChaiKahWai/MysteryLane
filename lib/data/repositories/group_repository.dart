import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/travel_group_model.dart';
import '../../core/config/supabase_config.dart';

class GroupRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  // 1. Fetch user teams
  Future<List<Map<String, dynamic>>> fetchUserTeams(String userId) async {
    final response = await _client
        .from('travel_group_members')
        .select('''
          group_id,
          member_role,
          membership_status,
          travel_groups!inner (
            group_id,
            team_name,
            team_type,
            invitation_code,
            max_capacity,
            owner_id,
            created_at
          )
        ''')
        .eq('user_id', userId)
        .eq('membership_status', 'ACTIVE');
    return response as List<Map<String, dynamic>>;
  }

  // 2. Fetch public teams
  Future<List<TravelGroup>> fetchPublicTeams() async {
    final response = await _client
        .from('travel_groups')
        .select('*')
        .eq('team_type', 'PUBLIC')
        .eq('group_status', 'ACTIVE')
        .limit(50);
    return (response as List).map((json) => TravelGroup.fromJson(json)).toList();
  }

  // 3. Fetch team info only (no members)
  Future<TravelGroup> fetchTeamInfo(String groupId) async {
    final response = await _client
        .from('travel_groups')
        .select('*')
        .eq('group_id', groupId)
        .single();
    return TravelGroup.fromJson(response);
  }

  // 4. Fetch members of a team (raw, without profile)
  Future<List<Map<String, dynamic>>> fetchTeamMembers(String groupId) async {
    final response = await _client
        .from('travel_group_members')
        .select('*')
        .eq('group_id', groupId)
        .eq('membership_status', 'ACTIVE');
    return response as List<Map<String, dynamic>>;
  }

  // 5. Fetch profiles for multiple user IDs
  Future<List<Map<String, dynamic>>> getProfiles(List<String> userIds) async {
    if (userIds.isEmpty) return [];
    final response = await _client
        .from('profiles')
        .select('id, full_name, profile_picture_url')
        .inFilter('id', userIds);
    return response as List<Map<String, dynamic>>;
  }

  // 6. Fetch a single profile
  Future<Map<String, dynamic>?> getProfile(String userId) async {
    final response = await _client
        .from('profiles')
        .select('full_name, profile_picture_url')
        .eq('id', userId)
        .maybeSingle();
    return response as Map<String, dynamic>?;
  }

  // 7. Fetch pending join requests (raw)
  Future<List<Map<String, dynamic>>> fetchPendingRequests(String groupId) async {
    final response = await _client
        .from('team_join_requests')
        .select('*')
        .eq('group_id', groupId)
        .eq('request_status', 'PENDING')
        .order('requested_at', ascending: false);
    return response as List<Map<String, dynamic>>;
  }

  // 8. Create team
  Future<TravelGroup> createTeam({
    required String ownerId,
    required String teamName,
    required String teamType,
    String? preferredLanguage,
    int? maxCapacity,
    required String invitationCode,
  }) async {
    final response = await _client
        .from('travel_groups')
        .insert({
      'owner_id': ownerId,
      'team_name': teamName,
      'team_type': teamType,
      'preferred_language': preferredLanguage,
      'invitation_code': invitationCode,
      'max_capacity': maxCapacity ?? 10,
      'group_status': 'ACTIVE',
    })
        .select()
        .single();
    return TravelGroup.fromJson(response);
  }

  // 9. Add team member
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
      'joined_at': DateTime.now().toIso8601String(),
    });
  }

  // 10. Insert join request
  Future<void> insertJoinRequest({
    required String groupId,
    required String userId,
  }) async {
    final existing = await _client
        .from('travel_group_members')
        .select('group_member_id')
        .eq('group_id', groupId)
        .eq('user_id', userId)
        .maybeSingle();
    if (existing != null) {
      throw Exception('You are already a member of this team.');
    }
    final pending = await _client
        .from('team_join_requests')
        .select('request_id')
        .eq('group_id', groupId)
        .eq('user_id', userId)
        .eq('request_status', 'PENDING')
        .maybeSingle();
    if (pending != null) {
      throw Exception('You already have a pending request.');
    }
    await _client.from('team_join_requests').insert({
      'group_id': groupId,
      'user_id': userId,
      'request_status': 'PENDING',
      'requested_at': DateTime.now().toIso8601String(),
    });
  }

  // 11. Handle join request
  Future<void> handleJoinRequest({
    required String requestId,
    required bool approve,
  }) async {
    final request = await _client
        .from('team_join_requests')
        .select('group_id, user_id')
        .eq('request_id', requestId)
        .single();
    if (approve) {
      await _client.from('travel_group_members').insert({
        'group_id': request['group_id'],
        'user_id': request['user_id'],
        'member_role': 'MEMBER',
        'membership_status': 'ACTIVE',
        'joined_at': DateTime.now().toIso8601String(),
      });
    }
    await _client.from('team_join_requests').update({
      'request_status': approve ? 'APPROVED' : 'REJECTED',
      'responded_at': DateTime.now().toIso8601String(),
    }).eq('request_id', requestId);
  }

  // 12. Leave team
  Future<void> leaveTeam({
    required String groupId,
    required String userId,
  }) async {
    await _client
        .from('travel_group_members')
        .delete()
        .eq('group_id', groupId)
        .eq('user_id', userId);

    try {
      await _client
          .from('profiles')
          .update({'team_status': null})
          .eq('id', userId);
    } catch (_) {}
  }

  // 12a. Disband team
  Future<void> disbandTeam({
    required String groupId,
    required String ownerId,
  }) async {
    // 1. Remove all members
    await _client
        .from('travel_group_members')
        .delete()
        .eq('group_id', groupId);

    // 2. Set group status to CLOSED
    await _client
        .from('travel_groups')
        .update({'group_status': 'CLOSED'})
        .eq('group_id', groupId);

    // 3. Reset owner profile team status
    try {
      await _client
          .from('profiles')
          .update({'team_status': null})
          .eq('id', ownerId);
    } catch (_) {}
  }

  // 12b. Transfer ownership and leave
  Future<void> transferOwnershipAndLeave({
    required String groupId,
    required String currentOwnerId,
    required String newOwnerId,
  }) async {
    // 1. Update owner in travel_groups
    await _client
        .from('travel_groups')
        .update({'owner_id': newOwnerId})
        .eq('group_id', groupId);

    // 2. Promote new owner in travel_group_members
    await _client
        .from('travel_group_members')
        .update({'member_role': 'OWNER'})
        .eq('group_id', groupId)
        .eq('user_id', newOwnerId);

    // 3. Remove current owner from travel_group_members
    await _client
        .from('travel_group_members')
        .delete()
        .eq('group_id', groupId)
        .eq('user_id', currentOwnerId);

    // 4. Reset previous owner profile team status
    try {
      await _client
          .from('profiles')
          .update({'team_status': null})
          .eq('id', currentOwnerId);
    } catch (_) {}
  }

  // 13. Find group by invitation code
  Future<TravelGroup?> findGroupByInvitationCode(String code) async {
    final response = await _client
        .from('travel_groups')
        .select('*')
        .eq('invitation_code', code)
        .eq('group_status', 'ACTIVE')
        .maybeSingle();
    if (response == null) return null;
    return TravelGroup.fromJson(response);
  }

  // -------------------------------------------------------------------------
  // NEW: Remove a member (for owner)
  // -------------------------------------------------------------------------
  Future<void> removeTeamMember({
    required String groupId,
    required String userId,
  }) async {
    // Delete the member record
    await _client
        .from('travel_group_members')
        .delete()
        .eq('group_id', groupId)
        .eq('user_id', userId);

    // Optionally reset the user's profile team_status to null
    try {
      await _client
          .from('profiles')
          .update({'team_status': null})
          .eq('id', userId);
    } catch (_) {
      // Ignore errors (profile might not exist or column missing)
    }
  }
}