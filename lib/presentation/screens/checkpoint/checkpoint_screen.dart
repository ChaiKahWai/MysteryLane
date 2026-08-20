import 'package:flutter/material.dart';
import 'checkpoint_mission_screen.dart';

class CheckpointScreen extends StatefulWidget {
  const CheckpointScreen({super.key});

  @override
  State<CheckpointScreen> createState() => _CheckpointScreenState();
}

class _CheckpointScreenState extends State<CheckpointScreen> {
  static const Color skyBlue = Color(0xFF0284C7);
  static const Color pageBackground = Color(0xFFF8FAFC);
  static const Color darkText = Color(0xFF0F172A);
  static const Color bodyText = Color(0xFF64748B);

  int _userPoints = 450;

  final List<_CheckpointMission> _missions = const [
    _CheckpointMission(
      title: 'Heritage Explorer',
      description:
      'Reach the heritage checkpoint and capture a photo as proof of your visit.',
      reward: 120,
      distance: '1.2 km',
      duration: '~25 min',
      status: _MissionStatus.available,
      x: 0.23,
      y: 0.34,
    ),
    _CheckpointMission(
      title: 'City Landmark Hunt',
      description:
      'Visit this popular landmark, explore the surrounding area, and complete the photo mission.',
      reward: 200,
      distance: '2.4 km',
      duration: '~45 min',
      status: _MissionStatus.popular,
      x: 0.67,
      y: 0.27,
    ),
    _CheckpointMission(
      title: 'Hidden Garden Trail',
      description:
      'Discover a quieter local attraction and verify your arrival at the checkpoint.',
      reward: 180,
      distance: '3.1 km',
      duration: '~55 min',
      status: _MissionStatus.available,
      x: 0.74,
      y: 0.57,
    ),
    _CheckpointMission(
      title: 'Old Town Discovery',
      description:
      'You have already completed this checkpoint and collected its exploration reward.',
      reward: 150,
      distance: '0.8 km',
      duration: '~20 min',
      status: _MissionStatus.completed,
      x: 0.34,
      y: 0.69,
    ),
  ];

  late _CheckpointMission _selectedMission;

  @override
  void initState() {
    super.initState();
    _selectedMission = _missions[1];
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(18, 0, 18, 92),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  Future<void> _openMission() async {
    if (_selectedMission.status == _MissionStatus.completed) {
      _showMessage('This checkpoint has already been completed.');
      return;
    }

    final int? earnedPoints = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (context) => CheckpointMissionScreen(
          title: _selectedMission.title,
          description: _selectedMission.description,
          reward: _selectedMission.reward,
          distance: _selectedMission.distance,
          duration: _selectedMission.duration,
          currentPoints: _userPoints,
        ),
      ),
    );

    if (earnedPoints != null && mounted) {
      setState(() {
        _userPoints += earnedPoints;
      });

      _showMessage('Mission reward added: +$earnedPoints EP');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 12),
              const Row(
                children: [
                  Icon(Icons.explore_rounded, size: 17, color: skyBlue),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Available checkpoints within 5 km of your location',
                      style: TextStyle(
                        color: bodyText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(child: _buildMap()),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        _roundButton(
          icon: Icons.arrow_back_rounded,
          tooltip: 'Back',
          onTap: () => Navigator.maybePop(context),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xFFBAE6FD)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: skyBlue,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Checkpoint Mission',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(26),
                    onTap: () =>
                        _showMessage('Puzzle Challenge UI will be connected later.'),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 11),
                      child: Center(
                        child: Text(
                          'Puzzle Challenge',
                          style: TextStyle(
                            color: Color(0xFF475569),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.toll_rounded, size: 15, color: skyBlue),
              const SizedBox(width: 4),
              Text(
                '$_userPoints',
                style: const TextStyle(
                  color: skyBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMap() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFE8F3F8),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;

          return Stack(
            children: [
              const Positioned.fill(
                child: CustomPaint(
                  painter: _MockMapPainter(),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: _buildLegend(),
              ),
              Positioned(
                left: width * 0.49 - 19,
                top: height * 0.43 - 19,
                child: _buildUserLocationDot(),
              ),
              ..._missions.map(
                    (mission) => Positioned(
                  left: width * mission.x - 21,
                  top: height * mission.y - 21,
                  child: _buildMissionPin(mission),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: _buildMissionCard(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _LegendItem(color: Color(0xFF10B981), label: 'Completed'),
          _LegendItem(color: Color(0xFFF59E0B), label: 'Popular'),
          _LegendItem(color: skyBlue, label: 'Available'),
          _LegendItem(color: Color(0xFF38BDF8), label: 'You'),
        ],
      ),
    );
  }

  Widget _buildUserLocationDot() {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0x2738BDF8),
        border: Border.all(color: const Color(0x5538BDF8), width: 2),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: skyBlue,
          border: Border.all(color: Colors.white, width: 3),
        ),
      ),
    );
  }

  Widget _buildMissionPin(_CheckpointMission mission) {
    final selected = identical(_selectedMission, mission);

    final Color color = switch (mission.status) {
      _MissionStatus.completed => const Color(0xFF10B981),
      _MissionStatus.popular => const Color(0xFFF59E0B),
      _MissionStatus.available => skyBlue,
    };

    final IconData icon = switch (mission.status) {
      _MissionStatus.completed => Icons.check_rounded,
      _MissionStatus.popular => Icons.star_rounded,
      _MissionStatus.available => Icons.flag_rounded,
    };

    return GestureDetector(
      onTap: () => setState(() => _selectedMission = mission),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: selected ? 44 : 36,
        height: selected ? 44 : 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(selected ? 0.24 : 0.16),
              blurRadius: selected ? 14 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, size: selected ? 21 : 17, color: Colors.white),
      ),
    );
  }

  Widget _buildMissionCard() {
    final isCompleted = _selectedMission.status == _MissionStatus.completed;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: Container(
        key: ValueKey(_selectedMission.title),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.97),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x260F172A),
              blurRadius: 18,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F9FF),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    isCompleted
                        ? Icons.check_circle_rounded
                        : Icons.location_on_rounded,
                    color: isCompleted
                        ? const Color(0xFF10B981)
                        : skyBlue,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedMission.title,
                        style: const TextStyle(
                          color: darkText,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_selectedMission.distance} away • ${_selectedMission.duration}',
                        style: const TextStyle(
                          color: bodyText,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                _rewardPill(_selectedMission.reward),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _selectedMission.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF475569),
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 43,
              child: FilledButton.icon(
                onPressed: isCompleted ? null : _openMission,
                style: FilledButton.styleFrom(
                  backgroundColor: skyBlue,
                  disabledBackgroundColor: const Color(0xFFCBD5E1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                icon: Icon(
                  isCompleted
                      ? Icons.check_rounded
                      : Icons.flag_rounded,
                  size: 18,
                ),
                label: Text(
                  isCompleted ? 'MISSION COMPLETED' : 'VIEW MISSION',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rewardPill(int points) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0F2FE)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: skyBlue, size: 15),
          const SizedBox(width: 3),
          Text(
            '+$points pts',
            style: const TextStyle(
              color: skyBlue,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 1,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(icon, size: 21, color: const Color(0xFF334155)),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return SafeArea(
      top: false,
      child: Container(
        height: 76,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _bottomItem(Icons.casino_rounded, 'Blind Box', false),
            _bottomItem(Icons.location_on_rounded, 'Missions', true),
            _bottomItem(Icons.home_rounded, 'Home', false),
            _bottomItem(Icons.map_rounded, 'Plan', false),
            _bottomItem(Icons.groups_rounded, 'Teams', false),
          ],
        ),
      ),
    );
  }

  Widget _bottomItem(IconData icon, String label, bool selected) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        if (label == 'Missions') return;

        if (label == 'Home') {
          Navigator.maybePop(context);
          return;
        }

        _showMessage('$label pressed - UI only for now.');
      },
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 23,
              color: selected ? skyBlue : const Color(0xFF94A3B8),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? skyBlue : const Color(0xFF64748B),
                fontSize: 9.5,
                fontWeight:
                selected ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _MissionStatus { available, popular, completed }

class _CheckpointMission {
  const _CheckpointMission({
    required this.title,
    required this.description,
    required this.reward,
    required this.distance,
    required this.duration,
    required this.status,
    required this.x,
    required this.y,
  });

  final String title;
  final String description;
  final int reward;
  final String distance;
  final String duration;
  final _MissionStatus status;
  final double x;
  final double y;
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF475569),
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _MockMapPainter extends CustomPainter {
  const _MockMapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = const Color(0xFFE8F3F8);
    canvas.drawRect(Offset.zero & size, background);

    final greenArea = Paint()..color = const Color(0xFFD9F1E1);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.77, size.height * 0.22),
        width: size.width * 0.42,
        height: size.height * 0.27,
      ),
      greenArea,
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.18, size.height * 0.66),
        width: size.width * 0.45,
        height: size.height * 0.24,
      ),
      greenArea,
    );

    final roadBorder = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 21
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 17
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final road1 = Path()
      ..moveTo(-20, size.height * 0.18)
      ..cubicTo(
        size.width * 0.24,
        size.height * 0.24,
        size.width * 0.35,
        size.height * 0.52,
        size.width + 20,
        size.height * 0.56,
      );

    final road2 = Path()
      ..moveTo(size.width * 0.20, -20)
      ..cubicTo(
        size.width * 0.34,
        size.height * 0.28,
        size.width * 0.61,
        size.height * 0.45,
        size.width * 0.76,
        size.height + 20,
      );

    final road3 = Path()
      ..moveTo(-20, size.height * 0.80)
      ..cubicTo(
        size.width * 0.28,
        size.height * 0.68,
        size.width * 0.68,
        size.height * 0.82,
        size.width + 20,
        size.height * 0.74,
      );

    for (final path in [road1, road2, road3]) {
      canvas.drawPath(path, roadBorder);
      canvas.drawPath(path, road);
    }

    final smallRoad = Paint()
      ..color = Colors.white.withOpacity(0.85)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(size.width * 0.05, size.height * 0.42),
      Offset(size.width * 0.91, size.height * 0.34),
      smallRoad,
    );

    canvas.drawLine(
      Offset(size.width * 0.13, size.height * 0.57),
      Offset(size.width * 0.88, size.height * 0.65),
      smallRoad,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
