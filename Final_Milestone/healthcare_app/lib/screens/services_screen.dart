import 'package:flutter/material.dart';

import '../models/signed_in_user.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/dashboard_action_card.dart';
import '../widgets/screen_header.dart';
import 'health_tips_screen.dart';
import 'lab_tests_screen.dart';
import 'order_medicine_screen.dart';

/// The three services on this screen. The enum keeps their labels and icons in
/// one place, the same way the dashboard boxes do, so adding a fourth later is
/// one line here rather than a change in three places.
enum ServiceAction {
  labTest('Lab Test', Icons.biotech_outlined),
  orderMedicine('Order Medicine', Icons.local_pharmacy_outlined),
  healthTips('Health Tips', Icons.tips_and_updates_outlined);

  const ServiceAction(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Screen 17 (User / Patient) - Services.
///
/// Reached from Services in the patient's drawer menu.
///
/// Three boxes laid out as the wireframe draws them: Lab Test across the top,
/// then Order Medicine and Health Tips side by side underneath, with Order
/// Medicine the wider of the two.
///
/// All three lead somewhere now: Health Tips opens the magazine, Order
/// Medicine opens the order screen, and Lab Test opens the tests on offer.
///
/// The lighting up is the same treatment every other box in the app uses
/// ([DashboardActionCard]), so these behave exactly like the dashboard boxes
/// the patient already knows - whether or not the box leads anywhere yet.
class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key, required this.patient});

  /// The signed in patient. Nothing on the screen needs it yet, but each of
  /// these services will be ordered or read for one patient, so it travels
  /// with the screen rather than being fetched again later.
  final SignedInUser patient;

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  /// The box tapped last, so it stays lit up.
  ServiceAction? _selectedAction;

  Future<void> _onActionTapped(ServiceAction action) async {
    setState(() => _selectedAction = action);

    switch (action) {
      case ServiceAction.healthTips:
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const HealthTipsScreen()),
        );
      case ServiceAction.orderMedicine:
        // Awaited because an order placed down this path lights the bell on
        // the dashboard, which refreshes its count when this screen closes.
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OrderMedicineScreen(patient: widget.patient),
          ),
        );
      case ServiceAction.labTest:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LabTestsScreen(patient: widget.patient),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: AppBottomNav(
        current: AppTab.services,
        patient: widget.patient,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ScreenHeader(title: 'Services'),
              const SizedBox(height: 24),

              // Fixed heights inside a scroll view rather than a grid, the
              // same as both dashboards: the wireframe has one wide box above
              // two side by side, and this cannot overflow on a short screen.
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Inset from both edges, because the wireframe draws Lab
                      // Test narrower than the pair below it rather than
                      // running the full width.
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: SizedBox(
                          height: 120,
                          child: _card(ServiceAction.labTest),
                        ),
                      ),
                      const SizedBox(height: 20),

                      SizedBox(
                        height: 150,
                        child: Row(
                          children: [
                            // 3 to 2, which is how the two boxes are drawn:
                            // "Order Medicine" is a two word label and needs
                            // the room, "Health Tips" does not.
                            Expanded(
                              flex: 3,
                              child: _card(ServiceAction.orderMedicine),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 2,
                              child: _card(ServiceAction.healthTips),
                            ),
                          ],
                        ),
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

  Widget _card(ServiceAction action) {
    return DashboardActionCard(
      icon: action.icon,
      label: action.label,
      selected: _selectedAction == action,
      onTap: () => _onActionTapped(action),
    );
  }
}
