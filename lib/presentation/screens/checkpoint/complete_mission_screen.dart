import 'dart:io';

import 'package:flutter/material.dart';

import '../../../application/controller/complete_mission_controller.dart';
import '../../../data/models/checkpoint_destination.dart';

import '../puzzle/puzzle_screen.dart';

class CompleteMissionScreen extends StatelessWidget {
  CompleteMissionScreen({
    super.key,
    required CheckpointDestination destination,
    required String title,
    required int reward,
    required int totalPoints,
    String? photoPath,
    String? verificationReason,
    double? verificationConfidence,
  }) : _controller = CompleteMissionController(
    destination: destination,
    title: title,
    reward: reward,
    totalPoints: totalPoints,
    photoPath: photoPath,
    verificationReason: verificationReason,
    verificationConfidence:
    verificationConfidence,
  );

  // ===========================================================================
  // CONTROLLER
  // ===========================================================================

  final CompleteMissionController _controller;

  // ===========================================================================
  // COLORS
  // ===========================================================================

  static const Color skyBlue =
  Color(0xFF0284C7);

  static const Color darkBlue =
  Color(0xFF0369A1);

  static const Color pageBackground =
  Color(0xFFF8FAFC);

  static const Color darkText =
  Color(0xFF0F172A);

  static const Color bodyText =
  Color(0xFF64748B);

  static const Color successGreen =
  Color(0xFF059669);

  static const Color lightGreen =
  Color(0xFFECFDF5);

  static const Color greenBorder =
  Color(0xFFA7F3D0);

  // ===========================================================================
  // RETURN TO CHECKPOINT
  // ===========================================================================

  void _returnToCheckpoint(
      BuildContext context,
      ) {
    Navigator.pop(
      context,
      _controller.reward,
    );
  }

  // ===========================================================================
  // OPEN PUZZLE
  //
  // SAME CONNECTION AS:
  // Checkpoint Screen -> VIEW PUZZLE
  //
  // Controller prepares destination data.
  // Presentation handles Navigator.
  // ===========================================================================

  void _openPuzzle(
      BuildContext context,
      ) {
    final CompleteMissionPuzzleData data =
        _controller.puzzleData;

    final MissionCheckpoint checkpoint =
    MissionCheckpoint(
      id:
      data.destinationId,

      title:
      data.title,

      imageUrl:
      data.imageUrl,

      locationName:
      data.locationName,

      category:
      data.category,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PuzzleScreen(
              mission:
              checkpoint,

              initialLocationSource:
              PuzzleLocationSource
                  .checkpoint,
            ),
      ),
    );
  }

  // ===========================================================================
  // VERIFICATION DETAILS
  // ===========================================================================

  void _showVerificationDetails(
      BuildContext context,
      ) {
    showModalBottomSheet<void>(
      context:
      context,

      backgroundColor:
      Colors.transparent,

      isScrollControlled:
      true,

      builder:
          (BuildContext sheetContext) {
        return SafeArea(
          child: Container(
            margin:
            const EdgeInsets.all(
              12,
            ),

            padding:
            const EdgeInsets.fromLTRB(
              20,
              12,
              20,
              24,
            ),

            decoration:
            BoxDecoration(
              color:
              Colors.white,

              borderRadius:
              BorderRadius.circular(
                26,
              ),
            ),

            child:
            Column(
              mainAxisSize:
              MainAxisSize.min,

              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [
                // -------------------------------------------------------------
                // DRAG HANDLE
                // -------------------------------------------------------------

                Center(
                  child:
                  Container(
                    width:
                    42,

                    height:
                    4,

                    decoration:
                    BoxDecoration(
                      color:
                      const Color(
                        0xFFCBD5E1,
                      ),

                      borderRadius:
                      BorderRadius.circular(
                        99,
                      ),
                    ),
                  ),
                ),

                const SizedBox(
                  height:
                  18,
                ),

                // -------------------------------------------------------------
                // TITLE
                // -------------------------------------------------------------

                const Row(
                  children: [
                    Icon(
                      Icons
                          .auto_awesome_rounded,

                      color:
                      successGreen,

                      size:
                      23,
                    ),

                    SizedBox(
                      width:
                      9,
                    ),

                    Expanded(
                      child:
                      Text(
                        'AI Verification Details',

                        style:
                        TextStyle(
                          color:
                          darkText,

                          fontSize:
                          17,

                          fontWeight:
                          FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height:
                  22,
                ),

                // -------------------------------------------------------------
                // RESULT
                // -------------------------------------------------------------

                const Text(
                  'Verification Result',

                  style:
                  TextStyle(
                    color:
                    bodyText,

                    fontSize:
                    10.5,

                    fontWeight:
                    FontWeight.w800,
                  ),
                ),

                const SizedBox(
                  height:
                  7,
                ),

                const Row(
                  children: [
                    Icon(
                      Icons
                          .check_circle_rounded,

                      color:
                      successGreen,

                      size:
                      19,
                    ),

                    SizedBox(
                      width:
                      7,
                    ),

                    Text(
                      'Verified',

                      style:
                      TextStyle(
                        color:
                        Color(
                          0xFF047857,
                        ),

                        fontSize:
                        13,

                        fontWeight:
                        FontWeight.w900,
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height:
                  20,
                ),

                // -------------------------------------------------------------
                // REASON
                // -------------------------------------------------------------

                const Text(
                  'Reason',

                  style:
                  TextStyle(
                    color:
                    bodyText,

                    fontSize:
                    10.5,

                    fontWeight:
                    FontWeight.w800,
                  ),
                ),

                const SizedBox(
                  height:
                  7,
                ),

                Text(
                  _controller
                      .verificationReasonText,

                  style:
                  const TextStyle(
                    color:
                    Color(
                      0xFF334155,
                    ),

                    fontSize:
                    12,

                    height:
                    1.5,
                  ),
                ),

                const SizedBox(
                  height:
                  20,
                ),

                // -------------------------------------------------------------
                // CONFIDENCE
                // -------------------------------------------------------------

                const Text(
                  'AI Confidence',

                  style:
                  TextStyle(
                    color:
                    bodyText,

                    fontSize:
                    10.5,

                    fontWeight:
                    FontWeight.w800,
                  ),
                ),

                const SizedBox(
                  height:
                  9,
                ),

                Row(
                  children: [
                    Expanded(
                      child:
                      ClipRRect(
                        borderRadius:
                        BorderRadius.circular(
                          99,
                        ),

                        child:
                        LinearProgressIndicator(
                          value:
                          _controller
                              .confidencePercent /
                              100,

                          minHeight:
                          8,

                          backgroundColor:
                          const Color(
                            0xFFD1FAE5,
                          ),

                          color:
                          successGreen,
                        ),
                      ),
                    ),

                    const SizedBox(
                      width:
                      12,
                    ),

                    Text(
                      '${_controller.confidencePercent}%',

                      style:
                      const TextStyle(
                        color:
                        successGreen,

                        fontSize:
                        13,

                        fontWeight:
                        FontWeight.w900,
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height:
                  25,
                ),

                // -------------------------------------------------------------
                // DONE
                // -------------------------------------------------------------

                SizedBox(
                  width:
                  double.infinity,

                  height:
                  48,

                  child:
                  FilledButton(
                    onPressed:
                        () {
                      Navigator.pop(
                        sheetContext,
                      );
                    },

                    style:
                    FilledButton.styleFrom(
                      backgroundColor:
                      skyBlue,

                      foregroundColor:
                      Colors.white,

                      shape:
                      RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(
                          24,
                        ),
                      ),
                    ),

                    child:
                    const Text(
                      'DONE',

                      style:
                      TextStyle(
                        fontWeight:
                        FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      backgroundColor:
      pageBackground,

      body:
      SafeArea(
        child:
        SingleChildScrollView(
          padding:
          const EdgeInsets.fromLTRB(
            18,
            14,
            18,
            28,
          ),

          child:
          Column(
            crossAxisAlignment:
            CrossAxisAlignment.stretch,

            children: [
              _buildHeader(
                context,
              ),

              const SizedBox(
                height:
                18,
              ),

              _buildSuccessCard(),

              const SizedBox(
                height:
                18,
              ),

              _buildVerificationCard(
                context,
              ),

              const SizedBox(
                height:
                20,
              ),

              // ===============================================================
              // RETURN TO CHECKPOINTS
              // ===============================================================

              SizedBox(
                height:
                52,

                child:
                FilledButton.icon(
                  onPressed:
                      () {
                    _returnToCheckpoint(
                      context,
                    );
                  },

                  style:
                  FilledButton.styleFrom(
                    backgroundColor:
                    const Color(
                      0xFF1E293B,
                    ),

                    foregroundColor:
                    Colors.white,

                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(
                        28,
                      ),
                    ),
                  ),

                  icon:
                  const Icon(
                    Icons
                        .explore_rounded,

                    size:
                    19,
                  ),

                  label:
                  const Text(
                    'RETURN TO CHECKPOINTS',

                    style:
                    TextStyle(
                      fontSize:
                      11,

                      fontWeight:
                      FontWeight.w900,

                      letterSpacing:
                      0.3,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height:
                10,
              ),

              // ===============================================================
              // PUZZLE
              // ===============================================================

              SizedBox(
                height:
                52,

                child:
                OutlinedButton.icon(
                  onPressed:
                      () {
                    _openPuzzle(
                      context,
                    );
                  },

                  style:
                  OutlinedButton.styleFrom(
                    foregroundColor:
                    skyBlue,

                    backgroundColor:
                    Colors.white,

                    side:
                    const BorderSide(
                      color:
                      skyBlue,

                      width:
                      1.4,
                    ),

                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(
                        28,
                      ),
                    ),
                  ),

                  icon:
                  const Icon(
                    Icons
                        .extension_rounded,

                    size:
                    19,
                  ),

                  label:
                  const Text(
                    'PUZZLE CHALLENGE',

                    style:
                    TextStyle(
                      fontSize:
                      11,

                      fontWeight:
                      FontWeight.w900,

                      letterSpacing:
                      0.3,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // HEADER
  // ===========================================================================

  Widget _buildHeader(
      BuildContext context,
      ) {
    return Row(
      children: [
        Material(
          color:
          Colors.white,

          shape:
          const CircleBorder(),

          elevation:
          1,

          child:
          InkWell(
            customBorder:
            const CircleBorder(),

            onTap:
                () {
              _returnToCheckpoint(
                context,
              );
            },

            child:
            const SizedBox(
              width:
              42,

              height:
              42,

              child:
              Icon(
                Icons
                    .arrow_back_rounded,

                size:
                21,

                color:
                Color(
                  0xFF334155,
                ),
              ),
            ),
          ),
        ),

        const Expanded(
          child:
          Text(
            'Mission Completed!',

            textAlign:
            TextAlign.center,

            style:
            TextStyle(
              color:
              darkText,

              fontSize:
              20,

              fontWeight:
              FontWeight.w900,
            ),
          ),
        ),

        Container(
          padding:
          const EdgeInsets.symmetric(
            horizontal:
            10,

            vertical:
            8,
          ),

          decoration:
          BoxDecoration(
            color:
            const Color(
              0xFFF0F9FF,
            ),

            borderRadius:
            BorderRadius.circular(
              20,
            ),

            border:
            Border.all(
              color:
              const Color(
                0xFFBAE6FD,
              ),
            ),
          ),

          child:
          Row(
            children: [
              const Icon(
                Icons
                    .toll_rounded,

                size:
                17,

                color:
                skyBlue,
              ),

              const SizedBox(
                width:
                4,
              ),

              Text(
                '${_controller.totalPoints}',

                style:
                const TextStyle(
                  color:
                  skyBlue,

                  fontSize:
                  13,

                  fontWeight:
                  FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // SUCCESS CARD
  // ===========================================================================

  Widget _buildSuccessCard() {
    return Container(
      padding:
      const EdgeInsets.fromLTRB(
        22,
        25,
        22,
        24,
      ),

      decoration:
      BoxDecoration(
        gradient:
        const LinearGradient(
          colors: [
            skyBlue,
            darkBlue,
          ],

          begin:
          Alignment.topLeft,

          end:
          Alignment.bottomRight,
        ),

        borderRadius:
        BorderRadius.circular(
          30,
        ),

        boxShadow:
        const [
          BoxShadow(
            color:
            Color(
              0x330284C7,
            ),

            blurRadius:
            22,

            offset:
            Offset(
              0,
              10,
            ),
          ),
        ],
      ),

      child:
      Column(
        children: [
          Container(
            width:
            72,

            height:
            72,

            decoration:
            BoxDecoration(
              shape:
              BoxShape.circle,

              color:
              const Color(
                0x33FBBF24,
              ),

              border:
              Border.all(
                color:
                const Color(
                  0xFFFCD34D,
                ),

                width:
                2,
              ),
            ),

            child:
            const Icon(
              Icons
                  .emoji_events_rounded,

              color:
              Color(
                0xFFFCD34D,
              ),

              size:
              38,
            ),
          ),

          const SizedBox(
            height:
            13,
          ),

          Container(
            padding:
            const EdgeInsets.symmetric(
              horizontal:
              12,

              vertical:
              5,
            ),

            decoration:
            BoxDecoration(
              color:
              Colors.white.withValues(
                alpha:
                0.16,
              ),

              borderRadius:
              BorderRadius.circular(
                20,
              ),
            ),

            child:
            const Text(
              '✦ CHECKPOINT MASTERED ✦',

              style:
              TextStyle(
                color:
                Color(
                  0xFFE0F2FE,
                ),

                fontSize:
                9.5,

                fontWeight:
                FontWeight.w900,

                letterSpacing:
                0.8,
              ),
            ),
          ),

          const SizedBox(
            height:
            10,
          ),

          Text(
            _controller.title,

            textAlign:
            TextAlign.center,

            style:
            const TextStyle(
              color:
              Colors.white,

              fontSize:
              22,

              fontWeight:
              FontWeight.w900,
            ),
          ),

          const SizedBox(
            height:
            6,
          ),

          const Text(
            'Mission evidence captured and checkpoint verified!',

            textAlign:
            TextAlign.center,

            style:
            TextStyle(
              color:
              Color(
                0xFFDBEAFE,
              ),

              fontSize:
              11.5,
            ),
          ),

          const SizedBox(
            height:
            16,
          ),

          Container(
            padding:
            const EdgeInsets.symmetric(
              horizontal:
              16,

              vertical:
              10,
            ),

            decoration:
            BoxDecoration(
              color:
              const Color(
                0xFFFBBF24,
              ),

              borderRadius:
              BorderRadius.circular(
                24,
              ),
            ),

            child:
            Row(
              mainAxisSize:
              MainAxisSize.min,

              children: [
                const Icon(
                  Icons
                      .star_rounded,

                  color:
                  darkText,

                  size:
                  19,
                ),

                const SizedBox(
                  width:
                  6,
                ),

                Text(
                  '+${_controller.reward} Exploration Points',

                  style:
                  const TextStyle(
                    color:
                    darkText,

                    fontSize:
                    11.5,

                    fontWeight:
                    FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // VERIFICATION CARD
  // ===========================================================================

  Widget _buildVerificationCard(
      BuildContext context,
      ) {
    return Container(
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
          24,
        ),

        border:
        Border.all(
          color:
          const Color(
            0xFFE2E8F0,
          ),
        ),
      ),

      child:
      Column(
        crossAxisAlignment:
        CrossAxisAlignment.stretch,

        children: [
          const Row(
            children: [
              Icon(
                Icons
                    .verified_rounded,

                color:
                successGreen,

                size:
                21,
              ),

              SizedBox(
                width:
                8,
              ),

              Expanded(
                child:
                Text(
                  'Mission Verification',

                  style:
                  TextStyle(
                    color:
                    darkText,

                    fontSize:
                    13.5,

                    fontWeight:
                    FontWeight.w900,
                  ),
                ),
              ),

              _VerifiedPill(),
            ],
          ),

          const SizedBox(
            height:
            16,
          ),

          // ===============================================================
          // PHOTO
          // ===============================================================

          _buildEvidenceImage(),

          const SizedBox(
            height:
            15,
          ),

          // ===============================================================
          // GPS
          // ===============================================================

          const _VerificationRow(
            icon:
            Icons
                .my_location_rounded,

            label:
            'GPS Confirmed',
          ),

          const SizedBox(
            height:
            9,
          ),

          // ===============================================================
          // AI
          // ===============================================================

          const _VerificationRow(
            icon:
            Icons
                .auto_awesome_rounded,

            label:
            'AI Photo Verification',
          ),

          const SizedBox(
            height:
            14,
          ),

          // ===============================================================
          // SIMPLE USER RESULT
          // ===============================================================

          Container(
            padding:
            const EdgeInsets.all(
              14,
            ),

            decoration:
            BoxDecoration(
              color:
              lightGreen,

              borderRadius:
              BorderRadius.circular(
                15,
              ),

              border:
              Border.all(
                color:
                greenBorder,
              ),
            ),

            child:
            Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [
                Container(
                  width:
                  34,

                  height:
                  34,

                  decoration:
                  BoxDecoration(
                    color:
                    Colors.white,

                    borderRadius:
                    BorderRadius.circular(
                      10,
                    ),
                  ),

                  child:
                  const Icon(
                    Icons
                        .check_circle_rounded,

                    color:
                    successGreen,

                    size:
                    20,
                  ),
                ),

                const SizedBox(
                  width:
                  10,
                ),

                const Expanded(
                  child:
                  Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,

                    children: [
                      Text(
                        'Photo Verified',

                        style:
                        TextStyle(
                          color:
                          Color(
                            0xFF047857,
                          ),

                          fontSize:
                          11.5,

                          fontWeight:
                          FontWeight.w900,
                        ),
                      ),

                      SizedBox(
                        height:
                        4,
                      ),

                      Text(
                        'Your photo matches the mission requirement.',

                        style:
                        TextStyle(
                          color:
                          Color(
                            0xFF475569,
                          ),

                          fontSize:
                          11.5,

                          height:
                          1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ===============================================================
          // DETAILS
          // ===============================================================

          Align(
            alignment:
            Alignment.centerRight,

            child:
            TextButton.icon(
              onPressed:
                  () {
                _showVerificationDetails(
                  context,
                );
              },

              icon:
              const Icon(
                Icons
                    .info_outline_rounded,

                size:
                16,
              ),

              label:
              const Text(
                'View verification details',

                style:
                TextStyle(
                  fontSize:
                  10.5,

                  fontWeight:
                  FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // EVIDENCE IMAGE
  // ===========================================================================

  Widget _buildEvidenceImage() {
    final String path =
        _controller.photoPath
            ?.trim() ??
            '';

    if (path.isNotEmpty) {
      final File file =
      File(path);

      if (file.existsSync()) {
        return ClipRRect(
          borderRadius:
          BorderRadius.circular(
            18,
          ),

          child:
          Image.file(
            file,

            height:
            220,

            width:
            double.infinity,

            fit:
            BoxFit.cover,

            errorBuilder:
                (
                context,
                error,
                stackTrace,
                ) {
              return _buildDestinationImage();
            },
          ),
        );
      }
    }

    return _buildDestinationImage();
  }

  Widget _buildDestinationImage() {
    final String imageUrl =
        _controller
            .destination
            .imageUrl
            ?.trim() ??
            '';

    if (imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius:
        BorderRadius.circular(
          18,
        ),

        child:
        Image.network(
          imageUrl,

          height:
          220,

          width:
          double.infinity,

          fit:
          BoxFit.cover,

          errorBuilder:
              (
              context,
              error,
              stackTrace,
              ) {
            return _buildEmptyImage();
          },
        ),
      );
    }

    return _buildEmptyImage();
  }

  Widget _buildEmptyImage() {
    return Container(
      height:
      220,

      decoration:
      BoxDecoration(
        color:
        const Color(
          0xFFE0F2FE,
        ),

        borderRadius:
        BorderRadius.circular(
          18,
        ),
      ),

      child:
      const Center(
        child:
        Icon(
          Icons
              .image_rounded,

          color:
          skyBlue,

          size:
          58,
        ),
      ),
    );
  }
}

// =============================================================================
// VERIFIED PILL
// =============================================================================

class _VerifiedPill extends StatelessWidget {
  const _VerifiedPill();

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal:
        8,

        vertical:
        5,
      ),

      decoration:
      BoxDecoration(
        color:
        const Color(
          0xFF059669,
        ),

        borderRadius:
        BorderRadius.circular(
          18,
        ),
      ),

      child:
      const Row(
        mainAxisSize:
        MainAxisSize.min,

        children: [
          Icon(
            Icons
                .check_circle_rounded,

            color:
            Colors.white,

            size:
            12,
          ),

          SizedBox(
            width:
            3,
          ),

          Text(
            'VERIFIED',

            style:
            TextStyle(
              color:
              Colors.white,

              fontSize:
              8,

              fontWeight:
              FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// VERIFICATION ROW
// =============================================================================

class _VerificationRow
    extends StatelessWidget {
  const _VerificationRow({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(
      BuildContext context,
      ) {
    return Row(
      children: [
        Container(
          width:
          34,

          height:
          34,

          decoration:
          BoxDecoration(
            color:
            const Color(
              0xFFECFDF5,
            ),

            borderRadius:
            BorderRadius.circular(
              10,
            ),
          ),

          child:
          Icon(
            icon,

            color:
            const Color(
              0xFF059669,
            ),

            size:
            18,
          ),
        ),

        const SizedBox(
          width:
          10,
        ),

        Expanded(
          child:
          Text(
            label,

            style:
            const TextStyle(
              color:
              Color(
                0xFF475569,
              ),

              fontSize:
              11.5,

              fontWeight:
              FontWeight.w700,
            ),
          ),
        ),

        Container(
          padding:
          const EdgeInsets.symmetric(
            horizontal:
            9,

            vertical:
            5,
          ),

          decoration:
          BoxDecoration(
            color:
            const Color(
              0xFFECFDF5,
            ),

            borderRadius:
            BorderRadius.circular(
              99,
            ),
          ),

          child:
          const Text(
            'VERIFIED',

            style:
            TextStyle(
              color:
              Color(
                0xFF059669,
              ),

              fontSize:
              8,

              fontWeight:
              FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}