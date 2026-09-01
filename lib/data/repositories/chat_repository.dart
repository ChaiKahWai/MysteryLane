import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_message_model.dart';
import '../../core/config/supabase_config.dart';

class ChatRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  // Stream for real-time messages of a specific team
  Stream<List<ChatMessage>> getMessagesStream(String groupId) {
    return _client
        .from('team_chat_messages')
        .stream(primaryKey: ['message_id'])
        .eq('group_id', groupId)
        .order('sent_at', ascending: true)
        .map((data) => (data as List)
        .map((json) => ChatMessage.fromJson(json))
        .toList());
  }

  // Send a message
  Future<void> sendMessage({
    required String groupId,
    required String userId,
    required String message,
  }) async {
    await _client.from('team_chat_messages').insert({
      'group_id': groupId,
      'user_id': userId,
      'message': message,
    });
  }

  // Get last message for a team (for chat list preview)
  Future<Map<String, dynamic>?> getLastMessageForTeam(String groupId) async {
    final response = await _client
        .from('team_chat_messages')
        .select('message, sent_at, profiles!inner(full_name)')
        .eq('group_id', groupId)
        .order('sent_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response == null) return null;

    // Safely extract fields
    final fullName = response['profiles']?['full_name'] ?? 'Unknown';
    return {
      'message': response['message'] ?? '',
      'sent_at': response['sent_at'],
      'full_name': fullName,
    };
  }
}