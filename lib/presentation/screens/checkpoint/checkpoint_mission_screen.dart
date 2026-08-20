import 'package:flutter/material.dart';

import 'complete_mission_screen.dart';

class CheckpointMissionScreen extends StatefulWidget {
  const CheckpointMissionScreen({
    super.key,
    required this.title,
    required this.description,
    required this.reward,
    required this.distance,
    required this.duration,
    required this.currentPoints,
  });

  final String title;
  final String description;
  final int reward;
  final String distance;
  final String duration;
  final int currentPoints;

  @override
  State<CheckpointMissionScreen> createState() =>
      _CheckpointMissionScreenState();
}

class _CheckpointMissionScreenState extends State<CheckpointMissionScreen> {
  static const Color skyBlue = Color(0xFF0284C7);
  static const Color pageBackground = Color(0xFFF8FAFC);
  static const Color darkText = Color(0xFF0F172A);
  static const Color bodyText = Color(0xFF64748B);

  bool _photoAttached = false;

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  void _submitMission() {
    if (!_photoAttached) {
      _showMessage('Please attach mission evidence first.');
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => CompleteMissionScreen(
          title: widget.title,
          reward: widget.reward,
          totalPoints: widget.currentPoints + widget.reward,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildProgressCard(),
              const SizedBox(height: 13),
              _buildMissionDetailCard(),
              const SizedBox(height: 13),
              _buildStatusCard(),
              const SizedBox(height: 13),
              _buildEvidenceBox(),
              const SizedBox(height: 18),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _submitMission,
                  style: FilledButton.styleFrom(
                    backgroundColor: skyBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text(
                    'SUBMIT MISSION',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
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

  Widget _buildHeader() {
    return Row(
      children: [
        _roundButton(
          icon: Icons.arrow_back_rounded,
          onTap: () => Navigator.pop(context),
        ),
        const Expanded(
          child: Text(
            'Checkpoint Mission',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: darkText,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F9FF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFBAE6FD)),
          ),
          child: Row(
            children: [
              const Icon(Icons.toll_rounded, size: 16, color: skyBlue),
              const SizedBox(width: 4),
              Text(
                '${widget.currentPoints}',
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

  Widget _buildProgressCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Row(
        children: [
          Text(
            'Solo',
            style: TextStyle(
              color: darkText,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(20)),
              child: LinearProgressIndicator(
                value: 0.60,
                minHeight: 9,
                backgroundColor: Color(0xFFF1F5F9),
                valueColor: AlwaysStoppedAnimation<Color>(skyBlue),
              ),
            ),
          ),
          SizedBox(width: 12),
          Text(
            '60%',
            style: TextStyle(
              color: skyBlue,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMissionDetailCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.terrain_rounded,
                  color: skyBlue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    color: darkText,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _rewardPill(widget.reward),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.description,
            style: const TextStyle(
              color: bodyText,
              fontSize: 12,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 15),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 13),
          Row(
            children: [
              _missionMeta(
                Icons.directions_walk_rounded,
                widget.distance,
              ),
              const SizedBox(width: 12),
              _missionMeta(
                Icons.schedule_rounded,
                widget.duration,
              ),
              const SizedBox(width: 12),
              _missionMeta(
                Icons.camera_alt_outlined,
                'Photo',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE0F2FE)),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.check_circle_rounded,
            color: skyBlue,
            size: 19,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'In Progress • You are within the 80 m radius. Capture the required photo.',
              style: TextStyle(
                color: Color(0xFF334155),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvidenceBox() {
    return InkWell(
      borderRadius: BorderRadius.circular(25),
      onTap: () {
        setState(() {
          _photoAttached = !_photoAttached;
        });

        _showMessage(
          _photoAttached
              ? 'Mock mission photo attached.'
              : 'Mock mission photo removed.',
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 190,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: _photoAttached
                ? const Color(0xFF86EFAC)
                : const Color(0xFFCBD5E1),
            width: 2,
          ),
        ),
        child: _photoAttached
            ? const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: Color(0xFFECFDF5),
              child: Icon(
                Icons.photo_camera_back_rounded,
                color: Color(0xFF059669),
                size: 32,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Photo Attached!',
              style: TextStyle(
                color: Color(0xFF047857),
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Tap again to remove mock evidence',
              style: TextStyle(
                color: bodyText,
                fontSize: 11,
              ),
            ),
          ],
        )
            : const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_upload_outlined,
              color: skyBlue,
              size: 43,
            ),
            SizedBox(height: 10),
            Text(
              'Tap to capture mission evidence',
              style: TextStyle(
                color: darkText,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'JPG, JPEG, PNG • max 10 MB',
              style: TextStyle(
                color: bodyText,
                fontSize: 11,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'UI demo: tap this box to attach a mock photo',
              style: TextStyle(
                color: skyBlue,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _missionMeta(IconData icon, String text) {
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: skyBlue),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF475569),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rewardPill(int points) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0F2FE)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.star_rounded,
            color: skyBlue,
            size: 15,
          ),
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
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 1,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(
            icon,
            size: 21,
            color: const Color(0xFF334155),
          ),
        ),
      ),
    );
  }
}
