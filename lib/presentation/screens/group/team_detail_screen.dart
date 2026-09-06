import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // <- added for clipboard
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../application/services/group_service.dart';
import '../../../data/models/travel_group_model.dart';
import '../../../data/models/trip_plan.dart';
import '../Blindbox/BlindBox_Screen.dart';
import '../checkpoint/checkpoint_screen.dart';
import '../plan/plan_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';
import '../profile/leaderboard_screen.dart';
import 'group_screen.dart';
import 'chat_list_screen.dart';

class TeamDetailScreen extends StatefulWidget {
  final String groupId;
  const TeamDetailScreen({super.key, required this.groupId});

  @override
  State<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends State<TeamDetailScreen> {
  static const Color skyBlue = Color(0xFF0284C7);
  static const Color teal = Color(0xFF0D9488);
  static const Color darkText = Color(0xFF0F172A);
  static const Color greyText = Color(0xFF64748B);
  static const Color pageBackground = Color(0xFFF8FAFC);
  static const Color borderColor = Color(0xFFE2E8F0);

  final GroupService _service = GroupService();
  bool _loading = true;
  TravelGroup? _team;
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  String? _myRole;
  TripPlan? _tripPlan;
  String? _headerProfilePictureUrl;

  @override
  void initState() {
    super.initState();
    _loadHeaderProfile();
    _loadData();
  }

  Future<void> _loadHeaderProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('profile_picture_url')
          .eq('id', user.id)
          .maybeSingle();
      if (mounted) {
        final picture = profile?['profile_picture_url']?.toString().trim();
        setState(() {
          _headerProfilePictureUrl =
          (picture != null && picture.isNotEmpty) ? picture : null;
        });
      }
    } catch (e) {
      debugPrint('Header profile error: $e');
    }
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

      final plan = await _service.getTripPlanForGroup(widget.groupId);
      setState(() {
        _tripPlan = plan;
      });

      _myRole = null;
      if (user != null) {
        for (var m in _members) {
          if (m['user_id'] == user.id) {
            _myRole = m['member_role']?.toString();
            break;
          }
        }
      }

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

  // ---- Navigation helpers ----
  void _openBlindBox() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const BlindBoxPage()),
    );
  }

  void _openMissions() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const CheckpointScreen()),
    );
  }

  void _openPlan() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PlanScreen(
          groupId: widget.groupId,
        ),
      ),
    );
  }

  void _openHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
    );
  }

  void _openProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
    _loadHeaderProfile();
  }

  void _openLeaderboard() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
    );
  }

  // ---- Team actions ----
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

  // ---- FIXED: copy code now actually copies to clipboard ----
  void _copyInviteCode() {
    final code = _team?.invitationCode;
    if (code != null && code.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: code));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invitation code "$code" copied to clipboard!'),
          duration: const Duration(seconds: 2),
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

  Future<void> _joinPublicTeam() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to join.')),
      );
      return;
    }

    if (_team?.invitationCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This team does not have an invitation code.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await _service.requestToJoinByCode(
        code: _team!.invitationCode!,
        userId: user.id,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Join request sent!')),
      );
      await _loadData();
    } catch (e) {
      String message = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---- Leave/Disband logic with redirection ----
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
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const GroupScreen()),
                (route) => false,
          );
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
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const GroupScreen()),
                (route) => false,
          );
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

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final isOwner = _myRole == 'OWNER';
    final isMember = _myRole != null;

    String hostName = 'Host';
    if (_members.isNotEmpty) {
      final ownerMember = _members.firstWhere(
            (m) => m['member_role'] == 'OWNER',
        orElse: () => _members.first,
      );
      final ownerProfile = ownerMember['profiles'] as Map<dynamic, dynamic>?;
      hostName = ownerProfile?['full_name']?.toString() ?? 'Host';
    }

    return Scaffold(
      backgroundColor: pageBackground,
      extendBody: true,
      appBar: _buildTopAppBar(),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- PUBLIC TEAM PLAN DETAILS TITLE ----
            if (_team?.teamType == 'PUBLIC')
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  'PUBLIC TEAM PLAN DETAILS',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: skyBlue,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

            // ---- TEAM INFO CARD ----
            Card(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.blue.shade100, width: 1.5),
              ),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _team?.teamName ?? '',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _team?.teamType == 'PUBLIC'
                                ? Colors.green[100]
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _team?.teamType ?? 'PRIVATE',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _team?.teamType == 'PUBLIC'
                                  ? Colors.green[800]
                                  : Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_tripPlan != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${_tripPlan!.startDate.day}/${_tripPlan!.startDate.month}/${_tripPlan!.startDate.year} → ${_tripPlan!.endDate.day}/${_tripPlan!.endDate.month}/${_tripPlan!.endDate.year} (${_tripPlan!.totalDays} Days)',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: darkText,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
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
                          tooltip: 'Copy invite code',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ---- ITINERARY CARD ----
            if (_tripPlan != null && _tripPlan!.stops.isNotEmpty) ...[
              Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.blue.shade100, width: 1.5),
                ),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ITINERARY HIGHLIGHTS:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: darkText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._tripPlan!.stops.map((stop) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: skyBlue.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${stop.dayNumber}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: skyBlue,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  stop.name,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 16,
                            color: greyText,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Squad: ${_members.length} Member${_members.length > 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 14,
                              color: greyText,
                            ),
                          ),
                          const Spacer(),
                          if (_members.isNotEmpty)
                            Text(
                              'Host: $hostName',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: darkText,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ---- MEMBERS LIST ----
            const Text(
              'Members',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ..._members.map((member) {
              final profile = member['profiles'] as Map<dynamic, dynamic>?;
              final fullName = profile?['full_name']?.toString() ?? 'Member';
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

            // ---- PENDING REQUESTS ----
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

            // ---- ACTION BUTTON ----
            if (isMember) ...[
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
            ] else if (_team?.teamType == 'PUBLIC') ...[
              ElevatedButton(
                onPressed: _loading ? null : _joinPublicTeam,
                style: ElevatedButton.styleFrom(
                  backgroundColor: skyBlue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Join Public Squad', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ] else ...[
              ElevatedButton(
                onPressed: null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[300],
                  foregroundColor: Colors.grey[600],
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Private Team – Not Joinable', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _buildHomeButton(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ---- TOP APP BAR ----
  PreferredSizeWidget _buildTopAppBar() {
    return AppBar(
      toolbarHeight: 68,
      elevation: 0,
      scrolledUnderElevation: 2,
      backgroundColor: Colors.white.withValues(alpha: 0.97),
      surfaceTintColor: Colors.white,
      titleSpacing: 16,
      title: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _openHome,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MysteryLaneLogo(),
              SizedBox(width: 10),
              Text(
                'MYSTERYLANE',
                style: TextStyle(
                  color: darkText,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        _TopActionButton(
          tooltip: 'Leaderboard',
          icon: Icons.emoji_events_rounded,
          background: const Color(0xFFFFFBEB),
          foreground: const Color(0xFFD97706),
          onTap: _openLeaderboard,
        ),
        const SizedBox(width: 6),
        _TopActionButton(
          tooltip: 'Chat',
          icon: Icons.chat_bubble_outline_rounded,
          background: const Color(0xFFF0F9FF),
          foreground: skyBlue,
          onTap: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const ChatListScreen()),
            );
          },
        ),
        const SizedBox(width: 6),
        _ProfileButton(
          onTap: _openProfile,
          imageUrl: _headerProfilePictureUrl,
        ),
        const SizedBox(width: 12),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(
          height: 1,
          thickness: 1,
          color: borderColor,
        ),
      ),
    );
  }

  // ---- BOTTOM BAR ----
  Widget _buildBottomBar() {
    return BottomAppBar(
      height: 78,
      padding: EdgeInsets.zero,
      color: Colors.white.withValues(alpha: 0.98),
      elevation: 18,
      shadowColor: const Color(0x330284C7),
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: _BottomItem(
                icon: Icons.inventory_2_outlined,
                label: 'BLIND BOX',
                active: false,
                onTap: _openBlindBox,
              ),
            ),
            Expanded(
              child: _BottomItem(
                icon: Icons.assignment_outlined,
                label: 'MISSIONS',
                active: false,
                onTap: _openMissions,
              ),
            ),
            const SizedBox(width: 74),
            Expanded(
              child: _BottomItem(
                icon: Icons.map_outlined,
                label: 'PLAN',
                active: false,
                onTap: _openPlan,
              ),
            ),
            Expanded(
              child: _BottomItem(
                icon: Icons.groups_2_outlined,
                label: 'TEAMS',
                active: true,
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const GroupScreen()),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- HOME FLOATING BUTTON ----
  Widget _buildHomeButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _openHome,
        child: Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [skyBlue, teal],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: const [
              BoxShadow(
                color: Color(0x3D0284C7),
                blurRadius: 16,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.home_rounded,
                color: Color(0xFFFDE68A),
                size: 27,
              ),
              Text(
                'HOME',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---- Helper widgets ----
class _MysteryLaneLogo extends StatelessWidget {
  const _MysteryLaneLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [_TeamDetailScreenState.skyBlue, _TeamDetailScreenState.teal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x300284C7),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(
        Icons.explore_rounded,
        color: Colors.white,
        size: 23,
      ),
    );
  }
}

class _TopActionButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  const _TopActionButton({
    required this.tooltip,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: background,
            shape: BoxShape.circle,
            border: Border.all(
              color: foreground.withValues(alpha: 0.20),
            ),
          ),
          child: Icon(
            icon,
            color: foreground,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _ProfileButton extends StatelessWidget {
  final VoidCallback onTap;
  final String? imageUrl;

  const _ProfileButton({
    required this.onTap,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final cleanUrl = imageUrl?.trim();
    final provider = (cleanUrl != null && cleanUrl.isNotEmpty)
        ? NetworkImage(cleanUrl) as ImageProvider
        : null;

    return Tooltip(
      message: 'Profile',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFBAE6FD),
              width: 1.4,
            ),
          ),
          child: CircleAvatar(
            backgroundColor: const Color(0xFFE0F2FE),
            backgroundImage: provider,
            child: provider == null
                ? const Icon(
              Icons.person_rounded,
              size: 20,
              color: _TeamDetailScreenState.skyBlue,
            )
                : null,
          ),
        ),
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _BottomItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 42,
              height: 29,
              decoration: BoxDecoration(
                color: active ? _TeamDetailScreenState.skyBlue : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 21,
                color: active ? Colors.white : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: TextStyle(
                color: active ? _TeamDetailScreenState.skyBlue : const Color(0xFF64748B),
                fontSize: 8,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}