import 'package:flutter/material.dart';

import '../models/appointment.dart';
import '../models/signed_in_user.dart';
import '../services/appointment_service.dart';
import '../theme/app_colors.dart';
import '../widgets/screen_header.dart';
import 'reschedule_appointment_screen.dart';

/// What the Manage screen did, handed back to the appointments list so it can
/// say the right thing once it has reloaded. Nothing happened is `null`.
enum ManageResult { cancelled, rescheduled }

/// Screen 15 (User / Patient) - Manage Appointments.
///
/// Reached from the Manage button on one card of the patient's appointments
/// screen. Two things can be done to a booking that has not happened yet, and
/// each gets a line explaining what it means before the button that does it:
///
///   Reschedule  move the visit to another day. Not built yet.
///   Cancel      call it off. Asks first, then writes.
///
/// Both write, and both pop back a [ManageResult] so the appointments screen
/// behind knows to reload rather than keep showing a visit that has moved or
/// is no longer happening.
class ManageAppointmentScreen extends StatefulWidget {
  const ManageAppointmentScreen({
    super.key,
    required this.patient,
    required this.appointment,
  });

  final SignedInUser patient;

  /// The one appointment being managed. A patient can have several upcoming at
  /// once, so this screen is always about a specific one rather than about
  /// "the next" appointment.
  final PatientAppointment appointment;

  @override
  State<ManageAppointmentScreen> createState() =>
      _ManageAppointmentScreenState();
}

class _ManageAppointmentScreenState extends State<ManageAppointmentScreen> {
  /// True while the cancel request is in flight, so Yes cannot be sent twice
  /// and Reschedule cannot be started on top of it.
  bool _isCancelling = false;

  /// Asks before doing anything, because a cancellation cannot be undone.
  Future<void> _onCancelPressed() async {
    final confirmed = await showDialog<bool>(
      context: context,
      // A stray tap outside the popup must not count as an answer either way.
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: const Text(
          'Are you sure you want to cancel?',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        content: Text(
          'Your appointment with ${widget.appointment.doctorDisplayName} on '
          '${widget.appointment.formattedDate} will be called off.\n\n'
          'This cannot be undone.',
          style: const TextStyle(
            fontSize: 15,
            color: AppColors.textMuted,
            height: 1.35,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        actions: [
          // No first and plainly drawn, so the safe answer is the easy one and
          // Yes is never the button under a reflex tap.
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textDark,
              side: const BorderSide(color: AppColors.fieldBorder, width: 1.5),
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'No',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.historyCancelled,
              foregroundColor: Colors.white,
              elevation: 2,
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Yes',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    // Both No and a closed popup land here as "not confirmed".
    if (confirmed != true || !mounted) return;

    setState(() => _isCancelling = true);

    final result = await AppointmentService.cancel(
      patientId: widget.patient.id,
      appointmentId: widget.appointment.id,
    );

    if (!mounted) return;

    setState(() => _isCancelling = false);

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

    // The API has already written the red history line, so there is nothing
    // left to do here but hand back to the list, which reloads and shows it.
    Navigator.of(context).pop(ManageResult.cancelled);
  }

  /// Opens the reschedule screen, which offers the days this doctor sits.
  ///
  /// It pops back with `true` once the appointment has actually moved, and
  /// that is handed straight on to the appointments list behind, so both
  /// screens close onto a list that reloads.
  Future<void> _onReschedulePressed() async {
    final moved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RescheduleAppointmentScreen(
          patient: widget.patient,
          appointmentId: widget.appointment.id,
        ),
      ),
    );

    if (!mounted || moved != true) return;

    Navigator.of(context).pop(ManageResult.rescheduled);
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
              const SizedBox(height: 18),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Which appointment this is about. A patient can have
                      // more than one upcoming, so without this the two
                      // buttons below would be ambiguous.
                      _AppointmentSummary(appointment: widget.appointment),
                      const SizedBox(height: 28),

                      const _ActionDescription(
                        'Move this visit to another day the doctor sits at '
                        'this hospital. The date you are giving up is kept in '
                        'your history.',
                      ),
                      const SizedBox(height: 10),
                      _ActionButton(
                        label: 'Reschedule',
                        colour: AppColors.logoGreen,
                        // Blocked only while a cancellation is being sent, so
                        // the two cannot race each other.
                        onPressed: _isCancelling
                            ? null
                            : _onReschedulePressed,
                      ),
                      const SizedBox(height: 30),

                      const _ActionDescription(
                        'Call this visit off. It leaves your current '
                        'appointments straight away and is recorded in your '
                        'history. This cannot be undone.',
                      ),
                      const SizedBox(height: 10),
                      _ActionButton(
                        label: _isCancelling ? 'Cancelling...' : 'Cancel',
                        colour: AppColors.historyCancelled,
                        onPressed: _isCancelling ? null : _onCancelPressed,
                      ),
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
}

/// The line above a button saying what that button is for.
class _ActionDescription extends StatelessWidget {
  const _ActionDescription(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        color: AppColors.textMuted,
        height: 1.4,
      ),
    );
  }
}

/// One full width action button, coloured by what it does.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.colour,
    required this.onPressed,
  });

  final String label;
  final Color colour;

  /// Passing null disables the button.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: colour,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFCBD3D1),
          disabledForegroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// A compact reminder of the appointment these buttons act on.
class _AppointmentSummary extends StatelessWidget {
  const _AppointmentSummary({required this.appointment});

  final PatientAppointment appointment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.fieldBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            appointment.doctorDisplayName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          if (appointment.departmentName.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              appointment.departmentName,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ],
          const SizedBox(height: 10),

          _SummaryLine(
            icon: Icons.calendar_month_outlined,
            text: appointment.formattedDate,
          ),
          if (appointment.time.isNotEmpty)
            _SummaryLine(
              icon: Icons.schedule_outlined,
              text: appointment.time,
            ),
          _SummaryLine(
            icon: Icons.local_hospital_outlined,
            text: appointment.hospitalLine,
          ),
        ],
      ),
    );
  }
}

/// One small icon plus text line inside the summary card.
class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textDark,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
