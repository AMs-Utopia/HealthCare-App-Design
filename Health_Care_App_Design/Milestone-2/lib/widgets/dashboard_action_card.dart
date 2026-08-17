import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// One of the big square buttons on a dashboard.
/// Uses the same lit up treatment as the account type cards on screen 2: a
/// neon green border and glow while [selected] is true, so the user can see
/// which one they just tapped.
class DashboardActionCard extends StatelessWidget {
  const DashboardActionCard({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF0FFEC) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.neonGreen : AppColors.fieldBorder,
            width: selected ? 3 : 1.5,
          ),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: AppColors.neonGreen,
                    blurRadius: 14,
                    spreadRadius: -2,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 38,
              color: selected ? AppColors.logoGreen : AppColors.textMuted,
            ),
            const SizedBox(height: 10),
            // Flexible so a two line label like "Call a Hospital" shrinks to
            // fit the tile instead of overflowing it on a small screen.
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.logoGreen : AppColors.textDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}