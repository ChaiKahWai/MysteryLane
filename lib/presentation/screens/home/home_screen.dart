import 'package:flutter/material.dart';

import '../../../core/app_imports.dart';
import '../../../core/config/supabase_config.dart';
import '../Blindbox/BlindBox_Screen.dart';
import '../checkpoint/checkpoint_screen.dart';
import '../profile/profile_screen.dart';
import '../profile/leaderboard_screen.dart';
import '../group/group_screen.dart';
import '../group/chat_list_screen.dart';
import '../plan/plan_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color skyBlue = Color(0xFF0284C7);
  static const Color teal = Color(0xFF0D9488);
  static const Color darkText = Color(0xFF0F172A);

  // IndexedStack state
  int _selectedIndex = 0;
  final List<Widget> _screens = [
    const _HomeContent(),       // index 0: Home (hero)
    const BlindBoxPage(),       // index 1: Blind Box
    const CheckpointScreen(),   // index 2: Missions
    const PlanScreen(),         // index 3: Plan
    const GroupScreen(),        // index 4: Teams
  ];

  String? _headerProfilePictureUrl;

  // Map tab to index
  int _tabToIndex(MysteryLaneTab tab) {
    switch (tab) {
      case MysteryLaneTab.blindBox:
        return 1;
      case MysteryLaneTab.missions:
        return 2;
      case MysteryLaneTab.plan:
        return 3;
      case MysteryLaneTab.teams:
        return 4;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadHeaderProfile();
  }

  Future<void> _loadHeaderProfile() async {
    try {
      final user = SupabaseConfig.client.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _headerProfilePictureUrl = null);
        return;
      }
      final profile = await SupabaseConfig.client
          .from('profiles')
          .select('profile_picture_url')
          .eq('id', user.id)
          .maybeSingle();
      if (!mounted) return;
      final picture = profile?['profile_picture_url']?.toString().trim();
      setState(() {
        _headerProfilePictureUrl =
        (picture != null && picture.isNotEmpty) ? picture : null;
      });
    } catch (error) {
      debugPrint('HOME HEADER PROFILE PHOTO ERROR: $error');
    }
  }

  // ---------- Navigation helpers ----------
  void _handleTabSelection(MysteryLaneTab tab) {
    setState(() {
      _selectedIndex = _tabToIndex(tab);
    });
  }

  void _goHome() {
    setState(() {
      _selectedIndex = 0;
    });
  }

  Future<void> _openProfile() async {
    await NavigationService().goToProfile();
    await _loadHeaderProfile();
  }

  void _openLeaderboard() {
    NavigationService().goToLeaderboard();
  }

  void _openChat() {
    NavigationService().goToChat();
  }

  // ---------- Build ----------
  @override
  Widget build(BuildContext context) {
    // We need to manually build the Scaffold because we use IndexedStack.
    // We'll use MysteryLaneAppBar and MysteryLaneBottomBar directly.

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      extendBody: true,
      appBar: MysteryLaneAppBar(
        title: 'MYSTERYLANE',
        onLeaderboardTap: _openLeaderboard,
        onChatTap: _openChat,
        onProfileTap: _openProfile,
        profileImageUrl: _headerProfilePictureUrl,
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: MysteryLaneHomeButton(
        onTap: _goHome,
      ),
      bottomNavigationBar: MysteryLaneBottomBar(
        selectedTab: _indexToTab(_selectedIndex),
        onTabSelected: _handleTabSelection,
      ),
    );
  }

  // Helper to convert index back to tab (for highlighting)
  MysteryLaneTab _indexToTab(int index) {
    switch (index) {
      case 1:
        return MysteryLaneTab.blindBox;
      case 2:
        return MysteryLaneTab.missions;
      case 3:
        return MysteryLaneTab.plan;
      case 4:
        return MysteryLaneTab.teams;
      default:
      // Home tab has no corresponding bottom bar item, so we default to blindBox
        return MysteryLaneTab.blindBox;
    }
  }
}

// ============================================================
// HOME CONTENT (extracted from original build)
// ============================================================

class _HomeContent extends StatelessWidget {
  const _HomeContent();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildWelcomeRow(),
            const SizedBox(height: 18),
            _buildDiscoveryHero(context),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeRow() {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ready for your next mystery?',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Discover somewhere new',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFE0F2FE),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: const Color(0xFFBAE6FD)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 15,
                color: Color(0xFF0284C7),
              ),
              SizedBox(width: 5),
              Text(
                'EXPLORE',
                style: TextStyle(
                  color: Color(0xFF0284C7),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDiscoveryHero(BuildContext context) {
    return Container(
      height: 470,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFBAE6FD)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 22,
            offset: Offset(0, 9),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            'https://images.unsplash.com/photo-1503899036084-c55cdd92da26?auto=format&fit=crop&w=1200&q=80',
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const ColoredBox(
                color: Color(0xFF0C4A6E),
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return const ColoredBox(
                color: Color(0xFF0C4A6E),
                child: Center(
                  child: Icon(
                    Icons.landscape_rounded,
                    size: 90,
                    color: Color(0x66FFFFFF),
                  ),
                ),
              );
            },
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x660F172A),
                  Color(0x990C4A6E),
                  Color(0xF20284C7),
                ],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.28),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.25),
                      ),
                    ),
                    child: const Text(
                      'FEATURED DISCOVERY  •  VOL. IV',
                      style: TextStyle(
                        color: Color(0xFFE0F2FE),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.7,
                      ),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Text(
                      'Destination\nDiscovery',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 35,
                        height: 1.02,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.0,
                        shadows: [
                          Shadow(
                            color: Color(0x66000000),
                            blurRadius: 12,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Open a mystery and discover an unexpected place waiting around you.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFE0F2FE),
                        fontSize: 14,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.96),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0284C7), Color(0xFF0D9488)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x3D0284C7),
                          blurRadius: 13,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          // Navigate to Blind Box using NavigationService
                          NavigationService().goToBlindBox();
                        },
                        child: const Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.casino_rounded,
                                color: Color(0xFFFDE68A),
                                size: 23,
                              ),
                              SizedBox(width: 10),
                              Text(
                                'EXPLORE BLIND BOX NOW',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}