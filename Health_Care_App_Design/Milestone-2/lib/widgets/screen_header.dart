import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'neon_divider.dart';
/// A back arrow and a screen title, closed off by a neon green line.
///
/// This is the top of the details wireframe. The glowing line uses the same
/// neon green as the app name box on the sign in screen so the two screens
/// look like they belong to the same app.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title, this.onBack});

  final String title;

  /// Defaults to going back one screen.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: onBack ?? () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              color: AppColors.textDark,
              iconSize: 28,
              tooltip: 'Back',
            ),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ),
            // Same width as the icon button, so the title sits in the middle
            // of the screen rather than in the middle of the leftover space.
            const SizedBox(width: 48),
          ],
        ),
        const SizedBox(height: 10),

        // The line under the title, closing the header off.
        const NeonDivider(),
      ],
    );
  }
}