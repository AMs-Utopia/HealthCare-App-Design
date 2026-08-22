import 'package:flutter/material.dart';

import '../models/patient_profile.dart';
import '../models/signed_in_user.dart';
import '../services/patient_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/neon_list_button.dart';
import '../widgets/screen_header.dart';
import 'basic_info_screen.dart';
import 'order_history_screen.dart';
import 'prescriptions_screen.dart';
import 'saved_addresses_screen.dart';

/// The rows under the account card. The enum keeps their labels and icons in
/// one place.
enum AccountDestination {
  savedAddresses('Saved Addresses', Icons.location_on_outlined),
  prescriptions('My Prescriptions', Icons.description_outlined),
  orderHistory('Order History', Icons.receipt_long_outlined);

  const AccountDestination(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// My Account (Patient) - reached from Profile in the dashboard drawer.
///
/// The card at the top is the account itself: photo, name, phone number, and
/// Edit beside it. It is read from the server rather than from the signed in
/// copy, because sign in only ever carried the name and the phone - the photo
/// was never part of it - and because a name changed on the Basic Info screen
/// has to show here the moment that screen closes.
///
/// If that read fails the card still draws, from the signed in account. A
/// profile screen that cannot show a name is worse than one showing the name
/// the patient signed in under.
///
/// Saved Addresses opens the address list, where the patient adds more
/// addresses and picks which one is their present one. My Prescriptions opens
/// everything a doctor has put them on, out of PRESCRIPTION and
/// PRESCRIPTION_ITEM. Order History opens every medicine order they have
/// placed, out of ORDER_HEADER and ORDER_ITEM.
///
/// Those last two are the two halves of the same medicine reached from
/// opposite ends - what a doctor said to take, and what was actually bought -
/// and both lead to the same Medications screen in the middle.
class MyAccountScreen extends StatefulWidget {
  const MyAccountScreen({super.key, required this.user});

  final SignedInUser user;

  @override
  State<MyAccountScreen> createState() => _MyAccountScreenState();
}

class _MyAccountScreenState extends State<MyAccountScreen> {
  /// The row tapped last, so it stays lit up like the drawer and the dashboard.
  AccountDestination? _selected;

  /// Null until the profile has been read, and after a read that failed.
  PatientProfile? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);

    final result = await PatientService.fetchProfile(widget.user.id);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      // A failure leaves _profile as it was and the card falls back to the
      // signed in account, so there is nothing to report here.
      if (result.isSuccess) _profile = result.profile;
    });
  }

  /// Opens Basic Info, and reads the account again if anything was saved.
  Future<void> _onEditPressed() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BasicInfoScreen(patient: widget.user),
      ),
    );

    if (changed == true && mounted) await _load();
  }

  Future<void> _onDestinationTapped(AccountDestination destination) async {
    setState(() => _selected = destination);

    switch (destination) {
      case AccountDestination.savedAddresses:
        await _openSavedAddresses();
      case AccountDestination.prescriptions:
        // Nothing here can change the account either, so the profile is not
        // read again on the way back.
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PrescriptionsScreen(patient: widget.user),
          ),
        );
      case AccountDestination.orderHistory:
        // Nothing here can change the account, so unlike the other two this
        // one does not read the profile again on the way back.
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OrderHistoryScreen(patient: widget.user),
          ),
        );
    }
  }

  /// Opens Saved Address, and reads the account again if anything was saved
  /// there - confirming a different address changes the present address the
  /// Basic Info screen shows.
  Future<void> _openSavedAddresses() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SavedAddressesScreen(patient: widget.user),
      ),
    );

    if (changed == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: AppBottomNav(
        current: null,
        patient: widget.user,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ScreenHeader(title: 'My Account'),
              const SizedBox(height: 18),

              _buildAccountCard(),
              const SizedBox(height: 22),

              for (final destination in AccountDestination.values) ...[
                NeonListButton(
                  icon: destination.icon,
                  title: destination.label,
                  selected: _selected == destination,
                  onTap: () => _onDestinationTapped(destination),
                ),
                const SizedBox(height: 14),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// The photo, the name and the number, with Edit on the right.
  Widget _buildAccountCard() {
    // Falls back to the signed in account while the profile is still loading,
    // and for good if the read failed, so the card is never blank.
    final name = _profile?.fullName ?? widget.user.fullName;
    final phone = _profile?.phone ?? widget.user.phone;
    final photo = _profile?.photoUrl;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.fieldBorder, width: 1.5),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: AppColors.logoGreen.withValues(alpha: 0.15),
            backgroundImage: photo == null
                ? null
                : NetworkImage(photo.toString()),
            // The placeholder stays until there really is a photo to show.
            child: photo != null
                ? null
                : const Icon(
                    Icons.person,
                    size: 38,
                    color: AppColors.logoGreen,
                  ),
          ),
          const SizedBox(width: 14),

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
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  phone,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          ElevatedButton(
            // Off only while the first read is in flight, so Edit cannot open
            // a form that has nothing to fill itself in with.
            onPressed: _isLoading ? null : _onEditPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.logoGreen,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.logoGreen.withValues(
                alpha: 0.4,
              ),
              disabledForegroundColor: Colors.white,
              elevation: 2,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 10,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Edit',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
