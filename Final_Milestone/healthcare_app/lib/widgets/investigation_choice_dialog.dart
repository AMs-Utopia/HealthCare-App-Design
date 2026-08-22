import 'package:flutter/material.dart';

import '../config/medex_config.dart';
import '../theme/app_colors.dart';
import 'neon_list_button.dart';

/// The two places Investigation can lead.
enum InvestigationChoice {
  /// Hand the patient over to MedEx in their browser.
  medex,

  /// Stay in the app and show the tests this centre offers.
  labTests,
}

/// The popup behind the Investigation box on the patient dashboard.
///
/// Investigation is the one dashboard box that means two different things, and
/// they are not two steps of one journey - they are a fork:
///
///   MedEx is somebody else's site, for reading up on a test or a medicine.
///   The app cannot book anything there and never sees what happens after.
///
///   Lab Tests is this app's own priced list, which ends in a booking on the
///   patient's own account.
///
/// So the choice is asked before either one opens, rather than one being
/// buried inside the other. Returns null when the patient backs out, which is
/// a real answer here - neither option is the safe default.
///
/// A tapped row lights up neon green for a moment before the popup closes, the
/// same way rows do on the area and hospital lists, so the tap is acknowledged
/// even though the screen is about to change.
Future<InvestigationChoice?> showInvestigationChoiceDialog(
  BuildContext context,
) {
  return showDialog<InvestigationChoice>(
    context: context,
    builder: (_) => const _InvestigationChoiceDialog(),
  );
}

class _InvestigationChoiceDialog extends StatefulWidget {
  const _InvestigationChoiceDialog();

  @override
  State<_InvestigationChoiceDialog> createState() =>
      _InvestigationChoiceDialogState();
}

class _InvestigationChoiceDialogState
    extends State<_InvestigationChoiceDialog> {
  /// The row tapped last, so it is lit while the popup is on its way out.
  InvestigationChoice? _selected;

  /// Lights the row, lets that be seen, then answers.
  ///
  /// The wait is short enough not to feel like a delay and long enough for the
  /// green to register. It is guarded by [mounted] because the popup can also
  /// be dismissed with the back button while it runs.
  Future<void> _choose(InvestigationChoice choice) async {
    setState(() => _selected = choice);

    await Future<void>.delayed(const Duration(milliseconds: 160));

    if (mounted) Navigator.of(context).pop(choice);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
      contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      title: const Text(
        'Investigation',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.textDark,
        ),
      ),
      content: SizedBox(
        // Without this the dialog shrinks to the widest row, and the two rows
        // are different widths. maxFinite lets it take the dialog's own width
        // so both rows line up.
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 14),
              child: Text(
                'Where do you want to look?',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textMuted,
                  height: 1.3,
                ),
              ),
            ),

            NeonListButton(
              icon: Icons.travel_explore_outlined,
              title: 'MedEx',
              // Names the site, because this one leaves the app and a patient
              // should know where they are being taken before they tap.
              subtitle: 'Opens ${MedexSite.displayName} in your browser',
              selected: _selected == InvestigationChoice.medex,
              onTap: () => _choose(InvestigationChoice.medex),
            ),
            const SizedBox(height: 12),

            NeonListButton(
              icon: Icons.biotech_outlined,
              title: 'Lab Tests',
              subtitle: 'Tests you can book here, with prices',
              selected: _selected == InvestigationChoice.labTests,
              onTap: () => _choose(InvestigationChoice.labTests),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actions: [
        // Backing out is an answer, so it is written on the popup rather than
        // left to the back button alone.
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
          child: const Text(
            'Cancel',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
