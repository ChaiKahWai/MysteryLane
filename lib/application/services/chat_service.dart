import '../../data/repositories/chat_repository.dart';
import '../../data/models/chat_message_model.dart';

class ChatService {
  final ChatRepository _repository = ChatRepository();

  Stream<List<ChatMessage>> getMessagesForTeam(String groupId) {
    return _repository.getMessagesStream(groupId);
  }

  Future<void> sendMessage({
    required String groupId,
    required String userId,
    required String message,
  }) async {
    if (message.trim().isEmpty) return;
    await _repository.sendMessage(
      groupId: groupId,
      userId: userId,
      message: message.trim(),
    );
  }

  // Expose the last-message method
  Future<Map<String, dynamic>?> getLastMessageForTeam(String groupId) async {
    return await _repository.getLastMessageForTeam(groupId);
  }
}