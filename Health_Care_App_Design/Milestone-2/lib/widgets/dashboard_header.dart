import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The top bar of a dashboard: drawer button, greeting, notification bell,
/// all inside the same neon green box used on the sign in screen.
class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    required this.userName,
    required this.onMenuPressed,
    required this.onBellPressed,
    this.unreadCount = 0,
  });

  final String userName;
  final VoidCallback onMenuPressed;
  final VoidCallback onBellPressed;
  /// Draws the little red dot on the bell when there is something to read.
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.neonGreen, width: 3),
        borderRadius: BorderRadius.circular(12),
        // A soft outer glow so the border reads as "neon", the same as the
        // app name box on screen 1.
        boxShadow: const [
          BoxShadow(
            color: AppColors.neonGreen,
            blurRadius: 14,
            spreadRadius: -3,
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onMenuPressed,
            icon: const Icon(Icons.menu),
            iconSize: 30,
            color: AppColors.textDark,
            tooltip: 'Menu',
          ),

          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Welcome',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  userName,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),

          // Stack so the unread dot can sit on the corner of the bell.
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                onPressed: onBellPressed,
                icon: const Icon(Icons.notifications_outlined),
                iconSize: 30,
                color: AppColors.textDark,
                tooltip: 'Notifications',
              ),
              if (unreadCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}