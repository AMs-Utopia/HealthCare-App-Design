import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/emr.dart';
import '../models/signed_in_user.dart';
import '../services/emr_service.dart';
import '../theme/app_colors.dart';
import '../widgets/primary_button.dart';
import '../widgets/screen_header.dart';

/// Screen 16 (Doctor) - Write up a visit.
///
/// The step the wireframe was missing.
///
/// The wireframe showed an EMR with four kinds of record in it but nothing
/// that ever put a record there, which is why a second visit would have shown
/// the doctor exactly as much as the first: nothing. This is the screen that
/// fills the record in - the doctor's diagnosis, how they are treating it, and
/// what they prescribed.
///
/// It writes against ONE VISIT, never against a patient in general. The
/// appointment decides the patient and the date, so a write up cannot end up
/// on the wrong day or on somebody else, and opening this screen again for the
/// same visit corrects that visit rather than adding a second write up of the
/// same consultation.
///
/// The prescription part looks the brand up on MedEx as the doctor types. It
/// is deliberately NOT a dropdown of medicines the app knows about: a doctor
/// does not choose from a list somebody prepared for them, and a list like
/// that would quietly decide what they are allowed to prescribe.
///
/// Pops with `true` when something was saved, so the record underneath knows
/// to read itself again.
class RecordVisitScreen extends StatefulWidget {
  const RecordVisitScreen({
    super.key,
    required this.doctor,
    required this.visit,
    required this.patientName,
  });

  final SignedInUser doctor;
  final EmrVisit visit;
  final String patientName;

  @override
  State<RecordVisitScreen> createState() => _RecordVisitScreenState();
}

class _RecordVisitScreenState extends State<RecordVisitScreen> {
  final _formKey = GlobalKey<FormState>();

  final _diagnosisController = TextEditingController();
  final _treatmentController = TextEditingController();
  final _notesController = TextEditingController();

  /// The prescription as it is being written. One entry per row on screen.
  final List<PrescriptionDraft> _lines = [];

  bool _isSaving = false;

  /// Errors sent back by PHP, keyed by the field name in the request.
  Map<String, String> _serverErrors = {};

  /// True when this visit already had a write up, which makes this an edit
  /// rather than a first entry.
  bool get _isEditing => widget.visit.isRecorded;

  @override
  void initState() {
    super.initState();

    // Editing starts from what is already recorded, so a doctor correcting one
    // word does not have to type the rest again.
    final record = widget.visit.record;
    if (record != null) {
      _diagnosisController.text = record.diagnosis ?? '';
      _treatmentController.text = record.treatmentPlan ?? '';
      _notesController.text = record.notes ?? '';
    }

    // The medicines already prescribed at this visit come back with the record
    // itself, so the rows can be built right here - nothing has to be searched
    // for again to reopen a prescription.
    final prescription = widget.visit.prescription;
    if (prescription != null) {
      for (final item in prescription.items) {
        _lines.add(
          PrescriptionDraft(
            medicine: MedicineOption.fromPrescribed(item),
            instruction: item.dosageInstruction,
            doses: item.remainingDoses,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _diagnosisController.dispose();
    _treatmentController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _addLine() {
    setState(() => _lines.add(PrescriptionDraft()));
  }

  void _removeLine(int index) {
    setState(() {
      _lines.removeAt(index);
      // The errors were keyed by row number, and the rows have just moved.
      _serverErrors = {};
    });
  }

  Future<void> _save() async {
    // Nothing here can be saved twice by a double tap.
    if (_isSaving) return;

    // Rows the doctor added and then left empty are dropped before anything
    // else happens. They are not worth an error, and dropping them here rather
    // than inside the request keeps the rows on screen lined up with the rows
    // the API validates - it reports a bad medicine by its position, and a
    // blank row silently removed on the way out would shift every position
    // after it onto the wrong row.
    setState(() {
      _lines.removeWhere((line) => line.isBlank);
      _serverErrors = {};
    });

    if (!(_formKey.currentState?.validate() ?? false)) return;

    // A row with a brand on it but no instruction would be refused by the API;
    // catching it here points at the row instead of at the whole form.
    for (var i = 0; i < _lines.length; i++) {
      final line = _lines[i];

      if (line.medicine == null) {
        setState(
          () => _serverErrors = {
            'medicines.$i': 'Search for a medicine and pick one.',
          },
        );
        return;
      }

      if (line.instruction.trim().isEmpty) {
        setState(
          () => _serverErrors = {
            'medicines.$i': 'Say how to take it, e.g. 1+0+1 after meals.',
          },
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    final result = await EmrService.saveVisitRecord(
      doctorId: widget.doctor.id,
      appointmentId: widget.visit.appointmentId,
      diagnosis: _diagnosisController.text.trim(),
      treatmentPlan: _treatmentController.text.trim(),
      notes: _notesController.text.trim(),
      medicines: _lines,
    );

    if (!mounted) return;

    setState(() {
      _isSaving = false;
      _serverErrors = result.fieldErrors;
    });

    if (result.success) {
      Navigator.of(context).pop(true);
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 4),
        ),
      );
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
              ScreenHeader(
                title: _isEditing ? 'Edit Write Up' : 'Write Up Visit',
              ),
              const SizedBox(height: 12),

              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _VisitHeader(
                        visit: widget.visit,
                        patientName: widget.patientName,
                      ),
                      const SizedBox(height: 18),

                      // The one thing a record cannot be without. Everything
                      // else on this form is optional; a record with no
                      // diagnosis is not a record of anything, so the API
                      // refuses it too.
                      _FieldBlock(
                        label: 'Diagnosis',
                        isRequired: true,
                        hint: 'What you concluded, e.g. Acute gastritis',
                        controller: _diagnosisController,
                        maxLength: 255,
                        minLines: 2,
                        maxLines: 3,
                        enabled: !_isSaving,
                        errorText: _serverErrors['diagnosis'],
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? 'Please write the diagnosis.'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      _FieldBlock(
                        label: 'Treatment plan',
                        hint: 'How it is being treated, and when to review',
                        controller: _treatmentController,
                        minLines: 3,
                        maxLines: 5,
                        enabled: !_isSaving,
                        errorText: _serverErrors['treatment_plan'],
                      ),
                      const SizedBox(height: 16),

                      _FieldBlock(
                        label: 'Notes',
                        hint: 'Symptoms, what the patient reported, anything '
                            'worth keeping',
                        controller: _notesController,
                        minLines: 3,
                        maxLines: 5,
                        enabled: !_isSaving,
                        errorText: _serverErrors['notes'],
                      ),
                      const SizedBox(height: 22),

                      _buildPrescription(),
                      const SizedBox(height: 24),

                      Center(
                        child: PrimaryButton(
                          label: _isSaving
                              ? 'Saving...'
                              : (_isEditing ? 'Save changes' : 'Save record'),
                          onPressed: _isSaving ? null : _save,
                          width: 230,
                          glow: !_isSaving,
                        ),
                      ),
                      const SizedBox(height: 10),

                      Text(
                        _isEditing
                            ? 'Saving corrects this visit. It does not add a '
                                  'second write up of the same consultation.'
                            : 'Once saved this becomes part of the patient\'s '
                                  'record, and it is what you will see the '
                                  'next time they visit.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.medication_outlined,
              size: 20,
              color: AppColors.logoGreen,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Prescription',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _isSaving ? null : _addLine,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add medicine'),
              style: TextButton.styleFrom(foregroundColor: AppColors.logoGreen),
            ),
          ],
        ),

        if (_lines.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              _isEditing
                  ? 'Nothing prescribed at this visit. Saving with no '
                        'medicines leaves it that way.'
                  : 'Nothing prescribed yet. Add a medicine if the patient '
                        'needs one - brands are searched on MedEx as you type.',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
                height: 1.35,
              ),
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < _lines.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                _PrescriptionRow(
                  key: ObjectKey(_lines[i]),
                  line: _lines[i],
                  enabled: !_isSaving,
                  errorText: _serverErrors['medicines.$i'],
                  onChanged: () => setState(() {}),
                  onRemove: () => _removeLine(i),
                ),
              ],
            ],
          ),
      ],
    );
  }
}

/// Which visit is being written up. Read only: the appointment decides the
/// patient and the date, and nothing on this screen can move them.
class _VisitHeader extends StatelessWidget {
  const _VisitHeader({required this.visit, required this.patientName});

  final EmrVisit visit;
  final String patientName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.logoGreen, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            patientName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            visit.visitNo == null
                ? '${visit.dateLine}  ·  ${visit.visitType}'
                : 'Visit ${visit.visitNo}  ·  ${visit.dateLine}  ·  '
                      '${visit.visitType}',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
              height: 1.35,
            ),
          ),
          if (visit.placeLine.isNotEmpty)
            Text(
              visit.placeLine,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
        ],
      ),
    );
  }
}

/// One labelled multi line box on this form.
class _FieldBlock extends StatelessWidget {
  const _FieldBlock({
    required this.label,
    required this.controller,
    required this.hint,
    this.isRequired = false,
    this.minLines = 1,
    this.maxLines = 3,
    this.maxLength,
    this.enabled = true,
    this.errorText,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final bool isRequired;
  final int minLines;
  final int maxLines;
  final int? maxLength;
  final bool enabled;

  /// An error from the API rather than from [validator].
  final String? errorText;

  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: label,
            children: [
              if (isRequired)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: Colors.red),
                ),
            ],
          ),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          enabled: enabled,
          minLines: minLines,
          maxLines: maxLines,
          maxLength: maxLength,
          textCapitalization: TextCapitalization.sentences,
          validator: validator,
          style: const TextStyle(fontSize: 15, color: AppColors.textDark),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              fontSize: 13.5,
              color: AppColors.textMuted,
            ),
            errorText: errorText,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: AppColors.fieldBorder,
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: AppColors.logoGreen,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One medicine on the prescription being written.
class _PrescriptionRow extends StatelessWidget {
  const _PrescriptionRow({
    super.key,
    required this.line,
    required this.enabled,
    required this.onChanged,
    required this.onRemove,
    this.errorText,
  });

  final PrescriptionDraft line;
  final bool enabled;
  final VoidCallback onChanged;
  final VoidCallback onRemove;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: errorText == null ? AppColors.fieldBorder : Colors.red,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _MedicinePicker(
                  chosen: line.medicine,
                  enabled: enabled,
                  onPicked: (medicine) {
                    line.medicine = medicine;
                    onChanged();
                  },
                ),
              ),
              IconButton(
                onPressed: enabled ? onRemove : null,
                icon: const Icon(Icons.delete_outline),
                color: AppColors.historyCancelled,
                tooltip: 'Remove',
              ),
            ],
          ),

          // The rest of the line only matters once there is a brand on it.
          if (line.medicine != null) ...[
            const SizedBox(height: 10),

            TextFormField(
              initialValue: line.instruction,
              enabled: enabled,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                labelText: 'How to take it',
                labelStyle: TextStyle(fontSize: 13, color: AppColors.textMuted),
                hintText: 'e.g. 1+0+1 after meals',
                hintStyle: TextStyle(fontSize: 13, color: AppColors.textMuted),
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
              ),
              onChanged: (value) => line.instruction = value,
            ),
            const SizedBox(height: 8),

            TextFormField(
              initialValue: line.doses?.toString() ?? '',
              enabled: enabled,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                labelText: 'Doses (optional)',
                labelStyle: TextStyle(fontSize: 13, color: AppColors.textMuted),
                hintText: 'e.g. 14',
                hintStyle: TextStyle(fontSize: 13, color: AppColors.textMuted),
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
              ),
              onChanged: (value) => line.doses = value.trim().isEmpty
                  ? null
                  : int.tryParse(value),
            ),
          ],

          if (errorText != null) ...[
            const SizedBox(height: 8),
            Text(
              errorText!,
              style: TextStyle(fontSize: 12.5, color: Colors.red.shade700),
            ),
          ],
        ],
      ),
    );
  }
}

/// Type the first letters of a brand, pick it out of what MedEx answers.
///
/// This is the control that replaced the dropdown of medicines. A doctor
/// writing "ros" gets Rosuva, Rosutin, Rosebac and the rest, each with its own
/// strength and dosage form, exactly as they would find them on MedEx - not
/// whichever handful of brands happen to be in this app's database.
///
/// Once a brand is chosen the search box is put away and the brand is shown as
/// a line of the prescription, with Change to go back.
class _MedicinePicker extends StatefulWidget {
  const _MedicinePicker({
    required this.chosen,
    required this.enabled,
    required this.onPicked,
  });

  final MedicineOption? chosen;
  final bool enabled;
  final ValueChanged<MedicineOption?> onPicked;

  @override
  State<_MedicinePicker> createState() => _MedicinePickerState();
}

class _MedicinePickerState extends State<_MedicinePicker> {
  final _searchController = TextEditingController();

  List<MedicineOption> _results = [];
  bool _isSearching = false;
  String _message = '';
  String? _error;

  /// True when the last answer came out of the offline fallback rather than
  /// MedEx, which the doctor is told about.
  bool _isFallback = false;

  /// Waits for the doctor to stop typing, so "rosuva" is one lookup rather
  /// than six.
  Timer? _debounce;

  /// Guards against an early search answering after a later one. Without it a
  /// slow reply for "ro" could land on top of the results for "rosuv".
  int _requestId = 0;

  /// Longer than the list one screen can show. Anything past this means the
  /// doctor should type another letter rather than scroll.
  static const int _maxShown = 8;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onTyped(String value) {
    _debounce?.cancel();

    if (value.trim().length < 2) {
      setState(() {
        _results = [];
        _isSearching = false;
        _message = '';
        _error = null;
      });
      return;
    }

    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 400), _search);
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.length < 2) return;

    final requestId = ++_requestId;

    final result = await EmrService.searchMedicines(query);

    // A reply for a query the doctor has already typed past is thrown away.
    if (!mounted || requestId != _requestId) return;

    setState(() {
      _isSearching = false;
      if (result.isSuccess) {
        _results = result.medicines;
        _message = result.message;
        _isFallback = !result.isLive;
        _error = null;
      } else {
        _results = [];
        _error = result.error;
      }
    });
  }

  void _pick(MedicineOption medicine) {
    // The keyboard has nothing left to do once a brand is chosen.
    FocusScope.of(context).unfocus();

    setState(() {
      _results = [];
      _message = '';
      _searchController.clear();
    });

    widget.onPicked(medicine);
  }

  void _clear() {
    widget.onPicked(null);
  }

  @override
  Widget build(BuildContext context) {
    final chosen = widget.chosen;

    if (chosen != null) {
      return _ChosenMedicine(
        medicine: chosen,
        enabled: widget.enabled,
        onChange: _clear,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _searchController,
          enabled: widget.enabled,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          onChanged: _onTyped,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            labelText: 'Medicine',
            labelStyle: const TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
            ),
            hintText: 'Type a brand name, e.g. ros',
            hintStyle: const TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
            ),
            isDense: true,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 12,
            ),
            suffixIcon: _isSearching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.logoGreen,
                      ),
                    ),
                  )
                : const Icon(Icons.search, size: 20),
          ),
        ),

        if (_error != null) ...[
          const SizedBox(height: 6),
          Text(
            _error!,
            style: TextStyle(fontSize: 12, color: Colors.red.shade700),
          ),
        ],

        // Saying where the suggestions came from matters when they came from
        // the fallback: three local brands must not look like all MedEx has.
        if (_error == null && _isFallback && _message.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 14,
                color: AppColors.historyRescheduled,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _message,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.historyRescheduled,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ],

        if (_error == null &&
            !_isSearching &&
            _results.isEmpty &&
            _searchController.text.trim().length >= 2 &&
            _message.isNotEmpty &&
            !_isFallback) ...[
          const SizedBox(height: 6),
          Text(
            _message,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],

        if (_results.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.fieldBorder),
            ),
            child: Column(
              children: [
                for (final medicine in _results.take(_maxShown))
                  _SuggestionRow(
                    medicine: medicine,
                    onTap: () => _pick(medicine),
                  ),
                if (_results.length > _maxShown)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Text(
                      '${_results.length - _maxShown} more - type another '
                      'letter to narrow it down.',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// One brand in the suggestion list.
class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({required this.medicine, required this.onTap});

  final MedicineOption medicine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const Icon(
              Icons.medication_outlined,
              size: 16,
              color: AppColors.logoGreen,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    medicine.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  if (medicine.dosage != null && medicine.dosage!.isNotEmpty)
                    Text(
                      medicine.dosage!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.add_circle_outline, size: 18, color: AppColors.logoGreen),
          ],
        ),
      ),
    );
  }
}

/// The brand once it has been chosen, with a way back to the search box.
class _ChosenMedicine extends StatelessWidget {
  const _ChosenMedicine({
    required this.medicine,
    required this.enabled,
    required this.onChange,
  });

  final MedicineOption medicine;
  final bool enabled;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                medicine.name,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              if (medicine.dosage != null && medicine.dosage!.isNotEmpty)
                Text(
                  medicine.dosage!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
        ),
        TextButton(
          onPressed: enabled ? onChange : null,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.logoBlue,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Change', style: TextStyle(fontSize: 13)),
        ),
      ],
    );
  }
}
