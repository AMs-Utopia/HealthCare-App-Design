import 'package:flutter/material.dart';

import '../config/api_client.dart';
import '../models/patient_profile.dart';
import '../models/signed_in_user.dart';
import '../screens/chamber_info_screen.dart';
import '../screens/health_records_screen.dart';
import '../screens/my_account_screen.dart';
import '../screens/patient_appointments_screen.dart';
import '../screens/services_screen.dart';
import '../screens/sign_in_screen.dart';
import '../theme/app_colors.dart';
import 'neon_divider.dart';
/// Every menu entry the drawer can show. Each dashboard passes the ones that
/// belong to it, so their labels and icons live in one place.
enum DrawerDestination {
  home('Home', Icons.home_outlined),
  profile('Profile', Icons.person_outline),
  appointment('Appointment', Icons.event_available_outlined),
  services('Services', Icons.grid_view_outlined),
  healthRecords('Health Records', Icons.folder_shared_outlined),
  chamberInfo('Chamber Info', Icons.meeting_room_outlined);

  const DrawerDestination(this.label, this.icon);

  final String label;
  final IconData icon;

  /// What a patient sees.
  static const List<DrawerDestination> forPatient = [
    home,
    profile,
    appointment,
    services,
    healthRecords,
  ];
  /// What a doctor sees.
  static const List<DrawerDestination> forDoctor = [home, chamberInfo];
}
/// The slide out menu behind a dashboard's hamburger button.

/// Logo and neon line on top, the destinations in the middle, and the signed
/// in account with a logout button pinned to the bottom. Both dashboards use
/// it - only [destinations] differs.
class AppDrawer extends StatefulWidget {
  const AppDrawer({
    super.key,
    required this.user,
    required this.destinations,
    this.profile,
    this.onDestinationClosed,
  });

  final SignedInUser user;
  final List<DrawerDestination> destinations;

  /// The patient's account as it stands now, when the dashboard has read it.
  ///
  /// [user] is the account as it was at sign in, and it has no photo in it at
  /// all - PATIENT.profile_image was never part of what sign in returns. It
  /// also goes stale the moment the patient edits their name on the Basic Info
  /// screen. So the footer below prefers this when it is there and falls back
  /// to [user] when it is not, which is what the doctor's drawer always does:
  /// the DOCTOR table has no photo column, so no doctor has one to show.
  final PatientProfile? profile;

  /// Called once the screen a drawer entry opened has been closed again.
  ///
  /// The dashboard behind uses it to refresh its notification dot: opening the
  /// appointments screen marks everything read, so the dot has to go without
  /// the dashboard being rebuilt from scratch.
  final VoidCallback? onDestinationClosed;

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}
class _AppDrawerState extends State<AppDrawer> {
  /// The entry tapped last, so it stays lit up like the dashboard boxes.
  DrawerDestination? _selected;

  void _onDestinationTapped(DrawerDestination destination) {
    setState(() => _selected = destination);

    if (destination == DrawerDestination.home) {
      // Home is the screen the drawer was opened from, so there is nowhere to
      // go - just close the drawer.
      Navigator.of(context).pop();
      return;
    }

    // These all open a screen, and they all do it the same way, so the route
    // is picked here and pushed once below.
    final WidgetBuilder? builder = switch (destination) {
      DrawerDestination.profile => (_) => MyAccountScreen(user: widget.user),
      DrawerDestination.appointment => (_) =>
        PatientAppointmentsScreen(patient: widget.user),
      DrawerDestination.chamberInfo => (_) =>
        ChamberInfoScreen(doctor: widget.user),
      DrawerDestination.services => (_) =>
        ServicesScreen(patient: widget.user),
      DrawerDestination.healthRecords => (_) =>
        HealthRecordsScreen(patient: widget.user),
      _ => null,
    };

    if (builder != null) {
      // Taken before the drawer closes, because popping invalidates the
      // context this widget was built with.
      final navigator = Navigator.of(context);

      // Taken now as well, because this State is disposed by the pop below -
      // the callback itself belongs to the dashboard, which stays alive.
      final onClosed = widget.onDestinationClosed;

      // Close the menu first, so back from the screen returns to the dashboard
      // rather than reopening the drawer over it.
      navigator.pop();
      navigator
          .push(MaterialPageRoute(builder: builder))
          .then((_) => onClosed?.call());
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${destination.label} is coming next.'),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  void _onLogoutPressed() {
    // Taken before the drawer closes, because popping invalidates the context
    // this widget was built with.
    final navigator = Navigator.of(context);

    // Throw the token away before the screens go, not after. Clearing the
    // navigation stack only stops the patient seeing the old account; forgetting
    // the token is what stops the app being able to ASK for it - without this,
    // a request left in flight, or the next account's first screen, would still
    // be carrying the last person's proof of identity.
    ApiClient.signOut();

    navigator.pop(); // Close the drawer.
    // Clear the whole stack so back cannot return to the dashboard of an
    // account that has signed out.
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SignInScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The same logo as the sign in screen, closed off by the neon line.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
              child: Image.asset(
                'assets/images/logo.jpg',
                height: 110,
                fit: BoxFit.contain,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: NeonDivider(),
            ),
            const SizedBox(height: 18),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final destination in widget.destinations) ...[
                    _DrawerItem(
                      destination: destination,
                      selected: _selected == destination,
                      onTap: () => _onDestinationTapped(destination),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),

            const Divider(height: 1),
            _buildAccountFooter(),
          ],
        ),
      ),
    );
  }
  /// The bottom strip: who is signed in on the left, logout on the right.
  Widget _buildAccountFooter() {
    final user = widget.user;
    final profile = widget.profile;

    // The photo and the name both come from the freshly read profile when the
    // dashboard has one, so uploading a picture or changing a name shows here
    // rather than waiting for the next sign in.
    final photo = profile?.photoUrl;
    final name = profile?.fullName ?? user.fullName;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.logoGreen.withValues(alpha: 0.15),
            backgroundImage: photo == null
                ? null
                : NetworkImage(photo.toString()),
            // The placeholder stays until there really is a picture to show.
            child: photo != null
                ? null
                : const Icon(
                    Icons.person,
                    size: 28,
                    color: AppColors.logoGreen,
                  ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user.accountSubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),

          IconButton(
            onPressed: _onLogoutPressed,
            icon: const Icon(Icons.logout),
            iconSize: 28,
            color: Colors.red.shade700,
            tooltip: 'Log out',
          ),
        ],
      ),
    );
  }
}
/// One tappable row of the drawer, lit up neon green while [selected].
class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final DrawerDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF0FFEC) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.neonGreen : AppColors.fieldBorder,
            width: selected ? 3 : 1.5,
          ),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: AppColors.neonGreen,
                    blurRadius: 14,
                    spreadRadius: -2,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              destination.icon,
              size: 26,
              color: selected ? AppColors.logoGreen : AppColors.textMuted,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                destination.label,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.logoGreen : AppColors.textDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}