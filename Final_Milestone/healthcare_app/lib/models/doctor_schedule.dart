import 'chamber.dart';
import 'weekday.dart';
///One row of DOCTOR_SCHEDULE: a doctor's sitting at one hospital.
///
///[chamber] is the room the hospital gave the doctor when this sitting was
///saved. It is not something the doctor chose, which is why the add schedule
///screen never asks for it - the Chamber Info screen just reads it back.
class DoctorSchedule {
  const DoctorSchedule({
    required this.id,
    required this.hospitalId,
    required this.hospitalName,
    required this.weekdays,
    required this.timeSlot,
    this.chamber = const Chamber(),
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

  /// The room the hospital assigned for this sitting.
  final Chamber chamber;

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
      chamber: Chamber.fromJson(json),
      offday: Weekday.fromCode(json['offday'] as String?),
    );
  }
}