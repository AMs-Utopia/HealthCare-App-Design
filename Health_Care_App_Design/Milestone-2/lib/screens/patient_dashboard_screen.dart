import 'package:flutter/material.dart';

import '../models/signed_in_user.dart';
import '../theme/app_colors.dart';
import '../widgets/app_drawer.dart';
import '../widgets/dashboard_action_card.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/dashboard_search_bar.dart';
import 'choose_area_screen.dart';

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
/// by `api/login.php`. Everything shown here comes from the signed in account;
/// the screen does not read the database again by itself.
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onActionTapped(DashboardAction action) {
    setState(() => _selectedAction = action);

    switch (action) {
      case DashboardAction.doctorLists:
        // Doctors are found by area first, so this opens the area picker.
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ChooseAreaScreen(patient: widget.user)),
        );
      case DashboardAction.monitorHealth:
      case DashboardAction.investigation:
      case DashboardAction.callHospital:
        // Each of these opens its own screen once it is designed.
        _showComingSoon(action.label);
    }
  }

  void _onSearchSubmitted(String query) {
    if (query.trim().isEmpty) return;
    _showComingSoon('Search');
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
        destinations: DrawerDestination.forPatient,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DashboardHeader(
                userName: widget.user.displayName,
                onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
                onBellPressed: () => _showComingSoon('Notifications'),
              ),
              const SizedBox(height: 24),

              DashboardSearchBar(
                controller: _searchController,
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