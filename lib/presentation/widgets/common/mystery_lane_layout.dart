import 'package:flutter/material.dart';
import '../../../core/constants/tabs.dart';
import 'mystery_lane_app_bar.dart';
import 'mystery_lane_bottom_nav.dart';

class MysteryLaneLayout extends StatelessWidget {
    final Widget child;
    final MysteryLaneTab selectedTab;
    final ValueChanged<MysteryLaneTab>? onTabSelected;
    final VoidCallback? onHomeTap;
    final String? appBarTitle;
    final VoidCallback? onLeaderboardTap;
    final VoidCallback? onChatTap;
    final VoidCallback? onProfileTap;
    final String? profileImageUrl;
    final PreferredSizeWidget? appBarBottom;
    final bool showFooter;

    const MysteryLaneLayout({
        super.key,
        required this.child,
        required this.selectedTab,
        this.onTabSelected,
        this.onHomeTap,
        this.appBarTitle = 'MYSTERYLANE',
        this.onLeaderboardTap,
        this.onChatTap,
        this.onProfileTap,
        this.profileImageUrl,
        this.appBarBottom,
        this.showFooter = true,
    });

    @override
    Widget build(BuildContext context) {
        return Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            extendBody: true,
        appBar: MysteryLaneAppBar(
        title: appBarTitle!,
        onLeaderboardTap: onLeaderboardTap,
        onChatTap: onChatTap,
        onProfileTap: onProfileTap,
        profileImageUrl: profileImageUrl,
        bottom: appBarBottom,
        ),
        body: child,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: showFooter
        ? MysteryLaneHomeButton(
        onTap: onHomeTap ?? () {
        Navigator.of(context).popUntil((route) => route.isFirst);
    },
        )
        : null,
        bottomNavigationBar: showFooter
        ? MysteryLaneBottomBar(
        selectedTab: selectedTab,
        onTabSelected: onTabSelected ?? (_) {},
        )
        : null,
        );
    }
}