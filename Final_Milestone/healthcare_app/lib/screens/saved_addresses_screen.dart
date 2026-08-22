import 'package:flutter/material.dart';

import '../models/saved_address.dart';
import '../models/signed_in_user.dart';
import '../services/patient_service.dart';
import '../theme/app_colors.dart';
import '../widgets/primary_button.dart';
import '../widgets/screen_header.dart';

/// Screen 25 (User / Patient) - Saved Address.
///
/// Reached from "Saved Addresses" on My Account. Two things, one above the
/// other, exactly as drawn on the wireframe:
///
///   + Add new Address   types one more address into ADDRESS.
///   the list            every address this patient has saved, starting with
///                       the one they typed on Basic Info, or the note "No
///                       addresses added currently" while there are none.
///
/// A patient keeps as many addresses as they like and exactly one of them is
/// their present address. While there is only one there is nothing to choose
/// between, so no radio buttons are drawn - the single address simply is the
/// present one. From the second address on, a radio appears beside each row
/// and Confirm appears at the bottom: whichever one is filled in when Confirm
/// is tapped becomes the patient's present address.
///
/// Confirming does not copy any text around. It moves the is_present flag in
/// ADDRESS, and the Basic Info screen's "Present Address" box reads that same
/// flag, so the two screens can never disagree about which address is in use.
///
/// Every write answers with the whole list back, so the screen redraws from
/// what the database really holds rather than from what it hoped it saved.
class SavedAddressesScreen extends StatefulWidget {
  const SavedAddressesScreen({super.key, required this.patient});

  final SignedInUser patient;

  @override
  State<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends State<SavedAddressesScreen> {
  List<SavedAddress> _addresses = [];

  bool _isLoading = true;
  String? _loadError;

  /// True while an add or a confirm is in flight, so neither can be fired
  /// twice and the buttons go quiet until the server has answered.
  bool _isSaving = false;

  /// The radio the patient has filled in but has not confirmed yet. Null only
  /// while the list is empty.
  int? _chosenId;

  /// True if anything was saved, so My Account knows the account it is showing
  /// may have moved on.
  bool _didChange = false;

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

    final result = await PatientService.fetchAddresses(widget.patient.id);

    // The screen can be gone by the time the reply arrives.
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.isSuccess) {
        _apply(result);
      } else {
        _addresses = [];
        _chosenId = null;
        _loadError = result.error;
      }
    });
  }

  /// Takes a freshly loaded or freshly saved list as the truth.
  ///
  /// The radio is put back on whichever row the server says is flagged, so an
  /// add that did not go through cannot leave the screen showing a choice the
  /// database never made.
  void _apply(AddressListResult result) {
    _addresses = result.addresses;
    _chosenId = result.present?.id ??
        (_addresses.isEmpty ? null : _addresses.first.id);
  }

  /// A radio is only worth drawing once there is something to choose between.
  bool get _hasChoice => _addresses.length > 1;

  /// The address flagged in the database right now, which is what Confirm is
  /// compared against - confirming the one already in use would be a write
  /// that changes nothing.
  int? get _presentId {
    for (final address in _addresses) {
      if (address.isPresent) return address.id;
    }
    return null;
  }

  bool get _canConfirm =>
      !_isSaving && _chosenId != null && _chosenId != _presentId;

  /// "+ Add new Address": asks for the address, then saves it.
  Future<void> _onAddPressed() async {
    final typed = await showDialog<String>(
      context: context,
      builder: (_) => const _AddAddressDialog(),
    );

    if (typed == null || !mounted) return;

    await _save(
      () => PatientService.addAddress(
        patientId: widget.patient.id,
        address: typed,
      ),
    );
  }

  /// Confirm: makes the filled in radio the patient's present address.
  Future<void> _onConfirmPressed() async {
    final chosen = _chosenId;
    if (chosen == null) return;

    await _save(
      () => PatientService.selectAddress(
        patientId: widget.patient.id,
        addressId: chosen,
      ),
    );
  }

  /// Adding and confirming both answer with the whole list, so they share the
  /// one save: run it, redraw from the reply, and say what the server said.
  Future<void> _save(Future<AddressListResult> Function() call) async {
    setState(() => _isSaving = true);

    final result = await call();

    if (!mounted) return;

    setState(() {
      _isSaving = false;
      if (result.isSuccess) {
        _didChange = true;
        _apply(result);
      }
    });

    _showMessage(
      result.isSuccess ? result.message : result.error!,
      isError: !result.isSuccess,
    );
  }

  void _showMessage(String message, {required bool isError}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red.shade700 : null,
          duration: Duration(seconds: isError ? 4 : 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    // The back arrow has to carry the "something was saved" answer back the
    // same way the Confirm path would, so it is handled here rather than by
    // ScreenHeader's own pop.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_didChange);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ScreenHeader(
                  title: 'Saved Address',
                  onBack: () => Navigator.of(context).pop(_didChange),
                ),
                const SizedBox(height: 18),

                _AddAddressButton(
                  onTap: _isSaving ? null : _onAddPressed,
                ),
                const SizedBox(height: 22),

                Expanded(child: _buildList()),

                // Only worth showing once there is a choice to confirm.
                if (_hasChoice) ...[
                  const SizedBox(height: 14),
                  Center(
                    child: PrimaryButton(
                      label: 'Confirm',
                      glow: _canConfirm,
                      onPressed: _canConfirm ? _onConfirmPressed : null,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.logoGreen),
            SizedBox(height: 16),
            Text(
              'Loading your addresses...',
              style: TextStyle(fontSize: 15, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    if (_loadError != null) return _buildError();

    if (_addresses.isEmpty) {
      return const Center(
        child: Text(
          'No addresses added currently',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            color: AppColors.textMuted,
            height: 1.35,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.logoGreen,
      child: ListView.separated(
        // Always scrollable, so pull to refresh still works with one address.
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _addresses.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final address = _addresses[index];

          return _AddressCard(
            address: address,
            // With a single address there is no radio, and the row is drawn
            // lit up because it is the present one by default.
            showRadio: _hasChoice,
            chosen: _hasChoice ? _chosenId == address.id : address.isPresent,
            onTap: _hasChoice && !_isSaving
                ? () => setState(() => _chosenId = address.id)
                : null,
          );
        },
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
            Icon(Icons.wifi_off, size: 34, color: Colors.red.shade400),
            const SizedBox(height: 10),
            Text(
              _loadError!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.red.shade700,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
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
}

/// The rounded "+ Add new Address" box at the top of the wireframe.
class _AddAddressButton extends StatelessWidget {
  const _AddAddressButton({required this.onTap});

  /// Null while a save is in flight, which greys the box out.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final colour = enabled ? AppColors.logoGreen : AppColors.textMuted;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          // The wireframe draws this one as a stadium, so it does not read as
          // one more address row.
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: colour, width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 26, color: colour),
            const SizedBox(width: 10),
            Text(
              'Add new Address',
              style: TextStyle(
                fontSize: 19,
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

/// One saved address, with its radio button when there is a choice to make.
class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.showRadio,
    required this.chosen,
    required this.onTap,
  });

  final SavedAddress address;

  /// False while the patient has only one address saved.
  final bool showRadio;

  /// True for the row whose radio is filled in.
  final bool chosen;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: chosen ? const Color(0xFFF0FFEC) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: chosen ? AppColors.neonGreen : AppColors.fieldBorder,
            width: chosen ? 3 : 1.5,
          ),
          boxShadow: chosen
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.location_on_outlined,
              size: 24,
              color: chosen ? AppColors.logoGreen : AppColors.textMuted,
            ),
            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    address.text,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                      height: 1.3,
                    ),
                  ),

                  // Says which one is actually in use, so a radio moved but
                  // not yet confirmed cannot be mistaken for a saved change.
                  if (address.isPresent) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'Present address',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.logoGreen,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            if (showRadio) ...[
              const SizedBox(width: 12),
              // Drawn rather than using Radio, because the row itself is the
              // tap target and this keeps the fill in the same neon green as
              // the border.
              Icon(
                chosen
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 26,
                color: chosen ? AppColors.logoGreen : AppColors.fieldBorder,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The box that "+ Add new Address" opens.
///
/// Pops with the typed address, or with null if it was cancelled. It only
/// checks that something was typed and that it fits the column - everything
/// else, including whether this address is already in the list, is the
/// server's answer to give.
class _AddAddressDialog extends StatefulWidget {
  const _AddAddressDialog();

  @override
  State<_AddAddressDialog> createState() => _AddAddressDialogState();
}

class _AddAddressDialogState extends State<_AddAddressDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSavePressed() {
    final typed = _controller.text.trim();

    if (typed.isEmpty) {
      setState(() => _error = 'Please type an address.');
      return;
    }

    // ADDRESS.present_address is varchar(255), so a longer one would be cut
    // off by MySQL rather than refused.
    if (typed.length > 255) {
      setState(() => _error = 'Address cannot be longer than 255 characters.');
      return;
    }

    Navigator.of(context).pop(typed);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Row(
        children: [
          Icon(Icons.add_location_alt_outlined,
              color: AppColors.logoGreen, size: 26),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Add new Address',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 3,
        minLines: 2,
        textCapitalization: TextCapitalization.words,
        style: const TextStyle(fontSize: 16, color: AppColors.textDark),
        onChanged: (_) {
          // Clears a complaint as soon as they start fixing it.
          if (_error != null) setState(() => _error = null);
        },
        decoration: InputDecoration(
          hintText: 'House, road, area',
          errorText: _error,
          errorMaxLines: 2,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: AppColors.fieldBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: AppColors.logoGreen, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Colors.red),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _onSavePressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.logoGreen,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
