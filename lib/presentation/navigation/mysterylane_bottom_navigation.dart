import 'package:flutter/material.dart';

enum MysteryLaneBottomItem {
  blindBox,
  missions,
  plan,
  teams,
}

class MysteryLaneBottomBar extends StatelessWidget {
  final MysteryLaneBottomItem selectedItem;

  final VoidCallback onBlindBoxTap;
  final VoidCallback onMissionsTap;
  final VoidCallback onPlanTap;
  final VoidCallback onTeamsTap;

  const MysteryLaneBottomBar({
    super.key,
    required this.selectedItem,
    required this.onBlindBoxTap,
    required this.onMissionsTap,
    required this.onPlanTap,
    required this.onTeamsTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      height: 78,
      padding: EdgeInsets.zero,
      elevation: 18,
      color: Colors.white,
      shadowColor: const Color(0x220F172A),
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,

      child: Row(
        children: [
          // ====================================================
          // BLIND BOX
          // ====================================================

          Expanded(
            child: _BottomItem(
              icon: Icons.inventory_2_outlined,
              label: 'BLIND\nBOX',
              selected:
              selectedItem ==
                  MysteryLaneBottomItem.blindBox,
              onTap: onBlindBoxTap,
            ),
          ),

          // ====================================================
          // MISSIONS
          // ====================================================

          Expanded(
            child: _BottomItem(
              icon: Icons.assignment_outlined,
              label: 'MISSIONS',
              selected:
              selectedItem ==
                  MysteryLaneBottomItem.missions,
              onTap: onMissionsTap,
            ),
          ),

          // Space for centre Home button
          const SizedBox(
            width: 72,
          ),

          // ====================================================
          // PLAN
          // ====================================================

          Expanded(
            child: _BottomItem(
              icon: Icons.map_outlined,
              label: 'PLAN',
              selected:
              selectedItem ==
                  MysteryLaneBottomItem.plan,
              onTap: onPlanTap,
            ),
          ),

          // ====================================================
          // TEAMS
          // ====================================================

          Expanded(
            child: _BottomItem(
              icon: Icons.groups_2_outlined,
              label: 'TEAMS',
              selected:
              selectedItem ==
                  MysteryLaneBottomItem.teams,
              onTap: onTeamsTap,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// BOTTOM NAV ITEM
// ============================================================

class _BottomItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BottomItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    const Color blue =
    Color(0xFF0284C7);

    return InkWell(
      onTap: onTap,

      child: Padding(
        padding:
        const EdgeInsets.only(
          top: 10,
          bottom: 4,
        ),

        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,

          children: [
            AnimatedContainer(
              duration:
              const Duration(
                milliseconds: 160,
              ),

              width: 42,
              height: 29,

              decoration:
              BoxDecoration(
                color:
                selected
                    ? blue
                    : Colors.transparent,

                borderRadius:
                BorderRadius.circular(
                  12,
                ),
              ),

              child: Icon(
                icon,

                size: 21,

                color:
                selected
                    ? Colors.white
                    : const Color(
                  0xFF64748B,
                ),
              ),
            ),

            const SizedBox(
              height: 3,
            ),

            Text(
              label,

              maxLines: 2,

              textAlign:
              TextAlign.center,

              overflow:
              TextOverflow.clip,

              style:
              TextStyle(
                color:
                selected
                    ? blue
                    : const Color(
                  0xFF64748B,
                ),

                fontSize: 8,

                fontWeight:
                FontWeight.w800,

                letterSpacing:
                0.45,

                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// CENTER HOME FLOATING BUTTON
// ============================================================

class MysteryLaneHomeFloatingButton
    extends StatelessWidget {
  final VoidCallback onTap;

  const MysteryLaneHomeFloatingButton({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
      const EdgeInsets.only(
        top: 10,
      ),

      child: InkWell(
        customBorder:
        const CircleBorder(),

        onTap:
        onTap,

        child: Container(
          width: 62,
          height: 62,

          decoration:
          BoxDecoration(
            shape:
            BoxShape.circle,

            gradient:
            const LinearGradient(
              colors: [
                Color(0xFF0284C7),
                Color(0xFF0D9488),
              ],

              begin:
              Alignment.topLeft,

              end:
              Alignment.bottomRight,
            ),

            border:
            Border.all(
              color:
              Colors.white,

              width:
              4,
            ),

            boxShadow:
            const [
              BoxShadow(
                color:
                Color(
                  0x3D0284C7,
                ),

                blurRadius:
                16,

                offset:
                Offset(
                  0,
                  7,
                ),
              ),
            ],
          ),

          child:
          const Column(
            mainAxisAlignment:
            MainAxisAlignment.center,

            children: [
              Icon(
                Icons.home_rounded,

                color:
                Color(
                  0xFFFDE68A,
                ),

                size:
                27,
              ),

              Text(
                'HOME',

                style:
                TextStyle(
                  color:
                  Colors.white,

                  fontSize:
                  8,

                  fontWeight:
                  FontWeight.w900,

                  letterSpacing:
                  0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}