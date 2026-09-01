// lib/data/models/travel_group_model.dart

class TravelGroup {
  final String groupId;
  final String ownerId;
  final String teamName;
  final String teamType;        // 'public' or 'private'
  final String? preferredLanguage;
  final String? invitationCode;
  final int? maxCapacity;
  final String? groupStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // For nested members or requests, you can add them as lists.
  // For now we keep it simple.

  TravelGroup({
    required this.groupId,
    required this.ownerId,
    required this.teamName,
    required this.teamType,
    this.preferredLanguage,
    this.invitationCode,
    this.maxCapacity,
    this.groupStatus,
    this.createdAt,
    this.updatedAt,
  });

  factory TravelGroup.fromJson(Map<String, dynamic> json) {
    return TravelGroup(
      groupId: json['group_id'] ?? '',
      ownerId: json['owner_id'] ?? '',
      teamName: json['team_name'] ?? '',
      teamType: json['team_type'] ?? 'public',
      preferredLanguage: json['preferred_language'],
      invitationCode: json['invitation_code'],
      maxCapacity: json['max_capacity'],
      groupStatus: json['group_status'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'group_id': groupId,
    'owner_id': ownerId,
    'team_name': teamName,
    'team_type': teamType,
    'preferred_language': preferredLanguage,
    'invitation_code': invitationCode,
    'max_capacity': maxCapacity,
    'group_status': groupStatus,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };
}