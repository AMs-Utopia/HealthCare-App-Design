import 'package:flutter/material.dart';

import '../models/area.dart';
import '../models/signed_in_user.dart';
import '../services/area_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/neon_list_button.dart';
import '../widgets/screen_header.dart';
import 'hospitals_screen.dart';

/// Screen 5 - Choose Area.
/// Reached from the "Doctor Lists" box on the patient dashboard. The areas
/// come from `api/areas.php`, which groups the `area` column of HOSPITAL, so
/// every area shown here has at least one hospital behind it.
class ChooseAreaScreen extends StatefulWidget {
  const ChooseAreaScreen({super.key, required this.patient});
  /// Carried through the whole booking path, because the booking form needs
  /// to know which patient is booking.
  final SignedInUser patient;

  @override
  State<ChooseAreaScreen> createState() => _ChooseAreaScreenState();
}

class _ChooseAreaScreenState extends State<ChooseAreaScreen> {
  List<Area> _areas = [];
  bool _isLoading = true;
  String? _loadError;

  /// The area tapped last, so it stays lit up.
  Area? _selected;

  @override
  void initState() {
    super.initState();
    _loadAreas();
  }

  Future<void> _loadAreas() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    final result = await AreaService.fetchAll();

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.isSuccess) {
        _areas = result.areas;
      } else {
        _loadError = result.error;
      }
    });
  }

  void _onAreaTapped(Area area) {
    setState(() => _selected = area);

    // Doctors are reached through the hospital they sit at, so the area leads
    // to the hospitals in it rather than straight to a list of doctors.
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HospitalsScreen(
          area: area.name,
          patient: widget.patient,
        )),
    );
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
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ScreenHeader(title: 'Choose Area'),
              const SizedBox(height: 22),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.logoGreen),
            SizedBox(height: 16),
            Text(
              'Loading areas...',
              style: TextStyle(fontSize: 15, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    if (_loadError != null) {
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
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.red.shade900),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: _loadAreas,
                icon: const Icon(Icons.refresh, size: 18),
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

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _areas.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final area = _areas[index];
        return NeonListButton(
          icon: Icons.location_on_outlined,
          title: area.name,
          subtitle: area.hospitalCount == 1
              ? '1 hospital'
              : '${area.hospitalCount} hospitals',
          selected: _selected?.name == area.name,
          onTap: () => _onAreaTapped(area),
        );
      },
    );
  }
}