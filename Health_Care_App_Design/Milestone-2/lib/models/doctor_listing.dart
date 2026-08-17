import 'weekday.dart';

/// Stores the doctor information shown to patients.
/// The schedule is for the selected hospital.
class DoctorListing {
  const DoctorListing({
    required this.id,
    required this.scheduleId,
    required this.fullName,
    required this.departmentName,
    required this.weekdays,
    required this.timeSlot,
    this.licenseNo,
    this.offday,
    this.degrees,
    this.chamberNo,
    this.floorNo,
  });

  final int id;

  /// The schedule ID for this doctor at the selected hospital.
  /// It is used when booking the appointment.
  final int scheduleId;
  final String fullName;
  final String departmentName;
  final String? licenseNo;
  /// The days this doctor sits at the hospital being browsed.
  final List<Weekday> weekdays;
  final String timeSlot;
  final Weekday? offday;
  /// The doctor's degrees already joined by the API, e.g.
  /// "MBBS, FCPS (Medicine)". Null when they have not added any.
  final String? degrees;
  final String? chamberNo;
  final String? floorNo;
  /// How the doctor is addressed in the list.
  String get displayName => 'Dr. $fullName';
  /// The chamber line, when the doctor has filled it in.
  String? get chamberLine {
    final parts = <String>[
      if (chamberNo != null && chamberNo!.isNotEmpty) 'Chamber $chamberNo',
      if (floorNo != null && floorNo!.isNotEmpty) 'Floor $floorNo',
    ];
    return parts.isEmpty ? null : parts.join(', ');
  }

  factory DoctorListing.fromJson(Map<String, dynamic> json) {
    return DoctorListing(
      id: int.tryParse('${json['doctor_id']}') ?? 0,
      scheduleId: int.tryParse('${json['schedule_id']}') ?? 0,
      fullName: (json['full_name'] as String?) ?? '',
      departmentName: (json['department_name'] as String?) ?? '',
      licenseNo: json['license_no'] as String?,
      weekdays: Weekday.parseCsv(json['weekday'] as String?),
      timeSlot: (json['time_slot'] as String?) ?? '',
      offday: Weekday.fromCode(json['offday'] as String?),
      degrees: json['degrees'] as String?,
      chamberNo: json['chamber_no'] as String?,
      floorNo: json['floor_no'] as String?,
    );
  }
}
