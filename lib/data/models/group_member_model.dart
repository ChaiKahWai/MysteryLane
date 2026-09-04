// lib/data/models/group_member_model.dart

class GroupMember {
  final String groupMemberId;
  final String groupId;
  final String userId;
  final String? memberRole;      // 'owner', 'admin', 'member'
  final String? membershipStatus; // 'active', 'pending', 'inactive'
  final DateTime? joinedAt;

  GroupMember({
    required this.groupMemberId,
    required this.groupId,
    required this.userId,
    this.memberRole,
    this.membershipStatus,
    this.joinedAt,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      groupMemberId: json['group_member_id'] ?? '',
      groupId: json['group_id'] ?? '',
      userId: json['user_id'] ?? '',
      memberRole: json['member_role'],
      membershipStatus: json['membership_status'],
      joinedAt: json['joined_at'] != null ? DateTime.parse(json['joined_at']) : null,
    );
  }
}