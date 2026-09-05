import 'package:flutter/material.dart';
import '../../presentation/screens/Blindbox/BlindBox_Screen.dart';
import '../../presentation/screens/checkpoint/checkpoint_screen.dart';
import '../../presentation/screens/plan/plan_screen.dart';
import '../../presentation/screens/group/group_screen.dart';
import '../../presentation/screens/home/home_screen.dart';
import '../../presentation/screens/profile/profile_screen.dart';
import '../../presentation/screens/profile/leaderboard_screen.dart';
import '../../presentation/screens/group/chat_list_screen.dart';
import '../../core/constants/tabs.dart';

class NavigationService {
    static final NavigationService _instance = NavigationService._internal();
    factory NavigationService() => _instance;
    NavigationService._internal();

    final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

    // ---- Main tabs (pushReplacement) ----
    void goToBlindBox() {
        navigatorKey.currentState?.pushReplacement(
            MaterialPageRoute(builder: (_) => const BlindBoxPage()),
        );
    }

    void goToMissions() {
        navigatorKey.currentState?.pushReplacement(
            MaterialPageRoute(builder: (_) => const CheckpointScreen()),
        );
    }

    void goToPlan() {
        navigatorKey.currentState?.pushReplacement(
            MaterialPageRoute(builder: (_) => const PlanScreen()),
        );
    }

    void goToTeams() {
        navigatorKey.currentState?.pushReplacement(
            MaterialPageRoute(builder: (_) => const GroupScreen()),
        );
    }

    void goHome() {
        navigatorKey.currentState?.popUntil((route) => route.isFirst);
    }

    // ---- Other screens (push, return Future) ----
    Future<T?> goToLeaderboard<T>() {
        return navigatorKey.currentState?.push<T>(
            MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
        ) ?? Future.value(null);
    }

    Future<T?> goToChat<T>() {
        return navigatorKey.currentState?.push<T>(
            MaterialPageRoute(builder: (_) => const ChatListScreen()),
        ) ?? Future.value(null);
    }

    Future<T?> goToProfile<T>() {
        return navigatorKey.currentState?.push<T>(
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
        ) ?? Future.value(null);
    }

    // ---- Helper for tab switching ----
    void switchTab(MysteryLaneTab tab) {
        switch (tab) {
            case MysteryLaneTab.blindBox:
                goToBlindBox();
                break;
            case MysteryLaneTab.missions:
                goToMissions();
                break;
            case MysteryLaneTab.plan:
                goToPlan();
                break;
            case MysteryLaneTab.teams:
                goToTeams();
                break;
        }
    }
}