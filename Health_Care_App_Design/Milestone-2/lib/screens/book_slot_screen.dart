import 'package:flutter/material.dart';

import '../models/appointment.dart';
import '../models/doctor_listing.dart';
import '../models/hospital.dart';
import '../models/signed_in_user.dart';
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

  @override
  void initState() {
    super.initState();
    // Prefilled from the signed in account, since most patients book for
    // themselves. Both stay editable for booking on someone else's behalf.
    _nameController = TextEditingController(text: widget.patient.fullName);
    _mobileController = TextEditingController(text: widget.patient.phone);
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
                Text(
                  booking.time,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                Text(
                  '${booking.visitType} · ${booking.hospitalName ?? ''}',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
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
    final canSubmit = _date != null && _visitType != null && !_isSaving;

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