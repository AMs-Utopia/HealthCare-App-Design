import 'dart:async';

import 'package:flutter/material.dart';

import '../models/appointment.dart';
import '../models/emr.dart';
import '../models/signed_in_user.dart';
import '../services/emr_service.dart';
import '../theme/app_colors.dart';
import '../widgets/screen_header.dart';
import 'emr_details_screen.dart';

/// Screen 14 (Doctor) - EMR: choose a patient.
///
/// Reached from the "EMR Details of Patients" box on the doctor dashboard.
///
/// The wireframe had the doctor type a Patient Name and a Patient UID and
/// press Continue. That is not built here, on purpose, and this screen is what
/// replaced it:
///
///  * A record cannot be conjured by typing an identity in. A doctor may open
///    the record of a patient who has booked them and nobody else, so the app
///    shows that list instead of asking for a name.
///  * Name AND UID together is one identity too many. The UID identifies a
///    patient on its own; asking for both only creates a way to fail - a real
///    patient refused because the name was spelt differently from the account.
///  * A typed UID has no relationship behind it. Typing somebody else's would
///    have opened somebody else's medical record.
///
/// What survives from the wireframe is the searching: one box that filters this
/// doctor's own patients by name or UID, and tapping a patient is Continue.
class EmrPatientsScreen extends StatefulWidget {
  const EmrPatientsScreen({super.key, required this.doctor});

  final SignedInUser doctor;

  @override
  State<EmrPatientsScreen> createState() => _EmrPatientsScreenState();
}

class _EmrPatientsScreenState extends State<EmrPatientsScreen> {
  final _searchController = TextEditingController();

  List<EmrPatient> _patients = [];
  bool _isLoading = true;
  String? _loadError;
  String _emptyMessage = '';

  /// Waits for the doctor to stop typing before asking the server, so a five
  /// letter name is one request rather than five.
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    final result = await EmrService.fetchPatients(
      widget.doctor.id,
      search: _searchController.text,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.isSuccess) {
        _patients = result.patients;
        _emptyMessage = result.message;
      } else {
        _loadError = result.error;
      }
    });
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _load);
  }

  Future<void> _openRecord(EmrPatient patient) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EmrDetailsScreen(
          doctor: widget.doctor,
          patientId: patient.id,
          patientName: patient.fullName,
        ),
      ),
    );

    // Coming back from a record that was just written up has to change the
    // "not written up yet" line on that patient's row, so the list is read
    // again rather than trusted.
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ScreenHeader(title: 'EMR Details'),
              const SizedBox(height: 12),

              const Text(
                'Your patients. A record opens the moment a patient books '
                'you, and fills up as you write each visit down.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _load(),
                decoration: InputDecoration(
                  hintText: 'Search by patient name or UID',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.textMuted,
                  ),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          color: AppColors.textMuted,
                          tooltip: 'Clear',
                          onPressed: () {
                            _searchController.clear();
                            _load();
                          },
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: AppColors.fieldBorder,
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: AppColors.logoGreen,
                      width: 2,
                    ),
                  ),
                ),
              ),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.logoGreen),
            SizedBox(height: 16),
            Text(
              'Loading your patients...',
              style: TextStyle(fontSize: 15, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    if (_loadError != null) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.red.shade900),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Try again'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.logoGreen,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_patients.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.folder_off_outlined,
                size: 48,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: 14),
              Text(
                _emptyMessage.isEmpty
                    ? 'No records to open yet.'
                    : _emptyMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'A patient appears here once they have booked you.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.logoGreen,
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: _patients.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _PatientCard(
          patient: _patients[index],
          onTap: () => _openRecord(_patients[index]),
        ),
      ),
    );
  }
}

/// One patient of this doctor's, and the state of their record.
class _PatientCard extends StatelessWidget {
  const _PatientCard({required this.patient, required this.onTap});

  final EmrPatient patient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.fieldBorder, width: 1.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Avatar(patient: patient),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    patient.fullName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    patient.identityLine,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // The two things a doctor about to open a record wants to
                  // know: how well they know this patient, and whether there
                  // is anything written down to read.
                  Text(
                    patient.visitsWithMe == 1
                        ? '1 visit with you'
                        : '${patient.visitsWithMe} visits with you',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  if (patient.lastVisitDate != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Last seen ${formatAppointmentDate(patient.lastVisitDate!)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  _RecordStateChip(patient: patient),
                ],
              ),
            ),

            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

/// The patient's photo, or their initial when they have not set one.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.patient});

  final EmrPatient patient;

  @override
  Widget build(BuildContext context) {
    final url = patient.photoUrl;
    final initial = patient.fullName.isEmpty
        ? '?'
        : patient.fullName.substring(0, 1).toUpperCase();

    return Container(
      width: 52,
      height: 52,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.logoGreen.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.logoGreen, width: 1.5),
      ),
      child: url == null
          ? Center(
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.logoGreen,
                ),
              ),
            )
          : Image.network(
              url.toString(),
              fit: BoxFit.cover,
              // A photo that will not load is not worth an error on a list
              // row; the initial says who this is just as well.
              errorBuilder: (_, _, _) => Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.logoGreen,
                  ),
                ),
              ),
            ),
    );
  }
}

/// Says what is in this patient's record, in the words the doctor thinks in:
/// a new patient with nothing written down, or one with visits still to write
/// up, or one whose record is complete.
class _RecordStateChip extends StatelessWidget {
  const _RecordStateChip({required this.patient});

  final EmrPatient patient;

  @override
  Widget build(BuildContext context) {
    final Color colour;
    final IconData icon;
    final String label;

    if (!patient.hasWrittenRecords) {
      colour = AppColors.historyRescheduled;
      icon = Icons.edit_note_outlined;
      label = patient.isFirstVisit
          ? 'First visit - nothing written yet'
          : 'Nothing written yet';
    } else if (patient.awaitingRecord > 0) {
      colour = AppColors.logoBlue;
      icon = Icons.pending_actions_outlined;
      label = patient.awaitingRecord == 1
          ? '1 visit still to write up'
          : '${patient.awaitingRecord} visits still to write up';
    } else {
      colour = AppColors.historyBooked;
      icon = Icons.fact_check_outlined;
      label = patient.recordedByMe == 1
          ? '1 visit recorded'
          : '${patient.recordedByMe} visits recorded';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colour, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colour),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colour,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
