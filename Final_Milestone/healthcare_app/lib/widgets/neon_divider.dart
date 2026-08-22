import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
/// The glowing neon green line used to close off a heading.
///
/// Sits under the "Details" title on the registration screens and under the
/// logo in the drawer. The shadow is what makes it read as neon rather than
/// as a plain divider.
class NeonDivider extends StatelessWidget {
  const NeonDivider({super.key, this.thickness = 3});

  final double thickness;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: thickness,
      decoration: BoxDecoration(
        color: AppColors.neonGreen,
        borderRadius: BorderRadius.circular(thickness / 1.5),
        boxShadow: const [
          BoxShadow(
            color: AppColors.neonGreen,
            blurRadius: 12,
            spreadRadius: -1,
          ),
        ],
      ),
    );
  }
}