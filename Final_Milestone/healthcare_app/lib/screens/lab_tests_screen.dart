import 'package:flutter/material.dart';

import '../models/lab_test.dart';
import '../models/signed_in_user.dart';
import '../services/lab_test_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/screen_header.dart';
import 'book_lab_test_screen.dart';

/// Screen 22 (User / Patient) - Lab Tests.
///
/// Reached from Lab Test in Services.
///
/// The tests the centre offers, one to a row: the name on the left, what it
/// costs on the right, and the whole row a button. The list scrolls, because
/// there are thirty of them and there will be more.
///
/// Every row leads to booking that test: the patient's details, the price, and
/// which hospital to have it done at.
///
/// There is no search box on purpose. The wireframe has none, and a patient
/// booking a test has been told which one to have and is scanning for that
/// name rather than exploring. If the list ever outgrows scrolling, a filter
/// field above it is the change to make.
class LabTestsScreen extends StatefulWidget {
  const LabTestsScreen({super.key, required this.patient});

  /// The signed in patient. Nothing on this screen needs it - the list is the
  /// same for everyone - but the booking it leads to is for one patient, so it
  /// travels with the screen rather than being fetched again there.
  final SignedInUser patient;

  @override
  State<LabTestsScreen> createState() => _LabTestsScreenState();
}

class _LabTestsScreenState extends State<LabTestsScreen> {
  List<LabTest> _tests = [];
  bool _isLoading = true;
  String _message = '';
  String? _error;

  /// The test tapped last, so its row stays lit up - the same treatment the
  /// drawer and the dashboard boxes use.
  int? _selectedTestId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _isLoading = true);

    final result = await LabTestService.fetchAll();

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.isSuccess) {
        _tests = result.tests;
        _message = result.message;
        _error = null;
      } else {
        _error = result.error;
      }
    });
  }

  /// Opens the booking form for the tapped test.
  ///
  /// The whole [LabTest] is handed over rather than just its id, so the form
  /// can draw the test and its price before anything has loaded. It comes back
  /// true when a booking was made, which is worth a word here - the patient
  /// has just come back to a list that looks exactly as they left it.
  Future<void> _openBooking(LabTest test) async {
    setState(() => _selectedTestId = test.id);

    final booked = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BookLabTestScreen(patient: widget.patient, test: test),
      ),
    );

    if (booked == true && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('${test.name} booked. It is on your bell.'),
            duration: const Duration(seconds: 3),
          ),
        );
    }
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
              const ScreenHeader(title: 'Lab Tests'),
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
        title: 'Could not load the tests',
        detail: _error!,
      );
    }

    if (_tests.isEmpty) {
      return _Note(
        icon: Icons.biotech_outlined,
        title: 'No tests listed',
        detail: _message.isEmpty
            ? 'No lab tests are on offer at the moment.'
            : _message,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            '$_message  ·  Tap one to book it.',
            style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
          ),
        ),

        Expanded(
          child: RefreshIndicator(
            color: AppColors.logoGreen,
            onRefresh: _load,
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: 8),
              itemCount: _tests.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, index) => _TestRow(
                test: _tests[index],
                selected: _selectedTestId == _tests[index].id,
                onTap: () => _openBooking(_tests[index]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One test: what it is on the left, what it costs on the right, and the whole
/// row a button.
class _TestRow extends StatelessWidget {
  const _TestRow({
    required this.test,
    required this.selected,
    required this.onTap,
  });

  final LabTest test;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.logoGreen.withValues(alpha: 0.12)
                : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.logoGreen : AppColors.fieldBorder,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.biotech_outlined,
                size: 20,
                color: AppColors.logoGreen,
              ),
              const SizedBox(width: 12),

              // The name takes whatever room is left and wraps onto a second
              // line rather than being cut off - "Ultrasonogram of Whole
              // Abdomen" does not fit on one, and half a test name is no use
              // to somebody looking for it.
              Expanded(
                child: Text(
                  test.name,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                    height: 1.25,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              Text(
                test.priceLine,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: test.hasPrice ? 15.5 : 12.5,
                  fontWeight: FontWeight.bold,
                  color: test.hasPrice
                      ? AppColors.logoGreen
                      : AppColors.textMuted,
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
      ),
    );
  }
}

/// The middle of the screen when there is nothing to list.
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
