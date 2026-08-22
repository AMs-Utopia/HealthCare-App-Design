import 'package:flutter/material.dart';

import '../models/hospital.dart';
import '../models/signed_in_user.dart';
import '../services/hospital_service.dart';
import '../theme/app_colors.dart';
import '../widgets/neon_list_button.dart';
import '../widgets/screen_header.dart';
import 'choose_department_screen.dart';

/// Screen 6 - Hospitals.

/// Reached by picking an area on the choose area screen. Lists the hospitals
/// in that area from `api/hospitals.php`; picking one leads to the doctors
/// who hold chambers there.
class HospitalsScreen extends StatefulWidget {
  const HospitalsScreen({
    super.key,
    required this.area,
    required this.patient,
  });

  final SignedInUser patient;
  /// The area chosen on the previous screen, e.g. "Badda".
  final String area;

  @override
  State<HospitalsScreen> createState() => _HospitalsScreenState();
}

class _HospitalsScreenState extends State<HospitalsScreen> {
  List<Hospital> _hospitals = [];
  bool _isLoading = true;
  String? _loadError;
  /// The hospital tapped last, so it stays lit up.
  Hospital? _selected;

  @override
  void initState() {
    super.initState();
    _loadHospitals();
  }

  Future<void> _loadHospitals() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    final result = await HospitalService.fetchByArea(widget.area);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.isSuccess) {
        _hospitals = result.hospitals;
      } else {
        _loadError = result.error;
      }
    });
  }

  void _onHospitalTapped(Hospital hospital) {
    setState(() => _selected = hospital);

    // Doctors at a hospital are grouped by department, so the hospital leads
    // to the departments in it rather than straight to a list of doctors.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChooseDepartmentScreen(
          hospital: hospital,
          patient: widget.patient,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ScreenHeader(title: 'Hospitals'),
              const SizedBox(height: 12),

              // Which area these hospitals belong to, so the screen makes
              // sense on its own.
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.area,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

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
              'Loading hospitals...',
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
                onPressed: _loadHospitals,
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
      itemCount: _hospitals.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final hospital = _hospitals[index];
        return NeonListButton(
          icon: Icons.local_hospital_outlined,
          title: hospital.name,
          subtitle: hospital.address,
          selected: _selected?.id == hospital.id,
          onTap: () => _onHospitalTapped(hospital),
        );
      },
    );
  }
}