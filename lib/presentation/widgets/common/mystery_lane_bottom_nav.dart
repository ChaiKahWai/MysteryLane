import 'package:flutter/material.dart';
import '../../../core/constants/tabs.dart';

// Bottom navigation bar (without the FAB)
class MysteryLaneBottomBar extends StatelessWidget {
  final MysteryLaneTab selectedTab;
  final ValueChanged<MysteryLaneTab> onTabSelected;

  const MysteryLaneBottomBar({
    super.key,
    required this.selectedTab,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      height: 78,
      padding: EdgeInsets.zero,
      color: Colors.white.withOpacity(0.98),
      elevation: 18,
      shadowColor: const Color(0x330284C7),
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: _BottomItem(
                icon: MysteryLaneTab.blindBox.icon,
                label: MysteryLaneTab.blindBox.label,
                active: selectedTab == MysteryLaneTab.blindBox,
                onTap: () => onTabSelected(MysteryLaneTab.blindBox),
              ),
            ),
            Expanded(
              child: _BottomItem(
                icon: MysteryLaneTab.missions.icon,
                label: MysteryLaneTab.missions.label,
                active: selectedTab == MysteryLaneTab.missions,
                onTap: () => onTabSelected(MysteryLaneTab.missions),
              ),
            ),
            const SizedBox(width: 74),
            Expanded(
              child: _BottomItem(
                icon: MysteryLaneTab.plan.icon,
                label: MysteryLaneTab.plan.label,
                active: selectedTab == MysteryLaneTab.plan,
                onTap: () => onTabSelected(MysteryLaneTab.plan),
              ),
            ),
            Expanded(
              child: _BottomItem(
                icon: MysteryLaneTab.teams.icon,
                label: MysteryLaneTab.teams.label,
                active: selectedTab == MysteryLaneTab.teams,
                onTap: () => onTabSelected(MysteryLaneTab.teams),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _BottomItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const Color blue = Color(0xFF0284C7);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 42,
              height: 29,
              decoration: BoxDecoration(
                color: active ? blue : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 21,
                color: active ? Colors.white : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: TextStyle(
                color: active ? blue : const Color(0xFF64748B),
                fontSize: 8,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Floating Home Button (to be used as floatingActionButton)
class MysteryLaneHomeButton extends StatelessWidget {
  final VoidCallback onTap;

  const MysteryLaneHomeButton({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 66,
          height: 66,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF0284C7), Color(0xFF0D9488)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: const [
              BoxShadow(
                color: Color(0x3D0284C7),
                blurRadius: 16,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.home_rounded,
                color: Color(0xFFFDE68A),
                size: 27,
              ),
              Text(
                'HOME',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}