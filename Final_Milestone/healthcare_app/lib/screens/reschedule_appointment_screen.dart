import 'package:flutter/material.dart';

import '../models/appointment.dart';
import '../models/signed_in_user.dart';
import '../services/appointment_service.dart';
import '../theme/app_colors.dart';
import '../widgets/form_dropdown.dart';
import '../widgets/primary_button.dart';
import '../widgets/screen_header.dart';

/// Screen 16 (User / Patient) - Reschedule.
///
/// Reached from the Reschedule button on the Manage screen. Shows the sitting
/// as it stands under "Current Schedule", then one green dropdown offering the
/// next few days that doctor actually holds a chamber.
///
/// The dropdown is filled by the server rather than by a free date picker, and
/// that is the whole design: a day the doctor does not sit can never be
/// chosen, so there is no impossible booking to reject afterwards and no error
/// message on this screen for one.
class RescheduleAppointmentScreen extends StatefulWidget {
  const RescheduleAppointmentScreen({
    super.key,
    required this.patient,
    required this.appointmentId,
  });

  final SignedInUser patient;

  /// Only the id is passed in. Everything shown is read back from the server,
  /// so the screen cannot show a stale date if the appointment changed since
  /// the list behind it was loaded.
  final int appointmentId;

  @override
  State<RescheduleAppointmentScreen> createState() =>
      _RescheduleAppointmentScreenState();
}

class _RescheduleAppointmentScreenState
    extends State<RescheduleAppointmentScreen> {
  RescheduleContext? _current;
  List<RescheduleOption> _options = [];

  /// The day the patient picked, still unconfirmed.
  RescheduleOption? _chosen;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _loadError;

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

    final result = await AppointmentService.rescheduleOptions(
      patientId: widget.patient.id,
      appointmentId: widget.appointmentId,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.isSuccess) {
        _current = result.current;
        _options = result.options;
        // A slot chosen before a refresh may no longer be on offer.
        if (!_options.any((option) => option.date == _chosen?.date)) {
          _chosen = null;
        }
      } else {
        _loadError = result.error;
      }
    });
  }

  Future<void> _onConfirmPressed() async {
    final chosen = _chosen;
    if (chosen == null) return;

    setState(() => _isSaving = true);

    final result = await AppointmentService.reschedule(
      patientId: widget.patient.id,
      appointmentId: widget.appointmentId,
      newDate: chosen.date,
    );

    if (!mounted) return;

    setState(() => _isSaving = false);

    if (!result.success) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      return;
    }

    // true all the way back, so the Manage screen and the appointments list
    // behind it both know to reload rather than keep showing the old date.
    Navigator.of(context).pop(true);
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
              const ScreenHeader(title: 'Manage Appointments'),
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

    if (_loadError != null || _current == null) {
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
                _loadError ?? 'This appointment could not be loaded.',
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

    final current = _current!;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionTitle(title: 'Current Schedule'),

          // The four lines from the wireframe, in its order.
          _DetailRow(label: 'Hospital', value: current.hospitalLine),
          _DetailRow(label: 'Dr', value: current.doctorDisplayName),
          _DetailRow(label: 'Room', value: current.chamber.roomLabel),
          _DetailRow(label: 'floor', value: current.floorLine),
          _DetailRow(label: 'Lift', value: current.chamber.liftLabel),
          _DetailRow(label: 'Date', value: current.formattedDate),
          _DetailRow(label: 'Time', value: current.time),

          const SizedBox(height: 26),

          if (_options.isEmpty)
            _buildNoSittings(current)
          else ...[
            Text(
              '${current.doctorDisplayName} sits on ${current.sittingDays}. '
              'The next available days are below.',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),

            // Green, because on this screen the dropdown is the action rather
            // than one field among several.
            FormDropdown<RescheduleOption>(
              hint: 'Choose New Slot',
              value: _chosen,
              items: _options,
              itemLabel: (option) => option.slotLabel,
              enabled: !_isSaving,
              icon: Icons.event_available_outlined,
              borderColor: AppColors.logoGreen,
              onChanged: (option) => setState(() => _chosen = option),
            ),
            const SizedBox(height: 8),

            // The chosen day decides the serial, so the new time is spelled
            // out here rather than left as a surprise on the next screen.
            if (_chosen != null && _chosen!.isFull)
              const Text(
                'That day is fully booked, so this appointment cannot be moved '
                'to it. Please choose another one.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.historyCancelled,
                  height: 1.35,
                ),
              )
            else if (_chosen?.nextTime != null)
              Text(
                'You would be serial ${_chosen!.nextSerial} that day, '
                'reporting at ${_chosen!.nextTime}. The hospital and the room '
                'stay the same. Your doctor is told, and confirms the new day.',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                  height: 1.35,
                ),
              )
            else
              const Text(
                'The hospital and the room stay the same - only the day '
                'changes. Your doctor is told, and confirms the new day.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                  height: 1.35,
                ),
              ),
            const SizedBox(height: 26),

            Center(
              child: PrimaryButton(
                label: _isSaving ? 'Moving...' : 'Confirm',
                // Disabled and dull until a day is picked, so Confirm can
                // never be tapped on nothing.
                onPressed:
                    _chosen == null || _isSaving || _chosen!.isFull
                    ? null
                    : _onConfirmPressed,
                glow: _chosen != null && !_chosen!.isFull && !_isSaving,
                width: 210,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Shown when the doctor has no sittings in the weeks ahead, which is the
  /// one case where there is nothing to offer.
  Widget _buildNoSittings(RescheduleContext current) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.fieldBorder, width: 1.5),
      ),
      child: Column(
        children: [
          const Icon(Icons.event_busy_outlined, size: 34, color: AppColors.textMuted),
          const SizedBox(height: 10),
          Text(
            '${current.doctorDisplayName} has no sittings coming up, so there '
            'is nothing to move this appointment to yet.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textMuted,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

/// A section heading with the rule under it, as drawn on the wireframe.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.only(bottom: 6),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.fieldBorder, width: 1.5),
          ),
        ),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
      ),
    );
  }
}

/// One "label : value" line with the underline the wireframe draws.
class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: 78,
            child: Text(
              '$label :',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.only(bottom: 4),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.fieldBorder, width: 1.2),
                ),
              ),
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textDark,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
