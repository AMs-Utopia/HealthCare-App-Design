import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/medex_config.dart';
import '../models/patient_profile.dart';
import '../models/signed_in_user.dart';
import '../services/notification_service.dart';
import '../services/patient_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_drawer.dart';
import '../widgets/dashboard_action_card.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/dashboard_search_bar.dart';
import '../widgets/investigation_choice_dialog.dart';
import 'call_hospital_screen.dart';
import 'choose_area_screen.dart';
import 'doctors_list_screen.dart';
import 'health_dashboard_screen.dart';
import 'lab_tests_screen.dart';
import 'notifications_screen.dart';

/// The four boxes on the dashboard. Each one leads to a screen that is not
/// built yet, so the enum keeps their labels and icons in one place.
enum DashboardAction {
  monitorHealth('Monitor Health', Icons.monitor_heart_outlined),
  doctorLists('Doctor Lists', Icons.medical_services_outlined),
  investigation('Investigation', Icons.science_outlined),
  callHospital('Call a Hospital', Icons.local_hospital_outlined);

  const DashboardAction(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Screen 4 (User / Patient) - Dashboard.

/// Reached from the sign in screen once the phone and password are accepted
/// by `api/login.php`.
///
/// Most of what is drawn comes from the signed in account, but the greeting
/// and the drawer's account strip do not: sign in never returned a photo, and
/// the name it did return goes stale as soon as the patient edits it on the
/// Basic Info screen. So the account is read once when the dashboard opens and
/// again whenever a drawer screen closes - which is the path an edit takes
/// back to here.
class PatientDashboardScreen extends StatefulWidget {
  const PatientDashboardScreen({super.key, required this.user});

  final SignedInUser user;

  @override
  State<PatientDashboardScreen> createState() => _PatientDashboardScreenState();
}

class _PatientDashboardScreenState extends State<PatientDashboardScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();

  /// The box the user tapped last, so it stays lit up.
  DashboardAction? _selectedAction;

  /// Anything that has happened on this patient's account that they have not
  /// opened their notifications to see. This is the dot on the bell - their own
  /// booking, reschedule, cancellation or medicine order lights it, and so does
  /// a cancellation made by the doctor.
  int _unseenCount = 0;

  /// The account as the database holds it now, for the greeting and the
  /// drawer's photo. Null until the first read finishes, and after one that
  /// failed - both fall back to the signed in account.
  PatientProfile? _profile;

  @override
  void initState() {
    super.initState();
    _refreshUnseenCount();
    _refreshProfile();
  }

  /// Reads the account again, so a newly uploaded picture or a changed name
  /// appears without the patient having to sign in again.
  ///
  /// A failure is deliberately silent: the dashboard still draws from the
  /// signed in account, and a snackbar about a photo the patient did not ask
  /// for would be noise on the screen they land on.
  Future<void> _refreshProfile() async {
    final result = await PatientService.fetchProfile(widget.user.id);

    if (!mounted || !result.isSuccess) return;

    setState(() => _profile = result.profile);
  }

  /// Both of the things a drawer screen can change on the way back: the dot on
  /// the bell, and the account behind the photo and the greeting.
  Future<void> _onDrawerScreenClosed() async {
    await _refreshUnseenCount();
    await _refreshProfile();
  }

  Future<void> _refreshUnseenCount() async {
    final count = await NotificationService.unseenCount(widget.user.id);

    if (!mounted) return;

    setState(() => _unseenCount = count);
  }

  /// The bell opens the notifications list, which is everything that has
  /// happened on this account - what became of their bookings, and the medicine
  /// orders they have placed - in one list.
  ///
  /// It does not go to the appointments screen any more. Two different things
  /// light this bell now, and that screen could only ever show one of them, so
  /// half the dot would have led somewhere that never explained it. Appointment
  /// in the drawer still opens the appointments screen, which is where an
  /// upcoming visit is managed rather than merely read about.
  ///
  /// Opening it marks everything read, so the dot is refreshed on the way back.
  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationsScreen(patient: widget.user),
      ),
    );

    if (mounted) await _refreshUnseenCount();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onActionTapped(DashboardAction action) async {
    setState(() => _selectedAction = action);

    switch (action) {
      case DashboardAction.doctorLists:
        // Doctors are found by area first, so this opens the area picker.
        // Awaited because a booking made down that path lights the bell.
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ChooseAreaScreen(patient: widget.user)),
        );
        if (mounted) await _refreshUnseenCount();
      case DashboardAction.callHospital:
        // Nothing here can change the account or the bell, so unlike Doctor
        // Lists this one does not refresh anything on the way back.
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CallHospitalScreen()),
        );
      case DashboardAction.investigation:
        // The one box that means two different things, so which of them is
        // asked before either opens. Awaited for the same reason Doctor Lists
        // is: a lab test booked down that path lights the bell.
        await _openInvestigation();
      case DashboardAction.monitorHealth:
        // The same screen Health Records' "Go To Interactive Dashboard" opens.
        // Nothing down there touches the bell, so no refresh on the way back.
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => HealthDashboardScreen(patient: widget.user),
          ),
        );
    }
  }

  /// Investigation. Asks which of the two it means, then goes there.
  ///
  /// MedEx leaves the app for the browser and nothing comes back from it. Lab
  /// Tests stays here and can end in a booking, which is why only that side
  /// refreshes the bell on the way back.
  Future<void> _openInvestigation() async {
    final choice = await showInvestigationChoiceDialog(context);

    // Backed out of the popup, or the dashboard went away while it was open.
    if (choice == null || !mounted) return;

    switch (choice) {
      case InvestigationChoice.medex:
        await _openMedex();
      case InvestigationChoice.labTests:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LabTestsScreen(patient: widget.user),
          ),
        );
        if (mounted) await _refreshUnseenCount();
    }
  }

  /// Hands the patient over to MedEx in whatever browser they use.
  ///
  /// [LaunchMode.externalApplication] on purpose: this is somebody else's site
  /// to be read and searched, not a page to be shown inside a booking flow, so
  /// it belongs in a real browser with a URL bar and the patient's own tabs.
  ///
  /// Android 11+ hides other apps from this one unless the http/https VIEW
  /// intent is declared in AndroidManifest.xml, and without it [launchUrl]
  /// reports that nothing can open the link. Both failures are told to the
  /// patient with the address in them, so the trip is not simply lost.
  Future<void> _openMedex() async {
    try {
      final opened = await launchUrl(
        MedexSite.home,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        _say('Could not open a browser. MedEx is at ${MedexSite.displayName}.');
      }
    } on Exception {
      // A device with no browser at all - an emulator without one, most often,
      // which is exactly where this will be tested.
      if (mounted) {
        _say('No browser on this device. MedEx is at ${MedexSite.displayName}.');
      }
    }
  }

  /// Doctor search. One line can carry a speciality, a hospital, an area, a
  /// career background or a day the patient is free - and the results screen is
  /// the same doctors list they would reach by browsing, so booking from a
  /// search works exactly the way booking from a department does.
  void _onSearchSubmitted(String query) {
    final typed = query.trim();

    if (typed.isEmpty) return;

    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) =>
                DoctorsListScreen.search(patient: widget.user, query: typed),
          ),
        )
        .then((_) {
          if (mounted) _refreshUnseenCount();
        });
  }

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      // The point of the bar is to reach the screens that are otherwise buried
      // - Lab Tests behind Services, Health Records behind the drawer - and the
      // place a patient most often sets off from is this one. So it belongs
      // here first, and on the inner screens second.
      //
      // Home is the tab already showing, so tapping it does nothing rather than
      // pushing another copy of the dashboard on top of itself.
      bottomNavigationBar: AppBottomNav(
        current: AppTab.home,
        patient: widget.user,
      ),
      drawer: AppDrawer(
        user: widget.user,
        destinations: DrawerDestination.forPatient,
        profile: _profile,
        // Appointment in the drawer opens the same screen the bell does and
        // clears the dot; Profile leads to the screen that changes the photo
        // and the name. Both come back through here, so both are refreshed.
        onDestinationClosed: _onDrawerScreenClosed,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DashboardHeader(
                // The freshly read name, so editing it on Basic Info changes
                // the greeting too rather than only the account strip.
                userName: _profile?.fullName ?? widget.user.displayName,
                unreadCount: _unseenCount,
                onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
                onBellPressed: _openNotifications,
              ),
              const SizedBox(height: 24),

              DashboardSearchBar(
                controller: _searchController,
                // Names the kinds of thing that work, so the box does not look
                // like it only takes a doctor's name.
                hint: 'Search: gastric, Dhanmondi, Saturday, professor',
                onSubmitted: _onSearchSubmitted,
              ),
              const SizedBox(height: 28),

              Expanded(child: _buildActionGrid()),
            ],
          ),
        ),
      ),
    );
  }
  /// The 2x2 block of boxes from wireframe.**
  Widget _buildActionGrid() {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      // Slightly wider than tall, like the boxes in the wireframe, but not so
      // flat that a two line label runs out of room.
      childAspectRatio: 1.05,
      // No shrinkWrap: the grid fills the space left under the search bar and
      // scrolls by itself on a short screen, rather than overflowing it.
      padding: EdgeInsets.zero,
      children: [
        for (final action in DashboardAction.values)
          DashboardActionCard(
            icon: action.icon,
            label: action.label,
            selected: _selectedAction == action,
            onTap: () => _onActionTapped(action),
          ),
      ],
    );
  }
}