class ChatMessage {
  final String messageId;
  final String groupId;
  final String userId;
  final String message;
  final DateTime sentAt;

  ChatMessage({
    required this.messageId,
    required this.groupId,
    required this.userId,
    required this.message,
    required this.sentAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      messageId: json['message_id'],
      groupId: json['group_id'],
      userId: json['user_id'],
      message: json['message'],
      sentAt: DateTime.parse(json['sent_at']),
    );
  }
}