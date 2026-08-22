import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/hospital.dart';
import '../services/hospital_service.dart';
import '../theme/app_colors.dart';
import '../widgets/screen_header.dart';

/// Screen 24 (User / Patient) - Call a Hospital.
///
/// Reached from Call a Hospital on the patient dashboard.
///
/// Every hospital with a helpline, grouped by area, each row a button that
/// opens the phone's dialer with the number already typed in.
///
/// What this screen deliberately does NOT do is place the call. [launchUrl]
/// with a `tel:` URI opens the dialer and stops there, so the patient always
/// presses the green button themselves. An app that dialled on a single tap
/// would be one mis-tap away from ringing a hospital switchboard, and a
/// healthcare app is the last place that should happen.
///
/// Hospitals with no number on file are still listed, greyed out and saying
/// so, rather than being hidden. A patient looking for a hospital they know is
/// on the list would otherwise think the app had lost it - and "we do not have
/// their number" is a more useful answer than an absence.
class CallHospitalScreen extends StatefulWidget {
  const CallHospitalScreen({super.key});

  @override
  State<CallHospitalScreen> createState() => _CallHospitalScreenState();
}

class _CallHospitalScreenState extends State<CallHospitalScreen> {
  List<Hospital> _hospitals = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _isLoading = true);

    final result = await HospitalService.fetchAll();

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.isSuccess) {
        _hospitals = result.hospitals;
        _error = null;
      } else {
        _error = result.error;
      }
    });
  }

  /// Hospitals that have a number, then the ones that do not.
  ///
  /// Both lists keep the server's ordering, which is by area then name - so
  /// the callable ones read as a proper directory rather than as whatever
  /// order the rows happened to come back in.
  List<Hospital> get _callable =>
      _hospitals.where((h) => _numberOf(h) != null).toList();

  List<Hospital> get _uncallable =>
      _hospitals.where((h) => _numberOf(h) == null).toList();

  /// The number to dial, or null when there is none on file.
  ///
  /// A row whose phone is an empty string counts as having none - the column
  /// is nullable and a blank is the same absence, just written differently.
  static String? _numberOf(Hospital hospital) {
    final phone = hospital.phone;

    if (phone == null || phone.trim().isEmpty) return null;

    return phone.trim();
  }

  // ===========================================================================
  // Dialling
  // ===========================================================================

  /// Opens the dialer with the number filled in.
  ///
  /// Everything but digits and a leading + is stripped out first. A number
  /// stored as "02-9661551" or "+880 2 966 1551" is perfectly readable to a
  /// person and not always to the dialer, and the tel: scheme wants it plain.
  Future<void> _call(Hospital hospital) async {
    final number = _numberOf(hospital);

    if (number == null) return;

    final dialable = number.replaceAll(RegExp(r'[^0-9+]'), '');

    if (dialable.isEmpty) {
      _say('${hospital.name} has no number that can be dialled.');
      return;
    }

    final uri = Uri(scheme: 'tel', path: dialable);

    try {
      final opened = await launchUrl(uri);

      if (!opened && mounted) {
        _say('This device could not open the dialer for $number.');
      }
    } on Exception {
      // Thrown on a device with no dialer at all - an emulator without the
      // phone app, most often, which is exactly where this will be tested.
      if (mounted) {
        _say(
          'No dialer on this device. $number is the number for '
          '${hospital.name}.',
        );
      }
    }
  }

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
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
              const ScreenHeader(title: 'Call a Hospital'),
              const SizedBox(height: 14),
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
        title: 'Could not load the hospitals',
        detail: _error!,
      );
    }

    final callable = _callable;
    final uncallable = _uncallable;

    return RefreshIndicator(
      color: AppColors.logoGreen,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 8),
        children: [
          const _NationalHelplineCard(),
          const SizedBox(height: 18),

          if (callable.isNotEmpty) ...[
            _SectionTitle(
              title: callable.length == 1
                  ? '1 hospital helpline'
                  : '${callable.length} hospital helplines',
              detail: 'Tap one to open your dialer.',
            ),
            const SizedBox(height: 10),

            for (final hospital in callable) ...[
              _HospitalRow(
                hospital: hospital,
                number: _numberOf(hospital)!,
                onCall: () => _call(hospital),
              ),
              const SizedBox(height: 10),
            ],
          ],

          // Listed, not hidden. A patient looking for a hospital they know is
          // in the app would otherwise think it had gone missing.
          if (uncallable.isNotEmpty) ...[
            const SizedBox(height: 8),
            _SectionTitle(
              title: 'No number on file',
              detail: uncallable.length == 1
                  ? 'We do not have a helpline for this one yet.'
                  : 'We do not have helplines for these '
                        '${uncallable.length} yet.',
            ),
            const SizedBox(height: 10),

            for (final hospital in uncallable) ...[
              _HospitalRow(hospital: hospital, number: null, onCall: null),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }
}

/// Bangladesh's own health line, above the hospitals.
///
/// Not a row of the HOSPITAL table and deliberately not put in it - 16263 is a
/// government call centre, not a hospital, and a fake hospital row would leak
/// into the booking screens, the doctor schedules and everything else that
/// reads that table.
///
/// It is here because it is the right number for most of the moments somebody
/// opens a screen called "Call a Hospital": they do not know which hospital
/// they need. Deleting this widget is the only change needed to remove it.
class _NationalHelplineCard extends StatelessWidget {
  const _NationalHelplineCard();

  static const String _number = '16263';

  Future<void> _call(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final opened = await launchUrl(Uri(scheme: 'tel', path: _number));

      if (!opened) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('This device could not open the dialer for 16263.'),
            ),
          );
      }
    } on Exception {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('No dialer on this device. Call 16263.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.logoGreen, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: AppColors.neonGreen,
            blurRadius: 12,
            spreadRadius: -6,
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.support_agent,
            size: 32,
            color: AppColors.logoGreen,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Shastho Batayon',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  "Bangladesh's government health line, open 24 hours",
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    height: 1.3,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  _number,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.logoGreen,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _CallButton(onPressed: () => _call(context)),
        ],
      ),
    );
  }
}

/// One hospital, and the way to ring it.
class _HospitalRow extends StatelessWidget {
  const _HospitalRow({
    required this.hospital,
    required this.number,
    required this.onCall,
  });

  final Hospital hospital;

  /// Null when there is no number on file, which greys the whole row.
  final String? number;

  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    final callable = number != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onCall,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            color: callable ? Colors.white : AppColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.fieldBorder, width: 1.5),
          ),
          child: Row(
            children: [
              Icon(
                Icons.local_hospital_outlined,
                size: 20,
                color: callable ? AppColors.logoGreen : AppColors.textMuted,
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hospital.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: callable
                            ? AppColors.textDark
                            : AppColors.textMuted,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hospital.area,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      number ?? 'No number on file',
                      style: TextStyle(
                        fontSize: callable ? 15 : 12.5,
                        fontWeight: callable
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontStyle: callable ? FontStyle.normal : FontStyle.italic,
                        color: callable
                            ? AppColors.logoBlue
                            : AppColors.textMuted,
                        letterSpacing: callable ? 1.0 : 0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              if (callable) _CallButton(onPressed: onCall!),
            ],
          ),
        ),
      ),
    );
  }
}

/// The green call button on a row.
class _CallButton extends StatelessWidget {
  const _CallButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.call, size: 18),
      label: const Text(
        'Call',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.logoGreen,
        foregroundColor: Colors.white,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

/// A heading over a group of rows.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            detail,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// The middle of the screen when nothing could be loaded.
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
