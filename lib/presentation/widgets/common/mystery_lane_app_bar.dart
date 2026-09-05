import 'package:flutter/material.dart';
import '../../../core/constants/tabs.dart';

class MysteryLaneAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onLeaderboardTap;
  final VoidCallback? onChatTap;
  final VoidCallback? onProfileTap;
  final String? profileImageUrl;
  final PreferredSizeWidget? bottom; // optional TabBar

  const MysteryLaneAppBar({
    super.key,
    required this.title,
    this.onLeaderboardTap,
    this.onChatTap,
    this.onProfileTap,
    this.profileImageUrl,
    this.bottom,
  });

  @override
  Size get preferredSize => Size.fromHeight(
      kToolbarHeight + (bottom?.preferredSize.height ?? 0) + 4);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: 68,
      elevation: 0,
      scrolledUnderElevation: 2,
      backgroundColor: Colors.white.withOpacity(0.97),
      surfaceTintColor: Colors.white,
      titleSpacing: 16,
      title: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _MysteryLaneLogo(),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (onLeaderboardTap != null)
          _TopActionButton(
            tooltip: 'Leaderboard',
            icon: Icons.emoji_events_rounded,
            background: const Color(0xFFFFFBEB),
            foreground: const Color(0xFFD97706),
            onTap: onLeaderboardTap!,
          ),
        const SizedBox(width: 6),
        if (onChatTap != null)
          _TopActionButton(
            tooltip: 'Chat',
            icon: Icons.chat_bubble_outline_rounded,
            background: const Color(0xFFF0F9FF),
            foreground: const Color(0xFF0284C7),
            onTap: onChatTap!,
          ),
        const SizedBox(width: 6),
        _ProfileButton(
          onTap: onProfileTap ?? () {},
          imageUrl: profileImageUrl,
        ),
        const SizedBox(width: 12),
      ],
      bottom: bottom,
    );
  }
}

class _MysteryLaneLogo extends StatelessWidget {
  const _MysteryLaneLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF0284C7), Color(0xFF0D9488)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x300284C7),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(
        Icons.explore_rounded,
        color: Colors.white,
        size: 23,
      ),
    );
  }
}

class _TopActionButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  const _TopActionButton({
    required this.tooltip,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: background,
            shape: BoxShape.circle,
            border: Border.all(
              color: foreground.withOpacity(0.20),
            ),
          ),
          child: Icon(
            icon,
            color: foreground,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _ProfileButton extends StatelessWidget {
  final VoidCallback onTap;
  final String? imageUrl;

  const _ProfileButton({
    required this.onTap,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final String? cleanUrl = imageUrl?.trim();
    final ImageProvider? provider =
    (cleanUrl != null && cleanUrl.isNotEmpty)
        ? NetworkImage(cleanUrl)
        : null;

    return Tooltip(
      message: 'Profile',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFBAE6FD),
              width: 1.4,
            ),
          ),
          child: CircleAvatar(
            backgroundColor: const Color(0xFFE0F2FE),
            backgroundImage: provider,
            child: provider == null
                ? const Icon(
              Icons.person_rounded,
              size: 20,
              color: Color(0xFF0284C7),
            )
                : null,
          ),
        ),
      ),
    );
  }
}