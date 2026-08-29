import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/config/supabase_config.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() =>
      _LeaderboardScreenState();
}

class _LeaderboardScreenState
    extends State<LeaderboardScreen> {
  static const Color _blue = Color(0xFF0284C7);
  static const Color _teal = Color(0xFF0D9488);
  static const Color _navy = Color(0xFF0F1B33);
  static const Color _page = Color(0xFFF8FAFC);
  static const Color _text = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);

  bool _loading = true;
  String? _errorMessage;

  String? _currentUserId;
  String? _headerProfilePictureUrl;

  List<LeaderboardEntry> _entries = [];

  Timer? _timer;
  Duration _untilMidnight = Duration.zero;

  @override
  void initState() {
    super.initState();

    _loadLeaderboard();
    _updateTimer();

    _timer = Timer.periodic(
      const Duration(seconds: 1),
          (_) => _updateTimer(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ============================================================
  // LOAD REAL USERS FROM SUPABASE
  //
  // SECURITY:
  // The leaderboard does NOT read public.profiles directly.
  // It calls the restricted get_leaderboard() RPC, which returns
  // only:
  // id
  // full_name
  // profile_picture_url
  // exploration_points
  //
  // Sensitive profile fields such as phone_number are not exposed.
  // ============================================================

  Future<void> _loadLeaderboard() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final user =
          SupabaseConfig.client.auth.currentUser;

      if (user == null) {
        throw Exception(
          'No authenticated traveller was found.',
        );
      }

      _currentUserId = user.id;

      final List<dynamic> response =
      await SupabaseConfig.client.rpc(
        'get_leaderboard',
      );

      final List<LeaderboardEntry> built = [];

      for (int i = 0; i < response.length; i++) {
        final Map<String, dynamic> row =
        Map<String, dynamic>.from(
          response[i] as Map,
        );

        final String id =
            row['id']?.toString() ?? '';

        final String fullName =
            row['full_name']?.toString().trim() ?? '';

        final String? picture =
        _cleanNullableString(
          row['profile_picture_url'],
        );

        final int explorationPoints =
        _toInt(
          row['exploration_points'],
        );

        built.add(
          LeaderboardEntry(
            rank: i + 1,
            userId: id,
            name: fullName.isEmpty
                ? 'Traveller'
                : fullName,
            explorationPoints:
            explorationPoints,
            profilePictureUrl: picture,
            isCurrentUser: id == user.id,
          ),
        );
      }

      final currentUserEntry =
      built.where(
            (entry) => entry.isCurrentUser,
      );

      if (currentUserEntry.isNotEmpty) {
        _headerProfilePictureUrl =
            currentUserEntry.first.profilePictureUrl;
      } else {
        final Map<String, dynamic>? ownProfile =
        await SupabaseConfig.client
            .from('profiles')
            .select(
          'profile_picture_url',
        )
            .eq('id', user.id)
            .maybeSingle();

        _headerProfilePictureUrl =
            _cleanNullableString(
              ownProfile?['profile_picture_url'],
            );
      }

      if (!mounted) return;

      setState(() {
        _entries = built;
        _loading = false;
      });
    } catch (error) {
      debugPrint(
        'LEADERBOARD LOAD ERROR: $error',
      );

      if (!mounted) return;

      setState(() {
        _loading = false;
        _errorMessage =
        'Unable to load leaderboard data from Supabase.';
      });
    }
  }

  String? _cleanNullableString(
      dynamic value,
      ) {
    if (value == null) {
      return null;
    }

    final String text =
    value.toString().trim();

    if (text.isEmpty) {
      return null;
    }

    return text;
  }

  int _toInt(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value.toString(),
    ) ??
        0;
  }

  void _updateTimer() {
    final now = DateTime.now();

    final nextMidnight = DateTime(
      now.year,
      now.month,
      now.day + 1,
    );

    if (!mounted) return;

    setState(() {
      _untilMidnight =
          nextMidnight.difference(now);
    });
  }

  String _twoDigits(int value) {
    return value
        .toString()
        .padLeft(2, '0');
  }

  LeaderboardEntry? get _currentUserEntry {
    for (final entry in _entries) {
      if (entry.userId ==
          _currentUserId) {
        return entry;
      }
    }

    return null;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _page,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopHeader(),
            Expanded(
              child: RefreshIndicator(
                color: _blue,
                onRefresh: _loadLeaderboard,
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation:
      FloatingActionButtonLocation.centerDocked,
      floatingActionButton:
      _buildHomeButton(),
      bottomNavigationBar:
      _buildBottomBar(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return ListView(
        physics:
        const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 250),
          Center(
            child:
            CircularProgressIndicator(
              color: _blue,
            ),
          ),
        ],
      );
    }

    if (_errorMessage != null) {
      return ListView(
        physics:
        const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 150),
          const Icon(
            Icons.leaderboard_outlined,
            color: _blue,
            size: 62,
          ),
          const SizedBox(height: 18),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _muted,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _loadLeaderboard,
            style: FilledButton.styleFrom(
              backgroundColor: _blue,
              minimumSize:
              const Size.fromHeight(
                50,
              ),
            ),
            child: const Text(
              'TRY AGAIN',
            ),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      physics:
      const AlwaysScrollableScrollPhysics(),
      padding:
      const EdgeInsets.fromLTRB(
        18,
        22,
        18,
        95,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints:
          const BoxConstraints(
            maxWidth: 760,
          ),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.stretch,
            children: [
              _buildBackButton(),

              const SizedBox(height: 28),

              _buildHeroHeading(),

              const SizedBox(height: 22),

              _buildResetCard(),

              const SizedBox(height: 20),

              _buildDailyTab(),

              const SizedBox(height: 22),

              if (_currentUserEntry != null)
                _buildCurrentUserCard(
                  _currentUserEntry!,
                ),

              if (_currentUserEntry != null)
                const SizedBox(height: 24),

              _buildRankingTable(),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TOP HEADER
  // ============================================================

  Widget _buildTopHeader() {
    return Container(
      height: 69,
      decoration: BoxDecoration(
        color:
        Colors.white.withOpacity(
          0.97,
        ),
        border: const Border(
          bottom: BorderSide(
            color: _border,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),

          Container(
            width: 38,
            height: 38,
            decoration:
            const BoxDecoration(
              shape: BoxShape.circle,
              gradient:
              LinearGradient(
                colors: [
                  _blue,
                  _teal,
                ],
                begin:
                Alignment.topLeft,
                end:
                Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color:
                  Color(0x300284C7),
                  blurRadius: 10,
                  offset:
                  Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.explore_rounded,
              color: Colors.white,
              size: 23,
            ),
          ),

          const SizedBox(width: 10),

          const Expanded(
            child: Text(
              'MYSTERYLANE',
              maxLines: 1,
              overflow:
              TextOverflow.fade,
              softWrap: false,
              style: TextStyle(
                color: _text,
                fontSize: 20,
                fontWeight:
                FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ),

          const _HeaderActionButton(
            tooltip: 'Leaderboard',
            icon:
            Icons.emoji_events_rounded,
            background:
            Color(0xFFFFFBEB),
            foreground:
            Color(0xFFD97706),
          ),

          const SizedBox(width: 6),

          const _HeaderActionButton(
            tooltip: 'Chat',
            icon: Icons
                .chat_bubble_outline_rounded,
            background:
            Color(0xFFF0F9FF),
            foreground: _blue,
          ),

          const SizedBox(width: 6),

          _buildHeaderProfilePicture(),

          const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _buildHeaderProfilePicture() {
    final String? imageUrl =
    _headerProfilePictureUrl
        ?.trim();

    final ImageProvider? provider =
    imageUrl != null &&
        imageUrl.isNotEmpty
        ? NetworkImage(imageUrl)
        : null;

    return Container(
      width: 38,
      height: 38,
      padding:
      const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color:
          const Color(
            0xFFBAE6FD,
          ),
          width: 1.4,
        ),
      ),
      child: CircleAvatar(
        backgroundColor:
        const Color(
          0xFFE0F2FE,
        ),
        backgroundImage: provider,
        child: provider == null
            ? const Icon(
          Icons.person_rounded,
          size: 20,
          color: _blue,
        )
            : null,
      ),
    );
  }

  // ============================================================
  // BACK BUTTON
  // ============================================================

  Widget _buildBackButton() {
    return Align(
      alignment:
      Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.of(context).pop();
        },
        style:
        OutlinedButton.styleFrom(
          foregroundColor: _text,
          backgroundColor:
          Colors.white,
          side: const BorderSide(
            color: _border,
          ),
          padding:
          const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          shape:
          RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(
              12,
            ),
          ),
        ),
        icon: const Icon(
          Icons.arrow_back,
          size: 18,
          color: _blue,
        ),
        label: const Text(
          'Back to Home',
          style: TextStyle(
            fontSize: 12,
            fontWeight:
            FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TITLE
  // ============================================================

  Widget _buildHeroHeading() {
    return Column(
      children: [
        Container(
          padding:
          const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color:
            const Color(
              0xFFF0F9FF,
            ),
            borderRadius:
            BorderRadius.circular(
              99,
            ),
            border: Border.all(
              color:
              const Color(
                0xFFBAE6FD,
              ),
            ),
          ),
          child: const Text(
            'GLOBAL EXPLORER RANKINGS  •  LIVE SUPABASE DATA',
            textAlign:
            TextAlign.center,
            style: TextStyle(
              color: _blue,
              fontSize: 9,
              fontWeight:
              FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
        ),

        const SizedBox(height: 10),

        const Text(
          'Explorer Leaderboard',
          textAlign:
          TextAlign.center,
          style: TextStyle(
            color: _text,
            fontSize: 34,
            height: 1.05,
            fontWeight:
            FontWeight.w900,
            fontFamily: 'serif',
          ),
        ),

        const SizedBox(height: 10),

        const Padding(
          padding:
          EdgeInsets.symmetric(
            horizontal: 16,
          ),
          child: Text(
            'See how explorers rank based on their accumulated Exploration Points.',
            textAlign:
            TextAlign.center,
            style: TextStyle(
              color:
              Color(0xFF475569),
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // RESET CARD
  // ============================================================

  Widget _buildResetCard() {
    final int hours =
        _untilMidnight.inHours;

    final int minutes =
    _untilMidnight.inMinutes
        .remainder(60);

    final int seconds =
    _untilMidnight.inSeconds
        .remainder(60);

    return Container(
      padding:
      const EdgeInsets.fromLTRB(
        18,
        16,
        18,
        16,
      ),
      decoration: BoxDecoration(
        color: _navy,
        borderRadius:
        BorderRadius.circular(
          16,
        ),
        boxShadow: const [
          BoxShadow(
            color:
            Color(0x220F172A),
            blurRadius: 12,
            offset:
            Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons
                    .access_time_rounded,
                color:
                Color(0xFF38BDF8),
                size: 18,
              ),

              const SizedBox(width: 8),

              const Expanded(
                child: Text(
                  'NEXT DAILY REFRESH IN',
                  style: TextStyle(
                    color:
                    Color(
                      0xFFBAE6FD,
                    ),
                    fontSize: 11,
                    fontWeight:
                    FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),

              OutlinedButton.icon(
                onPressed:
                _loadLeaderboard,
                style: OutlinedButton
                    .styleFrom(
                  foregroundColor:
                  const Color(
                    0xFF7DD3FC,
                  ),
                  side:
                  const BorderSide(
                    color:
                    Color(
                      0xFF1E5E89,
                    ),
                  ),
                  padding:
                  const EdgeInsets
                      .symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape:
                  RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius
                        .circular(
                      99,
                    ),
                  ),
                ),
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 16,
                ),
                label: const Text(
                  'Refresh',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Container(
            padding:
            const EdgeInsets
                .symmetric(
              vertical: 14,
            ),
            decoration: BoxDecoration(
              color:
              const Color(
                0xFF1C2A44,
              ),
              borderRadius:
              BorderRadius.circular(
                12,
              ),
              border: Border.all(
                color:
                const Color(
                  0xFF334155,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _timeBlock(
                    value:
                    _twoDigits(
                      hours,
                    ),
                    label: 'HOURS',
                  ),
                ),

                const Text(
                  ':',
                  style: TextStyle(
                    color:
                    Color(
                      0xFF64748B,
                    ),
                    fontSize: 24,
                    fontWeight:
                    FontWeight.w900,
                  ),
                ),

                Expanded(
                  child: _timeBlock(
                    value:
                    _twoDigits(
                      minutes,
                    ),
                    label: 'MINUTES',
                  ),
                ),

                const Text(
                  ':',
                  style: TextStyle(
                    color:
                    Color(
                      0xFF64748B,
                    ),
                    fontSize: 24,
                    fontWeight:
                    FontWeight.w900,
                  ),
                ),

                Expanded(
                  child: _timeBlock(
                    value:
                    _twoDigits(
                      seconds,
                    ),
                    label: 'SECONDS',
                    highlight: true,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          const Row(
            children: [
              Expanded(
                child: Text(
                  'Source: Supabase profiles',
                  style: TextStyle(
                    color:
                    Color(
                      0xFF7DD3FC,
                    ),
                    fontSize: 9,
                  ),
                ),
              ),
              Icon(
                Icons.circle,
                color:
                Color(
                  0xFF22D3EE,
                ),
                size: 6,
              ),
              SizedBox(width: 6),
              Text(
                'Live Leaderboard',
                style: TextStyle(
                  color:
                  Color(
                    0xFF38BDF8,
                  ),
                  fontSize: 9,
                  fontWeight:
                  FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _timeBlock({
    required String value,
    required String label,
    bool highlight = false,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: highlight
                ? const Color(
              0xFFFFC107,
            )
                : Colors.white,
            fontSize: 23,
            fontWeight:
            FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color:
            Color(0xFF7DD3FC),
            fontSize: 8,
            fontWeight:
            FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // DAILY TAB
  // ============================================================

  Widget _buildDailyTab() {
    return Center(
      child: Container(
        padding:
        const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: _blue,
          borderRadius:
          BorderRadius.circular(
            99,
          ),
        ),
        child: const Row(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            Icon(
              Icons
                  .calendar_month_outlined,
              color: Colors.white,
              size: 14,
            ),
            SizedBox(width: 7),
            Text(
              'CURRENT RANKING',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight:
                FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CURRENT USER CARD
  // ============================================================

  Widget _buildCurrentUserCard(
      LeaderboardEntry entry,
      ) {
    return Container(
      padding:
      const EdgeInsets.all(
        16,
      ),
      decoration: BoxDecoration(
        color:
        const Color(
          0xFFF0F9FF,
        ),
        borderRadius:
        BorderRadius.circular(
          16,
        ),
        border: Border.all(
          color:
          const Color(
            0xFFBAE6FD,
          ),
        ),
      ),
      child: Row(
        children: [
          _avatar(
            entry,
            size: 50,
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment
                  .start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.name,
                        overflow:
                        TextOverflow
                            .ellipsis,
                        style:
                        const TextStyle(
                          color: _text,
                          fontSize: 17,
                          fontWeight:
                          FontWeight
                              .w900,
                          fontFamily:
                          'serif',
                        ),
                      ),
                    ),

                    const SizedBox(
                      width: 7,
                    ),

                    Container(
                      padding:
                      const EdgeInsets
                          .symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration:
                      BoxDecoration(
                        color: _blue,
                        borderRadius:
                        BorderRadius
                            .circular(
                          4,
                        ),
                      ),
                      child:
                      const Text(
                        'YOU',
                        style:
                        TextStyle(
                          color:
                          Colors.white,
                          fontSize: 7,
                          fontWeight:
                          FontWeight
                              .w900,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 5,
                ),

                Text(
                  'CURRENT RANK: #${entry.rank}',
                  style:
                  const TextStyle(
                    color:
                    Color(
                      0xFF475569,
                    ),
                    fontSize: 9,
                    fontWeight:
                    FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),

          Column(
            crossAxisAlignment:
            CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.explorationPoints} EP',
                style:
                const TextStyle(
                  color: _blue,
                  fontSize: 18,
                  fontWeight:
                  FontWeight.w900,
                ),
              ),
              const SizedBox(
                height: 4,
              ),
              const Text(
                'TOTAL POINTS',
                style: TextStyle(
                  color: _muted,
                  fontSize: 8,
                  fontWeight:
                  FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RANKING TABLE
  // ============================================================

  Widget _buildRankingTable() {
    if (_entries.isEmpty) {
      return Container(
        padding:
        const EdgeInsets.all(
          30,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
          BorderRadius.circular(
            16,
          ),
          border: Border.all(
            color: _border,
          ),
        ),
        child: const Column(
          children: [
            Icon(
              Icons
                  .leaderboard_outlined,
              color: _blue,
              size: 44,
            ),
            SizedBox(height: 12),
            Text(
              'No leaderboard users found.',
              style: TextStyle(
                color: _muted,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(
          16,
        ),
        border: Border.all(
          color: _border,
        ),
      ),
      clipBehavior:
      Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding:
            const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 13,
            ),
            color:
            const Color(
              0xFFFAFCFE,
            ),
            child: const Row(
              children: [
                Expanded(
                  child: Text(
                    'RANK & EXPLORER',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 9,
                      fontWeight:
                      FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Text(
                  'EXPLORATION POINTS',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 9,
                    fontWeight:
                    FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),

          for (final entry
          in _entries)
            _rankingRow(entry),
        ],
      ),
    );
  }

  Widget _rankingRow(
      LeaderboardEntry entry,
      ) {
    Color background =
        Colors.white;

    if (entry.rank <= 3) {
      background =
      const Color(
        0xFFFFFAF4,
      );
    }

    if (entry.isCurrentUser) {
      background =
      const Color(
        0xFFF0F9FF,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: background,
        border: Border(
          top: const BorderSide(
            color:
            Color(
              0xFFF1F5F9,
            ),
          ),
          left:
          entry.isCurrentUser
              ? const BorderSide(
            color: _blue,
            width: 4,
          )
              : BorderSide.none,
        ),
      ),
      padding:
      EdgeInsets.fromLTRB(
        entry.isCurrentUser
            ? 12
            : 16,
        14,
        16,
        14,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: _rankWidget(
              entry.rank,
            ),
          ),

          const SizedBox(width: 8),

          _avatar(entry),

          const SizedBox(width: 11),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment
                  .start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.isCurrentUser
                            ? '${entry.name} (You)'
                            : entry.name,
                        overflow:
                        TextOverflow
                            .ellipsis,
                        style:
                        const TextStyle(
                          color: _text,
                          fontSize: 15,
                          fontWeight:
                          FontWeight
                              .w900,
                          fontFamily:
                          'serif',
                        ),
                      ),
                    ),

                    if (entry
                        .isCurrentUser) ...[
                      const SizedBox(
                        width: 6,
                      ),
                      Container(
                        padding:
                        const EdgeInsets
                            .symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration:
                        BoxDecoration(
                          color: _blue,
                          borderRadius:
                          BorderRadius
                              .circular(
                            3,
                          ),
                        ),
                        child:
                        const Text(
                          'YOU',
                          style:
                          TextStyle(
                            color:
                            Colors.white,
                            fontSize: 6,
                            fontWeight:
                            FontWeight
                                .w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  _explorerTitle(
                    entry.explorationPoints,
                  ),
                  style:
                  const TextStyle(
                    color: _muted,
                    fontSize: 9,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          Text(
            '${entry.explorationPoints} EP',
            style:
            const TextStyle(
              color: _blue,
              fontSize: 14,
              fontWeight:
              FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  String _explorerTitle(
      int points,
      ) {
    if (points >= 2000) {
      return 'Legendary Explorer';
    }

    if (points >= 1500) {
      return 'Elite Explorer';
    }

    if (points >= 1200) {
      return 'Master Explorer';
    }

    if (points >= 800) {
      return 'Seasoned Explorer';
    }

    if (points >= 500) {
      return 'Active Explorer';
    }

    if (points >= 300) {
      return 'Explorer Apprentice';
    }

    if (points >= 150) {
      return 'Rising Explorer';
    }

    return 'New Explorer';
  }

  Widget _rankWidget(
      int rank,
      ) {
    if (rank == 1) {
      return const Text(
        '🥇',
        textAlign:
        TextAlign.center,
        style:
        TextStyle(fontSize: 24),
      );
    }

    if (rank == 2) {
      return const Text(
        '🥈',
        textAlign:
        TextAlign.center,
        style:
        TextStyle(fontSize: 24),
      );
    }

    if (rank == 3) {
      return const Text(
        '🥉',
        textAlign:
        TextAlign.center,
        style:
        TextStyle(fontSize: 24),
      );
    }

    return Text(
      '#$rank',
      textAlign:
      TextAlign.center,
      style: const TextStyle(
        color:
        Color(0xFF94A3B8),
        fontSize: 13,
        fontWeight:
        FontWeight.w700,
      ),
    );
  }

  // ============================================================
  // PROFILE AVATAR
  // ============================================================

  Widget _avatar(
      LeaderboardEntry entry, {
        double size = 42,
      }) {
    final String? imageUrl =
    entry.profilePictureUrl
        ?.trim();

    final ImageProvider? provider =
    imageUrl != null &&
        imageUrl.isNotEmpty
        ? NetworkImage(imageUrl)
        : null;

    return Container(
      width: size,
      height: size,
      padding:
      const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: entry.isCurrentUser
            ? _blue
            : const Color(
          0xFFE2E8F0,
        ),
      ),
      child: CircleAvatar(
        backgroundColor:
        const Color(
          0xFFE0F2FE,
        ),
        backgroundImage: provider,
        child: provider == null
            ? Text(
          _initials(
            entry.name,
          ),
          style: TextStyle(
            color: _blue,
            fontSize:
            size * 0.27,
            fontWeight:
            FontWeight.w900,
          ),
        )
            : null,
      ),
    );
  }

  String _initials(
      String name,
      ) {
    final List<String> parts =
    name
        .trim()
        .split(
      RegExp(r'\s+'),
    )
        .where(
          (part) =>
      part.isNotEmpty,
    )
        .toList();

    if (parts.isEmpty) {
      return '?';
    }

    return parts
        .take(2)
        .map(
          (part) =>
          part[0]
              .toUpperCase(),
    )
        .join();
  }

  // ============================================================
  // HOME BUTTON
  // Same visual style as HomeScreen
  // ============================================================

  Widget _buildHomeButton() {
    return Padding(
      padding: const EdgeInsets.only(
        top: 10,
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          Navigator.of(context).pop();
        },
        child: Container(
          width: 66,
          height: 66,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [
                _blue,
                _teal,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: Colors.white,
              width: 4,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x3D0284C7),
                blurRadius: 16,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: const Column(
            mainAxisAlignment:
            MainAxisAlignment.center,
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

  // ============================================================
  // BOTTOM NAVIGATION
  // Same structure, notch, spacing and labels as HomeScreen
  // ============================================================

  Widget _buildBottomBar() {
    return BottomAppBar(
      height: 78,
      padding: EdgeInsets.zero,
      color: Colors.white.withOpacity(0.98),
      elevation: 18,
      shadowColor: const Color(
        0x330284C7,
      ),
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: _LeaderboardBottomItem(
                icon:
                Icons.inventory_2_outlined,
                label: 'BLIND BOX',
                onTap: () {
                  _showNavigationMessage(
                    'Blind Box',
                  );
                },
              ),
            ),

            Expanded(
              child: _LeaderboardBottomItem(
                icon:
                Icons.assignment_outlined,
                label: 'MISSIONS',
                onTap: () {
                  _showNavigationMessage(
                    'Missions',
                  );
                },
              ),
            ),

            const SizedBox(
              width: 74,
            ),

            Expanded(
              child: _LeaderboardBottomItem(
                icon:
                Icons.map_outlined,
                label: 'PLAN',
                onTap: () {
                  _showNavigationMessage(
                    'Plan',
                  );
                },
              ),
            ),

            Expanded(
              child: _LeaderboardBottomItem(
                icon:
                Icons.groups_2_outlined,
                label: 'TEAMS',
                onTap: () {
                  _showNavigationMessage(
                    'Teams',
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNavigationMessage(
      String feature,
      ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '$feature is not connected yet.',
          ),
          duration: const Duration(
            milliseconds: 900,
          ),
          behavior:
          SnackBarBehavior.floating,
        ),
      );
  }

}

// ============================================================
// LEADERBOARD ENTRY
// ============================================================

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.name,
    required this.explorationPoints,
    required this.profilePictureUrl,
    required this.isCurrentUser,
  });

  final int rank;
  final String userId;
  final String name;
  final int explorationPoints;
  final String? profilePictureUrl;
  final bool isCurrentUser;
}

// ============================================================
// BOTTOM ITEM
// Same visual style as HomeScreen
// ============================================================

class _LeaderboardBottomItem
    extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _LeaderboardBottomItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    const Color blue = Color(
      0xFF0284C7,
    );

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(
          top: 10,
          bottom: 4,
        ),
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 29,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius:
                BorderRadius.circular(
                  12,
                ),
              ),
              child: Icon(
                icon,
                size: 21,
                color: const Color(
                  0xFF64748B,
                ),
              ),
            ),
            const SizedBox(
              height: 3,
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: const TextStyle(
                  color: Color(
                    0xFF64748B,
                  ),
                  fontSize: 8,
                  fontWeight:
                  FontWeight.w800,
                  letterSpacing: 0.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// HEADER BUTTON
// ============================================================

class _HeaderActionButton
    extends StatelessWidget {
  const _HeaderActionButton({
    required this.tooltip,
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final String tooltip;
  final IconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(
      BuildContext context,
      ) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 38,
        height: 38,
        decoration:
        BoxDecoration(
          color: background,
          shape: BoxShape.circle,
          border: Border.all(
            color:
            foreground.withOpacity(
              0.20,
            ),
          ),
        ),
        child: Icon(
          icon,
          color: foreground,
          size: 20,
        ),
      ),
    );
  }
}
