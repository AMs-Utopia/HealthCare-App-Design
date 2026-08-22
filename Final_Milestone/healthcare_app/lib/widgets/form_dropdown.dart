import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Shared outline for the full width form fields, so a dropdown and a picker
/// sitting next to each other look like the same control.
InputBorder formFieldBorder(Color color, [double width = 1.5]) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: color, width: width),
  );
}
/// A full width dropdown whose label lives inside the box as a hint, like the
/// "Hospital ⌄" boxes on the add schedule wireframe.
class FormDropdown<T> extends StatelessWidget {
  const FormDropdown({
    super.key,
    required this.hint,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.validator,
    this.errorText,
    this.enabled = true,
    this.icon,
    this.borderColor = AppColors.fieldBorder,
  });
  /// Shown inside the box while nothing is chosen, e.g. "Hospital".
  final String hint;

  final T? value;
  final List<T> items;
  /// How to turn one item into the text shown in the list.
  final String Function(T) itemLabel;

  final ValueChanged<T?>? onChanged;
  final String? Function(T?)? validator;
  /// An error coming from the PHP API rather than from [validator].
  final String? errorText;

  final bool enabled;

  /// Optional leading icon inside the box.
  final IconData? icon;

  /// The colour of the box when it is not focused. Defaults to the same grey
  /// every other form field uses; the reschedule screen passes green, because
  /// there the dropdown is the action of the screen rather than one field
  /// among several.
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      validator: validator,
      isExpanded: true,
      style: const TextStyle(fontSize: 16, color: AppColors.textDark),
      hint: Text(
        hint,
        style: const TextStyle(fontSize: 16, color: AppColors.textMuted),
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
        prefixIcon: icon == null
            ? null
            : Icon(icon, size: 22, color: AppColors.textMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 18,
        ),
        enabledBorder: formFieldBorder(borderColor),
        disabledBorder: formFieldBorder(borderColor.withValues(alpha: 0.4)),
        focusedBorder: formFieldBorder(AppColors.logoGreen, 2),
        errorBorder: formFieldBorder(Colors.red),
        focusedErrorBorder: formFieldBorder(Colors.red, 2),
      ),
    );
  }
}