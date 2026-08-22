import 'package:flutter/material.dart';

import '../models/emr.dart';
import '../models/medication.dart';
import '../models/order.dart';
import '../models/signed_in_user.dart';
import '../services/medication_service.dart';
import '../theme/app_colors.dart';
import '../widgets/primary_button.dart';
import '../widgets/screen_header.dart';
import 'order_medicine_screen.dart';

/// Screen 20 (User / Patient) - Medications.
///
/// Reached by tapping a medicine on Order History.
///
/// It answers the three questions a patient holding a box of medicine actually
/// has: who put me on this, how do I take it, and how much is left. Then two
/// buttons - Completed for when the course is done, and Refill, which opens the
/// order screen with this medicine already on it.
///
/// The screen has two states, and which one it is in matters:
///
///   PRESCRIBED - a doctor here wrote it up, so there is a prescriber, a dosage
///   instruction and a dose count to show, and Completed means something.
///
///   NOT PRESCRIBED - the patient simply bought it. There is no doctor, no
///   instruction and no dose count, and the screen says so plainly instead of
///   leaving blanks where a prescription would be. Completed is off, because
///   there is no course to finish; Refill still works, because buying it again
///   is exactly as valid as buying it the first time.
///
/// The second state is not an edge case. The two halves of a medicine are
/// written by different screens into different tables that share only
/// MEDICINE.medicine_id - the doctor's write up fills PRESCRIPTION, the order
/// screen fills ORDER_ITEM - so a medicine having one and not the other is the
/// normal way round, not a fault.
class MedicationScreen extends StatefulWidget {
  const MedicationScreen({
    super.key,
    required this.patient,
    required this.medicineId,
    this.medicineName,
  });

  final SignedInUser patient;

  /// Which medicine. Everything else is read from the server, so this screen
  /// can be opened from anywhere that knows a medicine id.
  final int medicineId;

  /// What to put in the heading while the details are still loading, so the
  /// screen does not open blank on the medicine that was just tapped.
  final String? medicineName;

  @override
  State<MedicationScreen> createState() => _MedicationScreenState();
}

class _MedicationScreenState extends State<MedicationScreen> {
  Medication? _medication;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _isLoading = true);

    final result = await MedicationService.fetch(
      patientId: widget.patient.id,
      medicineId: widget.medicineId,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.isSuccess) {
        _medication = result.medication;
        _error = null;
      } else {
        _error = result.error;
      }
    });
  }

  // ===========================================================================
  // Completed
  // ===========================================================================

  /// "I have finished taking this one."
  ///
  /// Confirmed first because there is no way back: nothing on this screen
  /// un-completes a course, and a mis-tap would tell the patient a medicine
  /// they are still on is done with.
  Future<void> _onCompleted() async {
    final prescription = _medication?.prescription;

    if (prescription == null || _isSaving) return;

    final sure = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Finished with this?'),
        content: Text(
          'This marks ${_medication!.name} as completed and sets its '
          'remaining doses to zero. It cannot be undone here.',
          style: const TextStyle(
            fontSize: 15,
            color: AppColors.textDark,
            height: 1.35,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.logoGreen),
            child: const Text(
              'Yes',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (sure != true || !mounted) return;

    setState(() => _isSaving = true);

    final response = await MedicationService.markCompleted(
      patientId: widget.patient.id,
      prescriptionItemId: prescription.prescriptionItemId,
    );

    if (!mounted) return;

    setState(() => _isSaving = false);

    _say(response.message);

    // Read back rather than patched in place: the server decides whether that
    // finished the whole prescription, and it is the only thing that knows.
    if (response.success) await _load();
  }

  // ===========================================================================
  // Refill
  // ===========================================================================

  /// Opens the order screen with this medicine already on the order.
  ///
  /// The medicine travels as a [MedicineOption] carrying our own medicine id,
  /// which is what the price lookup needs: it answers with the price stored on
  /// that row, and failing that finds the brand on MedEx by name. So a medicine
  /// a doctor prescribed but nobody has ever ordered can still be refilled,
  /// even though the write up screen never recorded a MedEx id for it.
  Future<void> _onRefill() async {
    final medication = _medication;

    if (medication == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OrderMedicineScreen(
          patient: widget.patient,
          refill: MedicineOption(
            id: medication.medicineId,
            name: medication.name,
            dosage: medication.dosage,
            source: 'local',
          ),
        ),
      ),
    );

    // An order placed down there is a new refill up here.
    if (mounted) await _load();
  }

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
      );
  }

  // ===========================================================================
  // Drawing it
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ScreenHeader(title: 'Medications'),
              const SizedBox(height: 14),

              Expanded(child: _buildBody()),

              if (_medication != null) ...[
                const SizedBox(height: 10),
                _buildActions(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.logoGreen),
      );
    }

    if (_error != null) {
      return _Note(
        icon: Icons.wifi_off_outlined,
        title: 'Could not load this medicine',
        detail: _error!,
      );
    }

    final medication = _medication!;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMedicineHeading(medication),
          const SizedBox(height: 18),

          if (medication.isPrescribed)
            _buildPrescribed(medication)
          else
            _buildNotPrescribed(medication),

          if (medication.hasRefills) ...[
            const SizedBox(height: 18),
            _buildRefillHistory(medication),
          ],
        ],
      ),
    );
  }

  /// Which medicine this whole screen is about.
  Widget _buildMedicineHeading(Medication medication) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.fieldBorder, width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.medication_outlined,
            size: 30,
            color: AppColors.logoGreen,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  medication.name.isEmpty
                      ? (widget.medicineName ?? 'Medicine')
                      : medication.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                if (medication.dosage != null &&
                    medication.dosage!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    medication.dosage!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (medication.prescription != null)
            _StatusChip(
              label: medication.prescription!.isCompleted
                  ? 'Completed'
                  : 'Active',
              colour: medication.prescription!.isCompleted
                  ? AppColors.textMuted
                  : AppColors.historyBooked,
            ),
        ],
      ),
    );
  }

  /// The three things the wireframe asks for, in its order.
  Widget _buildPrescribed(Medication medication) {
    final prescription = medication.prescription!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DetailBlock(
          title: 'Prescribed by',
          body: prescription.doctorDisplayName,
          note: [
            if (prescription.departmentName != null &&
                prescription.departmentName!.isNotEmpty)
              prescription.departmentName!,
            if (prescription.prescribedOnLine != null)
              'on ${prescription.prescribedOnLine}',
          ].join('  ·  '),
        ),
        const SizedBox(height: 14),

        _DetailBlock(
          title: 'Consume details',
          // Shown exactly as the doctor typed it. They write "1-0-1 after
          // meal" in their own words rather than picking from a list, and
          // rewording a dosage instruction is not something an app should do.
          body: prescription.dosageInstruction == null ||
                  prescription.dosageInstruction!.trim().isEmpty
              ? 'The doctor did not write how to take this.'
              : prescription.dosageInstruction!,
          muted: prescription.dosageInstruction == null ||
              prescription.dosageInstruction!.trim().isEmpty,
        ),
        const SizedBox(height: 14),

        _DetailBlock(
          title: 'Remaining doses',
          body: medication.remainingDosesLine ?? 'Not counted',
          // NULL doses and 0 doses are different things and must not read the
          // same: one is "the doctor never said", the other is "none left".
          note: prescription.hasNoDoseCount
              ? 'The doctor did not say how many to take in all.'
              : (prescription.isFinished
                    ? 'You have marked this one completed.'
                    : null),
          muted: prescription.hasNoDoseCount || prescription.isFinished,
          highlight: !prescription.hasNoDoseCount && !prescription.isFinished,
        ),
      ],
    );
  }

  /// When the patient bought this without anyone prescribing it.
  Widget _buildNotPrescribed(Medication medication) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.historyRescheduled, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline,
                size: 18,
                color: AppColors.historyRescheduled,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Not prescribed here',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.historyRescheduled,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'No doctor on this app has prescribed ${medication.name} to you, '
            'so there are no dosage instructions and no dose count to show. '
            'You can still order it again.',
            style: const TextStyle(
              fontSize: 13.5,
              color: AppColors.textDark,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  /// Every time this medicine has been bought.
  Widget _buildRefillHistory(Medication medication) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            medication.refills.length == 1
                ? 'Refill history  ·  1 order'
                : 'Refill history  ·  ${medication.refills.length} orders',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textMuted,
            ),
          ),
        ),

        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.fieldBorder, width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < medication.refills.length; i++) ...[
                if (i > 0)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    indent: 12,
                    endIndent: 12,
                    color: AppColors.background,
                  ),
                _RefillRow(
                  refill: medication.refills[i],
                  dosage: medication.dosage,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Completed on the left, Refill on the right, the way the wireframe closes
  /// the screen off.
  Widget _buildActions() {
    final medication = _medication!;
    final canComplete = medication.canComplete && !_isSaving;

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: canComplete ? _onCompleted : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.logoGreen,
                disabledForegroundColor: AppColors.textMuted,
                side: BorderSide(
                  color: canComplete
                      ? AppColors.logoGreen
                      : AppColors.fieldBorder,
                  width: 1.5,
                ),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.logoGreen,
                      ),
                    )
                  : const Text(
                      'Completed',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        Expanded(
          child: PrimaryButton(
            label: 'Refill',
            width: double.infinity,
            glow: true,
            onPressed: _isSaving ? null : _onRefill,
          ),
        ),
      ],
    );
  }
}

/// One "arrow, heading, answer" block - the shape the wireframe repeats three
/// times down the screen.
class _DetailBlock extends StatelessWidget {
  const _DetailBlock({
    required this.title,
    required this.body,
    this.note,
    this.muted = false,
    this.highlight = false,
  });

  final String title;
  final String body;
  final String? note;

  /// Greys the answer, for when it is the absence of an answer.
  final bool muted;

  /// Picks the answer out, for the dose count a patient is actually watching.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.fieldBorder, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The arrow the wireframe puts in front of each of these.
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.double_arrow,
              size: 17,
              color: AppColors.logoGreen,
            ),
          ),
          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: highlight ? 22 : 17,
                    fontWeight: FontWeight.bold,
                    color: muted
                        ? AppColors.textMuted
                        : (highlight
                              ? AppColors.logoGreen
                              : AppColors.textDark),
                    height: 1.25,
                  ),
                ),
                if (note != null && note!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    note!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textMuted,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One past purchase of this medicine.
class _RefillRow extends StatelessWidget {
  const _RefillRow({required this.refill, required this.dosage});

  final RefillRecord refill;
  final String? dosage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          const Icon(
            Icons.shopping_bag_outlined,
            size: 16,
            color: AppColors.logoBlue,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  refill.quantityLine(dosage),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                if (refill.boughtOnLine != null)
                  Text(
                    '${refill.boughtOnLine}  ·  Order #${refill.orderId}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                refill.totalLine,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              // What it cost that day, which is not necessarily what it costs
              // now - the whole reason the price is kept on the order line.
              Text(
                '${formatTaka(refill.unitPrice)} each',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Whether the course is still running.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.colour});

  final String label;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: colour,
        ),
      ),
    );
  }
}

/// The middle of the screen when nothing could be loaded.
class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.title, required this.detail});

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
