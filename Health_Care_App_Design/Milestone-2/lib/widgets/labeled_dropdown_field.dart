import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A label on the left and a dropdown on the right.
///
/// The twin of [LabeledTextField] - same label width, same box, so a dropdown
/// sits in a form without looking different from the text fields around it.
class LabeledDropdownField<T> extends StatelessWidget {
  const LabeledDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.hint,
    this.validator,
    this.labelWidth = 100,
    this.isRequired = false,
    this.errorText,
    this.enabled = true,
  });

  final String label;

  /// The chosen item, or null when nothing is chosen yet.
  final T? value;

  final List<T> items;

  /// How to turn one item into the text shown in the list.
  final String Function(T) itemLabel;

  /// Passing null disables the dropdown.
  final ValueChanged<T?>? onChanged;

  /// Shown while [value] is null, e.g. "Choose a department".
  final String? hint;

  final String? Function(T?)? validator;

  /// Width reserved for the label so the fields line up with each other.
  final double labelWidth;

  /// Adds the red asterisk used by the required labels.
  final bool isRequired;

  /// An error coming from the PHP API rather than from [validator].
  final String? errorText;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: labelWidth,
          child: Padding(
            // Nudges the label down so it sits level with the text in the box.
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
          child: DropdownButtonFormField<T>(
            initialValue: value,
            validator: validator,
            isExpanded: true,
            style: const TextStyle(fontSize: 16, color: AppColors.textDark),
            hint: hint == null
                ? null
                : Text(
                    hint!,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textMuted,
                    ),
                  ),
            items: items
                .map(
                  (item) => DropdownMenuItem<T>(
                    value: item,
                    child: Text(itemLabel(item), overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: enabled ? onChanged : null,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              errorText: errorText,
              errorMaxLines: 2,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
              enabledBorder: border(AppColors.fieldBorder),
              disabledBorder: border(
                AppColors.fieldBorder.withValues(alpha: 0.4),
              ),
              focusedBorder: border(AppColors.logoGreen, 2),
              errorBorder: border(Colors.red),
              focusedErrorBorder: border(Colors.red, 2),
            ),
          ),
        ),
      ],
    );
  }
}