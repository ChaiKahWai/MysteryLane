// lib/data/models/join_request_model.dart

class JoinRequest {
  final String requestId;
  final String groupId;
  final String userId;
  final String? requestStatus;  // 'pending', 'approved', 'rejected'
  final DateTime? requestedAt;
  final DateTime? respondedAt;

  JoinRequest({
    required this.requestId,
    required this.groupId,
    required this.userId,
    this.requestStatus,
    this.requestedAt,
    this.respondedAt,
  });

  factory JoinRequest.fromJson(Map<String, dynamic> json) {
    return JoinRequest(
      requestId: json['request_id'] ?? '',
      groupId: json['group_id'] ?? '',
      userId: json['user_id'] ?? '',
      requestStatus: json['request_status'],
      requestedAt: json['requested_at'] != null ? DateTime.parse(json['requested_at']) : null,
      respondedAt: json['responded_at'] != null ? DateTime.parse(json['responded_at']) : null,
    );
  }
}