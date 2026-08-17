import 'package:flutter/material.dart';

import '../models/department.dart';
import '../models/doctor_listing.dart';
import '../models/hospital.dart';
import '../models/signed_in_user.dart';
import '../models/weekday.dart';
import '../services/doctor_service.dart';
import '../theme/app_colors.dart';
import '../widgets/screen_header.dart';
import 'book_slot_screen.dart';

/// Screen 11 - Doctors List.

/// Reached by picking a department on the choose department screen. Lists the
/// doctors of that department who hold a chamber at that hospital, with the
/// degrees and the sitting days a patient needs before booking.
class DoctorsListScreen extends StatefulWidget {
  const DoctorsListScreen({
    super.key,
    required this.hospital,
    required this.department,
    required this.patient,
  });

  final Hospital hospital;
  final Department department;
  final SignedInUser patient;

  @override
  State<DoctorsListScreen> createState() => _DoctorsListScreenState();
}

class _DoctorsListScreenState extends State<DoctorsListScreen> {
  List<DoctorListing> _doctors = [];
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  Future<void> _loadDoctors() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    final result = await DoctorService.fetchForHospitalDepartment(
      hospitalId: widget.hospital.id,
      departmentId: widget.department.id,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.isSuccess) {
        _doctors = result.doctors;
      } else {
        _loadError = result.error;
      }
    });
  }

  void _onBookPressed(DoctorListing doctor) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookSlotScreen(
          patient: widget.patient,
          doctor: doctor,
          hospital: widget.hospital,
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
              const ScreenHeader(title: 'Doctors List'),
              const SizedBox(height: 12),

              // Which department at which hospital these doctors belong to.
              Text(
                '${widget.department.name}  ·  ${widget.hospital.name}',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                  height: 1.3,
                ),
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
              'Loading doctors...',
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
                onPressed: _loadDoctors,
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

    if (_doctors.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.person_off_outlined,
                size: 48,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: 14),
              Text(
                'No ${widget.department.name} doctors sit at this hospital '
                'yet.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _loadDoctors,
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
      itemCount: _doctors.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _DoctorCard(
          doctor: _doctors[index],
          onBook: () => _onBookPressed(_doctors[index]),
        );
      },
    );
  }
}
/// One doctor row: who they are on the left, Book on the right.
class _DoctorCard extends StatelessWidget {
  const _DoctorCard({required this.doctor, required this.onBook});

  final DoctorListing doctor;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.fieldBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            doctor.displayName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          // Degrees are why a patient picks one doctor over another, so they
          // sit directly under the name.
          if (doctor.degrees != null && doctor.degrees!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              doctor.degrees!,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.logoBlue,
                height: 1.3,
              ),
            ),
          ],

          const SizedBox(height: 10),

          if (doctor.weekdays.isNotEmpty)
            _InfoLine(
              icon: Icons.calendar_month_outlined,
              text: Weekday.describe(doctor.weekdays),
            ),
          if (doctor.timeSlot.isNotEmpty)
            _InfoLine(
              icon: Icons.schedule_outlined,
              text: doctor.timeSlot,
            ),
          if (doctor.offday != null)
            _InfoLine(
              icon: Icons.event_busy_outlined,
              text: 'Off day: ${doctor.offday!.fullName}',
            ),
          if (doctor.chamberLine != null)
            _InfoLine(
              icon: Icons.meeting_room_outlined,
              text: doctor.chamberLine!,
            ),

          const SizedBox(height: 12),

          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: onBook,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.logoGreen,
                foregroundColor: Colors.white,
                elevation: 2,
                padding: const EdgeInsets.symmetric(
                  horizontal: 26,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Book',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
/// One small icon plus text line inside a doctor card.
class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textDark,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}