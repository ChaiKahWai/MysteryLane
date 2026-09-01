// lib/application/services/group_service.dart

import 'dart:math';
import '../../data/repositories/group_repository.dart';
import '../../data/models/travel_group_model.dart';

class GroupService {
  final GroupRepository _repository = GroupRepository();

  // Generate a random 6-character invitation code
  String generateInvitationCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(6, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
  }

  // Create a new team (including adding owner as member)
  Future<TravelGroup> createTeam({
    required String ownerId,
    required String teamName,
    required String teamType,
    String? preferredLanguage,
    int? maxCapacity,
  }) async {
    // Generate a unique invitation code
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
      teamType: teamType, // must be 'PUBLIC' or 'PRIVATE'
      preferredLanguage: preferredLanguage,
      maxCapacity: maxCapacity,
      invitationCode: code,
    );

    // Add the owner as a member with role 'OWNER'
    await _repository.addTeamMember(
      groupId: newGroup.groupId,
      userId: ownerId,
      role: 'OWNER',  // ✅ uppercase
    );

    return newGroup;
  }

  // Request to join a team by invitation code
  Future<void> requestToJoinByCode({
    required String code,
    required String userId,
  }) async {
    final group = await _repository.findGroupByInvitationCode(code);
    if (group == null) {
      throw Exception('Invalid or inactive invitation code');
    }

    await _repository.insertJoinRequest(
      groupId: group.groupId,
      userId: userId,
    );
  }

  // Get user's teams (with role info)
  Future<List<Map<String, dynamic>>> getUserTeams(String userId) async {
    return await _repository.fetchUserTeams(userId);
  }

  // Get public teams
  Future<List<TravelGroup>> getPublicTeams() async {
    return await _repository.fetchPublicTeams();
  }

  // Get team details (including members)
  Future<Map<String, dynamic>> getTeamDetails(String groupId) async {
    return await _repository.fetchTeamDetails(groupId);
  }

  // Get pending join requests for a team
  Future<List<dynamic>> getPendingRequests(String groupId) async {
    return await _repository.fetchPendingRequests(groupId);
  }

  // Handle join request (approve/reject)
  Future<void> handleJoinRequest(String requestId, bool approve) async {
    await _repository.handleJoinRequest(requestId: requestId, approve: approve);
  }

  // Leave team
  Future<void> leaveTeam(String groupId, String userId) async {
    await _repository.leaveTeam(groupId: groupId, userId: userId);
  }
}