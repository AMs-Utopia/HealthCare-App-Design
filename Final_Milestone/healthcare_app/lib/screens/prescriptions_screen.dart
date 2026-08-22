import 'package:flutter/material.dart';

import '../models/patient_prescription.dart';
import '../models/signed_in_user.dart';
import '../services/medication_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/screen_header.dart';
import 'medication_screen.dart';

/// Screen 21 (User / Patient) - My Prescriptions.
///
/// Reached from Profile in the drawer, then My Account, then My Prescriptions.
///
/// One card per prescription, newest first: the doctor who wrote it, their
/// speciality, the date, what they were treating, and the medicines underneath.
/// Tapping a medicine opens Medications, where the dose count, Completed and
/// Refill live.
///
/// Why this screen had to exist:
///
///   Every other route to a prescription in this app starts from an order -
///   Order History, tap a medicine, Medications. That means a patient could
///   only ever see a prescription for a medicine they had ALREADY BOUGHT, and
///   a course they had been put on and never filled was invisible to them.
///   That is precisely the course worth showing: it is medicine a doctor says
///   they should be taking and they are not.
///
/// So medicines that have never been ordered are called out rather than merely
/// listed, and the line at the top counts them.
class PrescriptionsScreen extends StatefulWidget {
  const PrescriptionsScreen({super.key, required this.patient});

  final SignedInUser patient;

  @override
  State<PrescriptionsScreen> createState() => _PrescriptionsScreenState();
}

class _PrescriptionsScreenState extends State<PrescriptionsScreen> {
  List<PatientPrescription> _prescriptions = [];
  bool _isLoading = true;
  String _message = '';
  String? _error;

  /// The medicine tapped last, so its row stays lit up.
  int? _selectedItemId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _isLoading = true);

    final result = await MedicationService.fetchPrescriptions(
      widget.patient.id,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.isSuccess) {
        _prescriptions = result.prescriptions;
        _message = result.message;
        _error = null;
      } else {
        _error = result.error;
      }
    });
  }

  /// Opens Medications for the tapped medicine.
  ///
  /// The same screen Order History opens, reached by the same medicine id, so
  /// a course marked completed from either place is completed in both.
  Future<void> _openMedication(PrescribedItem item) async {
    setState(() => _selectedItemId = item.prescriptionItemId);

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MedicationScreen(
          patient: widget.patient,
          medicineId: item.medicineId,
          medicineName: item.name,
        ),
      ),
    );

    // Completing a course or refilling one down there changes what this list
    // says about it.
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: AppBottomNav(
        current: null,
        patient: widget.patient,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ScreenHeader(title: 'My Prescriptions'),
              const SizedBox(height: 14),
              Expanded(child: _buildBody()),
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
        title: 'Could not load your prescriptions',
        detail: _error!,
      );
    }

    if (_prescriptions.isEmpty) {
      return _Note(
        icon: Icons.description_outlined,
        title: 'No prescriptions yet',
        detail: 'When a doctor writes up one of your visits, what they '
            'prescribe will appear here.',
      );
    }

    return RefreshIndicator(
      color: AppColors.logoGreen,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 8),
        // One extra row at the top for the summary line.
        itemCount: _prescriptions.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (_, index) {
          if (index == 0) return _buildSummary();

          return _PrescriptionCard(
            prescription: _prescriptions[index - 1],
            selectedItemId: _selectedItemId,
            onMedicineTapped: _openMedication,
          );
        },
      ),
    );
  }

  /// The server's own count, so the screen and the API cannot disagree about
  /// how many courses are running or how many have not been filled.
  Widget _buildSummary() {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 2),
      child: Text(
        _message,
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.textMuted,
          height: 1.35,
        ),
      ),
    );
  }
}

/// One prescription: the visit across the top, its medicines underneath.
class _PrescriptionCard extends StatelessWidget {
  const _PrescriptionCard({
    required this.prescription,
    required this.selectedItemId,
    required this.onMedicineTapped,
  });

  final PatientPrescription prescription;
  final int? selectedItemId;
  final ValueChanged<PrescribedItem> onMedicineTapped;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.fieldBorder, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          const Divider(height: 1, thickness: 1, color: AppColors.fieldBorder),

          for (var index = 0; index < prescription.items.length; index++) ...[
            if (index > 0)
              const Divider(
                height: 1,
                thickness: 1,
                indent: 12,
                endIndent: 12,
                color: AppColors.background,
              ),
            _MedicineRow(
              position: index + 1,
              item: prescription.items[index],
              selected:
                  selectedItemId ==
                  prescription.items[index].prescriptionItemId,
              onTap: () => onMedicineTapped(prescription.items[index]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.description_outlined,
                  size: 19,
                  color: AppColors.logoGreen,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  prescription.doctorDisplayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _Chip(
                label: prescription.isCompleted ? 'Completed' : 'Active',
                colour: prescription.isCompleted
                    ? AppColors.textMuted
                    : AppColors.historyBooked,
              ),
            ],
          ),

          if (prescription.visitLine.isNotEmpty) ...[
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.only(left: 27),
              child: Text(
                prescription.visitLine,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ],

          // What it was for. A prescription on its own says what to take and
          // never says what for, and the diagnosis is written up at the same
          // visit - so it belongs on the same card.
          if (prescription.diagnosis != null &&
              prescription.diagnosis!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'For: ${prescription.diagnosis}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textDark,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One prescribed medicine, and the way through to Medications.
class _MedicineRow extends StatelessWidget {
  const _MedicineRow({
    required this.position,
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final int position;
  final PrescribedItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
        color: selected
            ? AppColors.logoGreen.withValues(alpha: 0.12)
            : Colors.transparent,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                '$position)',
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(width: 8),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  if (item.dosage != null && item.dosage!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        item.dosage!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),

                  // How to take it, in the doctor's own words. This is the
                  // single most useful line on the card, so it is on the list
                  // rather than only one screen deeper.
                  if (item.dosageInstruction != null &&
                      item.dosageInstruction!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule,
                          size: 13,
                          color: AppColors.logoBlue,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            item.dosageInstruction!,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.logoBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (item.remainingLine != null)
                        _Chip(
                          label: item.remainingLine!,
                          colour: item.isFinished
                              ? AppColors.textMuted
                              : AppColors.historyBooked,
                        ),

                      // The whole reason this screen exists: medicine a doctor
                      // put them on that they have never actually bought.
                      if (item.isUnfilled)
                        const _Chip(
                          label: 'Not ordered yet',
                          colour: AppColors.historyRescheduled,
                        )
                      else
                        _Chip(
                          label: item.timesOrdered == 1
                              ? 'Ordered once'
                              : 'Ordered ${item.timesOrdered} times',
                          colour: AppColors.logoBlue,
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(
                Icons.chevron_right,
                size: 22,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small pill of text - a status, a dose count, whether it has been bought.
class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.colour});

  final String label;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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

/// The middle of the screen when there is nothing to list.
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
