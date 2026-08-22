import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
/// The rounded search box under the dashboard header.
///
/// The hint is deliberately faint - it tells the user what can be searched
/// without looking like text they typed.
class DashboardSearchBar extends StatelessWidget {
  const DashboardSearchBar({
    super.key,
    required this.controller,
    this.hint = 'Search doctors, departments, hospitals',
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final void Function(String)? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onSubmitted: onSubmitted,
      style: const TextStyle(fontSize: 16, color: AppColors.textDark),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 15,
          // Faded so it reads as a placeholder, not as a value.
          color: AppColors.textMuted.withValues(alpha: 0.6),
        ),
        prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: AppColors.fieldBorder, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: AppColors.logoGreen, width: 2),
        ),
      ),
    );
  }
}