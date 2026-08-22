import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
/// One of the two tappable boxes on the create account screen.

/// When [selected] is true the card lights up with a neon green border and
/// glow so the user can see which account type they picked.
class AccountTypeCard extends StatelessWidget {
  const AccountTypeCard({
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
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 10),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? AppColors.neonGreen.withValues(alpha: 0.18)
                    : const Color(0xFFEFF2F1),
                border: Border.all(
                  color: selected ? AppColors.logoGreen : AppColors.fieldBorder,
                  width: 2,
                ),
              ),
              child: Icon(
                icon,
                size: 44,
                color: selected ? AppColors.logoGreen : AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.logoGreen : AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}