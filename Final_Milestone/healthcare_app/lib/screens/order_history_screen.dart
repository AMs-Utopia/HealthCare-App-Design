import 'package:flutter/material.dart';

import '../models/order.dart';
import '../models/signed_in_user.dart';
import '../services/order_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/screen_header.dart';
import 'medication_screen.dart';

/// Screen 19 (User / Patient) - Order History.
///
/// Reached from Profile in the drawer, then My Account, then Order History.
///
/// One card per order, newest first: the order id and what it came to across
/// the top, then the medicines that were on it numbered underneath, each with
/// how many were bought.
///
/// Every medicine is a switch. Tapping one opens Medications, where the
/// patient sees who prescribed it, how to take it, how much is left, and can
/// mark it completed or reorder it.
///
/// The prices on these cards are what the patient was CHARGED, taken from
/// ORDER_ITEM rather than from MEDICINE. Medicine prices move; a receipt that
/// quietly repriced itself would stop adding up to its own total.
class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key, required this.patient});

  final SignedInUser patient;

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  List<OrderHistoryEntry> _orders = [];
  bool _isLoading = true;
  String _message = '';
  String? _error;

  /// The medicine tapped last, kept so its row stays lit up - the same
  /// treatment the drawer and the dashboard boxes use.
  int? _selectedItemId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _isLoading = true);

    final result = await OrderService.fetchHistory(widget.patient.id);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.isSuccess) {
        _orders = result.orders;
        _message = result.message;
        _error = null;
      } else {
        _error = result.error;
      }
    });
  }

  /// Opens Medications for the tapped medicine.
  ///
  /// Only the medicine id and its name are handed over - the id because that
  /// is what joins the prescription and the orders together, and the name only
  /// so the screen has a heading to draw while it loads. Everything else it
  /// shows is read fresh, so a course marked completed there is still marked
  /// completed the next time it is opened from anywhere else.
  Future<void> _openMedication(OrderedMedicine medicine) async {
    setState(() => _selectedItemId = medicine.orderItemId);

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MedicationScreen(
          patient: widget.patient,
          medicineId: medicine.medicineId,
          medicineName: medicine.name,
        ),
      ),
    );

    // A refill placed down there is a new order up here.
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: AppBottomNav(
        current: null,
        patient: widget.patient,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ScreenHeader(title: 'Order History'),
              const SizedBox(height: 16),
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

    if (_error != null) {
      return _Note(
        icon: Icons.wifi_off_outlined,
        title: 'Could not load your orders',
        detail: _error!,
      );
    }

    if (_orders.isEmpty) {
      return _Note(
        icon: Icons.receipt_long_outlined,
        title: 'No orders yet',
        detail: _message.isEmpty
            ? 'Medicine you order from Services will be listed here.'
            : '$_message\n\nMedicine you order from Services will be listed '
                  'here.',
      );
    }

    return RefreshIndicator(
      color: AppColors.logoGreen,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 8),
        itemCount: _orders.length,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (_, index) => _OrderCard(
          order: _orders[index],
          selectedItemId: _selectedItemId,
          onMedicineTapped: _openMedication,
        ),
      ),
    );
  }
}

/// One order: the id and the total across the top, the medicines underneath.
class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.selectedItemId,
    required this.onMedicineTapped,
  });

  final OrderHistoryEntry order;
  final int? selectedItemId;
  final ValueChanged<OrderedMedicine> onMedicineTapped;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.fieldBorder, width: 1.5),
      ),
      // So the tap ripple on the first and last medicine stays inside the
      // rounded corners rather than squaring them off.
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),

          // The line the wireframe draws under the order id, separating it
          // from the medicines.
          const Divider(height: 1, thickness: 1, color: AppColors.fieldBorder),

          for (var index = 0; index < order.items.length; index++) ...[
            if (index > 0)
              const Divider(
                height: 1,
                thickness: 1,
                indent: 12,
                endIndent: 12,
                color: AppColors.background,
              ),
            _MedicineRow(
              // The number the wireframe puts in front of each medicine.
              position: index + 1,
              medicine: order.items[index],
              selected: selectedItemId == order.items[index].orderItemId,
              onTap: () => onMedicineTapped(order.items[index]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  order.idLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // What the whole order came to - the overall price, beside the
              // id it belongs to.
              Text(
                order.totalLine,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.logoGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          Row(
            children: [
              if (order.placedLine != null)
                Flexible(
                  child: Text(
                    order.placedLine!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              _StatusChip(status: order.status),
            ],
          ),
        ],
      ),
    );
  }
}

/// One medicine on an order, and the switch that will open Medication.
class _MedicineRow extends StatelessWidget {
  const _MedicineRow({
    required this.position,
    required this.medicine,
    required this.selected,
    required this.onTap,
  });

  final int position;
  final OrderedMedicine medicine;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
        // Lit up when it was the last one tapped, the same as every other
        // tappable box in the app.
        color: selected
            ? AppColors.logoGreen.withValues(alpha: 0.12)
            : Colors.transparent,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '$position)',
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 8),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    medicine.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  if (medicine.dosage != null && medicine.dosage!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        medicine.dosage!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // How many were bought, counted in the medicine's own units -
            // "10 capsules" for a capsule, "10 tablets" for a tablet.
            Text(
              medicine.quantityLine,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.logoBlue,
              ),
            ),

            const Icon(
              Icons.chevron_right,
              size: 22,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

/// What became of the order. Only ever "Placed" so far - there is no pharmacy
/// or courier in this app to move it any further along.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.logoBlue.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.logoBlue,
        ),
      ),
    );
  }
}

/// The middle of the screen when there is nothing to list, or nothing loaded.
class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.title, required this.detail});

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
