import 'dart:math';
import '../../data/repositories/group_repository.dart';
import '../../data/models/travel_group_model.dart';

class GroupService {
  final GroupRepository _repository = GroupRepository();

  String generateInvitationCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(6, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
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

  Future<List<Map<String, dynamic>>> getUserTeams(String userId) async {
    return await _repository.fetchUserTeams(userId);
  }

  Future<List<TravelGroup>> getPublicTeams() async {
    return await _repository.fetchPublicTeams();
  }

  // Get team details with members enriched with profiles
  Future<Map<String, dynamic>> getTeamDetails(String groupId) async {
    // Fetch team info
    final team = await _repository.fetchTeamInfo(groupId);

    // Fetch members (raw)
    final members = await _repository.fetchTeamMembers(groupId);

    // Collect all user IDs from members
    final userIds = members.map((m) => m['user_id'] as String).toList();
    // Fetch profiles for these users
    final profiles = await _repository.getProfiles(userIds);
    // Build a map for quick lookup
    final profileMap = {for (var p in profiles) p['id']: p};

    // Attach profile to each member
    final enrichedMembers = members.map((m) {
      final profile = profileMap[m['user_id']];
      m['profiles'] = profile; // may be null
      return m;
    }).toList();

    return {
      'team': team,
      'members': enrichedMembers,
    };
  }

  // Get pending join requests with profile data
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

  // -------------------------------------------------------------------------
  // NEW: Remove a member (for owner)
  // -------------------------------------------------------------------------
  Future<void> removeMember({
    required String groupId,
    required String userId,
  }) async {
    await _repository.removeTeamMember(groupId: groupId, userId: userId);
  }
}