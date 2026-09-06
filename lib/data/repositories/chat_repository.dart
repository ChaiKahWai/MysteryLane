import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_message_model.dart';
import '../../core/config/supabase_config.dart';

class ChatRepository {
  final SupabaseClient _client = SupabaseConfig.client;
  final Map<String, String?> _profileCache = {}; // cache for user names

  // Stream for real-time messages of a specific team
  Stream<List<ChatMessage>> getMessagesStream(String groupId) {
    return _client
        .from('team_chat_messages')
        .stream(primaryKey: ['message_id'])
        .eq('group_id', groupId)
        .order('sent_at', ascending: true)
        .asyncMap((data) async {
      final list = data as List;
      final messages = list.map((json) => ChatMessage.fromJson(json)).toList();

      // Collect all user IDs from messages
      final userIds = messages.map((m) => m.userId).toSet().toList();
      if (userIds.isNotEmpty) {
        // Fetch profiles for these users (batch)
        final profiles = await _fetchProfiles(userIds);
        // Update cache with fetched data
        for (var p in profiles) {
          _profileCache[p['id']] = p['full_name'] as String?;
        }
      }

      // Map to final messages with fullName
      return messages.map((msg) {
        final name = _profileCache[msg.userId];
        return ChatMessage(
          messageId: msg.messageId,
          groupId: msg.groupId,
          userId: msg.userId,
          message: msg.message,
          sentAt: msg.sentAt,
          fullName: name ?? 'Unknown',
        );
      }).toList();
    });
  }

  // Helper to fetch profiles by IDs
  Future<List<Map<String, dynamic>>> _fetchProfiles(List<String> userIds) async {
    if (userIds.isEmpty) return [];
    final response = await _client
        .from('profiles')
        .select('id, full_name')
        .inFilter('id', userIds);
    return response as List<Map<String, dynamic>>;
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

  // Get last message for a team (chat list preview) – still uses join, works fine
  Future<Map<String, dynamic>?> getLastMessageForTeam(String groupId) async {
    final response = await _client
        .from('team_chat_messages')
        .select('message, sent_at, profiles!inner(full_name)')
        .eq('group_id', groupId)
        .order('sent_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response == null) return null;

    final fullName = response['profiles']?['full_name'] ?? 'Unknown';
    return {
      'message': response['message'] ?? '',
      'sent_at': response['sent_at'],
      'full_name': fullName,
    };
  }
}