// lib/data/repositories/group_repository.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/travel_group_model.dart';
import '../models/group_member_model.dart';
import '../models/join_request_model.dart';
import '../../core/config/supabase_config.dart';

class GroupRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  // 1. Fetch groups the user is a member of (with role)
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
        .eq('membership_status', 'ACTIVE'); // ✅ uppercase

    return response as List<Map<String, dynamic>>;
  }

  // 2. Fetch public teams (available to join)
  Future<List<TravelGroup>> fetchPublicTeams() async {
    final response = await _client
        .from('travel_groups')
        .select('*')
        .eq('team_type', 'PUBLIC')      // ✅ uppercase
        .eq('group_status', 'ACTIVE')   // ✅ uppercase
        .limit(50);

    return (response as List).map((json) => TravelGroup.fromJson(json)).toList();
  }

  // 3. Fetch a single team by id (with members)
  Future<Map<String, dynamic>> fetchTeamDetails(String groupId) async {
    // Fetch team info
    final teamResponse = await _client
        .from('travel_groups')
        .select('*')
        .eq('group_id', groupId)
        .single();

    // Fetch members with user profile info (join with profiles if needed)
    final membersResponse = await _client
        .from('travel_group_members')
        .select('''
          *,
          profiles!inner (
            full_name,
            profile_picture_url
          )
        ''')
        .eq('group_id', groupId)
        .eq('membership_status', 'ACTIVE'); // ✅ uppercase

    return {
      'team': TravelGroup.fromJson(teamResponse),
      'members': membersResponse as List<dynamic>,
    };
  }

  // 4. Fetch pending join requests for a team (only if user is owner/admin)
  Future<List<JoinRequest>> fetchPendingRequests(String groupId) async {
    final response = await _client
        .from('team_join_requests')
        .select('*')
        .eq('group_id', groupId)
        .eq('request_status', 'PENDING') // ✅ uppercase
        .order('requested_at', ascending: false);

    return (response as List).map((json) => JoinRequest.fromJson(json)).toList();
  }

  // 5. Insert a new team
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
      'team_type': teamType,          // must be 'PUBLIC' or 'PRIVATE'
      'preferred_language': preferredLanguage,
      'invitation_code': invitationCode,
      'max_capacity': maxCapacity ?? 10,
      'group_status': 'ACTIVE',       // ✅ uppercase
    })
        .select()
        .single();

    return TravelGroup.fromJson(response);
  }

  // 6. Add the creator as a member (owner role)
  Future<void> addTeamMember({
    required String groupId,
    required String userId,
    required String role, // must be 'OWNER' or 'MEMBER'
  }) async {
    await _client.from('travel_group_members').insert({
      'group_id': groupId,
      'user_id': userId,
      'member_role': role,                // e.g. 'OWNER'
      'membership_status': 'ACTIVE',      // ✅ uppercase
      'joined_at': DateTime.now().toIso8601String(),
    });
  }

  // 7. Submit a join request (if private) or join directly (if public, we handle via service)
  Future<void> insertJoinRequest({
    required String groupId,
    required String userId,
  }) async {
    // Check if already a member or pending
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
        .eq('request_status', 'PENDING') // ✅ uppercase
        .maybeSingle();

    if (pending != null) {
      throw Exception('You already have a pending request.');
    }

    await _client.from('team_join_requests').insert({
      'group_id': groupId,
      'user_id': userId,
      'request_status': 'PENDING',        // ✅ uppercase
      'requested_at': DateTime.now().toIso8601String(),
    });
  }

  // 8. Approve or reject a join request (owner/admin only)
  Future<void> handleJoinRequest({
    required String requestId,
    required bool approve,
  }) async {
    // Get the request details to know group_id and user_id
    final request = await _client
        .from('team_join_requests')
        .select('group_id, user_id')
        .eq('request_id', requestId)
        .single();

    if (approve) {
      // Add user to members
      await _client.from('travel_group_members').insert({
        'group_id': request['group_id'],
        'user_id': request['user_id'],
        'member_role': 'MEMBER',          // ✅ uppercase
        'membership_status': 'ACTIVE',    // ✅ uppercase
        'joined_at': DateTime.now().toIso8601String(),
      });
    }

    // Update the request status
    await _client.from('team_join_requests').update({
      'request_status': approve ? 'APPROVED' : 'REJECTED', // ✅ uppercase
      'responded_at': DateTime.now().toIso8601String(),
    }).eq('request_id', requestId);
  }

  // 9. Leave a team (delete membership)
  Future<void> leaveTeam({
    required String groupId,
    required String userId,
  }) async {
    // Prevent owner from leaving? You can add a check.
    await _client
        .from('travel_group_members')
        .delete()
        .eq('group_id', groupId)
        .eq('user_id', userId);
  }

  // 10. Find group by invitation code (for join by code)
  Future<TravelGroup?> findGroupByInvitationCode(String code) async {
    final response = await _client
        .from('travel_groups')
        .select('*')
        .eq('invitation_code', code)
        .eq('group_status', 'ACTIVE') // ✅ uppercase
        .maybeSingle();

    if (response == null) return null;
    return TravelGroup.fromJson(response);
  }
}