import 'package:flutter/material.dart';

import '../models/appointment.dart';
import '../models/signed_in_user.dart';
import '../services/appointment_service.dart';
import '../theme/app_colors.dart';
import '../widgets/screen_header.dart';

/// Screen 13 (Doctor) - Appointments List.
/// Reached from the "Check Appointments" box on the doctor dashboard. Opening
/// it counts as checking, so every appointment still Pending becomes
/// Confirmed and the dot on the doctor's bell clears.
class AppointmentsListScreen extends StatefulWidget {
  const AppointmentsListScreen({super.key, required this.doctor});

  final SignedInUser doctor;

  @override
  State<AppointmentsListScreen> createState() => _AppointmentsListScreenState();
}

class _AppointmentsListScreenState extends State<AppointmentsListScreen> {
  List<DoctorAppointment> _appointments = [];
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    // markSeen only on the first load: a manual refresh should not be needed
    // to clear the bell twice.
    _load(markSeen: true);
  }

  Future<void> _load({bool markSeen = false}) async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    final result = await AppointmentService.fetchForDoctor(
      widget.doctor.id,
      markSeen: markSeen,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.isSuccess) {
        _appointments = result.appointments;
      } else {
        _loadError = result.error;
      }
    });
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
              const ScreenHeader(title: 'Appointments List'),
              const SizedBox(height: 12),

              if (!_isLoading && _loadError == null)
                Text(
                  _appointments.length == 1
                      ? '1 appointment'
                      : '${_appointments.length} appointments',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textMuted,
                  ),
                ),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.logoGreen),
            SizedBox(height: 16),
            Text(
              'Loading appointments...',
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
                onPressed: _load,
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

    if (_appointments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.event_available_outlined,
                size: 48,
                color: AppColors.textMuted,
              ),
              SizedBox(height: 14),
              const Text(
                'No patients have booked you yet.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppColors.textDark),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _load,
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

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.logoGreen,
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: _appointments.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) =>
            _AppointmentCard(appointment: _appointments[index]),
      ),
    );
  }
}

/// One patient's booking, as the doctor sees it.
class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({required this.appointment});

  final DoctorAppointment appointment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.fieldBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The serial is what the doctor calls patients in by, so it
              // leads the card.
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.logoGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.logoGreen, width: 1.5),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'No.',
                      style: TextStyle(
                        fontSize: 9,
                        color: AppColors.textMuted,
                      ),
                    ),
                    Text(
                      '${appointment.serialNo}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.logoGreen,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      appointment.patientName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    if (appointment.patientUid != null)
                      Text(
                        appointment.patientUid!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),

              _VisitTypeChip(type: appointment.visitType),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.fieldBorder),
          const SizedBox(height: 10),

          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _Fact(
                label: 'Age',
                // No screen collects a date of birth yet, so this is normally
                // blank rather than wrong.
                value: appointment.age == null
                    ? 'Not set'
                    : '${appointment.age}',
              ),
              if (appointment.gender != null && appointment.gender!.isNotEmpty)
                _Fact(label: 'Gender', value: appointment.gender!),
              if (appointment.bloodGroup != null &&
                  appointment.bloodGroup!.isNotEmpty)
                _Fact(label: 'Blood', value: appointment.bloodGroup!),
              _Fact(
                label: 'Date',
                value: formatAppointmentDate(appointment.date),
              ),
              _Fact(label: 'Time', value: appointment.time),
              if (appointment.contactMobile != null)
                _Fact(label: 'Mobile', value: appointment.contactMobile!),
            ],
          ),

          // Only worth showing when the booking was made for someone else.
          if (appointment.contactName != null &&
              appointment.contactName != appointment.patientName) ...[
            const SizedBox(height: 8),
            Text(
              'Booked as: ${appointment.contactName}',
              style: const TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The New / Follow-up / Report Check tag.
class _VisitTypeChip extends StatelessWidget {
  const _VisitTypeChip({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    // A first visit is the one the doctor most needs to spot at a glance.
    final isNew = type == 'New';
    final colour = isNew ? AppColors.logoGreen : AppColors.logoBlue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colour),
      ),
      child: Text(
        type,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colour,
        ),
      ),
    );
  }
}

/// One small "label: value" pair inside an appointment card.
class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }
}