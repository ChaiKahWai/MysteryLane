// lib/presentation/screens/group/team_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../application/services/group_service.dart';
import '../../../data/models/travel_group_model.dart';

class TeamDetailScreen extends StatefulWidget {
  final String groupId;
  const TeamDetailScreen({super.key, required this.groupId});

  @override
  State<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends State<TeamDetailScreen> {
  final GroupService _service = GroupService();
  bool _loading = true;
  TravelGroup? _team;
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  String? _myRole;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final data = await _service.getTeamDetails(widget.groupId);
      final user = Supabase.instance.client.auth.currentUser;

      if (data['team'] != null) {
        setState(() {
          _team = data['team'] as TravelGroup;
          final rawMembers = data['members'] as List<dynamic>? ?? [];
          _members = rawMembers
              .map((m) => Map<String, dynamic>.from(m as Map<dynamic, dynamic>))
              .toList();
        });
        print('✅ Team loaded: ${_team?.teamName}, members: ${_members.length}');
      }

      // Determine my role
      if (user != null) {
        Map<String, dynamic>? myMember;
        for (var m in _members) {
          if (m['user_id'] == user.id) {
            myMember = m;
            break;
          }
        }
        _myRole = myMember?['member_role']?.toString();
        print('👤 My role: $_myRole');
      }

      // If owner, load pending requests
      if (_myRole == 'OWNER') {
        final requests = await _service.getPendingRequests(widget.groupId);
        print('📨 Pending requests count: ${requests.length}');
        setState(() {
          _pendingRequests = requests
              .map((r) => Map<String, dynamic>.from(r as Map<dynamic, dynamic>))
              .toList();
        });
      }
    } catch (e) {
      print('❌ Error loading team: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading team: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  void _copyInviteCode() {
    if (_team?.invitationCode != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invitation code: ${_team!.invitationCode} (copied)')),
      );
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_team?.teamName ?? 'Team Detail'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          if (_myRole == 'OWNER')
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                // TODO: Edit team screen
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Team info card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _team?.teamName ?? '',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text('Type: ${_team?.teamType ?? 'N/A'}'),
                    Text('Members: ${_members.length}'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Invite Code: ${_team?.invitationCode ?? 'N/A'}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy),
                          onPressed: _copyInviteCode,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Members list
            const Text(
              'Members',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ..._members.map((member) {
              final profile = member['profiles'] as Map<dynamic, dynamic>?;
              final fullName = profile?['full_name']?.toString() ?? 'Unknown';
              final initial = fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
              final role = member['member_role']?.toString() ?? 'MEMBER';
              return ListTile(
                leading: CircleAvatar(
                  child: Text(initial),
                ),
                title: Text(fullName),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: role == 'OWNER' ? Colors.amber[100] : Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    role,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: role == 'OWNER' ? Colors.brown[700] : Colors.grey[700],
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            }).toList(),

            // Pending requests (only for owner)
            if (_pendingRequests.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Pending Join Requests',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ..._pendingRequests.map((req) {
                final profile = req['profiles'] as Map<dynamic, dynamic>?;
                final requesterName = profile?['full_name']?.toString() ?? 'Unknown User';
                final requestedAt = req['requested_at'] != null
                    ? DateTime.parse(req['requested_at']).toLocal()
                    : null;
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(requesterName.isNotEmpty ? requesterName[0].toUpperCase() : '?'),
                  ),
                  title: Text(requesterName),
                  subtitle: requestedAt != null
                      ? Text('Requested ${_formatTimeAgo(requestedAt)}')
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: () async {
                          await _service.handleJoinRequest(req['request_id'], true);
                          _loadData();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () async {
                          await _service.handleJoinRequest(req['request_id'], false);
                          _loadData();
                        },
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],

            const SizedBox(height: 16),

            // Leave Team button
            ElevatedButton(
              onPressed: () async {
                final user = Supabase.instance.client.auth.currentUser;
                if (user == null) return;
                try {
                  await _service.leaveTeam(widget.groupId, user.id);
                  if (mounted) Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error leaving: $e')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text('Leave Team'),
            ),
          ],
        ),
      ),
    );
  }
}