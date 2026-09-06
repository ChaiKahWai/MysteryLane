import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../application/services/chat_service.dart';
import '../../../data/models/chat_message_model.dart';
import '../Blindbox/BlindBox_Screen.dart';
import '../checkpoint/checkpoint_screen.dart';
import '../plan/plan_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';
import '../profile/leaderboard_screen.dart';
import 'group_screen.dart';
import 'chat_list_screen.dart';

class TeamChatScreen extends StatefulWidget {
  final String groupId;
  const TeamChatScreen({super.key, required this.groupId});

  @override
  State<TeamChatScreen> createState() => _TeamChatScreenState();
}

class _TeamChatScreenState extends State<TeamChatScreen> {
  static const Color skyBlue = Color(0xFF0284C7);
  static const Color teal = Color(0xFF0D9488);
  static const Color darkText = Color(0xFF0F172A);
  static const Color greyText = Color(0xFF64748B);
  static const Color pageBackground = Color(0xFFF8FAFC);
  static const Color borderColor = Color(0xFFE2E8F0);

  final ChatService _chatService = ChatService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _headerProfilePictureUrl;
  String? _teamName;

  @override
  void initState() {
    super.initState();
    _loadHeaderProfile();
    _loadTeamName();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
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

  Future<void> _loadTeamName() async {
    try {
      final response = await Supabase.instance.client
          .from('travel_groups')
          .select('team_name')
          .eq('group_id', widget.groupId)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _teamName = response?['team_name'] as String? ?? 'Team Chat';
        });
      }
    } catch (e) {
      debugPrint('Team name error: $e');
      if (mounted) {
        setState(() {
          _teamName = 'Team Chat';
        });
      }
    }
  }

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

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      await _chatService.sendMessage(
        groupId: widget.groupId,
        userId: user.id,
        message: text,
      );
      _controller.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send: $e'),
          behavior: SnackBarBehavior.floating, // floating to avoid layout shift
        ),
      );
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom + 80.0;

    return Scaffold(
      backgroundColor: pageBackground,
      extendBody: true,
      // Keep resizeToAvoidBottomInset true to let the input move above the keyboard
      appBar: _buildTopAppBar(),
      body: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: Column(
          children: [
            // ---- Team name header with back button ----
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: borderColor, width: 1),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: darkText),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  Expanded(
                    child: Text(
                      _teamName ?? 'Loading...',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: darkText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<ChatMessage>>(
                stream: _chatService.getMessagesForTeam(widget.groupId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final messages = snapshot.data!;
                  if (messages.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 64,
                              color: greyText,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No messages yet',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: darkText,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Start the conversation!',
                              style: TextStyle(
                                fontSize: 14,
                                color: greyText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients) {
                      _scrollController.animateTo(
                        _scrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                  });
                  final currentUserId = Supabase.instance.client.auth.currentUser?.id;
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(bottom: 12),
                    itemCount: messages.length,
                    itemBuilder: (ctx, index) {
                      final msg = messages[index];
                      final isMe = msg.userId == currentUserId;
                      return _buildMessageBubble(msg, isMe);
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: skyBlue),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _buildHomeButton(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isMe ? Colors.blue[200] : Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              msg.fullName ?? 'Unknown',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isMe ? Colors.blue[900] : Colors.grey[800],
              ),
            ),
            const SizedBox(height: 2),
            Text(msg.message),
            const SizedBox(height: 2),
            Text(
              _formatTime(msg.sentAt),
              style: TextStyle(
                fontSize: 10,
                color: isMe ? Colors.blue[800] : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildTopAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
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
              MaterialPageRoute(builder: (_) => ChatListScreen()),
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
          colors: [_TeamChatScreenState.skyBlue, _TeamChatScreenState.teal],
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
              color: _TeamChatScreenState.skyBlue,
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
                color: active ? _TeamChatScreenState.skyBlue : Colors.transparent,
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
                color: active ? _TeamChatScreenState.skyBlue : const Color(0xFF64748B),
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