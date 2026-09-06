import 'package:flutter/foundation.dart';

import '../../core/config/supabase_config.dart';
import '../models/checkpoint_destination.dart';
import '../models/checkpoint_mission.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
        Supabase.instance.client.auth.currentUser;

    if (user == null) {
      throw Exception(
        'Traveller must be logged in.',
      );
    }

    // Check existing attempt first.
    final existing =
    await Supabase.instance.client
        .from(
      'user_checkpoint_missions',
    )
        .select(
      'user_mission_id, mission_status',
    )
        .eq(
      'user_id',
      user.id,
    )
        .eq(
      'mission_id',
      missionId,
    )
        .maybeSingle();

    if (existing != null) {
      final String status =
          existing['mission_status']
              ?.toString()
              .toUpperCase() ??
              'NOT_STARTED';

      final String userMissionId =
      existing['user_mission_id']
          .toString();

      // Never restart a completed mission.
      if (status == 'COMPLETED') {
        throw Exception(
          'This mission has already been completed.',
        );
      }

      // Existing mission is already IN_PROGRESS.
      // Just continue it.
      if (status == 'IN_PROGRESS') {
        return userMissionId;
      }

      // Existing NOT_STARTED / FAILED attempt.
      await Supabase.instance.client
          .from(
        'user_checkpoint_missions',
      )
          .update({
        'mission_status':
        'IN_PROGRESS',

        'started_at':
        DateTime.now()
            .toUtc()
            .toIso8601String(),
      })
          .eq(
        'user_mission_id',
        userMissionId,
      );

      return userMissionId;
    }

    // First time starting this mission.
    final row =
    await Supabase.instance.client
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
        .select(
      'user_mission_id',
    )
        .single();

    return row['user_mission_id']
        .toString();
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

  Future<Set<String>> getCompletedDestinationIds() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      return <String>{};
    }

    try {
      final rows = await Supabase.instance.client
          .from('user_checkpoint_missions')
          .select('''
          mission_id,
          checkpoint_missions (
            destination_id
          )
        ''')
          .eq('user_id', user.id)
          .eq('mission_status', 'COMPLETED');

      final Set<String> destinationIds = {};

      for (final raw in rows) {
        final row = Map<String, dynamic>.from(raw);

        final missionRaw =
        row['checkpoint_missions'];

        if (missionRaw is! Map) {
          continue;
        }

        final mission =
        Map<String, dynamic>.from(missionRaw);

        final destinationId =
        mission['destination_id']
            ?.toString();

        if (destinationId != null &&
            destinationId.isNotEmpty) {
          destinationIds.add(destinationId);
        }
      }

      debugPrint(
        '[CHECKPOINT] Current user: ${user.id}',
      );

      debugPrint(
        '[CHECKPOINT] Completed destinations: '
            '$destinationIds',
      );

      return destinationIds;
    } catch (error) {
      debugPrint(
        '[CHECKPOINT] Failed to load completed '
            'destinations: $error',
      );

      return <String>{};
    }
  }

  Future<ActiveCheckpointData>
  getActiveCheckpointDestinations() async {
    final SupabaseClient client =
        Supabase.instance.client;

    final User? user =
        client.auth.currentUser;

    if (user == null) {
      return const ActiveCheckpointData(
        destinations: [],
        rewardPoints: {},
      );
    }

    // ============================================================
    // 1. LOAD ACTIVE CHECKPOINT MISSIONS
    // ============================================================

    final missionRows =
    await client
        .from('checkpoint_missions')
        .select(
      '''
            destination_id,
            reward_points
            ''',
    )
        .eq(
      'is_active',
      true,
    );

    final Set<String> activeDestinationIds =
    <String>{};

    final Map<String, int> rewardPoints =
    <String, int>{};

    for (final raw in missionRows) {
      final Map<String, dynamic> row =
      Map<String, dynamic>.from(raw);

      final String destinationId =
          row['destination_id']
              ?.toString()
              .trim() ??
              '';

      if (destinationId.isEmpty) {
        continue;
      }

      activeDestinationIds.add(
        destinationId,
      );

      final dynamic rewardRaw =
      row['reward_points'];

      final int reward =
      rewardRaw is num
          ? rewardRaw.toInt()
          : int.tryParse(
        rewardRaw?.toString() ?? '',
      ) ??
          0;

      rewardPoints.putIfAbsent(
        destinationId,
            () => reward,
      );
    }

    if (activeDestinationIds.isEmpty) {
      return const ActiveCheckpointData(
        destinations: [],
        rewardPoints: {},
      );
    }

    // ============================================================
    // 2. LOAD CURRENT USER'S BLIND BOX HISTORY
    //
    // IMPORTANT:
    // Purple Blind Box pins are personal.
    // Another user's draws must not appear on this user's map.
    // ============================================================

    final historyRows =
    await client
        .from('blind_box_history')
        .select(
      'destination_id',
    )
        .eq(
      'user_id',
      user.id,
    );

    final Set<String>
    currentUserBlindBoxDestinationIds =
    <String>{};

    for (final raw in historyRows) {
      final Map<String, dynamic> row =
      Map<String, dynamic>.from(raw);

      final String destinationId =
          row['destination_id']
              ?.toString()
              .trim() ??
              '';

      if (destinationId.isNotEmpty) {
        currentUserBlindBoxDestinationIds.add(
          destinationId,
        );
      }
    }

    debugPrint(
      '[CHECKPOINT] Current user: ${user.email}',
    );

    debugPrint(
      '[CHECKPOINT] User Blind Box destinations: '
          '$currentUserBlindBoxDestinationIds',
    );

    // ============================================================
    // 3. LOAD ACTIVE DESTINATION DETAILS
    // ============================================================

    final destinationRows =
    await client
        .from('blind_box_destinations')
        .select()
        .inFilter(
      'destination_id',
      activeDestinationIds.toList(),
    );

    final List<CheckpointDestination>
    visibleDestinations =
    <CheckpointDestination>[];

    final Set<String>
    visibleDestinationIds =
    <String>{};

    // ============================================================
    // 4. APPLY VISIBILITY RULE
    //
    // CURATED
    // → visible to everyone
    //
    // GOOGLE
    // → visible only if current user drew it
    // ============================================================

    for (final raw in destinationRows) {
      try {
        final Map<String, dynamic> row =
        Map<String, dynamic>.from(raw);

        final CheckpointDestination destination =
        CheckpointDestination.fromJson(
          row,
        );

        final String source =
            destination.destinationSource
                ?.trim()
                .toUpperCase() ??
                '';

        final bool isBlindBox =
            source == 'GOOGLE';

        // --------------------------------------------------------
        // Hidden Gem
        // --------------------------------------------------------

        if (!isBlindBox) {
          visibleDestinations.add(
            destination,
          );

          visibleDestinationIds.add(
            destination.destinationId,
          );

          continue;
        }

        // --------------------------------------------------------
        // Blind Box
        //
        // Only current user's history is allowed.
        // --------------------------------------------------------

        final bool userHasDrawnDestination =
        currentUserBlindBoxDestinationIds
            .contains(
          destination.destinationId,
        );

        if (userHasDrawnDestination) {
          visibleDestinations.add(
            destination,
          );

          visibleDestinationIds.add(
            destination.destinationId,
          );
        }
      } catch (error) {
        debugPrint(
          '[CHECKPOINT] Unable to parse destination: '
              '$error',
        );
      }
    }

    // ============================================================
    // 5. REMOVE REWARDS FOR HIDDEN DESTINATIONS
    // ============================================================

    final Map<String, int>
    visibleRewardPoints =
    <String, int>{};

    for (final String destinationId
    in visibleDestinationIds) {
      final int? reward =
      rewardPoints[
      destinationId];

      if (reward != null) {
        visibleRewardPoints[
        destinationId] = reward;
      }
    }

    debugPrint(
      '[CHECKPOINT] Visible destinations: '
          '${visibleDestinations.length}',
    );

    debugPrint(
      '[CHECKPOINT] Visible Blind Box count: '
          '${visibleDestinations.where(
            (destination) =>
        destination.destinationSource
            ?.trim()
            .toUpperCase() ==
            'GOOGLE',
      ).length}',
    );

    return ActiveCheckpointData(
      destinations:
      visibleDestinations,

      rewardPoints:
      visibleRewardPoints,
    );
  }

  Future<String?>
  getCurrentProfilePictureUrl() async {
    final user =
        Supabase.instance.client.auth.currentUser;

    if (user == null) {
      return null;
    }

    final profile =
    await Supabase.instance.client
        .from('profiles')
        .select(
      'profile_picture_url',
    )
        .eq(
      'id',
      user.id,
    )
        .maybeSingle();

    final picture =
    profile?['profile_picture_url']
        ?.toString()
        .trim();

    if (picture == null ||
        picture.isEmpty) {
      return null;
    }

    return picture;
  }

  Future<UserCheckpointMissionState?>
  getCurrentUserMissionState({
    required String missionId,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      return null;
    }

    final row = await Supabase.instance.client
        .from('user_checkpoint_missions')
        .select(
      'user_mission_id, mission_status, reward_claimed',
    )
        .eq(
      'user_id',
      user.id,
    )
        .eq(
      'mission_id',
      missionId,
    )
        .maybeSingle();

    if (row == null) {
      return null;
    }

    return UserCheckpointMissionState(
      userMissionId:
      row['user_mission_id'].toString(),

      missionStatus:
      row['mission_status']
          ?.toString()
          .toUpperCase() ??
          'NOT_STARTED',

      rewardClaimed:
      row['reward_claimed'] == true,
    );
  }
}

class ActiveCheckpointData {
  final List<CheckpointDestination>
  destinations;

  final Map<String, int>
  rewardPoints;

  const ActiveCheckpointData({
    required this.destinations,
    required this.rewardPoints,
  });
}

class UserCheckpointMissionState {
  final String userMissionId;
  final String missionStatus;
  final bool rewardClaimed;

  const UserCheckpointMissionState({
    required this.userMissionId,
    required this.missionStatus,
    required this.rewardClaimed,
  });

  bool get isNotStarted =>
      missionStatus == 'NOT_STARTED';

  bool get isInProgress =>
      missionStatus == 'IN_PROGRESS';

  bool get isCompleted =>
      missionStatus == 'COMPLETED';
}