import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The app name displayed inside a neon green border.

/// This is the top box of the sign in wireframe. It is kept as a separate
/// widget so other screens can show the same header.
class AppNameHeader extends StatelessWidget {
  const AppNameHeader({super.key, this.title = 'Health Care'});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.neonGreen, width: 3),
        borderRadius: BorderRadius.circular(12),
        // A soft outer glow so the border reads as "neon".
        boxShadow: const [
          BoxShadow(
            color: AppColors.neonGreen,
            blurRadius: 14,
            spreadRadius: -3,
          ),
        ],
      ),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: AppColors.textDark,
        ),
      ),
    );
  }
}