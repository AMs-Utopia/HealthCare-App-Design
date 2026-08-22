import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The main action button of a screen, e.g. "Sign in" or "Continue".
///
/// Kept separate so every screen uses the same button style.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.width = 190,
    this.trailingIcon,
    this.glow = false,
  });

  final String label;

  /// Passing null disables the button.
  final VoidCallback? onPressed;

  final double width;

  /// Optional icon shown after the label, e.g. the arrow on "Continue".
  final IconData? trailingIcon;

  /// Adds a neon green glow to show the button is "lit up" and ready.
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: width,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: glow
            ? const [
                BoxShadow(
                  color: AppColors.neonGreen,
                  blurRadius: 16,
                  spreadRadius: -2,
                ),
              ]
            : null,
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.logoGreen,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFCBD3D1),
          disabledForegroundColor: Colors.white,
          elevation: 2,
          // Trimmed from the default so the label and the arrow always fit.
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (trailingIcon != null) ...[
              const SizedBox(width: 8),
              Icon(trailingIcon, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}