import 'package:flutter/material.dart';

class CompleteMissionScreen extends StatelessWidget {
  const CompleteMissionScreen({
    super.key,
    required this.title,
    required this.reward,
    required this.totalPoints,
  });

  final String title;
  final int reward;
  final int totalPoints;

  static const Color skyBlue = Color(0xFF0284C7);
  static const Color darkBlue = Color(0xFF0369A1);
  static const Color pageBackground = Color(0xFFF8FAFC);
  static const Color darkText = Color(0xFF0F172A);

  void _returnToMap(BuildContext context) {
    // Because CheckpointMissionScreen was replaced by this screen,
    // popping this page returns directly to CheckpointScreen.
    // The reward value is returned so the map page can update EP points.
    Navigator.pop(context, reward);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              const SizedBox(height: 20),
              _buildSuccessCard(),
              const SizedBox(height: 16),
              _buildEvidenceCard(),
              const SizedBox(height: 18),
              SizedBox(
                height: 50,
                child: FilledButton.icon(
                  onPressed: () => _returnToMap(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  icon: const Icon(Icons.explore_rounded),
                  label: const Text(
                    'RETURN TO CHECKPOINT MAP',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          'Puzzle Challenge UI will be connected later.',
                        ),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: skyBlue,
                    side: const BorderSide(color: skyBlue),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text(
                    'PUZZLE CHALLENGE',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
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

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Material(
          color: Colors.white,
          shape: const CircleBorder(),
          elevation: 1,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => _returnToMap(context),
            child: const SizedBox(
              width: 42,
              height: 42,
              child: Icon(
                Icons.arrow_back_rounded,
                size: 21,
                color: Color(0xFF334155),
              ),
            ),
          ),
        ),
        const Expanded(
          child: Text(
            'Mission Completed!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: darkText,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F9FF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFBAE6FD)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.toll_rounded,
                size: 17,
                color: skyBlue,
              ),
              const SizedBox(width: 4),
              Text(
                '$totalPoints',
                style: const TextStyle(
                  color: skyBlue,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 25),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [skyBlue, darkBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color(0x330284C7),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0x33FBBF24),
              border: Border.all(
                color: const Color(0xFFFCD34D),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: Color(0xFFFCD34D),
              size: 44,
            ),
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.24),
              ),
            ),
            child: const Text(
              '✦ CHECKPOINT MASTERED ✦',
              style: TextStyle(
                color: Color(0xFFE0F2FE),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.9,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Mission evidence captured and checkpoint verified!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFDBEAFE),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 17),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 9,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFFBBF24),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.star_rounded,
                  color: darkText,
                  size: 18,
                ),
                const SizedBox(width: 5),
                Text(
                  '+$reward EP Points',
                  style: const TextStyle(
                    color: darkText,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvidenceCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(
                Icons.camera_alt_rounded,
                color: skyBlue,
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Captured Mission Evidence',
                  style: TextStyle(
                    color: darkText,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _VerifiedPill(),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFDDF4FF),
                  Color(0xFFBAE6FD),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              children: [
                const Center(
                  child: Icon(
                    Icons.landscape_rounded,
                    size: 76,
                    color: Color(0x660284C7),
                  ),
                ),
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xD90F172A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Expanded(
                          child: Text(
                            '📍 Checkpoint Marker',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        Text(
                          'GPS Confirmed',
                          style: TextStyle(
                            color: Color(0xFF6EE7B7),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
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

class _VerifiedPill extends StatelessWidget {
  const _VerifiedPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF059669),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_rounded,
            color: Colors.white,
            size: 13,
          ),
          SizedBox(width: 3),
          Text(
            'VERIFIED',
            style: TextStyle(
              color: Colors.white,
              fontSize: 8.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
