import 'package:flutter/material.dart';

import '../../../data/models/checkpoint_destination.dart';
import '../../../data/models/checkpoint_mission.dart';
import '../../../data/repositories/checkpoint_repository.dart';
import 'mission_execution_screen.dart';

class CheckpointMissionScreen
    extends StatefulWidget {
  final CheckpointDestination destination;

  const CheckpointMissionScreen({
    super.key,
    required this.destination,
  });

  @override
  State<CheckpointMissionScreen>
  createState() =>
      _CheckpointMissionScreenState();
}

class _CheckpointMissionScreenState
    extends State<CheckpointMissionScreen> {
  final CheckpointRepository _repository =
  CheckpointRepository();

  CheckpointMission? _mission;

  bool _isLoading = true;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _loadMission();
  }

  Future<void> _loadMission() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint(
        'Loading mission for destination: '
            '${widget.destination.destinationId}',
      );

      final CheckpointMission? result =
      await _repository
          .getMissionByDestinationId(
        widget.destination.destinationId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _mission = result;
        _isLoading = false;
      });

      if (result == null) {
        debugPrint(
          'No mission found for '
              '${widget.destination.name}',
        );
      } else {
        debugPrint(
          'Mission loaded: '
              '${result.missionName}',
        );
      }
    } catch (error) {
      debugPrint(
        'MISSION LOAD ERROR: $error',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage =
            error.toString();

        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
      const Color(0xFFF4F7FB),

      appBar: AppBar(
        backgroundColor:
        Colors.white,

        surfaceTintColor:
        Colors.white,

        elevation: 0,

        leading: IconButton(
          onPressed: () {
            Navigator.pop(
              context,
            );
          },

          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color:
            Color(0xFF0F172A),
          ),
        ),

        title: const Text(
          'Mission Details',
          style: TextStyle(
            color:
            Color(0xFF0F172A),
            fontSize: 20,
            fontWeight:
            FontWeight.w700,
          ),
        ),

        centerTitle: true,
      ),

      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize:
          MainAxisSize.min,

          children: [
            CircularProgressIndicator(),

            SizedBox(
              height: 16,
            ),

            Text(
              'Loading mission...',
              style: TextStyle(
                color:
                Color(0xFF64748B),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_mission == null) {
      return _buildNoMissionState();
    }

    final CheckpointMission mission =
    _mission!;

    return SingleChildScrollView(
      padding:
      const EdgeInsets.fromLTRB(
        18,
        20,
        18,
        30,
      ),

      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [
          _buildDestinationHeader(),

          const SizedBox(
            height: 18,
          ),

          _buildMissionHeader(
            mission,
          ),

          const SizedBox(
            height: 18,
          ),

          _buildInformationCard(
            icon:
            Icons.flag_rounded,

            title:
            'Mission Objective',

            value:
            mission.objective,
          ),

          const SizedBox(
            height: 14,
          ),

          _buildInformationCard(
            icon:
            Icons
                .format_list_bulleted_rounded,

            title:
            'Instructions',

            value:
            mission
                .completionInstructions ??
                'Follow the checkpoint mission instructions.',
          ),

          const SizedBox(
            height: 14,
          ),

          if (mission.photoRequired)
            _buildInformationCard(
              icon:
              Icons
                  .photo_camera_rounded,

              title:
              'Photo Requirement',

              value:
              mission
                  .photoRequirement ??
                  'Capture a clear photo at the checkpoint.',
            ),

          if (mission.photoRequired)
            const SizedBox(
              height: 14,
            ),

          _buildMissionRules(
            mission,
          ),

          const SizedBox(
            height: 22,
          ),

          _buildSafetyNotice(),

          const SizedBox(
            height: 24,
          ),

          SizedBox(
            width: double.infinity,

            child:
            ElevatedButton.icon(
              onPressed: () {
                _startMission(
                  mission,
                );
              },

              icon: const Icon(
                Icons
                    .play_arrow_rounded,
              ),

              label: const Text(
                'Start Mission',
              ),

              style:
              ElevatedButton.styleFrom(
                backgroundColor:
                const Color(
                  0xFF2563EB,
                ),

                foregroundColor:
                Colors.white,

                padding:
                const EdgeInsets
                    .symmetric(
                  vertical: 16,
                ),

                shape:
                RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius
                      .circular(
                    14,
                  ),
                ),

                textStyle:
                const TextStyle(
                  fontSize: 16,
                  fontWeight:
                  FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DESTINATION HEADER
  // ============================================================

  Widget _buildDestinationHeader() {
    return Container(
      width: double.infinity,

      padding:
      const EdgeInsets.all(
        18,
      ),

      decoration: BoxDecoration(
        color:
        const Color(
          0xFFEFF6FF,
        ),

        borderRadius:
        BorderRadius.circular(
          20,
        ),

        border: Border.all(
          color:
          const Color(
            0xFFBFDBFE,
          ),
        ),
      ),

      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [
          Container(
            width: 52,
            height: 52,

            decoration:
            BoxDecoration(
              color:
              const Color(
                0xFF2563EB,
              ),

              borderRadius:
              BorderRadius
                  .circular(
                15,
              ),
            ),

            child:
            const Icon(
              Icons
                  .location_on_rounded,

              color:
              Colors.white,

              size: 29,
            ),
          ),

          const SizedBox(
            width: 14,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment
                  .start,

              children: [
                Text(
                  widget
                      .destination
                      .name,

                  style:
                  const TextStyle(
                    color:
                    Color(
                      0xFF0F172A,
                    ),
                    fontSize: 19,
                    fontWeight:
                    FontWeight
                        .w700,
                  ),
                ),

                if (widget
                    .destination
                    .category !=
                    null) ...[
                  const SizedBox(
                    height: 5,
                  ),

                  Text(
                    widget
                        .destination
                        .category!,

                    style:
                    const TextStyle(
                      color:
                      Color(
                        0xFF2563EB,
                      ),
                      fontSize: 13,
                      fontWeight:
                      FontWeight
                          .w600,
                    ),
                  ),
                ],

                if (widget
                    .destination
                    .address !=
                    null) ...[
                  const SizedBox(
                    height: 7,
                  ),

                  Text(
                    widget
                        .destination
                        .address!,

                    style:
                    const TextStyle(
                      color:
                      Color(
                        0xFF64748B,
                      ),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MISSION HEADER
  // ============================================================

  Widget _buildMissionHeader(
      CheckpointMission mission,
      ) {
    return Container(
      width: double.infinity,

      padding:
      const EdgeInsets.all(
        18,
      ),

      decoration:
      BoxDecoration(
        color:
        Colors.white,

        borderRadius:
        BorderRadius.circular(
          20,
        ),

        border: Border.all(
          color:
          const Color(
            0xFFE2E8F0,
          ),
        ),
      ),

      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Container(
                padding:
                const EdgeInsets
                    .symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),

                decoration:
                BoxDecoration(
                  color:
                  _difficultyColor(
                    mission
                        .difficultyLevel,
                  ).withValues(
                    alpha: 0.12,
                  ),

                  borderRadius:
                  BorderRadius
                      .circular(
                    30,
                  ),
                ),

                child: Text(
                  mission
                      .difficultyLevel,

                  style:
                  TextStyle(
                    color:
                    _difficultyColor(
                      mission
                          .difficultyLevel,
                    ),

                    fontSize: 11,

                    fontWeight:
                    FontWeight
                        .w700,
                  ),
                ),
              ),

              const Spacer(),

              if (mission.generatedBy ==
                  'GEMINI')
                Container(
                  padding:
                  const EdgeInsets
                      .symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),

                  decoration:
                  BoxDecoration(
                    color:
                    const Color(
                      0xFFF3E8FF,
                    ),

                    borderRadius:
                    BorderRadius
                        .circular(
                      30,
                    ),
                  ),

                  child:
                  const Text(
                    'AI Generated',
                    style:
                    TextStyle(
                      color:
                      Color(
                        0xFF7C3AED,
                      ),
                      fontSize: 11,
                      fontWeight:
                      FontWeight
                          .w600,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(
            height: 14,
          ),

          Text(
            mission.missionName,

            style:
            const TextStyle(
              color:
              Color(
                0xFF0F172A,
              ),

              fontSize: 22,

              fontWeight:
              FontWeight
                  .w800,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INFO CARD
  // ============================================================

  Widget _buildInformationCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      width: double.infinity,

      padding:
      const EdgeInsets.all(
        17,
      ),

      decoration:
      BoxDecoration(
        color: Colors.white,

        borderRadius:
        BorderRadius.circular(
          18,
        ),

        border: Border.all(
          color:
          const Color(
            0xFFE2E8F0,
          ),
        ),
      ),

      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [
          Container(
            width: 42,
            height: 42,

            decoration:
            BoxDecoration(
              color:
              const Color(
                0xFFEFF6FF,
              ),

              borderRadius:
              BorderRadius
                  .circular(
                12,
              ),
            ),

            child: Icon(
              icon,

              color:
              const Color(
                0xFF2563EB,
              ),

              size: 22,
            ),
          ),

          const SizedBox(
            width: 13,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment
                  .start,

              children: [
                Text(
                  title,

                  style:
                  const TextStyle(
                    color:
                    Color(
                      0xFF0F172A,
                    ),

                    fontSize: 14,

                    fontWeight:
                    FontWeight
                        .w700,
                  ),
                ),

                const SizedBox(
                  height: 7,
                ),

                Text(
                  value,

                  style:
                  const TextStyle(
                    color:
                    Color(
                      0xFF64748B,
                    ),

                    fontSize: 13,

                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MISSION RULES
  // ============================================================

  Widget _buildMissionRules(
      CheckpointMission mission,
      ) {
    return Container(
      padding:
      const EdgeInsets.all(
        18,
      ),

      decoration:
      BoxDecoration(
        color: Colors.white,

        borderRadius:
        BorderRadius.circular(
          18,
        ),

        border: Border.all(
          color:
          const Color(
            0xFFE2E8F0,
          ),
        ),
      ),

      child: Column(
        children: [
          _buildRuleRow(
            icon:
            Icons
                .my_location_rounded,

            title:
            'Verification Radius',

            value:
            '${mission.verificationRadiusM} metres',
          ),

          const Divider(
            height: 26,
          ),

          _buildRuleRow(
            icon:
            Icons
                .stars_rounded,

            title:
            'Mission Reward',

            value:
            '${mission.rewardPoints} Exploration Points',
          ),

          const Divider(
            height: 26,
          ),

          _buildRuleRow(
            icon:
            Icons
                .photo_camera_outlined,

            title:
            'Photo Required',

            value:
            mission.photoRequired
                ? 'Yes'
                : 'No',
          ),
        ],
      ),
    );
  }

  Widget _buildRuleRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,

          color:
          const Color(
            0xFF2563EB,
          ),

          size: 22,
        ),

        const SizedBox(
          width: 12,
        ),

        Expanded(
          child: Text(
            title,

            style:
            const TextStyle(
              color:
              Color(
                0xFF475569,
              ),

              fontSize: 13,
            ),
          ),
        ),

        Text(
          value,

          textAlign:
          TextAlign.right,

          style:
          const TextStyle(
            color:
            Color(
              0xFF0F172A,
            ),

            fontSize: 13,

            fontWeight:
            FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SAFETY NOTICE
  // ============================================================

  Widget _buildSafetyNotice() {
    return Container(
      width:
      double.infinity,

      padding:
      const EdgeInsets.all(
        15,
      ),

      decoration:
      BoxDecoration(
        color:
        const Color(
          0xFFFFFBEB,
        ),

        borderRadius:
        BorderRadius.circular(
          15,
        ),

        border: Border.all(
          color:
          const Color(
            0xFFFDE68A,
          ),
        ),
      ),

      child:
      const Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [
          Icon(
            Icons
                .info_outline_rounded,

            color:
            Color(
              0xFFD97706,
            ),

            size: 21,
          ),

          SizedBox(
            width: 10,
          ),

          Expanded(
            child: Text(
              'Only complete the mission from a safe and publicly accessible location. Follow local rules and restrictions.',
              style:
              TextStyle(
                color:
                Color(
                  0xFF92400E,
                ),

                fontSize: 12,

                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // START MISSION
  // ============================================================

  Future<void> _startMission(
      CheckpointMission mission,
      ) async {
    try {
      final String userMissionId =
      await _repository.startUserMission(
        missionId: mission.missionId,
      );

      if (!mounted) {
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MissionExecutionScreen(
            destination: widget.destination,
            mission: mission,
            userMissionId: userMissionId,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error
                .toString()
                .replaceFirst(
              'Exception: ',
              '',
            ),
          ),
        ),
      );
    }
  }

  Widget _buildNoMissionState() {
    return Center(
      child: Padding(
        padding:
        const EdgeInsets.all(
          30,
        ),

        child: Column(
          mainAxisSize:
          MainAxisSize.min,

          children: [
            const Icon(
              Icons
                  .flag_outlined,

              color:
              Color(
                0xFF94A3B8,
              ),

              size: 70,
            ),

            const SizedBox(
              height: 18,
            ),

            const Text(
              'No Mission Available',

              style:
              TextStyle(
                color:
                Color(
                  0xFF0F172A,
                ),

                fontSize: 20,

                fontWeight:
                FontWeight
                    .w700,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            Text(
              'No active checkpoint mission was found for ${widget.destination.name}.',

              textAlign:
              TextAlign.center,

              style:
              const TextStyle(
                color:
                Color(
                  0xFF64748B,
                ),

                fontSize: 14,
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            ElevatedButton.icon(
              onPressed:
              _loadMission,

              icon:
              const Icon(
                Icons.refresh,
              ),

              label:
              const Text(
                'Try Again',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildErrorState() {
    return Center(
      child:
      SingleChildScrollView(
        padding:
        const EdgeInsets.all(
          30,
        ),

        child: Column(
          mainAxisSize:
          MainAxisSize.min,

          children: [
            const Icon(
              Icons
                  .error_outline_rounded,

              color:
              Color(
                0xFFEF4444,
              ),

              size: 70,
            ),

            const SizedBox(
              height: 18,
            ),

            const Text(
              'Unable to Load Mission',

              style:
              TextStyle(
                color:
                Color(
                  0xFF0F172A,
                ),

                fontSize: 20,

                fontWeight:
                FontWeight
                    .w700,
              ),
            ),

            const SizedBox(
              height: 10,
            ),

            Text(
              _errorMessage ??
                  'Unknown error',

              textAlign:
              TextAlign.center,

              style:
              const TextStyle(
                color:
                Color(
                  0xFF64748B,
                ),

                fontSize: 13,
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            ElevatedButton.icon(
              onPressed:
              _loadMission,

              icon:
              const Icon(
                Icons.refresh,
              ),

              label:
              const Text(
                'Retry',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DIFFICULTY COLOUR
  // ============================================================

  Color _difficultyColor(
      String difficulty,
      ) {
    switch (
    difficulty.toUpperCase()) {
      case 'HARD':
        return const Color(
          0xFFDC2626,
        );

      case 'MEDIUM':
        return const Color(
          0xFFD97706,
        );

      case 'EASY':
      default:
        return const Color(
          0xFF16A34A,
        );
    }
  }
}