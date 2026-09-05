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
      }

      // If owner, load pending requests
      if (_myRole == 'OWNER') {
        final requests = await _service.getPendingRequests(widget.groupId);
        setState(() {
          _pendingRequests = requests
              .map((r) => Map<String, dynamic>.from(r as Map<dynamic, dynamic>))
              .toList();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading team: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  // -------------------------------------------------------------------------
  // NEW: Remove a member (only for owner)
  // -------------------------------------------------------------------------
  Future<void> _removeMember(String userId, String userName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Member?'),
        content: Text(
          'Are you sure you want to remove "$userName" from the team? They will lose access to all team content.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _loading = true);
      try {
        await _service.removeMember(
          groupId: widget.groupId,
          userId: userId,
        );
        // Remove the member from the local list
        setState(() {
          _members.removeWhere((m) => m['user_id'] == userId);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$userName has been removed.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error removing member: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  void _copyInviteCode() {
    if (_team?.invitationCode != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invitation code: ${_team!.invitationCode} (copied)'),
        ),
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
    final user = Supabase.instance.client.auth.currentUser;
    final isOwner = _myRole == 'OWNER';

    return Scaffold(
      appBar: AppBar(
        title: Text(_team?.teamName ?? 'Team Detail'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          if (isOwner)
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
              final userId = member['user_id'] as String;
              final isCurrentUser = user?.id == userId;
              final isMemberOwner = role == 'OWNER';

              return ListTile(
                leading: CircleAvatar(
                  child: Text(initial),
                ),
                title: Text(fullName),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isMemberOwner ? Colors.amber[100] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isMemberOwner ? 'OWNER' : 'MEMBER',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isMemberOwner ? Colors.brown[700] : Colors.grey[700],
                          fontSize: 12,
                        ),
                      ),
                    ),
                    // Remove button: owner can remove any non-owner member
                    if (isOwner && !isMemberOwner && !isCurrentUser) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                        tooltip: 'Remove member',
                        onPressed: () => _removeMember(userId, fullName),
                      ),
                    ],
                  ],
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
              onPressed: _loading ? null : _handleLeaveTeam,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Leave Team', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // LEAVE TEAM FLOWS (unchanged)
  // =========================================================================
  Future<void> _handleLeaveTeam() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final isOwner = _myRole == 'OWNER';

    if (isOwner) {
      if (_members.length <= 1) {
        await _confirmAutoDisbandAndLeave(user.id);
      } else {
        await _showOwnerLeaveChoiceDialog(user.id);
      }
    } else {
      await _confirmRegularMemberLeave(user.id);
    }
  }

  Future<void> _confirmRegularMemberLeave(String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Leave Team?'),
        content: Text(
          'Are you sure you want to leave "${_team?.teamName ?? 'this team'}"? You will no longer be part of this squad expedition.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Leave Team'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _loading = true);
      try {
        await _service.leaveTeam(widget.groupId, userId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You have left the team.')),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error leaving team: $e')),
          );
        }
      }
    }
  }

  Future<void> _confirmAutoDisbandAndLeave(String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Leave & Disband Squad?'),
        content: Text(
          'You are the only member in "${_team?.teamName ?? 'this team'}". Leaving will automatically disband and close this squad expedition.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Disband & Leave'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _loading = true);
      try {
        await _service.disbandTeam(widget.groupId, userId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Squad disbanded and you have left.')),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error disbanding team: $e')),
          );
        }
      }
    }
  }

  Future<void> _showOwnerLeaveChoiceDialog(String userId) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: Colors.amber),
            SizedBox(width: 8),
            Expanded(child: Text('Leave Squad as Host', style: TextStyle(fontSize: 18))),
          ],
        ),
        content: Text(
          'You are the host of "${_team?.teamName ?? 'this team'}". Before leaving, you must either transfer squad leadership to another member or disband the squad for everyone.',
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Cancel'),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx, 'disband'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
                child: const Text('Disband Squad'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, 'transfer'),
                child: const Text('Select New Host'),
              ),
            ],
          ),
        ],
      ),
    );

    if (choice == 'transfer') {
      await _showTransferHostDialog(userId);
    } else if (choice == 'disband') {
      await _confirmDisbandSquad(userId);
    }
  }

  Future<void> _showTransferHostDialog(String currentOwnerId) async {
    final otherMembers = _members.where((m) => m['user_id'] != currentOwnerId).toList();
    if (otherMembers.isEmpty) return;

    String selectedHostId = otherMembers.first['user_id'].toString();
    String selectedHostName = (otherMembers.first['profiles'] as Map<dynamic, dynamic>?)?['full_name']?.toString() ?? 'Member';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Select a New Host'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose which squad member will become the new Host before you leave:',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                ...otherMembers.map((m) {
                  final uid = m['user_id'].toString();
                  final profile = m['profiles'] as Map<dynamic, dynamic>?;
                  final name = profile?['full_name']?.toString() ?? 'Traveler';
                  final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

                  return RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    value: uid,
                    groupValue: selectedHostId,
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedHostId = val;
                          selectedHostName = name;
                        });
                      }
                    },
                    secondary: CircleAvatar(
                      radius: 16,
                      child: Text(initial, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  );
                }).toList(),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Transfer Host & Leave'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      setState(() => _loading = true);
      try {
        await _service.transferOwnershipAndLeave(
          groupId: widget.groupId,
          currentOwnerId: currentOwnerId,
          newOwnerId: selectedHostId,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Transferred host to $selectedHostName. You have left the squad.')),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error transferring ownership: $e')),
          );
        }
      }
    }
  }

  Future<void> _confirmDisbandSquad(String currentOwnerId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Disband Squad?'),
          ],
        ),
        content: Text(
          'Are you sure you want to disband "${_team?.teamName ?? 'this team'}"? This will remove all ${_members.length} members and permanently close the team for everyone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Disband Squad'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _loading = true);
      try {
        await _service.disbandTeam(widget.groupId, currentOwnerId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Squad has been disbanded.')),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error disbanding team: $e')),
          );
        }
      }
    }
  }
}