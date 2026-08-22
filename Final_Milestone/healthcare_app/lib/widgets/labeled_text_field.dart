import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A label on the left and an input box on the right, e.g. "Phone : [____]".
///
/// This matches the input rows in the wireframe and will be reused by the
/// register screen, so the label width is fixed to keep the boxes aligned.
class LabeledTextField extends StatelessWidget {
  const LabeledTextField({
    super.key,
    required this.label,
    required this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.validator,
    this.labelWidth = 100,
    this.isRequired = false,
    this.errorText,
    this.enabled = true,
    this.textInputAction,
    this.onFieldSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;

  /// Width reserved for the label so several fields line up with each other.
  final double labelWidth;

  /// Adds the red asterisk drawn next to the required labels in the wireframe.
  final bool isRequired;

  /// An error coming from the PHP API rather than from [validator], e.g.
  /// "This phone number is already registered."
  final String? errorText;

  /// Set to false while a request is in flight so the user cannot edit the
  /// values that are currently being saved.
  final bool enabled;

  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: labelWidth,
          child: Padding(
            // Nudges the label down so it sits level with the text inside the box.
            padding: const EdgeInsets.only(top: 14),
            child: Text.rich(
              TextSpan(
                text: label,
                children: [
                  if (isRequired)
                    const TextSpan(
                      text: '*',
                      style: TextStyle(color: Colors.red),
                    ),
                  const TextSpan(text: ' :'),
                ],
              ),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ),
        ),
        Expanded(
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscureText,
            validator: validator,
            enabled: enabled,
            textInputAction: textInputAction,
            onFieldSubmitted: onFieldSubmitted,
            style: const TextStyle(fontSize: 16, color: AppColors.textDark),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              errorText: errorText,
              // The wireframe boxes are all the same height, so a long error
              // message must not push its box taller than its neighbours.
              errorMaxLines: 2,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppColors.fieldBorder),
              ),
              // Same shape while saving, just a paler outline.
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                  color: AppColors.fieldBorder.withValues(alpha: 0.4),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(
                  color: AppColors.logoGreen,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Colors.red),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}