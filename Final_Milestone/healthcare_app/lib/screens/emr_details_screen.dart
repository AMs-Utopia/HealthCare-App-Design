import 'package:flutter/material.dart';

import '../models/appointment.dart';
import '../models/emr.dart';
import '../models/patient_profile.dart';
import '../models/signed_in_user.dart';
import '../services/emr_service.dart';
import '../theme/app_colors.dart';
import '../widgets/neon_divider.dart';
import '../widgets/screen_header.dart';
import 'record_visit_screen.dart';

/// Screen 15 (Doctor) - EMR Details.
///
/// This is the wireframe screen, with its architecture corrected.
///
/// The wireframe had Patient Name and Patient UID as EMPTY BOXES the doctor
/// typed into, then a Continue button, then the four record types. That made
/// the EMR look like something a doctor creates by filling a form in, and it
/// could not work:
///
///  * A record that only exists once somebody types a name into it has no
///    contents on the second visit either - nothing in the wireframe ever
///    wrote anything down.
///  * The identity boxes were asking the doctor for facts the app already
///    holds. A patient's name and UID are in their account; typing them again
///    can only introduce a mistake.
///
/// What is built instead follows the life of a real record:
///
///   1. The record exists from the patient's first booking. At that point it
///      holds their account details - name, UID, age, gender, blood group -
///      and one visit with nothing written against it. That is the top of this
///      screen, filled in automatically and not editable here.
///   2. After the consultation the doctor writes the visit up: diagnosis,
///      treatment plan, notes, prescription. That is the Record button, and it
///      is what puts contents into the four sections below.
///   3. At the second visit the doctor opens this same screen and everything
///      written at the first visit is there to read, above a fresh visit
///      waiting to be written up.
///
/// The four sections are kept from the wireframe exactly as drawn - Medical
/// History, Diagnosis, Prescription, Treatment Records - but they are four
/// readings of one list of visits rather than four separate stores, so they can
/// never contradict each other.
class EmrDetailsScreen extends StatefulWidget {
  const EmrDetailsScreen({
    super.key,
    required this.doctor,
    required this.patientId,
    this.patientName,
  });

  final SignedInUser doctor;
  final int patientId;

  /// Known from the list the doctor tapped, so the header has a name to show
  /// while the record is still loading.
  final String? patientName;

  @override
  State<EmrDetailsScreen> createState() => _EmrDetailsScreenState();
}

class _EmrDetailsScreenState extends State<EmrDetailsScreen> {
  EmrDetails? _details;
  bool _isLoading = true;
  String? _loadError;

  /// Which of the four record sections is open. Only one at a time, so the
  /// screen stays readable on a phone. Medical History starts open because it
  /// is the whole record in one list.
  int _openSection = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    final result = await EmrService.fetchDetails(
      doctorId: widget.doctor.id,
      patientId: widget.patientId,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.isSuccess) {
        _details = result.details;
      } else {
        _loadError = result.error;
      }
    });
  }

  /// Opens the write up form for one visit, then reads the record back.
  ///
  /// The record is re-fetched rather than patched in place: the save may have
  /// replaced a prescription as well as the write up, and re-reading is the
  /// only way the screen and the database cannot disagree.
  Future<void> _recordVisit(EmrVisit visit) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RecordVisitScreen(
          doctor: widget.doctor,
          visit: visit,
          patientName: _details?.patient.fullName ?? widget.patientName ?? '',
        ),
      ),
    );

    if (!mounted) return;

    if (saved == true) {
      await _load();

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Visit written up. It is part of the record now.'),
            duration: Duration(seconds: 3),
          ),
        );
    }
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
              'Opening the record...',
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

    final details = _details!;
    final awaiting = details.visitAwaitingRecord;

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.logoGreen,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _IdentityCard(details: details),
          const SizedBox(height: 14),

          // The state of the record, said plainly. A doctor opening a record
          // for the first time should be told it is empty because nothing has
          // been written yet, not left wondering whether it failed to load.
          if (details.summary.isNewRecord)
            _NewRecordNotice(hasVisitToRecord: awaiting != null),

          if (awaiting != null) ...[
            if (details.summary.isNewRecord) const SizedBox(height: 12),
            _RecordThisVisitCard(
              visit: awaiting,
              onPressed: () => _recordVisit(awaiting),
            ),
          ],

          const SizedBox(height: 20),

          // "Records", underlined - straight from the wireframe.
          const Text(
            'Records',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          const NeonDivider(),
          const SizedBox(height: 14),

          // The same four, in the same order the wireframe numbers them.
          _RecordSection(
            index: 1,
            title: 'Medical History',
            icon: Icons.history_outlined,
            count: details.medicalHistory.length,
            isOpen: _openSection == 0,
            onToggle: () => setState(() => _openSection = _openSection == 0 ? -1 : 0),
            emptyLine: 'This patient has no visits on record.',
            children: details.medicalHistory
                .map(
                  (visit) => _VisitCard(
                    visit: visit,
                    onRecord: visit.canRecord ? () => _recordVisit(visit) : null,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),

          _RecordSection(
            index: 2,
            title: 'Diagnosis',
            icon: Icons.medical_information_outlined,
            count: details.diagnoses.length,
            isOpen: _openSection == 1,
            onToggle: () => setState(() => _openSection = _openSection == 1 ? -1 : 1),
            emptyLine:
                'No diagnosis has been written yet. One appears here as soon '
                'as a visit is written up.',
            children: details.diagnoses
                .map(
                  (visit) => _EntryCard(
                    visit: visit,
                    body: visit.record!.diagnosis!,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),

          _RecordSection(
            index: 3,
            title: 'Prescription',
            icon: Icons.medication_outlined,
            count: details.prescriptions.length,
            isOpen: _openSection == 2,
            onToggle: () => setState(() => _openSection = _openSection == 2 ? -1 : 2),
            emptyLine: 'Nothing has been prescribed to this patient yet.',
            children: details.prescriptions
                .map((visit) => _PrescriptionCard(visit: visit))
                .toList(),
          ),
          const SizedBox(height: 12),

          _RecordSection(
            index: 4,
            title: 'Treatment Records',
            icon: Icons.healing_outlined,
            count: details.treatments.length,
            isOpen: _openSection == 3,
            onToggle: () => setState(() => _openSection = _openSection == 3 ? -1 : 3),
            emptyLine: 'No treatment plan has been recorded yet.',
            children: details.treatments
                .map((visit) => _TreatmentCard(visit: visit))
                .toList(),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Who the record belongs to.
///
/// Every field here is READ from the PATIENT row. These were the two empty
/// boxes on the wireframe; filling them in from the account is the difference
/// between a record that identifies a real person and a record that identifies
/// whatever was typed.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.details});

  final EmrDetails details;

  @override
  Widget build(BuildContext context) {
    final patient = details.patient;
    final summary = details.summary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.logoGreen, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PatientAvatar(patient: patient),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Patient Name',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                    Text(
                      patient.fullName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Patient UID',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                    Text(
                      patient.patientUid ?? 'Not issued',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.logoBlue,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.fieldBorder),
          const SizedBox(height: 12),

          Wrap(
            spacing: 20,
            runSpacing: 10,
            children: [
              // Age is worked out by MySQL from the date of birth, never
              // stored, so it can never drift out of date.
              _Fact(
                label: 'Age',
                value: patient.age == null ? 'Not set' : '${patient.age}',
              ),
              _Fact(
                label: 'Gender',
                value: (patient.gender == null || patient.gender!.isEmpty)
                    ? 'Not set'
                    : patient.gender!,
              ),
              _Fact(
                label: 'Blood group',
                value:
                    (patient.bloodGroup == null || patient.bloodGroup!.isEmpty)
                    ? 'Not set'
                    : patient.bloodGroup!,
              ),
              _Fact(label: 'Mobile', value: patient.phone),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.fieldBorder),
          const SizedBox(height: 10),

          // How well this doctor knows the patient. This is the line that
          // makes "second visit" mean something on the screen.
          Row(
            children: [
              const Icon(
                Icons.event_repeat_outlined,
                size: 16,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _visitsLine(summary),
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textMuted,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _visitsLine(EmrSummary summary) {
    if (summary.visitsWithMe == 0) {
      return 'No visits with you yet.';
    }

    final visits = summary.visitsWithMe == 1
        ? '1 visit with you'
        : '${summary.visitsWithMe} visits with you';

    final since = summary.firstVisitDate == null
        ? ''
        : ', first seen ${formatAppointmentDate(summary.firstVisitDate!)}';

    final others = summary.totalVisits - summary.visitsWithMe;
    final elsewhere = others > 0
        ? '. $others other visit${others == 1 ? '' : 's'} on record.'
        : '.';

    return '$visits$since$elsewhere';
  }
}

/// The photo from the patient's account, or their initial.
class _PatientAvatar extends StatelessWidget {
  const _PatientAvatar({required this.patient});

  final PatientProfile patient;

  @override
  Widget build(BuildContext context) {
    final url = patient.photoUrl;
    final name = patient.fullName;
    final initial = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();

    return Container(
      width: 64,
      height: 64,
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
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.logoGreen,
                ),
              ),
            )
          : Image.network(
              url.toString(),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.logoGreen,
                  ),
                ),
              ),
            ),
    );
  }
}

/// Shown while the record holds nothing but the account details.
///
/// This is the honest version of what the wireframe implied. A brand new
/// record is not broken and not missing - it is a record whose visits have not
/// been written up yet, and it says so.
class _NewRecordNotice extends StatelessWidget {
  const _NewRecordNotice({required this.hasVisitToRecord});

  final bool hasVisitToRecord;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.historyRescheduled.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.historyRescheduled, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            size: 20,
            color: AppColors.historyRescheduled,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hasVisitToRecord
                  ? 'This record was opened when the patient booked, so it '
                        'holds their details and nothing else yet. Write the '
                        'visit up and it will be here at their next one.'
                  : 'This record holds the patient\'s details only. It fills '
                        'in as visits are written up.',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textDark,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The one action this screen exists to offer: write up the visit that is
/// waiting.
class _RecordThisVisitCard extends StatelessWidget {
  const _RecordThisVisitCard({required this.visit, required this.onPressed});

  final EmrVisit visit;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.logoBlue, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.edit_note_outlined,
                size: 20,
                color: AppColors.logoBlue,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  visit.visitNo == null
                      ? 'Visit not written up'
                      : 'Visit ${visit.visitNo} not written up',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${visit.dateLine}  ·  ${visit.visitType}'
            '${visit.placeLine.isEmpty ? '' : '\n${visit.placeLine}'}',
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textMuted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.note_add_outlined, size: 20),
              label: const Text('Write up this visit'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.logoBlue,
                foregroundColor: Colors.white,
                elevation: 2,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One of the four numbered sections from the wireframe, which opens when it
/// is tapped.
class _RecordSection extends StatelessWidget {
  const _RecordSection({
    required this.index,
    required this.title,
    required this.icon,
    required this.count,
    required this.isOpen,
    required this.onToggle,
    required this.emptyLine,
    required this.children,
  });

  /// 1 to 4, drawn the way the wireframe numbers them.
  final int index;

  final String title;
  final IconData icon;
  final int count;
  final bool isOpen;
  final VoidCallback onToggle;

  /// What to say when this part of the record has nothing in it yet.
  final String emptyLine;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isEmpty = children.isEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isOpen ? AppColors.logoGreen : AppColors.fieldBorder,
          width: isOpen ? 2 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Text(
                    '$index)',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(icon, size: 20, color: AppColors.logoGreen),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  _CountChip(count: count),
                  const SizedBox(width: 6),
                  Icon(
                    isOpen ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),

          if (isOpen) ...[
            const Divider(height: 1, color: AppColors.fieldBorder),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: isEmpty
                  ? Text(
                      emptyLine,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                        height: 1.35,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < children.length; i++) ...[
                          if (i > 0) const SizedBox(height: 10),
                          children[i],
                        ],
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

/// How many entries a section holds. Zero is drawn grey rather than hidden, so
/// an empty section reads as "nothing recorded yet" instead of as missing.
class _CountChip extends StatelessWidget {
  const _CountChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colour = count == 0 ? AppColors.textMuted : AppColors.logoGreen;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colour, width: 1.2),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.bold,
          color: colour,
        ),
      ),
    );
  }
}

/// One visit in the Medical History section, whatever state it is in.
class _VisitCard extends StatelessWidget {
  const _VisitCard({required this.visit, this.onRecord});

  final EmrVisit visit;

  /// Null when this visit is not this doctor's to write up.
  final VoidCallback? onRecord;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: visit.isCancelled
              ? AppColors.historyCancelled
              : AppColors.fieldBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      visit.visitNo == null
                          ? visit.dateLine
                          : 'Visit ${visit.visitNo}  ·  ${visit.dateLine}',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      visit.isMine ? 'You  ·  ${visit.visitType}' : visit.doctorLine,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    if (visit.placeLine.isNotEmpty)
                      Text(
                        visit.placeLine,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              _VisitStateChip(visit: visit),
            ],
          ),

          if (visit.isRecorded && visit.record!.hasDiagnosis) ...[
            const SizedBox(height: 10),
            _LabelledBlock(
              label: 'Diagnosis',
              value: visit.record!.diagnosis!,
            ),
          ],

          if (onRecord != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: onRecord,
                icon: Icon(
                  visit.isRecorded
                      ? Icons.edit_outlined
                      : Icons.note_add_outlined,
                  size: 17,
                ),
                label: Text(visit.isRecorded ? 'Edit write up' : 'Write up'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.logoBlue,
                  side: const BorderSide(color: AppColors.logoBlue, width: 1.4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Whether a visit has been written up, is still waiting, or never happened.
class _VisitStateChip extends StatelessWidget {
  const _VisitStateChip({required this.visit});

  final EmrVisit visit;

  @override
  Widget build(BuildContext context) {
    final Color colour;
    final String label;

    if (visit.isCancelled) {
      colour = AppColors.historyCancelled;
      label = 'Cancelled';
    } else if (visit.isRecorded) {
      colour = AppColors.historyBooked;
      label = 'Recorded';
    } else {
      colour = AppColors.historyRescheduled;
      label = 'Not written up';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colour),
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

/// One dated entry in the Diagnosis section.
class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.visit, required this.body});

  final EmrVisit visit;
  final String body;

  @override
  Widget build(BuildContext context) {
    return _DatedBlock(
      visit: visit,
      child: Text(
        body,
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.textDark,
          height: 1.35,
        ),
      ),
    );
  }
}

/// One dated entry in the Prescription section.
class _PrescriptionCard extends StatelessWidget {
  const _PrescriptionCard({required this.visit});

  final EmrVisit visit;

  @override
  Widget build(BuildContext context) {
    final items = visit.prescription!.items;

    return _DatedBlock(
      visit: visit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Icon(
                    Icons.medication_outlined,
                    size: 15,
                    color: AppColors.logoGreen,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        items[i].nameLine,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        items[i].remainingDoses == null
                            ? items[i].dosageInstruction
                            : '${items[i].dosageInstruction}  ·  '
                                  '${items[i].remainingDoses} doses',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One dated entry in the Treatment Records section.
class _TreatmentCard extends StatelessWidget {
  const _TreatmentCard({required this.visit});

  final EmrVisit visit;

  @override
  Widget build(BuildContext context) {
    final record = visit.record!;

    return _DatedBlock(
      visit: visit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (record.treatmentPlan != null &&
              record.treatmentPlan!.trim().isNotEmpty)
            _LabelledBlock(label: 'Plan', value: record.treatmentPlan!),
          if (record.notes != null && record.notes!.trim().isNotEmpty) ...[
            if (record.treatmentPlan != null &&
                record.treatmentPlan!.trim().isNotEmpty)
              const SizedBox(height: 8),
            _LabelledBlock(label: 'Notes', value: record.notes!),
          ],
        ],
      ),
    );
  }
}

/// The frame the Diagnosis, Prescription and Treatment entries share: when it
/// was written and who wrote it, then the entry itself.
class _DatedBlock extends StatelessWidget {
  const _DatedBlock({required this.visit, required this.child});

  final EmrVisit visit;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 13,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${visit.dateLine}  ·  '
                  '${visit.isMine ? 'You' : 'Dr. ${visit.doctorName}'}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/// A small heading over a block of the doctor's own words.
class _LabelledBlock extends StatelessWidget {
  const _LabelledBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textDark,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

/// One small "label / value" pair in the identity card.
class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }
}
