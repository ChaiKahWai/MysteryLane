import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../application/services/group_service.dart';
import '../../../application/services/chat_service.dart';
import 'team_chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final GroupService _groupService = GroupService();
  final ChatService _chatService = ChatService();
  List<Map<String, dynamic>> _myTeams = [];
  Map<String, dynamic> _lastMessages = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      final teams = await _groupService.getUserTeams(user.id);
      setState(() {
        _myTeams = teams;
      });
      for (var team in teams) {
        final groupId = team['group_id'];
        final last = await _chatService.getLastMessageForTeam(groupId);
        if (last != null) {
          _lastMessages[groupId] = last;
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading chats: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  String _formatTime(String iso) {
    final dt = DateTime.parse(iso);
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dt.day}/${dt.month}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _myTeams.isEmpty
          ? const Center(child: Text('You are not in any team yet'))
          : ListView.builder(
        itemCount: _myTeams.length,
        itemBuilder: (ctx, index) {
          final team = _myTeams[index];
          final groupData = team['travel_groups'];
          final groupId = groupData['group_id'];
          final lastMsg = _lastMessages[groupId];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: ListTile(
              leading: CircleAvatar(
                child: Text(groupData['team_name'][0]),
              ),
              title: Text(groupData['team_name']),
              subtitle: lastMsg != null
                  ? Text(
                '${lastMsg['full_name']}: ${lastMsg['message']}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
                  : const Text('No messages yet'),
              trailing: lastMsg != null
                  ? Text(
                _formatTime(lastMsg['sent_at']),
                style: const TextStyle(fontSize: 12),
              )
                  : null,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TeamChatScreen(groupId: groupId),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}