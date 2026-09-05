import 'dart:io';

import 'package:flutter/material.dart';

class CompleteMissionScreen extends StatelessWidget {
  final String title;

  final int reward;

  final int totalPoints;

  // ============================================================
  // NEW
  // ============================================================

  final String? photoPath;

  final String? verificationReason;

  final double? verificationConfidence;

  const CompleteMissionScreen({
    super.key,
    required this.title,
    required this.reward,
    required this.totalPoints,
    this.photoPath,
    this.verificationReason,
    this.verificationConfidence,
  });

  // ============================================================
  // RETURN TO CHECKPOINT
  // ============================================================

  void _returnToCheckpoint(
      BuildContext context,
      ) {
    Navigator.pop(
      context,
      reward,
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      backgroundColor:
      const Color(
        0xFFF8FAFC,
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding:
          const EdgeInsets.fromLTRB(
            18,
            12,
            18,
            30,
          ),

          child: Column(
            children: [
              // =================================================
              // HEADER
              // =================================================

              _buildHeader(
                context,
              ),

              const SizedBox(
                height: 18,
              ),

              // =================================================
              // COMPLETION HERO
              // =================================================

              _buildCompletionHero(),

              const SizedBox(
                height: 18,
              ),

              // =================================================
              // MISSION VERIFICATION
              // =================================================

              _buildVerificationCard(),

              const SizedBox(
                height: 20,
              ),

              // =================================================
              // RETURN BUTTON
              // =================================================

              SizedBox(
                width:
                double.infinity,

                child:
                ElevatedButton.icon(
                  onPressed: () {
                    _returnToCheckpoint(
                      context,
                    );
                  },

                  icon:
                  const Icon(
                    Icons
                        .explore_rounded,

                    size:
                    18,
                  ),

                  label:
                  const Text(
                    'RETURN TO CHECKPOINTS',
                  ),

                  style:
                  ElevatedButton
                      .styleFrom(
                    backgroundColor:
                    const Color(
                      0xFF1E293B,
                    ),

                    foregroundColor:
                    Colors.white,

                    elevation: 0,

                    padding:
                    const EdgeInsets
                        .symmetric(
                      vertical: 16,
                    ),

                    textStyle:
                    const TextStyle(
                      fontSize: 12,

                      fontWeight:
                      FontWeight.w800,

                      letterSpacing:
                      0.4,
                    ),

                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(
                        30,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 10,
              ),

              // =================================================
              // PUZZLE
              // =================================================

              SizedBox(
                width:
                double.infinity,

                child:
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(
                      const SnackBar(
                        behavior:
                        SnackBarBehavior
                            .floating,

                        content:
                        Text(
                          'Puzzle Challenge will be connected later.',
                        ),
                      ),
                    );
                  },

                  icon:
                  const Icon(
                    Icons
                        .auto_awesome_rounded,

                    size:
                    18,
                  ),

                  label:
                  const Text(
                    'PUZZLE CHALLENGE',
                  ),

                  style:
                  OutlinedButton
                      .styleFrom(
                    foregroundColor:
                    const Color(
                      0xFF0284C7,
                    ),

                    side:
                    const BorderSide(
                      color:
                      Color(
                        0xFF0284C7,
                      ),
                    ),

                    padding:
                    const EdgeInsets
                        .symmetric(
                      vertical: 16,
                    ),

                    textStyle:
                    const TextStyle(
                      fontSize: 12,

                      fontWeight:
                      FontWeight.w800,

                      letterSpacing:
                      0.4,
                    ),

                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(
                        30,
                      ),
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

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader(
      BuildContext context,
      ) {
    return Row(
      children: [
        IconButton(
          onPressed: () {
            _returnToCheckpoint(
              context,
            );
          },

          icon:
          const Icon(
            Icons
                .arrow_back_ios_new_rounded,

            color:
            Color(
              0xFF0F172A,
            ),

            size: 20,
          ),
        ),

        const Expanded(
          child: Text(
            'Mission Completed!',

            textAlign:
            TextAlign.center,

            style:
            TextStyle(
              color:
              Color(
                0xFF0F172A,
              ),

              fontSize: 20,

              fontWeight:
              FontWeight.w900,
            ),
          ),
        ),

        Container(
          padding:
          const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 7,
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

            border: Border.all(
              color:
              const Color(
                0xFFBAE6FD,
              ),
            ),
          ),

          child: Row(
            children: [
              const Icon(
                Icons
                    .toll_rounded,

                size: 15,

                color:
                Color(
                  0xFF0284C7,
                ),
              ),

              const SizedBox(
                width: 4,
              ),

              Text(
                '$totalPoints',

                style:
                const TextStyle(
                  color:
                  Color(
                    0xFF0284C7,
                  ),

                  fontSize: 11,

                  fontWeight:
                  FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // COMPLETION HERO
  // ============================================================

  Widget _buildCompletionHero() {
    return Container(
      width:
      double.infinity,

      padding:
      const EdgeInsets.fromLTRB(
        20,
        27,
        20,
        24,
      ),

      decoration:
      BoxDecoration(
        gradient:
        const LinearGradient(
          colors: [
            Color(
              0xFF0284C7,
            ),
            Color(
              0xFF0369A1,
            ),
          ],

          begin:
          Alignment.topLeft,

          end:
          Alignment.bottomRight,
        ),

        borderRadius:
        BorderRadius.circular(
          28,
        ),

        boxShadow:
        const [
          BoxShadow(
            color:
            Color(
              0x260284C7,
            ),

            blurRadius: 18,

            offset:
            Offset(
              0,
              8,
            ),
          ),
        ],
      ),

      child: Column(
        children: [
          // Trophy
          Container(
            width: 82,
            height: 82,

            decoration:
            BoxDecoration(
              shape:
              BoxShape.circle,

              color:
              const Color(
                0x1AFFFFFF,
              ),

              border:
              Border.all(
                color:
                const Color(
                  0xFFFACC15,
                ),

                width: 2,
              ),
            ),

            child:
            const Icon(
              Icons.emoji_events_rounded,

              size: 37,

              color:
              Color(
                0xFFFACC15,
              ),
            ),
          ),

          const SizedBox(
            height: 18,
          ),

          Text(
            title,

            textAlign:
            TextAlign.center,

            style:
            const TextStyle(
              color:
              Colors.white,

              fontSize: 20,

              fontWeight:
              FontWeight.w900,
            ),
          ),

          const SizedBox(
            height: 7,
          ),

          const Text(
            'Mission evidence captured and checkpoint verified!',

            textAlign:
            TextAlign.center,

            style:
            TextStyle(
              color:
              Color(
                0xFFBAE6FD,
              ),

              fontSize: 11,
            ),
          ),

          const SizedBox(
            height: 17,
          ),

          Container(
            padding:
            const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 10,
            ),

            decoration:
            BoxDecoration(
              color:
              const Color(
                0xFFFBBF24,
              ),

              borderRadius:
              BorderRadius.circular(
                30,
              ),
            ),

            child: Row(
              mainAxisSize:
              MainAxisSize.min,

              children: [
                const Icon(
                  Icons.star_rounded,

                  color:
                  Color(
                    0xFF0F172A,
                  ),

                  size: 21,
                ),

                const SizedBox(
                  width: 6,
                ),

                Text(
                  '+$reward Exploration Points',

                  style:
                  const TextStyle(
                    color:
                    Color(
                      0xFF0F172A,
                    ),

                    fontSize: 12,

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

  // ============================================================
  // VERIFICATION CARD
  // ============================================================

  Widget _buildVerificationCard() {
    return Container(
      width:
      double.infinity,

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

      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [
          // ====================================================
          // TITLE + VERIFIED BADGE
          // ====================================================

          Row(
            children: [
              const Icon(
                Icons.verified_rounded,

                color:
                Color(
                  0xFF059669,
                ),

                size: 21,
              ),

              const SizedBox(
                width: 8,
              ),

              const Expanded(
                child: Text(
                  'Mission Verification',

                  style:
                  TextStyle(
                    color:
                    Color(
                      0xFF0F172A,
                    ),

                    fontSize: 14,

                    fontWeight:
                    FontWeight.w800,
                  ),
                ),
              ),

              const _VerifiedPill(),
            ],
          ),

          const SizedBox(
            height: 16,
          ),

          // ====================================================
          // ACTUAL SUBMITTED PHOTO
          // ====================================================

          if (photoPath != null &&
              photoPath!.isNotEmpty &&
              File(photoPath!).existsSync())
            ClipRRect(
              borderRadius:
              BorderRadius.circular(
                18,
              ),

              child: Image.file(
                File(
                  photoPath!,
                ),

                width:
                double.infinity,

                height: 230,

                fit:
                BoxFit.cover,
              ),
            )
          else
            Container(
              width:
              double.infinity,

              height: 150,

              decoration:
              BoxDecoration(
                color:
                const Color(
                  0xFFEFF6FF,
                ),

                borderRadius:
                BorderRadius.circular(
                  18,
                ),
              ),

              child:
              const Column(
                mainAxisAlignment:
                MainAxisAlignment.center,

                children: [
                  Icon(
                    Icons
                        .camera_alt_rounded,

                    color:
                    Color(
                      0xFF2563EB,
                    ),

                    size: 40,
                  ),

                  SizedBox(
                    height: 10,
                  ),

                  Text(
                    'Mission Photo Submitted',

                    style:
                    TextStyle(
                      color:
                      Color(
                        0xFF334155,
                      ),

                      fontWeight:
                      FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(
            height: 15,
          ),

          // ====================================================
          // GPS STATUS
          // ====================================================

          _buildVerificationRow(
            icon:
            Icons.my_location_rounded,

            label:
            'GPS Confirmed',

            value:
            'VERIFIED',
          ),

          const SizedBox(
            height: 10,
          ),

          // ====================================================
          // GEMINI STATUS
          // ====================================================

          _buildVerificationRow(
            icon:
            Icons
                .psychology_alt_rounded,

            label:
            'Gemini Photo Verification',

            value:
            'VERIFIED',
          ),

          // ====================================================
          // GEMINI REASON
          // ====================================================

          if (verificationReason !=
              null &&
              verificationReason!
                  .isNotEmpty) ...[
            const SizedBox(
              height: 16,
            ),

            Container(
              width:
              double.infinity,

              padding:
              const EdgeInsets.all(
                14,
              ),

              decoration:
              BoxDecoration(
                color:
                const Color(
                  0xFFF0FDF4,
                ),

                borderRadius:
                BorderRadius.circular(
                  15,
                ),

                border:
                Border.all(
                  color:
                  const Color(
                    0xFFBBF7D0,
                  ),
                ),
              ),

              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,

                children: [
                  const Text(
                    'Gemini Verification Result',

                    style:
                    TextStyle(
                      color:
                      Color(
                        0xFF047857,
                      ),

                      fontSize: 11,

                      fontWeight:
                      FontWeight.w800,
                    ),
                  ),

                  const SizedBox(
                    height: 7,
                  ),

                  Text(
                    verificationReason!,

                    style:
                    const TextStyle(
                      color:
                      Color(
                        0xFF475569,
                      ),

                      fontSize: 12,

                      height: 1.45,
                    ),
                  ),

                  if (verificationConfidence !=
                      null) ...[
                    const SizedBox(
                      height: 10,
                    ),

                    Row(
                      children: [
                        const Icon(
                          Icons
                              .analytics_outlined,

                          size: 15,

                          color:
                          Color(
                            0xFF059669,
                          ),
                        ),

                        const SizedBox(
                          width: 5,
                        ),

                        Text(
                          'Confidence: '
                              '${(verificationConfidence! * 100).toStringAsFixed(0)}%',

                          style:
                          const TextStyle(
                            color:
                            Color(
                              0xFF047857,
                            ),

                            fontSize:
                            11,

                            fontWeight:
                            FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // VERIFICATION ROW
  // ============================================================

  Widget _buildVerificationRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          width: 35,
          height: 35,

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

          child: Icon(
            icon,

            size: 18,

            color:
            const Color(
              0xFF059669,
            ),
          ),
        ),

        const SizedBox(
          width: 10,
        ),

        Expanded(
          child: Text(
            label,

            style:
            const TextStyle(
              color:
              Color(
                0xFF475569,
              ),

              fontSize: 12,

              fontWeight:
              FontWeight.w600,
            ),
          ),
        ),

        Container(
          padding:
          const EdgeInsets.symmetric(
            horizontal: 9,
            vertical: 5,
          ),

          decoration:
          BoxDecoration(
            color:
            const Color(
              0xFFECFDF5,
            ),

            borderRadius:
            BorderRadius.circular(
              20,
            ),
          ),

          child: Text(
            value,

            style:
            const TextStyle(
              color:
              Color(
                0xFF059669,
              ),

              fontSize: 9,

              fontWeight:
              FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// VERIFIED PILL
// ============================================================

class _VerifiedPill extends StatelessWidget {
  const _VerifiedPill();

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),

      decoration:
      BoxDecoration(
        color:
        const Color(
          0xFF059669,
        ),

        borderRadius:
        BorderRadius.circular(
          20,
        ),
      ),

      child:
      const Row(
        mainAxisSize:
        MainAxisSize.min,

        children: [
          Icon(
            Icons.check_circle,

            color:
            Colors.white,

            size: 11,
          ),

          SizedBox(
            width: 4,
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