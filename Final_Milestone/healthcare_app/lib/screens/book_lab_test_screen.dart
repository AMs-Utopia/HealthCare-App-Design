import 'package:flutter/material.dart';

import '../models/hospital.dart';
import '../models/lab_test.dart';
import '../models/order.dart';
import '../models/patient_profile.dart';
import '../models/signed_in_user.dart';
import '../services/hospital_service.dart';
import '../services/lab_test_service.dart';
import '../services/patient_service.dart';
import '../theme/app_colors.dart';
import '../widgets/primary_button.dart';
import '../widgets/screen_header.dart';

/// Screen 23 (User / Patient) - Lab Test booking.
///
/// Reached by tapping a test on the Lab Tests screen.
///
/// Patient Details across the top, the test and what it costs, and the one
/// thing the patient actually has to decide: which hospital to have it done at.
/// Confirm asks "Are you sure?" naming the test, the hospital and the price
/// before anything is written.
///
/// The patient details are READ, never typed. The account already holds the
/// name, UID, age, gender and blood group, and asking somebody to type their
/// own blood group into a lab booking is how a booking ends up disagreeing with
/// the record it belongs to. Anything missing says "Not set" and points at
/// Basic Info rather than offering a box to fill in here.
///
/// The price shown is quoted from the LAB_TEST row the list came from, and is
/// quoted again in the popup - but it is NOT sent when booking. The server
/// reads what the centre charges from its own table, because a price arriving
/// from a phone would be a price whoever sent the request chose.
class BookLabTestScreen extends StatefulWidget {
  const BookLabTestScreen({
    super.key,
    required this.patient,
    required this.test,
  });

  final SignedInUser patient;

  /// The test being booked, carried in from the list so the screen can draw
  /// itself before anything has loaded.
  final LabTest test;

  @override
  State<BookLabTestScreen> createState() => _BookLabTestScreenState();
}

class _BookLabTestScreenState extends State<BookLabTestScreen> {
  PatientProfile? _profile;
  List<Hospital> _hospitals = [];
  Hospital? _chosenHospital;

  bool _isLoading = true;
  bool _isBooking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// The account and the hospitals together, because neither is any use
  /// without the other and the screen cannot be filled in until both are here.
  Future<void> _load() async {
    if (mounted) setState(() => _isLoading = true);

    final results = await Future.wait([
      PatientService.fetchProfile(widget.patient.id),
      HospitalService.fetchAll(),
    ]);

    if (!mounted) return;

    final profileResult = results[0] as ProfileResult;
    final hospitalResult = results[1] as HospitalResult;

    setState(() {
      _isLoading = false;

      if (profileResult.isSuccess) _profile = profileResult.profile;

      if (hospitalResult.isSuccess) {
        _hospitals = hospitalResult.hospitals;
        _error = null;
      } else {
        // Without hospitals there is nothing to choose, so this one is worth
        // stopping for - unlike the profile, which falls back to the signed in
        // account.
        _error = hospitalResult.error;
      }
    });
  }

  // ===========================================================================
  // Confirming
  // ===========================================================================

  Future<void> _confirm() async {
    final hospital = _chosenHospital;

    if (hospital == null || _isBooking) return;

    final sure = await _askAreYouSure(hospital);

    if (sure != true || !mounted) return;

    setState(() => _isBooking = true);

    final result = await LabTestService.book(
      patientId: widget.patient.id,
      testId: widget.test.id,
      hospitalId: hospital.id,
    );

    if (!mounted) return;

    setState(() => _isBooking = false);

    if (!result.isSuccess) {
      _say(result.error!);
      return;
    }

    await _showBooked(result.booking!, hospital);

    if (mounted) Navigator.of(context).pop(true);
  }

  /// The popup: this test, at this hospital, at this price.
  ///
  /// All three are named on purpose. "Are you sure?" on its own asks the
  /// patient to remember what they just tapped; naming the test, the place and
  /// the money is what makes confirming mean something.
  Future<bool?> _askAreYouSure(Hospital hospital) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Are you sure?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Book this test?',
              style: TextStyle(fontSize: 15, color: AppColors.textDark),
            ),
            const SizedBox(height: 12),
            _DialogLine(label: 'Test', value: widget.test.name),
            const SizedBox(height: 8),
            _DialogLine(
              label: 'Hospital',
              value: '${hospital.name}, ${hospital.area}',
            ),
            const SizedBox(height: 8),
            _DialogLine(
              label: 'Price',
              value: widget.test.priceLine,
              bold: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.logoGreen),
            child: const Text(
              'Yes',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showBooked(LabBooking booking, Hospital hospital) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: AppColors.logoGreen,
              size: 26,
            ),
            const SizedBox(width: 10),
            const Text('Test booked'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${booking.testName} is booked at ${hospital.name} for '
              '${booking.priceLine}.',
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textDark,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'It is on your dashboard bell, and it stays in your test '
              'history.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
                height: 1.35,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: TextButton.styleFrom(foregroundColor: AppColors.logoGreen),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
      );
  }

  // ===========================================================================
  // Drawing it
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ScreenHeader(title: 'Lab Test'),
              const SizedBox(height: 14),
              Expanded(child: _buildBody()),

              if (!_isLoading && _error == null) ...[
                const SizedBox(height: 10),
                _buildConfirm(),
              ],
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
        title: 'Could not load the booking form',
        detail: _error!,
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPatientDetails(),
          const SizedBox(height: 16),
          _buildTestCard(),
          const SizedBox(height: 16),
          _buildHospitalPicker(),
        ],
      ),
    );
  }

  /// Read from the account, never typed. The wireframe's "Patient Details".
  Widget _buildPatientDetails() {
    // Falls back to the signed in account, so the card is never blank even if
    // the profile read failed.
    final name = _profile?.fullName ?? widget.patient.displayName;
    final phone = _profile?.phone ?? widget.patient.phone;
    final uid = _profile?.patientUid;
    final age = _profile?.age;
    final gender = _profile?.gender;
    final blood = _profile?.bloodGroup;

    // The three that come from Basic Info and are commonly still unset. Said
    // out loud rather than left blank, because a lab needs them and the
    // patient is the only one who can fill them in.
    final missing = <String>[
      if (age == null) 'date of birth',
      if (gender == null || gender.isEmpty) 'gender',
      if (blood == null || blood.isEmpty) 'blood group',
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.fieldBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Patient Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          const Divider(height: 12, color: AppColors.background, thickness: 1),

          _DetailLine(label: 'Name', value: name),
          _DetailLine(label: 'Patient ID', value: uid ?? 'Not set'),
          _DetailLine(label: 'Phone', value: phone),
          _DetailLine(
            label: 'Age',
            value: age == null ? 'Not set' : '$age yrs',
            muted: age == null,
          ),
          _DetailLine(
            label: 'Gender',
            value: gender == null || gender.isEmpty ? 'Not set' : gender,
            muted: gender == null || gender.isEmpty,
          ),
          _DetailLine(
            label: 'Blood group',
            value: blood == null || blood.isEmpty ? 'Not set' : blood,
            muted: blood == null || blood.isEmpty,
            last: true,
          ),

          if (missing.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 14,
                  color: AppColors.historyRescheduled,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Your ${missing.join(', ')} '
                    '${missing.length == 1 ? 'is' : 'are'} not set. You can '
                    'still book, but add ${missing.length == 1 ? 'it' : 'them'} '
                    'in Profile, Basic Info so the lab has it.',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.historyRescheduled,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Which test, and what it costs.
  Widget _buildTestCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.logoGreen, width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.biotech_outlined,
            size: 26,
            color: AppColors.logoGreen,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Test',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.test.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            widget.test.priceLine,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.logoGreen,
            ),
          ),
        ],
      ),
    );
  }

  /// The one thing on this screen the patient actually decides.
  Widget _buildHospitalPicker() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          // Picked out until it is answered, since nothing can be confirmed
          // without it.
          color: _chosenHospital == null
              ? AppColors.historyRescheduled
              : AppColors.fieldBorder,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Where do you want the test done?',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 10),

          DropdownButtonFormField<Hospital>(
            initialValue: _chosenHospital,
            isExpanded: true,
            decoration: InputDecoration(
              hintText: 'Choose a hospital',
              hintStyle: const TextStyle(
                fontSize: 14,
                color: AppColors.textMuted,
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            items: [
              for (final hospital in _hospitals)
                DropdownMenuItem(
                  value: hospital,
                  child: Text(
                    // The area is part of the choice, not decoration - there
                    // are four hospitals in Badda alone, and the patient is
                    // picking the one they can get to.
                    '${hospital.name}  ·  ${hospital.area}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
            ],
            onChanged: _isBooking
                ? null
                : (hospital) => setState(() => _chosenHospital = hospital),
          ),

          if (_chosenHospital == null) ...[
            const SizedBox(height: 6),
            const Text(
              'Pick one to confirm the booking.',
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.historyRescheduled,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConfirm() {
    final ready = _chosenHospital != null;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'You will pay',
                style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
              ),
              const SizedBox(height: 2),
              Text(
                widget.test.hasPrice
                    ? formatTaka(widget.test.price!)
                    : widget.test.priceLine,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),

        _isBooking
            ? const SizedBox(
                width: 150,
                height: 48,
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.logoGreen,
                    ),
                  ),
                ),
              )
            : PrimaryButton(
                label: 'Confirm',
                width: 150,
                glow: ready,
                onPressed: ready ? _confirm : null,
              ),
      ],
    );
  }
}

/// One "label ..... value" row of the patient details card.
class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.label,
    required this.value,
    this.muted = false,
    this.last = false,
  });

  final String label;
  final String value;

  /// Greys a value that is the absence of one.
  final bool muted;

  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: muted ? FontWeight.normal : FontWeight.w600,
                color: muted ? AppColors.textMuted : AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One line inside the "Are you sure?" popup.
class _DialogLine extends StatelessWidget {
  const _DialogLine({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 66,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: bold ? 16 : 14,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: bold ? AppColors.logoGreen : AppColors.textDark,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}

/// The middle of the screen when the form could not be loaded.
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
