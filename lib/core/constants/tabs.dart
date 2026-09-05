import 'package:flutter/material.dart';

enum MysteryLaneTab {
  blindBox,
  missions,
  plan,
  teams,
}

extension MysteryLaneTabExtension on MysteryLaneTab {
  String get label {
    switch (this) {
      case MysteryLaneTab.blindBox:
        return 'BLIND BOX';
      case MysteryLaneTab.missions:
        return 'MISSIONS';
      case MysteryLaneTab.plan:
        return 'PLAN';
      case MysteryLaneTab.teams:
        return 'TEAMS';
    }
  }

  IconData get icon {
    switch (this) {
      case MysteryLaneTab.blindBox:
        return Icons.inventory_2_outlined;
      case MysteryLaneTab.missions:
        return Icons.assignment_outlined;
      case MysteryLaneTab.plan:
        return Icons.map_outlined;
      case MysteryLaneTab.teams:
        return Icons.groups_2_outlined;
    }
  }
}