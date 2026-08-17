import 'package:flutter/material.dart';

import '../models/weekday.dart';
import '../theme/app_colors.dart';
import 'form_dropdown.dart';
/// A box that looks like the other dropdowns but picks several days at once.
///
/// A doctor can sit on more than one day, and a plain dropdown only takes one
/// answer, so tapping this opens a list of checkboxes instead.
class WeekdayPickerField extends StatelessWidget {
  const WeekdayPickerField({
    super.key,
    required this.selected,
    required this.onChanged,
    this.hint = 'Weekdays',
    this.errorText,
    this.enabled = true,
    this.disabledDay,
  });

  final List<Weekday> selected;
  final ValueChanged<List<Weekday>> onChanged;
  final String hint;
  final String? errorText;
  final bool enabled;

  /// A day that cannot be picked because it is already the off day.
  final Weekday? disabledDay;

  Future<void> _openPicker(BuildContext context) async {
    final result = await showDialog<List<Weekday>>(
      context: context,
      builder: (dialogContext) => _WeekdayDialog(
        selected: selected,
        disabledDay: disabledDay,
      ),
    );

    if (result != null) {
      onChanged(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = selected.isNotEmpty;

    return InkWell(
      onTap: enabled ? () => _openPicker(context) : null,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        isEmpty: false,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          errorText: errorText,
          errorMaxLines: 2,
          prefixIcon: const Icon(
            Icons.calendar_month_outlined,
            size: 22,
            color: AppColors.textMuted,
          ),
          suffixIcon: const Icon(Icons.arrow_drop_down),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 18,
          ),
          enabledBorder: formFieldBorder(AppColors.fieldBorder),
          disabledBorder: formFieldBorder(
            AppColors.fieldBorder.withValues(alpha: 0.4),
          ),
          errorBorder: formFieldBorder(Colors.red),
          focusedErrorBorder: formFieldBorder(Colors.red, 2),
        ),
        child: Text(
          hasSelection ? Weekday.describe(selected) : hint,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 16,
            color: hasSelection ? AppColors.textDark : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
/// The checkbox list behind the weekdays box.
class _WeekdayDialog extends StatefulWidget {
  const _WeekdayDialog({required this.selected, this.disabledDay});

  final List<Weekday> selected;
  final Weekday? disabledDay;

  @override
  State<_WeekdayDialog> createState() => _WeekdayDialogState();
}
class _WeekdayDialogState extends State<_WeekdayDialog> {
  late final Set<Weekday> _chosen = widget.selected.toSet();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      title: const Text('Available days'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final day in Weekday.values)
              CheckboxListTile(
                value: _chosen.contains(day),
                title: Text(day.fullName),
                // The off day cannot also be a consultation day, so it is
                // shown greyed out rather than silently rejected on save.
                subtitle: day == widget.disabledDay
                    ? const Text(
                        'Set as your off day',
                        style: TextStyle(fontSize: 12),
                      )
                    : null,
                activeColor: AppColors.logoGreen,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: day == widget.disabledDay
                    ? null
                    : (checked) {
                        setState(() {
                          if (checked == true) {
                            _chosen.add(day);
                          } else {
                            _chosen.remove(day);
                          }
                        });
                      },
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(
            // Always hand back the days in week order.
            Weekday.values.where(_chosen.contains).toList(),
          ),
          style: TextButton.styleFrom(foregroundColor: AppColors.logoGreen),
          child: const Text('Done'),
        ),
      ],
    );
  }
}