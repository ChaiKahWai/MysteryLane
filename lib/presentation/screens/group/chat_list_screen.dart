import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../application/services/group_service.dart';
import '../../../application/services/chat_service.dart';
import 'team_chat_screen.dart';
import '../Blindbox/BlindBox_Screen.dart';
import '../checkpoint/checkpoint_screen.dart';
import '../plan/plan_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';
import '../profile/leaderboard_screen.dart';
import 'group_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  static const Color skyBlue = Color(0xFF0284C7);
  static const Color teal = Color(0xFF0D9488);
  static const Color darkText = Color(0xFF0F172A);
  static const Color greyText = Color(0xFF64748B);
  static const Color pageBackground = Color(0xFFF8FAFC);
  static const Color borderColor = Color(0xFFE2E8F0);
  static const Color cardBorder = Color(0xFFE8EDF2);

  final GroupService _groupService = GroupService();
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _myTeams = [];
  Map<String, dynamic> _lastMessages = {};
  bool _loading = true;
  String _searchQuery = '';

  String? _headerProfilePictureUrl;

  @override
  void initState() {
    super.initState();
    _loadHeaderProfile();
    _loadData();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  List<Map<String, dynamic>> get _filteredTeams {
    if (_searchQuery.isEmpty) return _myTeams;
    return _myTeams.where((team) {
      final name = team['travel_groups']?['team_name']?.toLowerCase() ?? '';
      return name.contains(_searchQuery.toLowerCase());
    }).toList();
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
      MaterialPageRoute(builder: (_) => const PlanScreen()),
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

  void _openChatList() {
    // already here
  }

  void _goBack() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true,
      appBar: _buildTopAppBar(),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // ---- Header: Back button + centered title + chat icon ----
          SizedBox(
            height: 56,
            child: Stack(
              children: [
                const Align(
                  alignment: Alignment.center,
                  child: Text(
                    'Expedition Chat Hub',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: darkText,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: darkText),
                      onPressed: _goBack,
                      tooltip: 'Back',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: EdgeInsets.only(right: 16.0),
                    child: Icon(
                      Icons.chat_bubble_outline,
                      color: greyText,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ---- Search Bar ----
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search teams...',
                prefixIcon: const Icon(Icons.search, color: greyText),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, color: greyText),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: skyBlue),
                ),
              ),
            ),
          ),
          Expanded(
            child: _filteredTeams.isEmpty
                ? const Center(
              child: Text('No teams match your search'),
            )
                : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
              itemCount: _filteredTeams.length,
              itemBuilder: (ctx, index) {
                final team = _filteredTeams[index];
                final groupData = team['travel_groups'];
                final groupId = groupData['group_id'];
                final lastMsg = _lastMessages[groupId];
                return _ChatListItem(
                  teamName: groupData['team_name'],
                  lastMessage: lastMsg,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TeamChatScreen(groupId: groupId),
                      ),
                    );
                  },
                  formatTime: _formatTime,
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _buildHomeButton(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ---- TOP APP BAR (unchanged) ----
  PreferredSizeWidget _buildTopAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 68,
      elevation: 0,
      scrolledUnderElevation: 2,
      backgroundColor: Colors.white,
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
          onTap: _openChatList,
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

  // ---- BOTTOM BAR (unchanged) ----
  Widget _buildBottomBar() {
    return BottomAppBar(
      height: 78,
      padding: EdgeInsets.zero,
      color: Colors.white,
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
                    MaterialPageRoute(builder: (_) => GroupScreen()),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- HOME FLOATING BUTTON (unchanged) ----
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

// ---- Custom chat list item with white + light blue theme ----
class _ChatListItem extends StatefulWidget {
  final String teamName;
  final Map<String, dynamic>? lastMessage;
  final VoidCallback onTap;
  final String Function(String) formatTime;

  const _ChatListItem({
    required this.teamName,
    required this.lastMessage,
    required this.onTap,
    required this.formatTime,
  });

  @override
  State<_ChatListItem> createState() => _ChatListItemState();
}

class _ChatListItemState extends State<_ChatListItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isPressed ? _ChatListScreenState.skyBlue : const Color(0xFFE8EDF2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _isPressed
                  ? const Color(0x1A0284C7)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: CircleAvatar(
            backgroundColor: const Color(0xFFEAF6FE),
            child: Text(
              widget.teamName[0],
              style: const TextStyle(
                color: _ChatListScreenState.skyBlue,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          title: Text(
            widget.teamName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _ChatListScreenState.darkText,
            ),
          ),
          subtitle: widget.lastMessage != null
              ? Text(
            '${widget.lastMessage!['full_name']}: ${widget.lastMessage!['message']}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _ChatListScreenState.greyText,
              fontSize: 14,
            ),
          )
              : const Text(
            'No messages yet',
            style: TextStyle(
              color: _ChatListScreenState.greyText,
              fontSize: 14,
            ),
          ),
          trailing: widget.lastMessage != null
              ? Text(
            widget.formatTime(widget.lastMessage!['sent_at']),
            style: const TextStyle(
              fontSize: 12,
              color: _ChatListScreenState.greyText,
            ),
          )
              : null,
        ),
      ),
    );
  }
}

// ---- Reusable helper widgets (unchanged) ----
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
          colors: [_ChatListScreenState.skyBlue, _ChatListScreenState.teal],
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
              color: _ChatListScreenState.skyBlue,
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
                color: active ? _ChatListScreenState.skyBlue : Colors.transparent,
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
                color: active ? _ChatListScreenState.skyBlue : const Color(0xFF64748B),
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