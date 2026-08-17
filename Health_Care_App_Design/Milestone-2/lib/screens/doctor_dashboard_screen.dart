import 'package:flutter/material.dart';

import '../models/signed_in_user.dart';
import '../services/appointment_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_drawer.dart';
import '../widgets/dashboard_action_card.dart';
import '../widgets/dashboard_header.dart';
import 'add_degrees_screen.dart';
import 'add_schedule_screen.dart';
import 'appointments_list_screen.dart';

/// The four boxes on the doctor dashboard. Each one leads to a screen that is
/// not built yet, so the enum keeps their labels and icons in one place.
enum DoctorAction {
  addSchedule('Add Schedule', Icons.calendar_month_outlined),
  addDegrees('Add Degrees', Icons.school_outlined),
  checkAppointments('Check Appointments', Icons.event_note_outlined),
  emrDetails('EMR Details of Patients', Icons.folder_shared_outlined);

  const DoctorAction(this.label, this.icon);

  final String label;
  final IconData icon;
}
/// Screen 7 (Doctor) - Dashboard.
/// Reached from the sign in screen when the account that signed in came from
/// the DOCTOR table. Everything shown here comes from the signed in account;
/// the screen does not read the database again by itself.
class DoctorDashboardScreen extends StatefulWidget {
  const DoctorDashboardScreen({super.key, required this.user});

  final SignedInUser user;

  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  /// The box the doctor tapped last, so it stays lit up.
  DoctorAction? _selectedAction;
  /// Appointments booked since the doctor last checked. This is the dot on
  /// the bell; the bell itself is always there.
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _refreshPendingCount();
  }

  Future<void> _refreshPendingCount() async {
    final count = await AppointmentService.pendingCount(widget.user.id);

    if (!mounted) return;

    setState(() => _pendingCount = count);
  }

  Future<void> _onActionTapped(DoctorAction action) async {
    setState(() => _selectedAction = action);

    switch (action) {
      case DoctorAction.addSchedule:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AddScheduleScreen(doctor: widget.user),
          ),
        );
      case DoctorAction.addDegrees:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AddDegreesScreen(doctor: widget.user),
          ),
        );
      case DoctorAction.checkAppointments:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AppointmentsListScreen(doctor: widget.user),
          ),
        );
        // Opening the list marks everything as seen, so coming back should
        // show a bell with no dot.
        if (mounted) await _refreshPendingCount();
      case DoctorAction.emrDetails:
        // This one opens its own screen once it is designed.
        _showComingSoon(action.label);
    }
  }

  void _showComingSoon(String what) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$what is coming next.'),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: AppDrawer(
        user: widget.user,
        destinations: DrawerDestination.forDoctor,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DashboardHeader(
                userName: widget.user.displayName,
                unreadCount: _pendingCount,
                onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
                onBellPressed: () {
                  if (_pendingCount == 0) {
                    _showComingSoon('Notifications');
                    return;
                  }
                  // The dot means new appointments, so the bell leads there.
                  _onActionTapped(DoctorAction.checkAppointments);
                },
              ),
              const SizedBox(height: 24),

              // Fixed heights inside a scroll view rather than a grid, because
              // the wireframe has two boxes on one row and two full width ones
              // below, and this cannot overflow on a short screen.
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 150,
                        child: Row(
                          children: [
                            Expanded(child: _card(DoctorAction.addSchedule)),
                            const SizedBox(width: 16),
                            Expanded(child: _card(DoctorAction.addDegrees)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      SizedBox(
                        height: 115,
                        child: _card(DoctorAction.checkAppointments),
                      ),
                      const SizedBox(height: 16),

                      SizedBox(
                        height: 130,
                        child: _card(DoctorAction.emrDetails),
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

  Widget _card(DoctorAction action) {
    return DashboardActionCard(
      icon: action.icon,
      label: action.label,
      selected: _selectedAction == action,
      onTap: () => _onActionTapped(action),
    );
  }
}