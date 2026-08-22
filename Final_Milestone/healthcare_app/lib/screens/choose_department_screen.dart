import 'package:flutter/material.dart';

import '../models/department.dart';
import '../models/hospital.dart';
import '../models/signed_in_user.dart';
import '../services/department_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/neon_list_button.dart';
import '../widgets/screen_header.dart';
import 'doctors_list_screen.dart';

/// Screen 10 - Choose Department.
/// Reached by picking a hospital on the hospitals screen. Only departments
/// that have a doctor sitting at that hospital are listed, because a doctor
/// is tied to a hospital through DOCTOR_SCHEDULE - picking a department with
/// nobody in it would lead to an empty list of doctors.
class ChooseDepartmentScreen extends StatefulWidget {
  const ChooseDepartmentScreen({
    super.key,
    required this.hospital,
    required this.patient,
  });

  final Hospital hospital;
  final SignedInUser patient;

  @override
  State<ChooseDepartmentScreen> createState() => _ChooseDepartmentScreenState();
}

class _ChooseDepartmentScreenState extends State<ChooseDepartmentScreen> {
  List<Department> _departments = [];
  bool _isLoading = true;
  String? _loadError;
  /// The department tapped last, so it stays lit up.
  Department? _selected;

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  Future<void> _loadDepartments() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    final result = await DepartmentService.fetchForHospital(
      widget.hospital.id,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.isSuccess) {
        _departments = result.departments;
      } else {
        _loadError = result.error;
      }
    });
  }

  void _onDepartmentTapped(Department department) {
    setState(() => _selected = department);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DoctorsListScreen(
          hospital: widget.hospital,
          department: department,
          patient: widget.patient,
        ),
      ),
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
              const ScreenHeader(title: 'Choose Department'),
              const SizedBox(height: 12),

              // Which hospital these departments belong to, so the screen
              // makes sense on its own.
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.local_hospital_outlined,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      widget.hospital.name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
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
              'Loading departments...',
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
                onPressed: _loadDepartments,
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
    // Not an error: the hospital is real, no doctor has set up a chamber
    // there yet. Saying so plainly beats an empty screen.
    if (_departments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.event_busy_outlined,
                size: 48,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: 14),
              const Text(
                'No doctors are available at this hospital yet.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppColors.textDark),
              ),
              const SizedBox(height: 6),
              const Text(
                'A department appears here once a doctor adds a schedule at '
                'this hospital.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textMuted,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _loadDepartments,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh'),
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
      itemCount: _departments.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final department = _departments[index];
        return NeonListButton(
          icon: Icons.medical_services_outlined,
          title: department.name,
          subtitle: department.doctorCount == 1
              ? '1 doctor'
              : '${department.doctorCount} doctors',
          selected: _selected?.id == department.id,
          onTap: () => _onDepartmentTapped(department),
        );
      },
    );
  }
}