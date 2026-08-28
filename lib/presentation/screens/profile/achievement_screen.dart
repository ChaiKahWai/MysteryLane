import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';

class AchievementScreen extends StatefulWidget {
  const AchievementScreen({super.key});

  @override
  State<AchievementScreen> createState() => _AchievementScreenState();
}

class _AchievementScreenState extends State<AchievementScreen> {
  static const Color primaryBlue = Color(0xFF0284C7);
  static const Color teal = Color(0xFF0D9488);
  static const Color darkText = Color(0xFF0F172A);
  static const Color greyText = Color(0xFF64748B);
  static const Color pageBackground = Color(0xFFF8FAFC);
  static const Color borderColor = Color(0xFFE2E8F0);

  bool _isLoading = true;
  String? _errorMessage;

  int _explorationPoints = 0;

  List<AchievementViewData> _achievements = [];

  @override
  void initState() {
    super.initState();
    _loadAchievements();
  }

  Future<void> _loadAchievements() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final User? user = SupabaseConfig.client.auth.currentUser;

      if (user == null) {
        throw Exception('No authenticated traveller was found.');
      }

      final Map<String, dynamic>? profile =
      await SupabaseConfig.client
          .from('profiles')
          .select('exploration_points')
          .eq('id', user.id)
          .maybeSingle();

      _explorationPoints =
          _toInt(profile?['exploration_points']);

      final List<dynamic> achievementRows =
      await SupabaseConfig.client
          .from('achievements')
          .select()
          .order('created_at', ascending: true);

      final List<dynamic> userAchievementRows =
      await SupabaseConfig.client
          .from('user_achievements')
          .select()
          .eq('user_id', user.id);

      final Map<String, Map<String, dynamic>> progressByAchievement = {
        for (final dynamic raw in userAchievementRows)
          if (raw is Map<String, dynamic> &&
              raw['achievement_id'] != null)
            raw['achievement_id'].toString(): raw,
      };

      final List<AchievementViewData> built = [];

      for (final dynamic raw in achievementRows) {
        if (raw is! Map<String, dynamic>) {
          continue;
        }

        final String achievementId =
            raw['achievement_id']?.toString() ?? '';

        if (achievementId.isEmpty) {
          continue;
        }

        final Map<String, dynamic>? userProgress =
        progressByAchievement[achievementId];

        final String requirementType =
        (raw['requirement_type']?.toString() ?? '')
            .trim()
            .toLowerCase();

        final int targetValue =
        _toInt(raw['target_value']);

        int currentProgress =
        _toInt(userProgress?['progress_value']);

        // For point-based achievements, use the real
        // profile.exploration_points value automatically.
        if (requirementType == 'exploration_points' ||
            requirementType == 'exploration point' ||
            requirementType == 'points' ||
            requirementType == 'ep') {
          currentProgress = _explorationPoints;
        }

        final bool unlocked =
            targetValue > 0 &&
                currentProgress >= targetValue;

        final String calculatedStatus;

        if (unlocked) {
          calculatedStatus = 'unlocked';
        } else if (currentProgress > 0) {
          calculatedStatus = 'in_progress';
        } else {
          calculatedStatus = 'locked';
        }

        // IMPORTANT:
        // Do not insert/update user_achievements while this page is loading.
        // The UI status is calculated safely from the real progress values.
        // This prevents database CHECK constraints or triggers from breaking
        // the whole Achievement page.
        final String? earnedAt =
        userProgress?['earned_at']?.toString();

        built.add(
          AchievementViewData(
            achievementId: achievementId,
            name:
            raw['name']?.toString() ??
                'Achievement',
            description:
            raw['description']?.toString() ?? '',
            achievementType:
            raw['achievement_type']?.toString() ??
                'Explorer Achievement',
            requirementType: requirementType,
            unlockRequirement:
            raw['unlock_requirement']?.toString() ??
                'Complete the required activity.',
            targetValue: targetValue,
            rewardPoints:
            _toInt(raw['reward_points']),
            termsAndConditions:
            raw['terms_and_conditions']?.toString(),
            repeatable:
            raw['repeatable'] == true,
            imageUrl:
            raw['image_url']?.toString(),
            progressValue: currentProgress,
            status: calculatedStatus,
            earnedAt: earnedAt,
          ),
        );
      }

      if (!mounted) return;

      setState(() {
        _achievements = built;
        _isLoading = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage =
        'Unable to load achievements: ${error.message}';
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage =
        'Unable to load achievements: $error';
      });
    }
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value.toString()) ?? 0;
  }

  List<AchievementViewData> get _mainAchievements {
    return _achievements
        .where(
          (achievement) =>
      achievement.achievementType.toUpperCase() == 'ACHIEVEMENT' &&
          achievement.status != 'in_progress',
    )
        .toList();
  }

  List<AchievementViewData> get _inProgressItems {
    final List<AchievementViewData> items = _achievements
        .where(
          (achievement) => achievement.status == 'in_progress',
    )
        .toList();

    items.sort(
          (a, b) {
        final double aProgress =
        a.targetValue <= 0 ? 0 : a.progressValue / a.targetValue;
        final double bProgress =
        b.targetValue <= 0 ? 0 : b.progressValue / b.targetValue;

        return bProgress.compareTo(aProgress);
      },
    );

    return items;
  }

  List<AchievementViewData> get _badges {
    final List<AchievementViewData> items = _achievements
        .where(
          (achievement) =>
      achievement.achievementType.toUpperCase() == 'BADGE' &&
          achievement.status != 'in_progress',
    )
        .toList();

    items.sort((a, b) {
      int rank(String status) {
        return status == 'unlocked' ? 0 : 1;
      }

      final int statusCompare = rank(a.status).compareTo(rank(b.status));

      if (statusCompare != 0) {
        return statusCompare;
      }

      return a.targetValue.compareTo(b.targetValue);
    });

    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBackground,
      body: SafeArea(
        child:
        _isLoading
            ? const Center(
          child: CircularProgressIndicator(
            color: primaryBlue,
          ),
        )
            : RefreshIndicator(
          color: primaryBlue,
          onRefresh: _loadAchievements,
          child: SingleChildScrollView(
            physics:
            const AlwaysScrollableScrollPhysics(),
            padding:
            const EdgeInsets.fromLTRB(
              26,
              18,
              26,
              36,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints:
                const BoxConstraints(
                  maxWidth: 650,
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .stretch,
                  children: [
                    _buildTopBar(),
                    const SizedBox(height: 24),

                    if (_errorMessage != null)
                      _buildErrorCard()
                    else ...[
                      const Text(
                        'Explorer Achievements',
                        style: TextStyle(
                          color: darkText,
                          fontFamily: 'serif',
                          fontSize: 23,
                          fontWeight:
                          FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'TAP ANY ACHIEVEMENT TO INSPECT UNLOCK REQUIREMENTS 🎯',
                        style: TextStyle(
                          color: primaryBlue,
                          fontSize: 8.5,
                          fontWeight:
                          FontWeight.w900,
                          letterSpacing: 0.9,
                        ),
                      ),
                      const SizedBox(height: 15),

                      if (_mainAchievements.isEmpty)
                        _emptyState(
                          'No locked or unlocked achievements yet.',
                        )
                      else
                        ..._mainAchievements.map(
                              (achievement) =>
                              Padding(
                                padding:
                                const EdgeInsets.only(
                                  bottom: 13,
                                ),
                                child:
                                _buildAchievementCard(
                                  achievement,
                                ),
                              ),
                        ),

                      const SizedBox(height: 14),

                      const Text(
                        'In Progress',
                        style: TextStyle(
                          color: darkText,
                          fontFamily: 'serif',
                          fontSize: 23,
                          fontWeight:
                          FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 13),

                      if (_inProgressItems
                          .isEmpty)
                        _emptyState(
                          'No achievements currently in progress.',
                        )
                      else
                        ..._inProgressItems.map(
                              (achievement) =>
                              Padding(
                                padding:
                                const EdgeInsets.only(
                                  bottom: 13,
                                ),
                                child:
                                _buildInProgressCard(
                                  achievement,
                                ),
                              ),
                        ),

                      const SizedBox(height: 18),

                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Explorer Badges',
                              style: TextStyle(
                                color: darkText,
                                fontFamily: 'serif',
                                fontSize: 23,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(
                                color: const Color(0xFFFDE68A),
                              ),
                            ),
                            child: Text(
                              '${_badges.where((badge) => badge.status == 'unlocked').length}/${_badges.length}',
                              style: const TextStyle(
                                color: Color(0xFFD97706),
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'COLLECT BADGES BY REACHING SPECIAL EXPLORATION MILESTONES',
                        style: TextStyle(
                          color: primaryBlue,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 13),

                      if (_badges.isEmpty)
                        _emptyState(
                          'No badges are available yet.',
                        )
                      else
                        ..._badges.map(
                              (badge) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: 12,
                            ),
                            child: _buildBadgeCard(badge),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        InkWell(
          customBorder: const CircleBorder(),
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: borderColor,
              ),
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              color: darkText,
              size: 21,
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          'Achievements',
          style: TextStyle(
            color: darkText,
            fontFamily: 'serif',
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFECACA),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFDC2626),
            size: 32,
          ),
          const SizedBox(height: 10),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF991B1B),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _loadAchievements,
            child: const Text('TRY AGAIN'),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String text) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: greyText,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildAchievementCard(
      AchievementViewData achievement,
      ) {
    final bool unlocked =
        achievement.status == 'unlocked';

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap:
            () => _showAchievementDetail(
          achievement,
        ),
        child: SizedBox(
          height: 129,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _achievementBackground(
                achievement,
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x120F172A),
                      Color(0x660F172A),
                      Color(0xE60F172A),
                    ],
                    stops: [0.0, 0.48, 1.0],
                  ),
                ),
              ),
              Positioned(
                top: 11,
                right: 12,
                child: _statusBadge(
                  achievement.status,
                ),
              ),
              Positioned(
                left: 15,
                right: 15,
                bottom: 12,
                child: Row(
                  crossAxisAlignment:
                  CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        mainAxisSize:
                        MainAxisSize.min,
                        children: [
                          Text(
                            _displayCategory(achievement),
                            style: const TextStyle(
                              color:
                              Color(0xFFBAE6FD),
                              fontSize: 8,
                              height: 1.1,
                              fontWeight:
                              FontWeight.w900,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            achievement.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'serif',
                              fontSize: 19,
                              height: 1.0,
                              fontWeight:
                              FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            unlocked
                                ? (achievement.earnedAt == null || achievement.earnedAt!.trim().isEmpty
                                ? 'Requirement completed'
                                : 'Earned ${_formatDate(achievement.earnedAt)}')
                                : 'Requirement: ${achievement.unlockRequirement}',
                            maxLines: 1,
                            overflow:
                            TextOverflow.ellipsis,
                            style: const TextStyle(
                              color:
                              Color(0xFFE2E8F0),
                              fontSize: 8.5,
                              fontWeight:
                              FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _epBadge(
                      achievement.rewardPoints,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final String normalized = status.trim().toLowerCase();

    late final String label;
    late final Color backgroundColor;
    late final Color textColor;
    late final IconData icon;

    switch (normalized) {
      case 'unlocked':
        label = 'UNLOCKED';
        backgroundColor = const Color(0xFFDCFCE7);
        textColor = const Color(0xFF15803D);
        icon = Icons.lock_open_rounded;
        break;
      case 'in_progress':
        label = 'IN PROGRESS';
        backgroundColor = const Color(0xFFDBEAFE);
        textColor = const Color(0xFF1D4ED8);
        icon = Icons.timelapse_rounded;
        break;
      default:
        label = 'LOCKED';
        backgroundColor = const Color(0xFFE2E8F0);
        textColor = const Color(0xFF475569);
        icon = Icons.lock_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: textColor.withOpacity(0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 11,
            color: textColor,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 7.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _epBadge(int rewardPoints) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: const Color(0xFFFED7AA),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.bolt_rounded,
            color: Color(0xFFEA580C),
            size: 11,
          ),
          const SizedBox(width: 3),
          Text(
            '+$rewardPoints EP',
            style: const TextStyle(
              color: Color(0xFFEA580C),
              fontSize: 7.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.25,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInProgressCard(
      AchievementViewData achievement,
      ) {
    final double progress =
    achievement.targetValue <= 0
        ? 0
        : (achievement.progressValue /
        achievement.targetValue)
        .clamp(0.0, 1.0);

    final int remaining =
    (achievement.targetValue -
        achievement.progressValue)
        .clamp(0, achievement.targetValue);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap:
            () => _showAchievementDetail(
          achievement,
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius:
            BorderRadius.circular(17),
            border: Border.all(
              color: borderColor,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A0F172A),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color:
                      const Color(0xFFF0F9FF),
                      borderRadius:
                      BorderRadius.circular(12),
                      border: Border.all(
                        color:
                        const Color(0xFFBAE6FD),
                      ),
                    ),
                    child: Icon(
                      achievement.achievementType.toUpperCase() == 'BADGE'
                          ? Icons.military_tech_outlined
                          : Icons.emoji_events_outlined,
                      color: primaryBlue,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          achievement.achievementType.toUpperCase() == 'BADGE'
                              ? 'BADGE'
                              : 'ACHIEVEMENT',
                          style: const TextStyle(
                            color: primaryBlue,
                            fontSize: 7.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.7,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                achievement.name,
                                style:
                                const TextStyle(
                                  color: darkText,
                                  fontFamily:
                                  'serif',
                                  fontSize: 16,
                                  fontWeight:
                                  FontWeight
                                      .w900,
                                ),
                              ),
                            ),
                            Text(
                              '${achievement.progressValue}/${achievement.targetValue}',
                              style:
                              const TextStyle(
                                color:
                                Color(
                                  0xFF94A3B8,
                                ),
                                fontSize: 10,
                                fontWeight:
                                FontWeight
                                    .w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          achievement
                              .unlockRequirement,
                          maxLines: 2,
                          overflow:
                          TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: greyText,
                            fontSize: 10.5,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$remaining more needed to unlock',
                          style: const TextStyle(
                            color: primaryBlue,
                            fontSize: 8.5,
                            fontWeight:
                            FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius:
                BorderRadius.circular(99),
                child: SizedBox(
                  height: 8,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const ColoredBox(
                        color: Color(0xFFF1F5F9),
                      ),
                      FractionallySizedBox(
                        alignment:
                        Alignment.centerLeft,
                        widthFactor: progress,
                        child:
                        const DecoratedBox(
                          decoration:
                          BoxDecoration(
                            gradient:
                            LinearGradient(
                              colors: [
                                primaryBlue,
                                teal,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadgeCard(
      AchievementViewData badge,
      ) {
    final bool unlocked = badge.status == 'unlocked';
    final bool inProgress = badge.status == 'in_progress';

    final double progress =
    badge.targetValue <= 0
        ? 0
        : (badge.progressValue / badge.targetValue)
        .clamp(0.0, 1.0);

    final int remaining =
    (badge.targetValue - badge.progressValue)
        .clamp(0, badge.targetValue);

    final Color accent =
    unlocked
        ? const Color(0xFFD97706)
        : inProgress
        ? primaryBlue
        : const Color(0xFF64748B);

    final Color background =
    unlocked
        ? const Color(0xFFFFFBEB)
        : inProgress
        ? const Color(0xFFF0F9FF)
        : const Color(0xFFF8FAFC);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => _showAchievementDetail(badge),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: unlocked
                  ? const Color(0xFFFDE68A)
                  : inProgress
                  ? const Color(0xFFBAE6FD)
                  : borderColor,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: background,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: accent.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Icon(
                      unlocked
                          ? Icons.workspace_premium_rounded
                          : inProgress
                          ? Icons.military_tech_outlined
                          : Icons.lock_outline_rounded,
                      color: accent,
                      size: 29,
                    ),
                  ),
                  if (unlocked)
                    Positioned(
                      right: -2,
                      bottom: -1,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            badge.name,
                            style: const TextStyle(
                              color: darkText,
                              fontFamily: 'serif',
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _badgeSmallStatus(badge.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      badge.unlockRequirement,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: greyText,
                        fontSize: 10.5,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Text(
                          '+${badge.rewardPoints} EP',
                          style: TextStyle(
                            color: accent,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Spacer(),
                        if (!unlocked)
                          Text(
                            '${badge.progressValue}/${badge.targetValue}',
                            style: const TextStyle(
                              color: greyText,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          )
                        else
                          Text(
                            badge.earnedAt == null
                                ? 'COMPLETED'
                                : _formatDate(badge.earnedAt).toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                      ],
                    ),
                    if (!unlocked) ...[
                      const SizedBox(height: 7),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: SizedBox(
                          height: 6,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              const ColoredBox(
                                color: Color(0xFFF1F5F9),
                              ),
                              FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: progress,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        accent,
                                        inProgress ? teal : accent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        badge.progressValue == 0
                            ? 'Tap to view how to unlock this badge.'
                            : '$remaining more needed to unlock.',
                        style: const TextStyle(
                          color: greyText,
                          fontSize: 8.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Padding(
                padding: EdgeInsets.only(top: 18),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badgeSmallStatus(String status) {
    final bool unlocked = status == 'unlocked';
    final bool inProgress = status == 'in_progress';

    final Color color =
    unlocked
        ? const Color(0xFF059669)
        : inProgress
        ? primaryBlue
        : const Color(0xFF64748B);

    final Color background =
    unlocked
        ? const Color(0xFFECFDF5)
        : inProgress
        ? const Color(0xFFE0F2FE)
        : const Color(0xFFF1F5F9);

    final String label =
    unlocked
        ? 'EARNED'
        : inProgress
        ? 'IN PROGRESS'
        : 'LOCKED';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 7,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.25,
        ),
      ),
    );
  }

  Widget _achievementBackground(
      AchievementViewData achievement,
      ) {
    final String? imageUrl =
    _achievementBackgroundUrl(achievement);

    final List<Color> themeColors =
    _achievementThemeColors(achievement);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background images are now controlled by Supabase only.
        // No achievement image URL is hardcoded in this Dart file.
        if (imageUrl != null)
          Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) {
              return _achievementFallbackBackground(
                achievement,
                themeColors,
              );
            },
          )
        else
          _achievementFallbackBackground(
            achievement,
            themeColors,
          ),

        // Dark overlay keeps white text readable on any Supabase image.
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                const Color(0xFF07111F).withOpacity(0.78),
                const Color(0xFF07111F).withOpacity(0.43),
                const Color(0xFF07111F).withOpacity(0.22),
              ],
              stops: const [0.0, 0.58, 1.0],
            ),
          ),
        ),

        // Locked items remain visibly darker.
        if (achievement.status == 'locked')
          Container(
            color: const Color(0xFF0F172A).withOpacity(0.34),
          ),
      ],
    );
  }

  Widget _achievementFallbackBackground(
      AchievementViewData achievement,
      List<Color> themeColors,
      ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: themeColors,
        ),
      ),
      child: Center(
        child: Icon(
          _achievementThemeIcon(achievement),
          size: 70,
          color: Colors.white.withOpacity(0.18),
        ),
      ),
    );
  }

  String? _achievementBackgroundUrl(
      AchievementViewData achievement,
      ) {
    final String? databaseImage =
    achievement.imageUrl?.trim();

    // Supabase is the single source of truth for achievement images.
    // If image_url is null/empty, the UI uses the gradient fallback.
    if (databaseImage == null ||
        databaseImage.isEmpty) {
      return null;
    }

    return databaseImage;
  }

  List<Color> _achievementThemeColors(
      AchievementViewData achievement,
      ) {
    final String key = [
      achievement.name,
      achievement.requirementType,
      achievement.unlockRequirement,
      achievement.achievementType,
    ].join(' ').toLowerCase();

    if (key.contains('histor') ||
        key.contains('heritage') ||
        key.contains('codex')) {
      return const [
        Color(0xFF7C2D12),
        Color(0xFFB45309),
        Color(0xFFF59E0B),
      ];
    }

    if (key.contains('night') ||
        key.contains('after 8') ||
        key.contains('dark')) {
      return const [
        Color(0xFF312E81),
        Color(0xFF4338CA),
        Color(0xFF0F172A),
      ];
    }

    if (key.contains('north') ||
        key.contains('compass') ||
        key.contains('navigation') ||
        key.contains('checkpoint')) {
      return const [
        Color(0xFF0F766E),
        Color(0xFF0891B2),
        Color(0xFF0369A1),
      ];
    }

    if (key.contains('code') ||
        key.contains('riddle') ||
        key.contains('puzzle')) {
      return const [
        Color(0xFF581C87),
        Color(0xFF7E22CE),
        Color(0xFFDB2777),
      ];
    }

    if (key.contains('blind') ||
        key.contains('mystery') ||
        key.contains('box')) {
      return const [
        Color(0xFF9F1239),
        Color(0xFFE11D48),
        Color(0xFFF97316),
      ];
    }

    if (key.contains('mission')) {
      return const [
        Color(0xFF1D4ED8),
        Color(0xFF2563EB),
        Color(0xFF06B6D4),
      ];
    }

    if (key.contains('cafe') ||
        key.contains('coffee')) {
      return const [
        Color(0xFF78350F),
        Color(0xFFA16207),
        Color(0xFFD97706),
      ];
    }

    if (key.contains('photo') ||
        key.contains('shutter') ||
        key.contains('camera')) {
      return const [
        Color(0xFF0F766E),
        Color(0xFF14B8A6),
        Color(0xFF22C55E),
      ];
    }

    if (key.contains('exploration_points') ||
        key.contains('exploration points') ||
        key.contains('explorer')) {
      return const [
        Color(0xFF1E3A8A),
        Color(0xFF2563EB),
        Color(0xFF14B8A6),
      ];
    }

    if (achievement.achievementType.toUpperCase() ==
        'BADGE') {
      return const [
        Color(0xFF92400E),
        Color(0xFFF59E0B),
        Color(0xFFF97316),
      ];
    }

    final int seed =
    achievement.name.codeUnits.fold<int>(
      0,
          (sum, value) => sum + value,
    );

    final List<List<Color>> palettes = [
      const [
        Color(0xFF1E40AF),
        Color(0xFF2563EB),
        Color(0xFF0891B2),
      ],
      const [
        Color(0xFF065F46),
        Color(0xFF059669),
        Color(0xFF0D9488),
      ],
      const [
        Color(0xFF6B21A8),
        Color(0xFF9333EA),
        Color(0xFFDB2777),
      ],
      const [
        Color(0xFF9A3412),
        Color(0xFFEA580C),
        Color(0xFFF59E0B),
      ],
      const [
        Color(0xFF334155),
        Color(0xFF475569),
        Color(0xFF0F172A),
      ],
    ];

    return palettes[seed % palettes.length];
  }

  IconData _achievementThemeIcon(
      AchievementViewData achievement,
      ) {
    final String key = [
      achievement.name,
      achievement.requirementType,
      achievement.unlockRequirement,
    ].join(' ').toLowerCase();

    if (key.contains('histor') ||
        key.contains('heritage') ||
        key.contains('codex')) {
      return Icons.menu_book_rounded;
    }

    if (key.contains('night') ||
        key.contains('dark')) {
      return Icons.nightlight_round;
    }

    if (key.contains('north') ||
        key.contains('compass') ||
        key.contains('navigation')) {
      return Icons.explore_rounded;
    }

    if (key.contains('checkpoint')) {
      return Icons.location_on_rounded;
    }

    if (key.contains('code') ||
        key.contains('riddle') ||
        key.contains('puzzle')) {
      return Icons.extension_rounded;
    }

    if (key.contains('blind') ||
        key.contains('mystery') ||
        key.contains('box')) {
      return Icons.redeem_rounded;
    }

    if (key.contains('mission')) {
      return Icons.flag_rounded;
    }

    if (key.contains('cafe') ||
        key.contains('coffee')) {
      return Icons.local_cafe_rounded;
    }

    if (key.contains('photo') ||
        key.contains('shutter') ||
        key.contains('camera')) {
      return Icons.photo_camera_rounded;
    }

    if (achievement.achievementType.toUpperCase() ==
        'BADGE') {
      return Icons.workspace_premium_rounded;
    }

    return Icons.auto_awesome_rounded;
  }

  Future<void> _showAchievementDetail(
      AchievementViewData achievement,
      ) async {
    await showDialog<void>(
      context: context,
      barrierColor:
      const Color(0xB30F172A),
      builder: (dialogContext) {
        final double maxHeight =
            MediaQuery.of(
              dialogContext,
            ).size.height *
                0.86;

        final int remaining =
        (achievement.targetValue -
            achievement
                .progressValue)
            .clamp(
          0,
          achievement.targetValue,
        );

        return Dialog(
          insetPadding:
          const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 24,
          ),
          backgroundColor:
          Colors.transparent,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 385,
              maxHeight: maxHeight,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: pageBackground,
                borderRadius:
                BorderRadius.circular(25),
                border: Border.all(
                  color: borderColor,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x55000000),
                    blurRadius: 30,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child:
              SingleChildScrollView(
                child: Column(
                  mainAxisSize:
                  MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 177,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _achievementBackground(
                            achievement,
                          ),
                          const DecoratedBox(
                            decoration:
                            BoxDecoration(
                              gradient:
                              LinearGradient(
                                begin:
                                Alignment
                                    .topCenter,
                                end:
                                Alignment
                                    .bottomCenter,
                                colors: [
                                  Color(
                                    0x160F172A,
                                  ),
                                  Color(
                                    0x660F172A,
                                  ),
                                  Color(
                                    0xF00F172A,
                                  ),
                                ],
                                stops: [
                                  0,
                                  0.50,
                                  1,
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 13,
                            left: 13,
                            child: Container(
                              padding:
                              const EdgeInsets.symmetric(
                                horizontal:
                                10,
                                vertical:
                                6,
                              ),
                              decoration: BoxDecoration(
                                color:
                                const Color(
                                  0xCC1E293B,
                                ),
                                borderRadius:
                                BorderRadius.circular(
                                  99,
                                ),
                              ),
                              child: Text(
                                _displayCategory(achievement),
                                style:
                                const TextStyle(
                                  color:
                                  Color(
                                    0xFFBAE6FD,
                                  ),
                                  fontSize:
                                  8,
                                  fontWeight:
                                  FontWeight
                                      .w900,
                                  letterSpacing:
                                  0.7,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 12,
                            right: 12,
                            child: InkWell(
                              customBorder:
                              const CircleBorder(),
                              onTap:
                                  () => Navigator.pop(
                                dialogContext,
                              ),
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration:
                                const BoxDecoration(
                                  color:
                                  Color(
                                    0xAA1E293B,
                                  ),
                                  shape:
                                  BoxShape
                                      .circle,
                                ),
                                child:
                                const Icon(
                                  Icons
                                      .close_rounded,
                                  color:
                                  Colors
                                      .white,
                                  size: 19,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 15,
                            right: 15,
                            bottom: 12,
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                              children: [
                                Row(
                                  children: [
                                    _statusBadge(
                                      achievement
                                          .status,
                                    ),
                                    const SizedBox(
                                      width: 6,
                                    ),
                                    _epBadge(
                                      achievement
                                          .rewardPoints,
                                    ),
                                  ],
                                ),
                                const SizedBox(
                                  height: 5,
                                ),
                                Text(
                                  achievement
                                      .name,
                                  style:
                                  const TextStyle(
                                    color:
                                    Colors
                                        .white,
                                    fontFamily:
                                    'serif',
                                    fontSize:
                                    25,
                                    height:
                                    1.0,
                                    fontWeight:
                                    FontWeight
                                        .w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding:
                      const EdgeInsets.fromLTRB(
                        20,
                        20,
                        20,
                        19,
                      ),
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment
                            .stretch,
                        children: [
                          Text(
                            achievement
                                .description,
                            style:
                            const TextStyle(
                              color:
                              greyText,
                              fontSize: 12,
                              height: 1.55,
                            ),
                          ),
                          const SizedBox(
                            height: 18,
                          ),
                          Container(
                            padding:
                            const EdgeInsets.all(
                              15,
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
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.adjust_rounded,
                                      color: Color(0xFFEA580C),
                                      size: 17,
                                    ),
                                    const SizedBox(
                                      width: 7,
                                    ),
                                    Text(
                                      achievement.achievementType
                                          .toUpperCase() ==
                                          'BADGE'
                                          ? 'BADGE REQUIREMENT'
                                          : 'UNLOCK REQUIREMENT',
                                      style: const TextStyle(
                                        color: primaryBlue,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(
                                  height: 10,
                                ),
                                Container(
                                  width:
                                  double.infinity,
                                  padding:
                                  const EdgeInsets.all(
                                    13,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                    Colors.white,
                                    borderRadius:
                                    BorderRadius.circular(
                                      12,
                                    ),
                                    border:
                                    Border.all(
                                      color:
                                      borderColor,
                                    ),
                                  ),
                                  child: Text(
                                    achievement
                                        .unlockRequirement,
                                    style:
                                    const TextStyle(
                                      color:
                                      darkText,
                                      fontSize:
                                      11,
                                      height:
                                      1.55,
                                      fontWeight:
                                      FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          if (achievement.status ==
                              'in_progress') ...[
                            const SizedBox(
                              height: 15,
                            ),
                            _detailProgress(
                              achievement,
                              remaining,
                            ),
                          ],

                          const SizedBox(
                            height: 15,
                          ),

                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  achievement
                                      .status ==
                                      'unlocked'
                                      ? (achievement.earnedAt == null || achievement.earnedAt!.trim().isEmpty
                                      ? 'Requirement completed'
                                      : 'Unlocked on ${_formatDate(achievement.earnedAt)}')
                                      : achievement
                                      .status ==
                                      'in_progress'
                                      ? '$remaining more needed'
                                      : '🔒 Requirement not started',
                                  style:
                                  const TextStyle(
                                    color:
                                    greyText,
                                    fontSize:
                                    8.5,
                                    fontWeight:
                                    FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                'Reward: +${achievement.rewardPoints} EP',
                                style:
                                const TextStyle(
                                  color:
                                  primaryBlue,
                                  fontSize:
                                  8.5,
                                  fontWeight:
                                  FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(
                            height: 18,
                          ),
                          SizedBox(
                            height: 48,
                            child: FilledButton(
                              onPressed:
                                  () => Navigator.pop(
                                dialogContext,
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor:
                                primaryBlue,
                                foregroundColor:
                                Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(
                                    12,
                                  ),
                                ),
                              ),
                              child:
                              const Text(
                                'GOT IT',
                                style:
                                TextStyle(
                                  fontSize:
                                  11,
                                  fontWeight:
                                  FontWeight.w900,
                                  letterSpacing:
                                  2.0,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _detailProgress(
      AchievementViewData achievement,
      int remaining,
      ) {
    final double progress =
    achievement.targetValue <= 0
        ? 0
        : (achievement.progressValue /
        achievement.targetValue)
        .clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(14),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'YOUR PROGRESS',
                style: TextStyle(
                  color: darkText,
                  fontSize: 9,
                  fontWeight:
                  FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                '${achievement.progressValue}/${achievement.targetValue}',
                style: const TextStyle(
                  color: primaryBlue,
                  fontSize: 10,
                  fontWeight:
                  FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius:
            BorderRadius.circular(99),
            child: SizedBox(
              height: 8,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(
                    color:
                    Color(0xFFF1F5F9),
                  ),
                  FractionallySizedBox(
                    alignment:
                    Alignment.centerLeft,
                    widthFactor: progress,
                    child:
                    const DecoratedBox(
                      decoration:
                      BoxDecoration(
                        gradient:
                        LinearGradient(
                          colors: [
                            primaryBlue,
                            teal,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$remaining more required to unlock this achievement.',
            style: const TextStyle(
              color: greyText,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  String _displayCategory(
      AchievementViewData achievement,
      ) {
    if (achievement.achievementType.toUpperCase() == 'BADGE') {
      return 'EXPLORER BADGE';
    }

    switch (achievement.name.trim().toLowerCase()) {
      case 'novice historian':
        return 'CODEX OF ELDORIA';
      case 'night walker':
        return 'CITY EXPLORER';
      case 'true north':
        return 'COMPASS NAVIGATION';
      case 'cryptic codebreaker':
        return 'RIDDLE MASTER';
      case 'blind box connoisseur':
        return 'MYSTERY WANDERER';
      default:
        return achievement.achievementType.toUpperCase();
    }
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null ||
        isoDate.trim().isEmpty) {
      return '-';
    }

    final DateTime? date =
    DateTime.tryParse(isoDate);

    if (date == null) {
      return isoDate;
    }

    const List<String> months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${months[date.month - 1]} '
        '${date.day.toString().padLeft(2, '0')}, '
        '${date.year}';
  }
}

class AchievementViewData {
  final String achievementId;
  final String name;
  final String description;
  final String achievementType;
  final String requirementType;
  final String unlockRequirement;
  final int targetValue;
  final int rewardPoints;
  final String? termsAndConditions;
  final bool repeatable;
  final String? imageUrl;
  final int progressValue;
  final String status;
  final String? earnedAt;

  const AchievementViewData({
    required this.achievementId,
    required this.name,
    required this.description,
    required this.achievementType,
    required this.requirementType,
    required this.unlockRequirement,
    required this.targetValue,
    required this.rewardPoints,
    required this.termsAndConditions,
    required this.repeatable,
    required this.imageUrl,
    required this.progressValue,
    required this.status,
    required this.earnedAt,
  });
}
