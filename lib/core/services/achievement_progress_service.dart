import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

/// Keeps user_achievements.progress_value in sync when the traveller
/// completes an activity.
///
/// Supported requirement_type values:
/// - exploration_points
/// - mission_count
/// - checkpoint_count
/// - blind_box_count
///
/// Use the increment methods at the exact point where an activity is
/// successfully completed. The Achievement screen then automatically
/// shows LOCKED / IN PROGRESS / UNLOCKED from the stored progress.
class AchievementProgressService {
  AchievementProgressService._();

  static Future<void> addMissionCompleted({
    int amount = 1,
  }) async {
    await _incrementRequirement(
      requirementType: 'mission_count',
      amount: amount,
    );
  }

  static Future<void> addCheckpointCompleted({
    int amount = 1,
  }) async {
    await _incrementRequirement(
      requirementType: 'checkpoint_count',
      amount: amount,
    );
  }

  static Future<void> addBlindBoxCompleted({
    int amount = 1,
  }) async {
    await _incrementRequirement(
      requirementType: 'blind_box_count',
      amount: amount,
    );
  }

  static Future<void> syncExplorationPoints(
      int explorationPoints,
      ) async {
    await _setRequirementProgress(
      requirementType: 'exploration_points',
      progressValue: explorationPoints,
    );
  }

  static Future<void> _incrementRequirement({
    required String requirementType,
    required int amount,
  }) async {
    if (amount <= 0) return;

    final User? user =
        SupabaseConfig.client.auth.currentUser;

    if (user == null) {
      throw Exception(
        'No authenticated traveller was found.',
      );
    }

    final List<dynamic> rows =
    await SupabaseConfig.client
        .from('achievements')
        .select(
      'achievement_id, target_value',
    )
        .eq(
      'requirement_type',
      requirementType,
    );

    for (final dynamic raw in rows) {
      if (raw is! Map<String, dynamic>) {
        continue;
      }

      final String achievementId =
          raw['achievement_id']?.toString() ?? '';

      if (achievementId.isEmpty) {
        continue;
      }

      final int targetValue =
      _toInt(raw['target_value']);

      final Map<String, dynamic>? existing =
      await SupabaseConfig.client
          .from('user_achievements')
          .select(
        'user_achievement_id, progress_value, status, earned_at',
      )
          .eq(
        'user_id',
        user.id,
      )
          .eq(
        'achievement_id',
        achievementId,
      )
          .maybeSingle();

      final int oldProgress =
      _toInt(existing?['progress_value']);

      final int newProgress =
          oldProgress + amount;

      await _saveProgress(
        userId: user.id,
        achievementId: achievementId,
        progressValue: newProgress,
        targetValue: targetValue,
        existing: existing,
      );
    }
  }

  static Future<void> _setRequirementProgress({
    required String requirementType,
    required int progressValue,
  }) async {
    final User? user =
        SupabaseConfig.client.auth.currentUser;

    if (user == null) {
      throw Exception(
        'No authenticated traveller was found.',
      );
    }

    final List<dynamic> rows =
    await SupabaseConfig.client
        .from('achievements')
        .select(
      'achievement_id, target_value',
    )
        .eq(
      'requirement_type',
      requirementType,
    );

    for (final dynamic raw in rows) {
      if (raw is! Map<String, dynamic>) {
        continue;
      }

      final String achievementId =
          raw['achievement_id']?.toString() ?? '';

      if (achievementId.isEmpty) {
        continue;
      }

      final int targetValue =
      _toInt(raw['target_value']);

      final Map<String, dynamic>? existing =
      await SupabaseConfig.client
          .from('user_achievements')
          .select(
        'user_achievement_id, progress_value, status, earned_at',
      )
          .eq(
        'user_id',
        user.id,
      )
          .eq(
        'achievement_id',
        achievementId,
      )
          .maybeSingle();

      await _saveProgress(
        userId: user.id,
        achievementId: achievementId,
        progressValue: progressValue,
        targetValue: targetValue,
        existing: existing,
      );
    }
  }

  static Future<void> _saveProgress({
    required String userId,
    required String achievementId,
    required int progressValue,
    required int targetValue,
    required Map<String, dynamic>? existing,
  }) async {
    final int safeProgress =
    progressValue < 0 ? 0 : progressValue;

    final String status;

    if (targetValue > 0 &&
        safeProgress >= targetValue) {
      status = 'unlocked';
    } else if (safeProgress > 0) {
      status = 'in_progress';
    } else {
      status = 'locked';
    }

    final String? existingEarnedAt =
    existing?['earned_at']?.toString();

    final Map<String, dynamic> values = {
      'progress_value': safeProgress,
      'status': status,
      'updated_at':
      DateTime.now().toIso8601String(),
    };

    if (status == 'unlocked' &&
        (existingEarnedAt == null ||
            existingEarnedAt.isEmpty)) {
      values['earned_at'] =
          DateTime.now().toIso8601String();
    }

    if (existing != null &&
        existing['user_achievement_id'] != null) {
      await SupabaseConfig.client
          .from('user_achievements')
          .update(values)
          .eq(
        'user_achievement_id',
        existing['user_achievement_id'],
      );

      return;
    }

    await SupabaseConfig.client
        .from('user_achievements')
        .insert({
      'user_id': userId,
      'achievement_id': achievementId,
      ...values,
    });
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;

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
}
