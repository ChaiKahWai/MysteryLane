import 'package:flutter/foundation.dart';

import '../../core/config/supabase_config.dart';
import '../models/checkpoint_destination.dart';
import '../models/checkpoint_mission.dart';

class CheckpointRepository {
  // ============================================================
  // LOAD CURATED HIDDEN-GEM DESTINATIONS
  // ============================================================

  Future<List<CheckpointDestination>>
  getHiddenGemDestinations() async {
    try {
      final List<dynamic> response =
      await SupabaseConfig.client
          .from('blind_box_destinations')
          .select()
          .eq(
        'destination_source',
        'CURATED',
      )
          .eq(
        'popularity_classification',
        'LESS_POPULAR',
      )
          .order(
        'created_at',
        ascending: false,
      );

      return response.map(
            (dynamic item) {
          return CheckpointDestination.fromJson(
            Map<String, dynamic>.from(
              item as Map,
            ),
          );
        },
      ).toList();
    } catch (error) {
      debugPrint(
        'LOAD DESTINATION ERROR: $error',
      );

      throw Exception(
        'Unable to load checkpoint destinations.',
      );
    }
  }

  // ============================================================
  // GET MISSION BY DESTINATION
  // ============================================================

  Future<CheckpointMission?>
  getMissionByDestinationId(
      String destinationId,
      ) async {
    try {
      debugPrint(
        'QUERY MISSION destination_id = $destinationId',
      );

      final List<dynamic> response =
      await SupabaseConfig.client
          .from('checkpoint_missions')
          .select()
          .eq(
        'destination_id',
        destinationId,
      )
          .eq(
        'is_active',
        true,
      );

      debugPrint(
        'MISSION QUERY RESPONSE: $response',
      );

      if (response.isEmpty) {
        return null;
      }

      return CheckpointMission.fromJson(
        Map<String, dynamic>.from(
          response.first as Map,
        ),
      );
    } catch (error) {
      debugPrint(
        'MISSION LOAD ERROR: $error',
      );

      throw Exception(
        'Unable to load checkpoint mission.',
      );
    }
  }

  // ============================================================
  // START USER MISSION
  // ============================================================

  Future<String> startUserMission({
    required String missionId,
  }) async {
    final user =
        SupabaseConfig.client.auth.currentUser;

    if (user == null) {
      throw Exception(
        'Traveller is not logged in.',
      );
    }

    try {
      final Map<String, dynamic>? existing =
      await SupabaseConfig.client
          .from(
        'user_checkpoint_missions',
      )
          .select()
          .eq(
        'user_id',
        user.id,
      )
          .eq(
        'mission_id',
        missionId,
      )
          .maybeSingle();

      // ========================================================
      // EXISTING MISSION
      // ========================================================

      if (existing != null) {
        final String status =
            existing['mission_status']
                ?.toString() ??
                'NOT_STARTED';

        if (status == 'COMPLETED') {
          throw Exception(
            'You have already completed this mission.',
          );
        }

        final String userMissionId =
        existing['user_mission_id']
            .toString();

        await SupabaseConfig.client
            .from(
          'user_checkpoint_missions',
        )
            .update({
          'mission_status':
          'IN_PROGRESS',

          'verification_result':
          'PENDING',

          'started_at':
          DateTime.now()
              .toUtc()
              .toIso8601String(),
        }).eq(
          'user_mission_id',
          userMissionId,
        );

        debugPrint(
          'EXISTING MISSION STARTED: '
              '$userMissionId',
        );

        return userMissionId;
      }

      // ========================================================
      // CREATE NEW USER MISSION
      // ========================================================

      final Map<String, dynamic> created =
      await SupabaseConfig.client
          .from(
        'user_checkpoint_missions',
      )
          .insert({
        'user_id':
        user.id,

        'mission_id':
        missionId,

        'mission_status':
        'IN_PROGRESS',

        'verification_result':
        'PENDING',

        'reward_claimed':
        false,

        'started_at':
        DateTime.now()
            .toUtc()
            .toIso8601String(),
      })
          .select()
          .single();

      final String userMissionId =
      created['user_mission_id']
          .toString();

      debugPrint(
        'NEW USER MISSION CREATED: '
            '$userMissionId',
      );

      return userMissionId;
    } catch (error) {
      debugPrint(
        'START MISSION ERROR: $error',
      );

      rethrow;
    }
  }

  // ============================================================
  // COMPLETE MISSION
  //
  // TEMPORARY:
  // Gemini verification will later replace automatic VERIFIED.
  //
  // IMPORTANT:
  // - Reward points only once
  // - Point transaction only once
  // - Journey history only once
  // - Missing records can be repaired automatically
  // ============================================================

  Future<int> completeMissionForTesting({
    required String userMissionId,
    required String missionId,
    required String destinationId,
    required int rewardPoints,
  }) async {
    final user =
        SupabaseConfig.client.auth.currentUser;

    if (user == null) {
      throw Exception(
        'Traveller is not logged in.',
      );
    }

    try {
      debugPrint(
        '=====================================',
      );

      debugPrint(
        'COMPLETE MISSION START',
      );

      debugPrint(
        'USER MISSION ID: $userMissionId',
      );

      debugPrint(
        'MISSION ID: $missionId',
      );

      // ========================================================
      // 1. GET USER MISSION
      // ========================================================

      final Map<String, dynamic> userMission =
      await SupabaseConfig.client
          .from(
        'user_checkpoint_missions',
      )
          .select()
          .eq(
        'user_mission_id',
        userMissionId,
      )
          .eq(
        'user_id',
        user.id,
      )
          .single();

      final bool rewardAlreadyClaimed =
          userMission['reward_claimed']
          as bool? ??
              false;

      debugPrint(
        'REWARD ALREADY CLAIMED: '
            '$rewardAlreadyClaimed',
      );

      // ========================================================
      // 2. GET CURRENT POINTS
      // ========================================================

      final Map<String, dynamic> profile =
      await SupabaseConfig.client
          .from('profiles')
          .select(
        'exploration_points',
      )
          .eq(
        'id',
        user.id,
      )
          .single();

      int currentPoints =
      _toInt(
        profile['exploration_points'],
      );

      debugPrint(
        'CURRENT POINTS: $currentPoints',
      );

      // ========================================================
      // 3. AWARD POINTS ONLY IF NOT CLAIMED
      // ========================================================

      if (!rewardAlreadyClaimed) {
        final int newTotal =
            currentPoints +
                rewardPoints;

        // ------------------------------------------------------
        // MARK MISSION COMPLETED
        // ------------------------------------------------------

        await SupabaseConfig.client
            .from('user_checkpoint_missions')
            .update({
          'mission_status':
          'COMPLETED',

          'reward_claimed':
          true,

          'completed_at':
          DateTime.now()
              .toUtc()
              .toIso8601String(),
        }).eq(
          'user_mission_id',
          userMissionId,
        );

        debugPrint(
          'MISSION STATUS UPDATED TO COMPLETED',
        );

        // ------------------------------------------------------
        // UPDATE EXPLORATION POINTS
        // ------------------------------------------------------

        await SupabaseConfig.client
            .from('profiles')
            .update({
          'exploration_points':
          newTotal,
        }).eq(
          'id',
          user.id,
        );

        currentPoints =
            newTotal;

        debugPrint(
          'POINTS AWARDED: +$rewardPoints',
        );

        debugPrint(
          'NEW TOTAL POINTS: $currentPoints',
        );
      } else {
        debugPrint(
          'REWARD ALREADY CLAIMED. '
              'NO EXTRA POINTS ADDED.',
        );
      }

      // ========================================================
      // 4. CHECK POINT TRANSACTION EXISTS
      // ========================================================

      final Map<String, dynamic>?
      existingTransaction =
      await SupabaseConfig.client
          .from(
        'point_transactions',
      )
          .select()
          .eq(
        'user_id',
        user.id,
      )
          .eq(
        'reference_id',
        missionId,
      )
          .eq(
        'transaction_type',
        'CHECKPOINT_REWARD',
      )
          .maybeSingle();

      // ========================================================
      // 5. INSERT POINT TRANSACTION IF MISSING
      // ========================================================

      if (existingTransaction == null) {
        await SupabaseConfig.client
            .from(
          'point_transactions',
        )
            .insert({
          'user_id':
          user.id,

          'amount':
          rewardPoints,

          'transaction_type':
          'CHECKPOINT_REWARD',

          'description':
          'Checkpoint mission reward',

          'reference_id':
          missionId,

          'created_at':
          DateTime.now()
              .toUtc()
              .toIso8601String(),
        });

        debugPrint(
          'POINT TRANSACTION CREATED',
        );
      } else {
        debugPrint(
          'POINT TRANSACTION ALREADY EXISTS',
        );
      }

      // ========================================================
      // 6. CHECK JOURNEY HISTORY EXISTS
      // ========================================================

      final Map<String, dynamic>?
      existingJourneyHistory =
      await SupabaseConfig.client
          .from(
        'journey_history',
      )
          .select()
          .eq(
        'user_id',
        user.id,
      )
          .eq(
        'mission_id',
        missionId,
      )
          .eq(
        'activity_type',
        'CHECKPOINT_COMPLETED',
      )
          .maybeSingle();

      // ========================================================
      // 7. INSERT JOURNEY HISTORY IF MISSING
      // ========================================================

      if (existingJourneyHistory == null) {
        await SupabaseConfig.client
            .from(
          'journey_history',
        )
            .insert({
          'user_id':
          user.id,

          'destination_id':
          destinationId,

          'mission_id':
          missionId,

          'activity_type':
          'CHECKPOINT_COMPLETED',

          'exploration_points_earned':
          rewardPoints,

          'recorded_at':
          DateTime.now()
              .toUtc()
              .toIso8601String(),
        });

        debugPrint(
          'JOURNEY HISTORY CREATED',
        );
      } else {
        debugPrint(
          'JOURNEY HISTORY ALREADY EXISTS',
        );
      }

      debugPrint(
        'MISSION COMPLETION FINISHED',
      );

      debugPrint(
        '=====================================',
      );

      return currentPoints;
    } catch (error) {
      debugPrint(
        'COMPLETE MISSION ERROR: $error',
      );

      rethrow;
    }
  }

  // ============================================================
  // GET CURRENT EXPLORATION POINTS
  // ============================================================

  Future<int>
  getCurrentExplorationPoints() async {
    final user =
        SupabaseConfig.client.auth.currentUser;

    if (user == null) {
      return 0;
    }

    try {
      final Map<String, dynamic> response =
      await SupabaseConfig.client
          .from('profiles')
          .select(
        'exploration_points',
      )
          .eq(
        'id',
        user.id,
      )
          .single();

      return _toInt(
        response['exploration_points'],
      );
    } catch (error) {
      debugPrint(
        'GET POINTS ERROR: $error',
      );

      return 0;
    }
  }

  // ============================================================
  // HELPER
  // ============================================================

  int _toInt(
      dynamic value,
      ) {
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
  // ============================================================
// GET COMPLETED CHECKPOINT DESTINATION IDS
// ============================================================

  Future<Set<String>>
  getCompletedDestinationIds() async {
    final user =
        SupabaseConfig.client.auth.currentUser;

    if (user == null) {
      return <String>{};
    }

    try {
      final List<dynamic> userMissions =
      await SupabaseConfig.client
          .from('user_checkpoint_missions')
          .select(
        'mission_id',
      )
          .eq(
        'user_id',
        user.id,
      )
          .eq(
        'mission_status',
        'COMPLETED',
      );

      if (userMissions.isEmpty) {
        return <String>{};
      }

      final List<String> missionIds =
      userMissions
          .map(
            (dynamic row) =>
            row['mission_id']
                .toString(),
      )
          .toList();

      final List<dynamic> missions =
      await SupabaseConfig.client
          .from('checkpoint_missions')
          .select(
        'mission_id, destination_id',
      )
          .inFilter(
        'mission_id',
        missionIds,
      );

      return missions
          .map(
            (dynamic row) =>
            row['destination_id']
                .toString(),
      )
          .toSet();
    } catch (error) {
      debugPrint(
        'LOAD COMPLETED DESTINATIONS ERROR: $error',
      );

      return <String>{};
    }
  }
}