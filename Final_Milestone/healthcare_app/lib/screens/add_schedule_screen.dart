import 'package:flutter/material.dart';

import '../models/doctor_schedule.dart';
import '../models/hospital.dart';
import '../models/signed_in_user.dart';
import '../models/weekday.dart';
import '../services/hospital_service.dart';
import '../services/schedule_service.dart';
import '../theme/app_colors.dart';
import '../widgets/form_dropdown.dart';
import '../widgets/primary_button.dart';
import '../widgets/screen_header.dart';
import '../widgets/weekday_picker_field.dart';

/// Screen 8 (Doctor) - Add Schedule.
/// Allows doctors to add or update their hospital schedule.
/// The doctor selects a hospital, working days, time slot, and optional off day.
/// If a schedule already exists for that hospital, Update replaces it.
class AddScheduleScreen extends StatefulWidget {
  const AddScheduleScreen({super.key, required this.doctor});

  final SignedInUser doctor;

  @override
  State<AddScheduleScreen> createState() => _AddScheduleScreenState();
}

class _AddScheduleScreenState extends State<AddScheduleScreen> {
  List<Hospital> _hospitals = [];

  /// What the doctor has already saved, keyed by hospital id.
  Map<int, DoctorSchedule> _existing = {};

  bool _isLoading = true;
  String? _loadError;
  bool _isSaving = false;

  Hospital? _hospital;
  List<Weekday> _weekdays = [];
  String? _timeSlot;
  Weekday? _offday;

  /// Errors sent back by PHP, keyed by the field name in the request.
  Map<String, String> _serverErrors = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Hospitals for the dropdown, plus the schedules this doctor already has.
  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    final hospitalResult = await HospitalService.fetchAll();
    if (!mounted) return;

    if (!hospitalResult.isSuccess) {
      setState(() {
        _isLoading = false;
        _loadError = hospitalResult.error;
      });
      return;
    }

    final scheduleResult = await ScheduleService.fetchForDoctor(
      widget.doctor.id,
    );
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _hospitals = hospitalResult.hospitals;
      // A doctor with no schedules yet is not an error, so the list simply
      // stays empty and nothing is prefilled.
      _existing = {
        for (final schedule in scheduleResult.schedules)
          schedule.hospitalId: schedule,
      };
    });
  }
  /// Loads whatever is already saved for the hospital that was just picked.
  void _onHospitalChanged(Hospital? hospital) {
    setState(() {
      _hospital = hospital;
      _serverErrors = {};

      final saved = hospital == null ? null : _existing[hospital.id];

      if (saved != null) {
        _weekdays = saved.weekdays;
        _timeSlot = saved.timeSlot;
        _offday = saved.offday;
      } else {
        _weekdays = [];
        _timeSlot = null;
        _offday = null;
      }
    });
  }

  Future<void> _onUpdatePressed() async {
    final hospital = _hospital;
    final timeSlot = _timeSlot;

    if (hospital == null || timeSlot == null || _weekdays.isEmpty) {
      return; // The button is disabled in this case anyway.
    }

    setState(() {
      _isSaving = true;
      _serverErrors = {};
    });

    final response = await ScheduleService.save(
      doctorId: widget.doctor.id,
      hospitalId: hospital.id,
      weekdays: _weekdays,
      timeSlot: timeSlot,
      offday: _offday,
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

    // Keep the local copy in step, so picking this hospital again shows what
    // was just saved without another round trip.
    final data = response.data;
    if (data != null) {
      setState(() {
        _existing[hospital.id] = DoctorSchedule.fromJson(data);
      });
    }

    await _showSuccessDialog(response.message);
  }

  Future<void> _showSuccessDialog(String message) async {
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
              Expanded(child: Text('Successful')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 14),
              Text(
                _hospital?.name ?? '',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                Weekday.describe(_weekdays),
                style: const TextStyle(color: AppColors.textMuted),
              ),
              Text(
                _timeSlot ?? '',
                style: const TextStyle(color: AppColors.textMuted),
              ),
              if (_offday != null)
                Text(
                  'Off day: ${_offday!.fullName}',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
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
  }

  @override
  Widget build(BuildContext context) {
    // Lit up only once the schedule is complete, the same rule the other
    // screens use. The off day is optional - a doctor may have none.
    final canUpdate = _hospital != null &&
        _weekdays.isNotEmpty &&
        _timeSlot != null &&
        !_isSaving;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ScreenHeader(title: 'Add Schedule'),
              const SizedBox(height: 24),
              Expanded(child: _buildBody(canUpdate)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(bool canUpdate) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.logoGreen),
            SizedBox(height: 16),
            Text(
              'Loading hospitals...',
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

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FormDropdown<Hospital>(
            hint: 'Hospital',
            icon: Icons.local_hospital_outlined,
            value: _hospital,
            items: _hospitals,
            // The area is part of the label because several hospitals share a
            // name across areas.
            itemLabel: (hospital) => '${hospital.name}  ·  ${hospital.area}',
            errorText: _serverErrors['hospital_id'],
            enabled: !_isSaving,
            onChanged: _onHospitalChanged,
          ),
          const SizedBox(height: 16),

          WeekdayPickerField(
            selected: _weekdays,
            enabled: !_isSaving,
            disabledDay: _offday,
            errorText: _serverErrors['weekday'],
            onChanged: (days) => setState(() => _weekdays = days),
          ),
          const SizedBox(height: 16),

          FormDropdown<String>(
            hint: 'Time Slot',
            icon: Icons.schedule_outlined,
            value: _timeSlot,
            items: TimeSlots.all,
            itemLabel: (slot) => slot,
            errorText: _serverErrors['time_slot'],
            enabled: !_isSaving,
            onChanged: (slot) => setState(() => _timeSlot = slot),
          ),
          const SizedBox(height: 16),

          FormDropdown<Weekday>(
            hint: 'Off day',
            icon: Icons.event_busy_outlined,
            value: _offday,
            // A day already chosen as a consultation day cannot be the off
            // day, so it is left out of the list.
            items: Weekday.values
                .where((day) => !_weekdays.contains(day))
                .toList(),
            itemLabel: (day) => day.fullName,
            errorText: _serverErrors['offday'],
            enabled: !_isSaving,
            onChanged: (day) => setState(() => _offday = day),
          ),

          if (_hospital != null && _existing.containsKey(_hospital!.id)) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 18,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You already have a schedule here. Update will replace it.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 30),

          Align(
            alignment: Alignment.centerRight,
            child: PrimaryButton(
              label: _isSaving ? 'Saving...' : 'Update',
              onPressed: canUpdate ? _onUpdatePressed : null,
              glow: canUpdate,
              width: 160,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}