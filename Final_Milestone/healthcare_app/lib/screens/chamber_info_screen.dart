import 'package:flutter/material.dart';

import '../models/doctor_schedule.dart';
import '../models/signed_in_user.dart';
import '../models/weekday.dart';
import '../services/schedule_service.dart';
import '../theme/app_colors.dart';
import '../widgets/screen_header.dart';

/// Chamber Info (Doctor) - reached from the drawer menu.
///
/// One card per hospital the doctor sits at, naming the room they were given,
/// the floor it is on and the lift that reaches it, next to the days and hours
/// they hold that chamber.
///
/// Nothing on this screen can be edited, and that is the point. There is no
/// hospital account and no admin anywhere in this app, so the hospital assigns
/// a free room the moment the doctor saves a sitting there and it stays theirs
/// from then on. This screen reads those columns back; the patient's booking
/// form reads the very same ones, which is what stops the two ever naming
/// different rooms.
class ChamberInfoScreen extends StatefulWidget {
  const ChamberInfoScreen({super.key, required this.doctor});

  final SignedInUser doctor;

  @override
  State<ChamberInfoScreen> createState() => _ChamberInfoScreenState();
}

class _ChamberInfoScreenState extends State<ChamberInfoScreen> {
  List<DoctorSchedule> _schedules = [];
  bool _isLoading = true;
  String? _loadError;

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

    final result = await ScheduleService.fetchForDoctor(widget.doctor.id);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.isSuccess) {
        _schedules = result.schedules;
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
              const ScreenHeader(title: 'Chamber Info'),
              const SizedBox(height: 12),

              if (!_isLoading && _loadError == null && _schedules.isNotEmpty)
                const Text(
                  'Assigned by the hospital when you added the schedule.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
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
              'Loading your chambers...',
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

    if (_schedules.isEmpty) {
      // A doctor only gets a room once they say where they sit, so this points
      // at the screen that would give them one rather than just saying no.
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.meeting_room_outlined,
                size: 48,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: 14),
              const Text(
                'You have no chamber yet.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Add a schedule at a hospital and it will give you a room.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textMuted,
                  height: 1.35,
                ),
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
        itemCount: _schedules.length,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (context, index) =>
            _ChamberCard(schedule: _schedules[index]),
      ),
    );
  }
}

/// One hospital's chamber.
class _ChamberCard extends StatelessWidget {
  const _ChamberCard({required this.schedule});

  final DoctorSchedule schedule;

  @override
  Widget build(BuildContext context) {
    final chamber = schedule.chamber;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.fieldBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.local_hospital_outlined,
                size: 22,
                color: AppColors.logoBlue,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      schedule.hospitalName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    if (schedule.area != null && schedule.area!.isNotEmpty)
                      Text(
                        schedule.area!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // The room is the one thing a patient will be told, so it is the
          // biggest thing on the card.
          if (chamber.isAssigned)
            Row(
              children: [
                Expanded(
                  child: _ChamberTile(
                    icon: Icons.meeting_room_outlined,
                    label: 'Room',
                    value: chamber.roomNo!,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ChamberTile(
                    icon: Icons.stairs_outlined,
                    label: 'Floor',
                    value: chamber.floor ?? '-',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ChamberTile(
                    icon: Icons.elevator_outlined,
                    label: 'Lift',
                    value: chamber.floor ?? '-',
                  ),
                ),
              ],
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.fieldBorder),
              ),
              child: const Text(
                'No room assigned yet. Save this schedule again and the '
                'hospital will give you one.',
                style: TextStyle(
                  fontSize: 13.5,
                  color: AppColors.textMuted,
                  height: 1.35,
                ),
              ),
            ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.fieldBorder),
          const SizedBox(height: 12),

          _InfoRow(
            icon: Icons.calendar_month_outlined,
            label: 'Days',
            value: schedule.weekdays.isEmpty
                ? 'Not set'
                : Weekday.describe(schedule.weekdays),
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.schedule_outlined,
            label: 'Hours',
            value: schedule.timeSlot.isEmpty ? 'Not set' : schedule.timeSlot,
          ),
          if (schedule.offday != null) ...[
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.event_busy_outlined,
              label: 'Off day',
              value: schedule.offday!.fullName,
            ),
          ],
        ],
      ),
    );
  }
}

/// One of the three boxes: Room, Floor, Lift.
class _ChamberTile extends StatelessWidget {
  const _ChamberTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.logoGreen.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.logoGreen, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: AppColors.logoGreen),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.logoGreen,
            ),
          ),
        ],
      ),
    );
  }
}

/// One "label: value" line under the divider.
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 10),
        SizedBox(
          width: 62,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
