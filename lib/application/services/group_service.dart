import 'dart:math';
import '../../data/repositories/group_repository.dart';
import '../../data/models/travel_group_model.dart';
import '../../data/models/trip_plan.dart';
import '../../data/datasources/trip_plan_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GroupService {
  final GroupRepository _repository = GroupRepository();
  final TripPlanDataSource _tripPlanDataSource = TripPlanDataSource();

  String generateInvitationCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(6, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
  }

  // In group_service.dart

  Future<void> markChatAsRead(String userId, String groupId) async {
    await Supabase.instance.client
        .from('travel_group_members')
        .update({
      'last_read_at': DateTime.now().toUtc().toIso8601String(),
    })
        .eq('user_id', userId)
        .eq('group_id', groupId);
  }

  Future<TravelGroup> createTeam({
    required String ownerId,
    required String teamName,
    required String teamType,
    String? preferredLanguage,
    int? maxCapacity,
  }) async {
    String code;
    bool exists;
    do {
      code = generateInvitationCode();
      final existing = await _repository.findGroupByInvitationCode(code);
      exists = existing != null;
    } while (exists);

    final newGroup = await _repository.createTeam(
      ownerId: ownerId,
      teamName: teamName,
      teamType: teamType,
      preferredLanguage: preferredLanguage,
      maxCapacity: maxCapacity,
      invitationCode: code,
    );

    await _repository.addTeamMember(
      groupId: newGroup.groupId,
      userId: ownerId,
      role: 'OWNER',
    );

    return newGroup;
  }

  // ---- UPDATED: requestToJoinByCode now prevents duplicates ----
  Future<void> requestToJoinByCode({
    required String code,
    required String userId,
  }) async {
    final group = await _repository.findGroupByInvitationCode(code);
    if (group == null) {
      throw Exception('Invalid or inactive invitation code');
    }

    // Check if already a member
    final isMember = await _repository.hasActiveMembership(group.groupId, userId);
    if (isMember) {
      throw Exception('You are already a member of this team.');
    }

    // Check if there's a pending request
    final hasPending = await _repository.hasPendingRequest(group.groupId, userId);
    if (hasPending) {
      throw Exception('You already have a pending join request for this team.');
    }

    await _repository.insertJoinRequest(
      groupId: group.groupId,
      userId: userId,
    );
  }

  Future<List<Map<String, dynamic>>> getUserTeams(String userId) async {
    return await _repository.fetchUserTeams(userId);
  }

  Future<List<Map<String, dynamic>>> getPublicTeams() async {
    return await _repository.fetchPublicTeams();
  }

  Future<Map<String, dynamic>> getTeamDetails(String groupId) async {
    final team = await _repository.fetchTeamInfo(groupId);
    final members = await _repository.fetchTeamMembers(groupId);
    return {
      'team': team,
      'members': members,
    };
  }

  Future<List<Map<String, dynamic>>> getPendingRequests(String groupId) async {
    final requests = await _repository.fetchPendingRequests(groupId);
    final userIds = requests.map((r) => r['user_id'] as String).toList();
    final profiles = await _repository.getProfiles(userIds);
    final profileMap = {for (var p in profiles) p['id']: p};

    final enriched = requests.map((req) {
      req['profiles'] = profileMap[req['user_id']];
      return req;
    }).toList();
    return enriched;
  }

  Future<void> handleJoinRequest(String requestId, bool approve) async {
    await _repository.handleJoinRequest(requestId: requestId, approve: approve);
  }

  Future<void> leaveTeam(String groupId, String userId) async {
    await _repository.leaveTeam(groupId: groupId, userId: userId);
  }

  Future<void> disbandTeam(String groupId, String ownerId) async {
    await _repository.disbandTeam(groupId: groupId, ownerId: ownerId);
  }

  Future<void> transferOwnershipAndLeave({
    required String groupId,
    required String currentOwnerId,
    required String newOwnerId,
  }) async {
    await _repository.transferOwnershipAndLeave(
      groupId: groupId,
      currentOwnerId: currentOwnerId,
      newOwnerId: newOwnerId,
    );
  }

  Future<void> removeMember({
    required String groupId,
    required String userId,
  }) async {
    await _repository.removeTeamMember(groupId: groupId, userId: userId);
  }

  Future<TripPlan?> getTripPlanForGroup(String groupId) async {
    return await _tripPlanDataSource.getPlanForGroup(groupId);
  }
}