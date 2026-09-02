import 'package:flutter/material.dart';

class CompleteMissionScreen
    extends StatelessWidget {
  const CompleteMissionScreen({
    super.key,
    required this.title,
    required this.reward,
    required this.totalPoints,
  });

  final String title;

  final int reward;

  final int totalPoints;

  static const Color skyBlue =
  Color(
    0xFF0284C7,
  );

  static const Color darkBlue =
  Color(
    0xFF0369A1,
  );

  static const Color pageBackground =
  Color(
    0xFFF8FAFC,
  );

  static const Color darkText =
  Color(
    0xFF0F172A,
  );

  // ============================================================
  // RETURN TO CHECKPOINT SCREEN
  // ============================================================

  void _returnToCheckpoint(
      BuildContext context,
      ) {
    Navigator.pop(
      context,
      reward,
    );
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      backgroundColor:
      pageBackground,

      body: SafeArea(
        child:
        SingleChildScrollView(
          padding:
          const EdgeInsets
              .fromLTRB(
            18,
            18,
            18,
            30,
          ),

          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment
                .stretch,

            children: [
              _buildHeader(
                context,
              ),

              const SizedBox(
                height:
                24,
              ),

              _buildSuccessCard(),

              const SizedBox(
                height:
                18,
              ),

              _buildEvidenceCard(),

              const SizedBox(
                height:
                22,
              ),

              SizedBox(
                height:
                52,

                child:
                FilledButton.icon(
                  onPressed: () {
                    _returnToCheckpoint(
                      context,
                    );
                  },

                  style:
                  FilledButton
                      .styleFrom(
                    backgroundColor:
                    const Color(
                      0xFF1E293B,
                    ),

                    foregroundColor:
                    Colors.white,

                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius
                          .circular(
                        26,
                      ),
                    ),
                  ),

                  icon:
                  const Icon(
                    Icons
                        .explore_rounded,
                  ),

                  label:
                  const Text(
                    'RETURN TO CHECKPOINTS',

                    style:
                    TextStyle(
                      fontSize:
                      12,

                      fontWeight:
                      FontWeight
                          .w900,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height:
                10,
              ),

              SizedBox(
                height:
                52,

                child:
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(
                      const SnackBar(
                        content:
                        Text(
                          'Puzzle Challenge will be connected later.',
                        ),
                      ),
                    );
                  },

                  style:
                  OutlinedButton
                      .styleFrom(
                    foregroundColor:
                    skyBlue,

                    side:
                    const BorderSide(
                      color:
                      skyBlue,
                    ),

                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius
                          .circular(
                        26,
                      ),
                    ),
                  ),

                  icon:
                  const Icon(
                    Icons
                        .auto_awesome_rounded,
                  ),

                  label:
                  const Text(
                    'PUZZLE CHALLENGE',

                    style:
                    TextStyle(
                      fontSize:
                      12,

                      fontWeight:
                      FontWeight
                          .w900,
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
                .arrow_back_rounded,
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
              21,

              fontWeight:
              FontWeight.w900,
            ),
          ),
        ),

        Container(
          padding:
          const EdgeInsets
              .symmetric(
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
            BorderRadius
                .circular(
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
                '$totalPoints',

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

  // ============================================================
  // SUCCESS CARD
  // ============================================================

  Widget _buildSuccessCard() {
    return Container(
      padding:
      const EdgeInsets
          .fromLTRB(
        22,
        28,
        22,
        25,
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
            86,

            height:
            86,

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
              44,
            ),
          ),

          const SizedBox(
            height:
            16,
          ),

          Text(
            title,

            textAlign:
            TextAlign.center,

            style:
            const TextStyle(
              color:
              Colors.white,

              fontSize:
              24,

              fontWeight:
              FontWeight.w900,
            ),
          ),

          const SizedBox(
            height:
            8,
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
              12,

              height:
              1.4,
            ),
          ),

          const SizedBox(
            height:
            18,
          ),

          Container(
            padding:
            const EdgeInsets
                .symmetric(
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
              BorderRadius
                  .circular(
                22,
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
                ),

                const SizedBox(
                  width:
                  5,
                ),

                Text(
                  '+$reward Exploration Points',

                  style:
                  const TextStyle(
                    color:
                    darkText,

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
  // EVIDENCE CARD
  // ============================================================

  Widget _buildEvidenceCard() {
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
        CrossAxisAlignment
            .start,

        children: [
          const Row(
            children: [
              Icon(
                Icons
                    .verified_rounded,

                color:
                Color(
                  0xFF059669,
                ),
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

                    fontWeight:
                    FontWeight.w800,
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

          Container(
            height:
            150,

            width:
            double.infinity,

            decoration:
            BoxDecoration(
              color:
              const Color(
                0xFFEFF6FF,
              ),

              borderRadius:
              BorderRadius
                  .circular(
                18,
              ),
            ),

            child:
            const Column(
              mainAxisAlignment:
              MainAxisAlignment
                  .center,

              children: [
                Icon(
                  Icons
                      .photo_camera_rounded,

                  size:
                  52,

                  color:
                  Color(
                    0xFF2563EB,
                  ),
                ),

                SizedBox(
                  height:
                  8,
                ),

                Text(
                  'Mission Photo Submitted',

                  style:
                  TextStyle(
                    color:
                    Color(
                      0xFF475569,
                    ),

                    fontWeight:
                    FontWeight.w600,
                  ),
                ),

                SizedBox(
                  height:
                  4,
                ),

                Text(
                  'GPS Confirmed',

                  style:
                  TextStyle(
                    color:
                    Color(
                      0xFF059669,
                    ),

                    fontSize:
                    12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VerifiedPill
    extends StatelessWidget {
  const _VerifiedPill();

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      padding:
      const EdgeInsets
          .symmetric(
        horizontal:
        9,

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
            13,
          ),

          SizedBox(
            width:
            4,
          ),

          Text(
            'VERIFIED',

            style:
            TextStyle(
              color:
              Colors.white,

              fontSize:
              9,

              fontWeight:
              FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}