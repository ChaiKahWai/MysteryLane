// lib/presentation/screens/group/group_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../application/services/group_service.dart';
import '../../../data/models/travel_group_model.dart';
import 'team_detail_screen.dart';
import 'join_team_screen.dart';
import '../profile/profile_screen.dart';
import '../profile/leaderboard_screen.dart';

class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key});

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> with SingleTickerProviderStateMixin {
  final GroupService _groupService = GroupService();
  late TabController _tabController;

  List<Map<String, dynamic>> _myTeams = [];
  List<TravelGroup> _publicTeams = [];
  bool _isLoading = false;
  String _searchQuery = '';

  // Header state
  String? _headerProfilePictureUrl;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadHeaderProfile();
    _loadData();
  }

  // ---------- Header helpers ----------
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

  Future<void> _openProfile() async {
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

  void _showPressedMessage(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 92),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Text('$feature pressed - UI only for now.'),
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }

  // ---------- Data loading ----------
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final myTeams = await _groupService.getUserTeams(user.id);
        final publicTeams = await _groupService.getPublicTeams();
        setState(() {
          _myTeams = myTeams;
          _publicTeams = publicTeams;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading teams: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _navigateToDetail(Map<String, dynamic> teamData) {
    final groupId = teamData['group_id'] ?? teamData['travel_groups']['group_id'];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeamDetailScreen(groupId: groupId),
      ),
    ).then((_) => _loadData());
  }

  List<Map<String, dynamic>> _filterMyTeams() {
    if (_searchQuery.isEmpty) return _myTeams;
    return _myTeams.where((team) {
      final name = team['travel_groups']['team_name']?.toLowerCase() ?? '';
      return name.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  List<TravelGroup> _filterPublicTeams() {
    if (_searchQuery.isEmpty) return _publicTeams;
    return _publicTeams.where((team) {
      return team.teamName.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  // ---------- Build ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildCustomAppBar(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search teams...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildMyTeamsList(),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildPublicTeamsList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Custom App Bar (with TabBar) ----------
  PreferredSizeWidget _buildCustomAppBar() {
    const Color skyBlue = Color(0xFF0284C7);
    const Color darkText = Color(0xFF0F172A);

    return AppBar(
      toolbarHeight: 68,
      elevation: 0,
      scrolledUnderElevation: 2,
      backgroundColor: Colors.white.withValues(alpha: 0.97),
      surfaceTintColor: Colors.white,
      titleSpacing: 16,
      title: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showPressedMessage('Teams'),
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
        // Leaderboard
        _TopActionButton(
          tooltip: 'Leaderboard',
          icon: Icons.emoji_events_rounded,
          background: const Color(0xFFFFFBEB),
          foreground: const Color(0xFFD97706),
          onTap: _openLeaderboard,
        ),
        const SizedBox(width: 6),
        // Chat (placeholder)
        _TopActionButton(
          tooltip: 'Chat',
          icon: Icons.chat_bubble_outline_rounded,
          background: const Color(0xFFF0F9FF),
          foreground: skyBlue,
          onTap: () => _showPressedMessage('Chat'),
        ),
        const SizedBox(width: 6),
        // Join with code (custom action for this screen)
        _TopActionButton(
          tooltip: 'Join with code',
          icon: Icons.person_add_alt_1,
          background: const Color(0xFFE0F2FE),
          foreground: skyBlue,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const JoinTeamScreen()),
            ).then((_) => _loadData());
          },
        ),
        const SizedBox(width: 6),
        // Profile picture
        _ProfileButton(
          onTap: _openProfile,
          imageUrl: _headerProfilePictureUrl,
        ),
        const SizedBox(width: 12),
      ],
      // 👇 The TabBar is placed here, below the header
      bottom: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'My Teams'),
          Tab(text: 'Discover'),
        ],
        labelColor: skyBlue,
        unselectedLabelColor: Colors.grey,
        indicatorColor: skyBlue,
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  // ---------- List builders ----------
  Widget _buildMyTeamsList() {
    final filtered = _filterMyTeams();
    if (filtered.isEmpty) {
      return const Center(child: Text('You are not in any teams yet.'));
    }
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (ctx, index) {
        final team = filtered[index];
        final groupData = team['travel_groups'] as Map<String, dynamic>;
        final role = team['member_role'] ?? 'MEMBER';
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            title: Text(groupData['team_name'] ?? 'Unnamed'),
            subtitle: Text('${groupData['team_type']} · ${team['membership_status']}'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: role == 'OWNER' ? Colors.amber[100] : Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                role,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: role == 'OWNER' ? Colors.brown[700] : Colors.grey[700],
                ),
              ),
            ),
            onTap: () => _navigateToDetail(team),
          ),
        );
      },
    );
  }

  Widget _buildPublicTeamsList() {
    final filtered = _filterPublicTeams();
    if (filtered.isEmpty) {
      return const Center(child: Text('No public teams available.'));
    }
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (ctx, index) {
        final team = filtered[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            title: Text(team.teamName),
            subtitle: Text('${team.teamType} · ${team.maxCapacity ?? '?'} members'),
            trailing: ElevatedButton(
              onPressed: () async {
                try {
                  final user = Supabase.instance.client.auth.currentUser;
                  if (user == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please log in first.')),
                    );
                    return;
                  }
                  await _groupService.requestToJoinByCode(
                    code: team.invitationCode ?? '',
                    userId: user.id,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Join request sent!')),
                  );
                  _loadData();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[100],
                foregroundColor: Colors.blue[800],
              ),
              child: const Text('Join'),
            ),
            onTap: () => _navigateToDetail({'group_id': team.groupId}),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

// ---------- Reusable widgets (copied from HomeScreen) ----------
class _MysteryLaneLogo extends StatelessWidget {
  const _MysteryLaneLogo();

  @override
  Widget build(BuildContext context) {
    const Color skyBlue = Color(0xFF0284C7);
    const Color teal = Color(0xFF0D9488);
    return Container(
      width: 38,
      height: 38,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [skyBlue, teal],
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
              color: Color(0xFF0284C7),
            )
                : null,
          ),
        ),
      ),
    );
  }
}