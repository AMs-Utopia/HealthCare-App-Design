import 'package:flutter/material.dart';

import '../models/appointment.dart';
import '../models/doctor_listing.dart';
import '../models/hospital.dart';
import '../models/signed_in_user.dart';
import '../models/slot_availability.dart';
import '../models/weekday.dart';
import '../services/appointment_service.dart';
import '../theme/app_colors.dart';
import '../widgets/form_dropdown.dart';
import '../widgets/primary_button.dart';
import '../widgets/screen_header.dart';

/// Screen 12 - Book a Slot.
/// Reached from the Book button on the doctors list. Writes one row to
/// APPOINTMENT. The date picker only allows days the doctor actually sits at
/// this hospital, so an impossible booking cannot be sent in the first place.
///
/// Two things are shown before the patient commits to anything, and both come
/// from the server rather than being worked out here:
///
///  - the chamber: the room the hospital gave this doctor, the floor it is on
///    and the lift that reaches it, so the patient knows where to go
///  - the slot: the doctor's hours are cut into fifteen minute serials, and
///    which one the patient would get depends on how many people have already
///    booked that day - something only the database knows, and something that
///    can change while this form is open
///
/// Once the day's last serial reaches the end of the sitting there is nothing
/// left to hand out, so the form says so and Submit is turned off rather than
/// letting the patient send a booking that would only be refused.
class BookSlotScreen extends StatefulWidget {
  const BookSlotScreen({
    super.key,
    required this.patient,
    required this.doctor,
    required this.hospital,
  });

  final SignedInUser patient;
  final DoctorListing doctor;
  final Hospital hospital;

  @override
  State<BookSlotScreen> createState() => _BookSlotScreenState();
}

class _BookSlotScreenState extends State<BookSlotScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _mobileController;

  DateTime? _date;
  String? _visitType;

  bool _isSaving = false;
  Map<String, String> _serverErrors = {};

  /// The chamber, and the slot the patient would be given on [_date].
  ///
  /// Loaded once without a date for the chamber alone, then again every time
  /// the date changes for the serial that goes with it.
  SlotAvailability? _slot;
  bool _isLoadingSlot = true;
  String? _slotError;

  @override
  void initState() {
    super.initState();
    // Prefilled from the signed in account, since most patients book for
    // themselves. Both stay editable for booking on someone else's behalf.
    _nameController = TextEditingController(text: widget.patient.fullName);
    _mobileController = TextEditingController(text: widget.patient.phone);

    _loadSlot();
  }

  /// Asks the server where the chamber is and, once a date has been picked,
  /// which serial and time that date would give.
  ///
  /// A failure here is deliberately not fatal: the chamber and the serial are
  /// worth showing but the booking does not depend on them, and the server
  /// works both out again for itself when Submit is pressed. So a patient on a
  /// flaky connection still gets a form they can send.
  Future<void> _loadSlot() async {
    setState(() {
      _isLoadingSlot = true;
      _slotError = null;
    });

    final result = await AppointmentService.slotAvailability(
      scheduleId: widget.doctor.scheduleId,
      date: _date == null ? null : _isoDate,
    );

    if (!mounted) return;

    setState(() {
      _isLoadingSlot = false;
      if (result.isSuccess) {
        _slot = result.slot;
      } else {
        _slotError = result.error;
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    super.dispose();
  }
  /// True only for the weekdays this doctor sits at this hospital.
  bool _isDoctorSitting(DateTime day) {
    // DateTime.weekday is 1 Monday .. 7 Sunday; Weekday runs Sat first.
    const byDartWeekday = {
      DateTime.saturday: Weekday.sat,
      DateTime.sunday: Weekday.sun,
      DateTime.monday: Weekday.mon,
      DateTime.tuesday: Weekday.tue,
      DateTime.wednesday: Weekday.wed,
      DateTime.thursday: Weekday.thu,
      DateTime.friday: Weekday.fri,
    };

    final weekday = byDartWeekday[day.weekday];
    return weekday != null && widget.doctor.weekdays.contains(weekday);
  }

  Future<void> _pickDate() async {
    if (_isSaving) return;

    final today = DateTime.now();
    final firstAllowed = DateTime(today.year, today.month, today.day);

    // Start on the doctor's next sitting rather than on a greyed out today.
    var initial = _date ?? firstAllowed;
    var guard = 0;
    while (!_isDoctorSitting(initial) && guard < 14) {
      initial = initial.add(const Duration(days: 1));
      guard++;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstAllowed,
      // Three months ahead is plenty for booking a chamber visit.
      lastDate: firstAllowed.add(const Duration(days: 90)),
      selectableDayPredicate: _isDoctorSitting,
      helpText: 'Select appointment date',
    );

    if (picked != null) {
      setState(() {
        _date = picked;
        _serverErrors.remove('appointment_date');
      });

      // A different day has a different queue, so the serial shown has to be
      // counted again against the day just picked.
      await _loadSlot();
    }
  }
  /// yyyy-mm-dd, which is what the date column takes.
  String get _isoDate {
    final date = _date!;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<void> _onSubmitPressed() async {
    setState(() => _serverErrors = {});

    if (!_formKey.currentState!.validate()) return;
    if (_date == null || _visitType == null) return;

    setState(() => _isSaving = true);

    final response = await AppointmentService.book(
      patientId: widget.patient.id,
      scheduleId: widget.doctor.scheduleId,
      contactName: _nameController.text.trim(),
      contactMobile: _mobileController.text.trim(),
      appointmentDate: _isoDate,
      visitType: _visitType!,
    );

    if (!mounted) return;

    setState(() {
      _isSaving = false;
      _serverErrors = response.fieldErrors;
    });

    if (!response.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.message),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 4),
        ),
      );

      // Somebody else may have taken the last slot while this form was open,
      // which is what the refusal usually means, so the count is read again to
      // show what is really left.
      await _loadSlot();
      return;
    }

    await _showSuccessDialog(
      response.data == null
          ? null
          : BookedAppointment.fromJson(response.data!),
    );
  }

  Future<void> _showSuccessDialog(BookedAppointment? booking) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.logoGreen),
              SizedBox(width: 10),
              Expanded(child: Text('Application Successful')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your appointment has been booked.'),
              if (booking != null) ...[
                const SizedBox(height: 14),
                // The serial is the one thing the patient needs on the day.
                Text(
                  'Serial no: ${booking.serialNo}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.logoGreen,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.doctor.displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  formatAppointmentDate(booking.date),
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                // The exact quarter hour this serial was given, not the
                // doctor's whole sitting.
                Text(
                  'Report at ${booking.time}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  '${booking.visitType} · ${booking.hospitalName ?? ''}',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                if (booking.chamber.summary != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    booking.chamber.summary!,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.logoBlue,
                    ),
                  ),
                ],
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    // Back to the doctors list, which is where booking started.
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // A day with no slots left cannot be booked, so Submit is off rather than
    // sending something the server is bound to refuse. An unknown slot - still
    // loading, or the check itself failed - does not block: the server settles
    // it either way.
    final isFull = _slot?.isFull ?? false;
    final canSubmit =
        _date != null && _visitType != null && !_isSaving && !isFull;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ScreenHeader(title: 'Book a Slot'),
              const SizedBox(height: 18),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildDoctorCard(),
                      const SizedBox(height: 12),
                      _buildChamberCard(),
                      const SizedBox(height: 22),

                      const Text(
                        'Application Form',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Divider(color: AppColors.fieldBorder),
                      const SizedBox(height: 14),

                      _buildForm(),
                      const SizedBox(height: 26),

                      Center(
                        child: PrimaryButton(
                          label: _isSaving ? 'Submitting...' : 'Submit',
                          onPressed: canSubmit ? _onSubmitPressed : null,
                          glow: canSubmit,
                          width: 180,
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

  /// The doctor's photo, name, qualifications and department.
  Widget _buildDoctorCard() {
    final doctor = widget.doctor;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.fieldBorder, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Doctors have no photo column yet, so this is the placeholder the
          // wireframe marks "img".
          CircleAvatar(
            radius: 34,
            backgroundColor: AppColors.logoGreen.withValues(alpha: 0.15),
            child: const Icon(
              Icons.person,
              size: 40,
              color: AppColors.logoGreen,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  doctor.displayName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                if (doctor.degrees != null && doctor.degrees!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    doctor.degrees!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.logoBlue,
                      height: 1.3,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  doctor.departmentName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.hospital.name} · ${doctor.timeSlot}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDateField(),
          const SizedBox(height: 10),
          _buildSlotPreview(),
          const SizedBox(height: 16),

          TextFormField(
            controller: _nameController,
            enabled: !_isSaving,
            textInputAction: TextInputAction.next,
            style: const TextStyle(fontSize: 16, color: AppColors.textDark),
            decoration: _fieldDecoration(
              label: 'Name',
              icon: Icons.person_outline,
              errorText: _serverErrors['contact_name'],
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _mobileController,
            enabled: !_isSaving,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            style: const TextStyle(fontSize: 16, color: AppColors.textDark),
            decoration: _fieldDecoration(
              label: 'Mobile',
              icon: Icons.phone_outlined,
              errorText: _serverErrors['contact_mobile'],
            ),
            validator: (value) {
              final mobile = value?.trim() ?? '';
              if (mobile.isEmpty) return 'Please enter a mobile number';
              if (!RegExp(r'^01[0-9]{9}$').hasMatch(mobile)) {
                return 'Enter an 11 digit number, e.g. 01712345678';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          FormDropdown<String>(
            hint: 'Type',
            icon: Icons.assignment_outlined,
            value: _visitType,
            items: VisitTypes.all,
            itemLabel: (type) => type,
            errorText: _serverErrors['visit_type'],
            enabled: !_isSaving,
            onChanged: (type) => setState(() => _visitType = type),
          ),
        ],
      ),
    );
  }

  /// Where the chamber is: room, floor and lift.
  ///
  /// The room comes from the doctor's schedule row, which the hospital filled
  /// in when the doctor saved that sitting. The doctors list already carries
  /// it, so it is drawn from there straight away and only replaced once the
  /// server answers - which keeps the card from flickering in empty on a slow
  /// connection.
  Widget _buildChamberCard() {
    final chamber = _slot?.chamber ?? widget.doctor.chamber;

    if (!chamber.isAssigned) {
      // Only true for a sitting saved before hospitals handed rooms out.
      // Saying so is better than printing "Room null" or a blank strip.
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.fieldBorder, width: 1.5),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.meeting_room_outlined,
              size: 20,
              color: AppColors.textMuted,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Chamber not assigned yet. Ask at the hospital reception.',
                style: TextStyle(fontSize: 13.5, color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.logoBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.logoBlue, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chamber',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.logoBlue,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _ChamberFact(
                icon: Icons.meeting_room_outlined,
                label: 'Room',
                value: chamber.roomNo!,
              ),
              _ChamberFact(
                icon: Icons.stairs_outlined,
                label: 'Floor',
                value: chamber.floor ?? '-',
              ),
              _ChamberFact(
                icon: Icons.elevator_outlined,
                label: 'Lift',
                value: chamber.floor ?? '-',
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// What the patient would be given on the date they picked: their place in
  /// the queue and the quarter hour that goes with it.
  Widget _buildSlotPreview() {
    if (_date == null) {
      return _SlotBox(
        colour: AppColors.textMuted,
        icon: Icons.schedule_outlined,
        title: 'Pick a date to see your serial and time.',
        subtitle: widget.doctor.timeSlot.isEmpty
            ? null
            : 'The doctor sits ${widget.doctor.timeSlot}.',
      );
    }

    if (_isLoadingSlot) {
      return const _SlotBox(
        colour: AppColors.textMuted,
        icon: Icons.hourglass_empty,
        title: 'Checking that day...',
      );
    }

    // The booking itself does not need this, so a failed check says so quietly
    // and leaves Submit alone.
    if (_slotError != null) {
      return _SlotBox(
        colour: AppColors.textMuted,
        icon: Icons.help_outline,
        title: 'Could not check that day.',
        subtitle: 'You can still book - your time will be shown after you do.',
      );
    }

    final slot = _slot;

    // A sitting whose hours could not be read has no ladder to show, and
    // neither does an answer that was only ever about the chamber.
    if (slot == null || !slot.hasSlots || !slot.hasDate) {
      return _SlotBox(
        colour: AppColors.textMuted,
        icon: Icons.schedule_outlined,
        title: widget.doctor.timeSlot.isEmpty
            ? 'The doctor has not set their hours.'
            : widget.doctor.timeSlot,
      );
    }

    if (slot.isFull) {
      return _SlotBox(
        colour: AppColors.historyCancelled,
        icon: Icons.event_busy_outlined,
        title: 'No more slots on this date.',
        subtitle: slot.closingTime == null
            ? 'Please choose another day.'
            : 'The chamber closes at ${slot.closingTime}. '
                  'Please choose another day.',
      );
    }

    return _SlotBox(
      colour: AppColors.logoGreen,
      icon: Icons.confirmation_number_outlined,
      title: 'Serial ${slot.nextSerial} · report at ${slot.nextTime}',
      subtitle:
          '${slot.remainingLine} '
          'Each patient gets ${slot.slotMinutes} minutes.',
    );
  }

  /// The date box, which opens the picker instead of a keyboard.
  Widget _buildDateField() {
    final error = _serverErrors['appointment_date'];

    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: _fieldDecoration(
          label: 'Select Date',
          icon: Icons.calendar_today_outlined,
          errorText: error,
        ).copyWith(
          suffixIcon: const Icon(Icons.edit_calendar_outlined),
          // The label would otherwise float over the chosen date.
          labelText: null,
          hintText: null,
        ),
        child: Text(
          _date == null ? 'Select Date' : formatAppointmentDate(_isoDate),
          style: TextStyle(
            fontSize: 16,
            color: _date == null ? AppColors.textMuted : AppColors.textDark,
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    String? errorText,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      hintText: label,
      hintStyle: const TextStyle(fontSize: 16, color: AppColors.textMuted),
      errorText: errorText,
      errorMaxLines: 2,
      prefixIcon: Icon(icon, size: 22, color: AppColors.textMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      enabledBorder: formFieldBorder(AppColors.fieldBorder),
      disabledBorder: formFieldBorder(
        AppColors.fieldBorder.withValues(alpha: 0.4),
      ),
      focusedBorder: formFieldBorder(AppColors.logoGreen, 2),
      errorBorder: formFieldBorder(Colors.red),
      focusedErrorBorder: formFieldBorder(Colors.red, 2),
    );
  }
}

/// One of Room / Floor / Lift on the chamber strip.
class _ChamberFact extends StatelessWidget {
  const _ChamberFact({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.logoBlue),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The strip under the date field. Green when there is a slot, red when the
/// day is full, grey while nothing is known yet.
class _SlotBox extends StatelessWidget {
  const _SlotBox({
    required this.colour,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final Color colour;
  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colour, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: colour),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: colour,
                  ),
                ),
                if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!.trim(),
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
