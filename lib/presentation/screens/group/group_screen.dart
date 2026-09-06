import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../application/services/group_service.dart';
import '../../../data/models/travel_group_model.dart';
import 'team_detail_screen.dart';
import 'join_team_screen.dart';
import 'chat_list_screen.dart';
import '../profile/profile_screen.dart';
import '../profile/leaderboard_screen.dart';
import '../Blindbox/BlindBox_Screen.dart';
import '../checkpoint/checkpoint_screen.dart';
import '../plan/plan_screen.dart';
import '../home/home_screen.dart';

class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key});

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  // ---- COLORS ----
  static const Color skyBlue = Color(0xFF0284C7);
  static const Color teal = Color(0xFF0D9488);
  static const Color darkText = Color(0xFF0F172A);
  static const Color greyText = Color(0xFF64748B);
  static const Color pageBackground = Color(0xFFF8FAFC);
  static const Color borderColor = Color(0xFFE2E8F0);

  final GroupService _groupService = GroupService();

  // ---- Tab state (0 = My Teams, 1 = Public Teams) ----
  int _selectedTabIndex = 0;

  List<Map<String, dynamic>> _myTeams = [];
  List<Map<String, dynamic>> _publicTeams = [];
  bool _isLoading = false;
  String _searchQuery = '';

  // Date filter
  DateTime? _selectedDate;

  // Pagination
  int _currentPage = 0;
  static const int _itemsPerPage = 10;

  String? _headerProfilePictureUrl;

  @override
  void initState() {
    super.initState();
    _loadHeaderProfile();
    _loadData();
  }

  @override
  void dispose() {
    super.dispose();
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

  void _openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChatListScreen()),
    );
  }

  // ---------- Navigation helpers ----------
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
          _currentPage = 0;
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

  List<Map<String, dynamic>> get _filteredPublicTeams {
    List<Map<String, dynamic>> filtered = _publicTeams;

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((item) {
        final team = item['team'] as TravelGroup;
        return team.teamName.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    if (_selectedDate != null) {
      filtered = filtered.where((item) {
        final team = item['team'] as TravelGroup;
        if (team.tripStartDate == null || team.tripEndDate == null) return false;
        return (_selectedDate!.isAfter(team.tripStartDate!) || _selectedDate!.isAtSameMomentAs(team.tripStartDate!)) &&
            (_selectedDate!.isBefore(team.tripEndDate!) || _selectedDate!.isAtSameMomentAs(team.tripEndDate!));
      }).toList();
    }

    // Exclude teams the user has already joined
    final Set<String> joinedGroupIds = _myTeams
        .map((team) => team['travel_groups']['group_id'] as String)
        .toSet();
    filtered = filtered.where((item) {
      final team = item['team'] as TravelGroup;
      return !joinedGroupIds.contains(team.groupId);
    }).toList();

    return filtered;
  }

  int get _totalPages => (_filteredPublicTeams.length / _itemsPerPage).ceil();

  List<Map<String, dynamic>> get _paginatedTeams {
    if (_filteredPublicTeams.isEmpty) return [];
    final start = _currentPage * _itemsPerPage;
    final end = (start + _itemsPerPage).clamp(0, _filteredPublicTeams.length);
    return _filteredPublicTeams.sublist(start, end);
  }

  void _goToPage(int page) {
    if (page < 0 || page >= _totalPages) return;
    setState(() {
      _currentPage = page;
    });
  }

  void _onFilterChanged() {
    setState(() {
      _currentPage = 0;
    });
  }

  // ---- Date picker methods ----
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      helpText: 'Select a date within trip range',
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _currentPage = 0;
      });
    }
  }

  void _clearDateFilter() {
    setState(() {
      _selectedDate = null;
      _currentPage = 0;
    });
  }

  // ---------- Build ----------
  @override
  Widget build(BuildContext context) {
    final filteredPublic = _filteredPublicTeams;
    final totalPages = _totalPages;
    final paginated = _paginatedTeams;

    return Scaffold(
      backgroundColor: pageBackground,
      extendBody: false,
      appBar: _buildTopAppBar(),
      body: Column(
        children: [
          _buildBodyHeader(),
          // ---- SEARCH BAR + DATE FILTER BUTTON ----
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6),
            child: Row(
              children: [
                Expanded(
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
                    onChanged: (value) {
                      _searchQuery = value;
                      _onFilterChanged();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    _selectedDate == null ? Icons.calendar_today : Icons.calendar_today,
                    color: _selectedDate != null ? skyBlue : greyText,
                  ),
                  onPressed: _pickDate,
                  tooltip: 'Filter by trip date',
                ),
                if (_selectedDate != null)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: _clearDateFilter,
                    tooltip: 'Clear date filter',
                  ),
              ],
            ),
          ),
          // ---- PUBLIC TEAMS HEADER (shown only when public tab is active) ----
          if (_selectedTabIndex == 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Available Public Teams',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: darkText,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: skyBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${filteredPublic.length} squad${filteredPublic.length != 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: skyBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // ---- CONTENT based on selected tab ----
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _selectedTabIndex == 0
                ? _buildMyTeamsList()
                : _buildPublicTeamsList(paginated, totalPages),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _buildHomeButton(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ---- TOP APP BAR ----
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
          onTap: _openChat,
        ),
        const SizedBox(width: 6),
        _ProfileButton(
          onTap: _openProfile,
          imageUrl: _headerProfilePictureUrl,
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  // ---- IN‑BODY HEADER (custom pill tabs like planner) ----
  Widget _buildBodyHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Teams',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: darkText,
              fontFamily: 'serif',
            ),
          ),
          const SizedBox(height: 10),
          // Custom tab row
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFD7EAF7)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildTab(
                    label: 'My Teams',
                    icon: Icons.people_alt_rounded,
                    selected: _selectedTabIndex == 0,
                    onTap: () => setState(() => _selectedTabIndex = 0),
                  ),
                ),
                Expanded(
                  child: _buildTab(
                    label: 'Public Teams',
                    icon: Icons.public_rounded,
                    selected: _selectedTabIndex == 1,
                    onTap: () => setState(() => _selectedTabIndex = 1),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? skyBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? Colors.white : const Color(0xFF475569),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'sans-serif',
                color: selected ? Colors.white : const Color(0xFF334155),
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
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
                onTap: () {},
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

  // ---- BODY: My Teams list ----
  Widget _buildMyTeamsList() {
    final filtered = _filterMyTeams();
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const JoinTeamScreen()),
              ).then((_) => _loadData());
            },
            icon: const Icon(Icons.add_link, color: Colors.white, size: 20),
            label: const Text(
              'Join a team with invitation code',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: skyBlue,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
              shadowColor: skyBlue.withOpacity(0.3),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(
              child: Text('You are not in any teams yet.'),
            ),
          )
        else
          ...filtered.map((team) {
            final groupData = team['travel_groups'] as Map<String, dynamic>;
            final role = team['member_role'] ?? 'MEMBER';
            return Card(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.blue.shade100, width: 1.5),
              ),
              elevation: 2,
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
          }),
      ],
    );
  }

  // ---- BODY: Public Teams list ----
  Widget _buildPublicTeamsList(List<Map<String, dynamic>> paginated, int totalPages) {
    if (_filteredPublicTeams.isEmpty) {
      return Center(
        child: Text(
          _selectedDate == null
              ? 'No public teams available.'
              : 'No teams with trips covering ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}.',
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: paginated.length + 1,
      itemBuilder: (ctx, index) {
        if (index == paginated.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _currentPage > 0 ? () => _goToPage(_currentPage - 1) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  'Page ${_currentPage + 1} of $totalPages',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                IconButton(
                  onPressed: _currentPage < totalPages - 1 ? () => _goToPage(_currentPage + 1) : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          );
        }

        final item = paginated[index];
        final team = item['team'] as TravelGroup;
        final ownerName = item['ownerName'] as String;
        final tripStart = item['tripStart'] as DateTime?;
        final tripEnd = item['tripEnd'] as DateTime?;
        final firstStopName = item['firstStopName'] as String?;

        return Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.blue.shade100, width: 1.5),
          ),
          elevation: 2,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            title: Text(team.teamName),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${team.teamType} · ${team.maxCapacity ?? '?'} members · Host: $ownerName'),
                if (tripStart != null && tripEnd != null)
                  Text(
                    'Trip: ${tripStart.day}/${tripStart.month}/${tripStart.year} → ${tripEnd.day}/${tripEnd.month}/${tripEnd.year}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                if (firstStopName != null && firstStopName.isNotEmpty)
                  Text(
                    '📍 $firstStopName',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: skyBlue),
                  ),
              ],
            ),
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
}

// ---------- Helper widgets ----------
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
          colors: [_GroupScreenState.skyBlue, _GroupScreenState.teal],
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
              color: _GroupScreenState.skyBlue,
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
                color: active ? _GroupScreenState.skyBlue : Colors.transparent,
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
                color: active ? _GroupScreenState.skyBlue : const Color(0xFF64748B),
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