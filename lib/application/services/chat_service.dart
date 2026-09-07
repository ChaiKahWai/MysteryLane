import '../../data/repositories/chat_repository.dart';
import '../../data/models/chat_message_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  Future<Map<String, dynamic>?> getLastMessageForTeam(String groupId) async {
    return await _repository.getLastMessageForTeam(groupId);
  }

  Future<Map<String, dynamic>> getChatListData(
      String userId,
      List<String> groupIds,
      ) async {
    if (groupIds.isEmpty) return {'lastMessages': {}, 'unreadStatus': {}};

    // 1. Fetch last message per group (using raw query or multiple queries)
    //    We'll use a simple approach: fetch all messages for these groups,
    //    then group by group_id and pick the latest.
    final allMessages = await Supabase.instance.client
        .from('team_chat_messages')
        .select('''
        group_id,
        message_id,
        message,
        sent_at,
        user_id,
        profiles!inner(full_name)
      ''')
        .filter('group_id', 'in', groupIds)
        .order('sent_at', ascending: false);

    // Build a map of groupId -> latest message (first occurrence after ordering)
    final Map<String, Map<String, dynamic>> lastMessages = {};
    for (var msg in allMessages) {
      final gid = msg['group_id'] as String;
      if (!lastMessages.containsKey(gid)) {
        final profile = msg['profiles'] as Map<String, dynamic>?;
        lastMessages[gid] = {
          'message_id': msg['message_id'],
          'message': msg['message'],
          'sent_at': msg['sent_at'],
          'full_name': profile?['full_name'] ?? 'Unknown',
          'user_id': msg['user_id'],
        };
      }
    }

    // 2. Fetch last_read_at for this user in each group
    final memberships = await Supabase.instance.client
        .from('travel_group_members')
        .select('group_id, last_read_at')
        .eq('user_id', userId)
        .filter('group_id', 'in', groupIds);

    final lastReadMap = {
      for (var row in memberships)
        row['group_id'] as String: row['last_read_at'] as String?
    };

    // 3. Compute unread status: true if last message sent_at > last_read_at
    final Map<String, bool> unreadStatus = {};
    for (var gid in groupIds) {
      final last = lastMessages[gid];
      if (last == null) {
        unreadStatus[gid] = false;
        continue;
      }
      final sentAt = DateTime.parse(last['sent_at'] as String);
      final lastRead = lastReadMap[gid] != null
          ? DateTime.parse(lastReadMap[gid]!)
          : null;
      unreadStatus[gid] = lastRead == null || sentAt.isAfter(lastRead);
    }

    return {
      'lastMessages': lastMessages,
      'unreadStatus': unreadStatus,
    };
  }
}