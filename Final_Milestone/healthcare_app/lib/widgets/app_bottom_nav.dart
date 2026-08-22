import 'package:flutter/material.dart';

import '../models/signed_in_user.dart';
import '../screens/health_dashboard_screen.dart';
import '../screens/health_records_screen.dart';
import '../screens/patient_appointments_screen.dart';
import '../screens/services_screen.dart';
import '../theme/app_colors.dart';

/// The five places a patient can always get to, from anywhere inside the app.
///
/// The problem it solves: everything below the dashboard used to be reachable
/// only by the path that led there. Health Records sat behind the drawer, the
/// Health Dashboard behind a box on the dashboard or a button at the foot of
/// Health Records, and Lab Tests three taps down inside Services. Two screens
/// deep, the only way anywhere else was to press back until something familiar
/// appeared - which is exactly how somebody loses track of where they are.
///
/// So these five are always underfoot, and tapping one arrives at that screen
/// in one tap rather than several.
///
/// **Why it never pushes onto the current screen.** Every tab first pops back
/// to the dashboard and only then pushes, so the stack is never deeper than
/// dashboard + one screen. Without that, hopping Records → Health → Records
/// would stack five screens that all look like destinations, and back would
/// walk the patient through their own browsing history in reverse - a worse
/// version of the disorientation this is meant to fix. With it, back always
/// means "return to the dashboard", from everywhere.
///
/// It is deliberately absent from screens in the middle of doing something -
/// booking a slot, ordering medicine, editing a profile. A bar offering to
/// leave is not a kindness when leaving abandons a half finished booking.
enum AppTab {
  home('Home', Icons.home_outlined, Icons.home),
  appointments('Appointments', Icons.event_available_outlined, Icons.event_available),
  services('Services', Icons.grid_view_outlined, Icons.grid_view),
  records('Records', Icons.folder_shared_outlined, Icons.folder_shared),
  health('Health', Icons.monitor_heart_outlined, Icons.monitor_heart);

  const AppTab(this.label, this.icon, this.activeIcon);

  final String label;
  final IconData icon;

  /// The filled version, shown for the tab you are already on. Shape as well as
  /// colour, so the current tab is not told apart by colour alone.
  final IconData activeIcon;
}

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.current, required this.patient});

  /// The tab this screen belongs to, drawn as the selected one.
  ///
  /// Null for a screen that is reachable from the bar but is not itself one of
  /// the five - a doctor's details, say, reached from Home. Nothing is lit, and
  /// every tab is a real move.
  final AppTab? current;

  final SignedInUser patient;

  void _onTap(BuildContext context, AppTab tab) {
    if (tab == current) return;

    final navigator = Navigator.of(context);

    // Back to the dashboard first - see the note on [AppTab] for why.
    navigator.popUntil((route) => route.isFirst);

    if (tab == AppTab.home) return;

    navigator.push(
      MaterialPageRoute(
        builder: (_) => switch (tab) {
          AppTab.appointments => PatientAppointmentsScreen(patient: patient),
          AppTab.services => ServicesScreen(patient: patient),
          AppTab.records => HealthRecordsScreen(patient: patient),
          AppTab.health => HealthDashboardScreen(patient: patient),
          AppTab.home => throw StateError('handled above'),
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.fieldBorder, width: 1.5)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (final tab in AppTab.values)
              Expanded(
                child: _NavItem(
                  tab: tab,
                  selected: tab == current,
                  onTap: () => _onTap(context, tab),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final AppTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colour = selected ? AppColors.logoGreen : AppColors.textMuted;

    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // A short bar above the selected tab, so which one is current
              // survives being read in greyscale or by someone who cannot pick
              // the green out from the grey.
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                height: 3,
                width: selected ? 26 : 0,
                margin: const EdgeInsets.only(bottom: 5),
                decoration: BoxDecoration(
                  color: AppColors.neonGreen,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Icon(selected ? tab.activeIcon : tab.icon, size: 22, color: colour),
              const SizedBox(height: 3),
              Text(
                tab.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.1,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  color: colour,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
