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
  List<dynamic> _members = [];
  List<dynamic> _pendingRequests = [];
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
          _members = data['members'] as List<dynamic>;
        });
      }
      // Determine my role
      if (user != null) {
        final myMember = _members.firstWhere(
              (m) => m['user_id'] == user.id,
          orElse: () => null,
        );
        _myRole = myMember?['member_role']; // e.g. 'OWNER'
      }
      // If owner, load pending requests
      if (_myRole == 'OWNER') {
        final requests = await _service.getPendingRequests(widget.groupId);
        setState(() => _pendingRequests = requests);
      }
    } catch (e) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_team?.teamName ?? 'Team Detail'),
        actions: [
          if (_myRole == 'OWNER')
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                // TODO: Navigate to edit team screen
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
                    Text('Type: ${_team?.teamType}'),
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
            const Text(
              'Members',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ..._members.map((member) {
              return ListTile(
                leading: CircleAvatar(
                  child: Text(
                    member['profiles']?['full_name']?.substring(0, 1) ?? '?',
                  ),
                ),
                title: Text(member['profiles']?['full_name'] ?? 'Unknown'),
                trailing: Text(
                  member['member_role'] ?? 'MEMBER',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: member['member_role'] == 'OWNER'
                        ? Colors.amber[800]
                        : Colors.grey,
                  ),
                ),
              );
            }).toList(),
            if (_pendingRequests.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Pending Join Requests',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ..._pendingRequests.map((req) {
                return ListTile(
                  title: Text('User ID: ${req['user_id']}'),
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
            ElevatedButton(
              onPressed: () async {
                final user = Supabase.instance.client.auth.currentUser;
                if (user == null) return;
                try {
                  await _service.leaveTeam(widget.groupId, user.id);
                  Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error leaving: $e')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Leave Team'),
            ),
          ],
        ),
      ),
    );
  }
}