import 'weekday.dart';
///One row of DOCTOR_SCHEDULE: a doctor's sitting at one hospital.
class DoctorSchedule {
  const DoctorSchedule({
    required this.id,
    required this.hospitalId,
    required this.hospitalName,
    required this.weekdays,
    required this.timeSlot,
    this.offday,
    this.area,
  });
  final int id;
  final int hospitalId;
  final String hospitalName;
  final String? area;
  ///The days the doctor sits, already back in week order.
  final List<Weekday> weekdays;
  final String timeSlot;
  /// Null when the doctor did not set one.
  final Weekday? offday;

  factory DoctorSchedule.fromJson(Map<String, dynamic> json) {
    return DoctorSchedule(
      id: int.tryParse('${json['schedule_id']}') ?? 0,
      hospitalId: int.tryParse('${json['hospital_id']}') ?? 0,
      hospitalName: (json['hospital_name'] as String?) ?? '',
      area: json['area'] as String?,
      weekdays: Weekday.parseCsv(json['weekday'] as String?),
      timeSlot: (json['time_slot'] as String?) ?? '',
      offday: Weekday.fromCode(json['offday'] as String?),
    );
  }
}