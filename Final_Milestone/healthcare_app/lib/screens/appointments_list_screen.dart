import 'package:flutter/material.dart';

import '../models/appointment.dart';
import '../models/signed_in_user.dart';
import '../services/appointment_service.dart';
import '../theme/app_colors.dart';
import '../widgets/screen_header.dart';

/// Screen 13 (Doctor) - Appointments List.
///
/// Reached from the "Check Appointments" box on the doctor dashboard. Opening
/// it counts as checking, so every appointment still Pending becomes Confirmed
/// and the dot on the doctor's bell clears.
///
/// The list is not only new bookings: a patient who moves or calls off a visit
/// shows up here too, badged with what they did, which is what the bell was
/// telling the doctor about. Cancelled visits stay on the list rather than
/// vanishing - a visit that will not happen is something the doctor needs to
/// see. The doctor can also call one off from here.
///
/// Newest first, and newest means most recently acted on rather than soonest
/// due. The doctor arrives here because something changed, so what changed has
/// to be at the top where they see it without scrolling; older bookings, which
/// they have already read, keep the bottom. The order is set by the API, from
/// APPOINTMENT_HISTORY - the only place anything in this flow is timestamped -
/// so it cannot drift from what the bell counted.
class AppointmentsListScreen extends StatefulWidget {
  const AppointmentsListScreen({super.key, required this.doctor});

  final SignedInUser doctor;

  @override
  State<AppointmentsListScreen> createState() => _AppointmentsListScreenState();
}

class _AppointmentsListScreenState extends State<AppointmentsListScreen> {
  List<DoctorAppointment> _appointments = [];
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    // markSeen only on the first load: a manual refresh should not be needed
    // to clear the bell twice.
    _load(markSeen: true);
  }

  Future<void> _load({bool markSeen = false}) async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    final result = await AppointmentService.fetchForDoctor(
      widget.doctor.id,
      markSeen: markSeen,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.isSuccess) {
        _appointments = result.appointments;
      } else {
        _loadError = result.error;
      }
    });
  }

  /// The doctor calling one patient's visit off. Asks first, the same way the
  /// patient's own cancel does, because it cannot be undone either.
  Future<void> _onCancelPressed(DoctorAppointment appointment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Cancel this appointment?',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        content: Text(
          '${appointment.patientName} is booked for '
          '${formatAppointmentDate(appointment.date)}.\n\n'
          'They will be told, and this cannot be undone.',
          style: const TextStyle(
            fontSize: 15,
            color: AppColors.textMuted,
            height: 1.35,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        actions: [
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

    if (confirmed != true || !mounted) return;

    final result = await AppointmentService.cancelByDoctor(
      doctorId: widget.doctor.id,
      appointmentId: appointment.id,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? null : Colors.red.shade700,
          duration: const Duration(seconds: 3),
        ),
      );

    // Reloading without markSeen: the doctor did this one, so it was never
    // unread, and re-marking would clear anything that arrived meanwhile.
    if (result.success) await _load();
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
              const ScreenHeader(title: 'Appointments List'),
              const SizedBox(height: 12),

              if (!_isLoading && _loadError == null)
                Text(
                  _appointments.length == 1
                      ? '1 appointment'
                      : '${_appointments.length} appointments · newest first',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textMuted,
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
              'Loading appointments...',
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

    if (_appointments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.event_available_outlined,
                size: 48,
                color: AppColors.textMuted,
              ),
              SizedBox(height: 14),
              const Text(
                'No patients have booked you yet.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppColors.textDark),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.logoGreen,
                ),
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
        itemCount: _appointments.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _AppointmentCard(
          appointment: _appointments[index],
          onCancel: () => _onCancelPressed(_appointments[index]),
        ),
      ),
    );
  }
}

/// One patient's booking, as the doctor sees it.
class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({required this.appointment, required this.onCancel});

  final DoctorAppointment appointment;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        // A called off visit is drawn in red so it cannot be mistaken for one
        // the doctor still has to attend.
        border: Border.all(
          color: appointment.isCancelled
              ? AppColors.historyCancelled
              : AppColors.fieldBorder,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The serial is what the doctor calls patients in by, so it
              // leads the card.
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.logoGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.logoGreen, width: 1.5),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'No.',
                      style: TextStyle(
                        fontSize: 9,
                        color: AppColors.textMuted,
                      ),
                    ),
                    Text(
                      '${appointment.serialNo}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.logoGreen,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      appointment.patientName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    if (appointment.patientUid != null)
                      Text(
                        appointment.patientUid!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),

              _VisitTypeChip(type: appointment.visitType),
            ],
          ),

          // What last happened to this booking. Only shown when it is worth
          // saying: a plain booking the doctor has already seen says nothing.
          if (appointment.lastAction != null &&
              (appointment.wasChanged || appointment.hasUnseen)) ...[
            const SizedBox(height: 10),
            _ChangeBadge(appointment: appointment),
          ],

          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.fieldBorder),
          const SizedBox(height: 10),

          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _Fact(
                label: 'Age',
                // No screen collects a date of birth yet, so this is normally
                // blank rather than wrong.
                value: appointment.age == null
                    ? 'Not set'
                    : '${appointment.age}',
              ),
              if (appointment.gender != null && appointment.gender!.isNotEmpty)
                _Fact(label: 'Gender', value: appointment.gender!),
              if (appointment.bloodGroup != null &&
                  appointment.bloodGroup!.isNotEmpty)
                _Fact(label: 'Blood', value: appointment.bloodGroup!),
              _Fact(
                label: 'Date',
                value: formatAppointmentDate(appointment.date),
              ),
              // The quarter hour this patient was given, worked out from
              // their serial - not the doctor's whole sitting.
              _Fact(label: 'Reports at', value: appointment.time),
              if (appointment.contactMobile != null)
                _Fact(label: 'Mobile', value: appointment.contactMobile!),
            ],
          ),

          // What the list is ordered by, said out loud, so the order does not
          // look arbitrary to a doctor reading down the screen.
          if (appointment.lastActivityLine != null) ...[
            const SizedBox(height: 8),
            Text(
              '${_actionVerb(appointment)} ${appointment.lastActivityLine!}',
              style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
            ),
          ],

          // Only worth showing when the booking was made for someone else.
          if (appointment.contactName != null &&
              appointment.contactName != appointment.patientName) ...[
            const SizedBox(height: 8),
            Text(
              'Booked as: ${appointment.contactName}',
              style: const TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: AppColors.textMuted,
              ),
            ),
          ],

          // Nothing left to cancel on a visit that is already off.
          if (!appointment.isCancelled) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: onCancel,
                icon: const Icon(Icons.event_busy_outlined, size: 18),
                label: const Text('Cancel'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.historyCancelled,
                  side: const BorderSide(
                    color: AppColors.historyCancelled,
                    width: 1.5,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
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

/// How the timestamp under a card reads, which depends on what it is the time
/// of: a booking, a move, or a cancellation.
String _actionVerb(DoctorAppointment appointment) {
  switch (appointment.lastAction) {
    case AppointmentAction.rescheduled:
      return 'Moved';
    case AppointmentAction.cancelled:
      return 'Cancelled';
    default:
      return 'Booked';
  }
}

/// Says what last happened to a booking, in the same colours the patient's own
/// history uses: green booked, amber moved, red called off.
///
/// The filled dot means the doctor had not seen it when the list was opened,
/// which is the per row version of the dot on their bell.
class _ChangeBadge extends StatelessWidget {
  const _ChangeBadge({required this.appointment});

  final DoctorAppointment appointment;

  Color get _colour {
    switch (appointment.lastAction) {
      case AppointmentAction.rescheduled:
        return AppColors.historyRescheduled;
      case AppointmentAction.cancelled:
        return AppColors.historyCancelled;
      default:
        return AppColors.historyBooked;
    }
  }

  IconData get _icon {
    switch (appointment.lastAction) {
      case AppointmentAction.rescheduled:
        return Icons.event_repeat_outlined;
      case AppointmentAction.cancelled:
        return Icons.event_busy_outlined;
      default:
        return Icons.fiber_new_outlined;
    }
  }

  String get _label {
    final byDoctor = appointment.lastActor == 'doctor';

    switch (appointment.lastAction) {
      case AppointmentAction.rescheduled:
        return 'Patient moved this appointment';
      case AppointmentAction.cancelled:
        return byDoctor ? 'You cancelled this' : 'Patient cancelled this';
      default:
        return 'New booking';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colour = _colour;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colour, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 16, color: colour),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              _label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: colour,
              ),
            ),
          ),
          if (appointment.hasUnseen) ...[
            const SizedBox(width: 8),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
            ),
          ],
        ],
      ),
    );
  }
}

/// The New / Follow-up / Report Check tag.
class _VisitTypeChip extends StatelessWidget {
  const _VisitTypeChip({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    // A first visit is the one the doctor most needs to spot at a glance.
    final isNew = type == 'New';
    final colour = isNew ? AppColors.logoGreen : AppColors.logoBlue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colour),
      ),
      child: Text(
        type,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colour,
        ),
      ),
    );
  }
}

/// One small "label: value" pair inside an appointment card.
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