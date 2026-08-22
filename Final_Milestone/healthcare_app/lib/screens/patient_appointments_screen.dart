import 'package:flutter/material.dart';

import '../models/appointment.dart';
import '../models/signed_in_user.dart';
import '../services/appointment_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/screen_header.dart';
import 'manage_appointment_screen.dart';

/// Screen 14 (User / Patient) - Appointments.
///
/// Reached from the "Appointment" entry in the patient's drawer. Two sections,
/// one above the other, exactly as drawn on the wireframe:
///
///   Current Appointments  the visits still ahead of them, each with the
///                         Manage button that will reschedule or cancel it.
///   History               every action ever taken on their bookings, most
///                         recent at the top, colour coded green for a
///                         booking, yellow for a reschedule and red for a
///                         cancellation.
///
/// The two are different things, not two views of the same thing. A current
/// appointment is a row of APPOINTMENT; a history line is a row of
/// APPOINTMENT_HISTORY, which keeps one entry per action so a booking that was
/// moved and then called off still shows all three steps rather than only its
/// final state.
class PatientAppointmentsScreen extends StatefulWidget {
  const PatientAppointmentsScreen({super.key, required this.patient});

  final SignedInUser patient;

  @override
  State<PatientAppointmentsScreen> createState() =>
      _PatientAppointmentsScreenState();
}

class _PatientAppointmentsScreenState extends State<PatientAppointmentsScreen> {
  List<PatientAppointment> _current = [];
  List<AppointmentHistoryEntry> _history = [];

  bool _isLoading = true;
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

    // Opening this screen shows the whole history, so everything on it counts
    // as read and the red dot on the patient's bell clears.
    final result = await AppointmentService.fetchForPatient(
      widget.patient.id,
      markSeen: true,
    );

    // The screen can be gone by the time the reply arrives.
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.isSuccess) {
        _current = result.current;
        _history = result.history;
      } else {
        _current = [];
        _history = [];
        _loadError = result.error;
      }
    });
  }

  /// Opens the Manage screen for one appointment.
  ///
  /// It pops back saying what it did, and the list is reloaded either way:
  /// a cancellation drops the visit out of Current and adds its red line to
  /// History, a reschedule moves the card and adds a yellow one.
  Future<void> _onManagePressed(PatientAppointment appointment) async {
    final result = await Navigator.of(context).push<ManageResult>(
      MaterialPageRoute(
        builder: (_) => ManageAppointmentScreen(
          patient: widget.patient,
          appointment: appointment,
        ),
      ),
    );

    if (!mounted || result == null) return;

    await _load();

    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            switch (result) {
              ManageResult.cancelled => 'Your appointment has been cancelled.',
              ManageResult.rescheduled => 'Your appointment has been moved.',
            },
          ),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: AppBottomNav(
        current: AppTab.appointments,
        patient: widget.patient,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ScreenHeader(title: 'Appointments'),
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
              'Loading your appointments...',
              style: TextStyle(fontSize: 15, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    if (_loadError != null) {
      return _buildError();
    }

    // One scroll view over both sections, so a long history scrolls the whole
    // page the way the wireframe shows rather than scrolling in a box of its
    // own underneath a pinned card.
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.logoGreen,
      child: CustomScrollView(
        // Always scrollable, so pull to refresh still works when both lists
        // are short enough to fit on the screen.
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(
            child: _SectionTitle(title: 'Current Appointments'),
          ),

          if (_current.isEmpty)
            const SliverToBoxAdapter(
              child: _EmptyNote(
                icon: Icons.event_available_outlined,
                message:
                    'You have no upcoming appointments.\nBook one from Doctor '
                    'Lists on your dashboard.',
              ),
            )
          else
            SliverList.separated(
              itemCount: _current.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _CurrentAppointmentCard(
                appointment: _current[index],
                onManage: () => _onManagePressed(_current[index]),
              ),
            ),

          const SliverToBoxAdapter(
            child: _SectionTitle(title: 'History', topPadding: 26),
          ),

          if (_history.isEmpty)
            const SliverToBoxAdapter(
              child: _EmptyNote(
                icon: Icons.history,
                message:
                    'Nothing here yet. Booking, rescheduling or cancelling an '
                    'appointment will show up here.',
              ),
            )
          else
            SliverList.separated(
              itemCount: _history.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) =>
                  _HistoryRow(entry: _history[index]),
            ),

          // Breathing room under the last row, so it does not sit against the
          // bottom edge of the phone.
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _buildError() {
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
              style: TextButton.styleFrom(foregroundColor: AppColors.logoGreen),
            ),
          ],
        ),
      ),
    );
  }
}

/// A section heading with the rule under it, as drawn on the wireframe.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.topPadding = 0});

  final String title;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: topPadding, bottom: 14),
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

/// Shown in place of a list that has nothing in it.
class _EmptyNote extends StatelessWidget {
  const _EmptyNote({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.fieldBorder, width: 1.5),
      ),
      child: Column(
        children: [
          Icon(icon, size: 34, color: AppColors.textMuted),
          const SizedBox(height: 10),
          Text(
            message,
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

/// One upcoming appointment: the details on the left, Manage on the right.
class _CurrentAppointmentCard extends StatelessWidget {
  const _CurrentAppointmentCard({
    required this.appointment,
    required this.onManage,
  });

  final PatientAppointment appointment;
  final VoidCallback onManage;

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
          const Text(
            'Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 10),

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

          _InfoLine(
            icon: Icons.calendar_month_outlined,
            text: appointment.formattedDate,
          ),
          if (appointment.time.isNotEmpty)
            _InfoLine(
              icon: Icons.schedule_outlined,
              text: 'Report at ${appointment.time}',
            ),
          _InfoLine(
            icon: Icons.local_hospital_outlined,
            text: appointment.hospitalLine,
          ),
          // Where in the building to go, as the booking form said it.
          if (appointment.chamber.summary != null)
            _InfoLine(
              icon: Icons.meeting_room_outlined,
              text: appointment.chamber.summary!,
            ),
          if (appointment.serialNo > 0)
            _InfoLine(
              icon: Icons.confirmation_number_outlined,
              text: 'Serial no. ${appointment.serialNo}',
            ),
          if (appointment.visitType.isNotEmpty)
            _InfoLine(
              icon: Icons.medical_information_outlined,
              text: appointment.visitType,
            ),
          // Only worth naming when the visit is for somebody else.
          if (appointment.contactName != null &&
              appointment.contactName!.isNotEmpty &&
              appointment.contactName != appointment.doctorName)
            _InfoLine(
              icon: Icons.person_outline,
              text: 'For ${appointment.contactName}',
            ),

          const SizedBox(height: 12),

          // The status on the left, Manage on the right, as on the wireframe.
          Row(
            children: [
              Expanded(child: _StatusChip(appointment: appointment)),
              const SizedBox(width: 12),
              // Green, the same as Book on the doctors list, because both are
              // the action the card exists for.
              ElevatedButton(
                onPressed: onManage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.logoGreen,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Manage',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Whether the doctor has seen this booking yet.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.appointment});

  final PatientAppointment appointment;

  @override
  Widget build(BuildContext context) {
    final waiting = appointment.isAwaitingDoctor;

    // Amber while the doctor has not opened their list, green once they have.
    // Same two colours the history list uses, so they read the same way.
    final colour = waiting
        ? AppColors.historyRescheduled
        : AppColors.historyBooked;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: colour.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colour, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              waiting ? Icons.hourglass_top : Icons.check_circle_outline,
              size: 14,
              color: colour,
            ),
            const SizedBox(width: 5),
            Text(
              waiting ? 'Awaiting doctor' : 'Confirmed',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colour,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One line of the history list, with its colour down the left hand side.
///
/// The stripe is the point of this row: green for a booking, yellow for a
/// reschedule and red for a cancellation, so the trail can be read without
/// reading any of the words.
class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry});

  final AppointmentHistoryEntry entry;

  /// The one place the three colours are attached to the three actions.
  Color get _colour {
    switch (entry.action) {
      case AppointmentAction.booked:
        return AppColors.historyBooked;
      case AppointmentAction.rescheduled:
        return AppColors.historyRescheduled;
      case AppointmentAction.cancelled:
        return AppColors.historyCancelled;
      case AppointmentAction.unknown:
        return AppColors.textMuted;
    }
  }

  IconData get _icon {
    switch (entry.action) {
      case AppointmentAction.booked:
        return Icons.event_available_outlined;
      case AppointmentAction.rescheduled:
        return Icons.event_repeat_outlined;
      case AppointmentAction.cancelled:
        return Icons.event_busy_outlined;
      case AppointmentAction.unknown:
        return Icons.history;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colour = _colour;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.fieldBorder, width: 1.5),
      ),
      // clipBehavior lets the coloured stripe follow the rounded corners
      // instead of poking out past them.
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The colour, beside the entry.
            Container(width: 7, color: colour),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(_icon, size: 17, color: colour),
                        const SizedBox(width: 6),
                        Text(
                          entry.action.label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: colour,
                          ),
                        ),
                        const Spacer(),
                        // When it happened. This is what the list is ordered
                        // by, so it belongs on every row.
                        Flexible(
                          child: Text(
                            entry.formattedTimestamp,
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    Text(
                      entry.description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textDark,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),

                    Text(
                      '${entry.doctorDisplayName}  ·  ${entry.hospitalLine}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One small icon plus text line inside a card.
class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

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
