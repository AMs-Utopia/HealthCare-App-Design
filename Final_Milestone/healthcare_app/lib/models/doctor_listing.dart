import 'chamber.dart';
import 'hospital.dart';
import 'weekday.dart';

/// Stores the doctor information shown to patients.
/// The schedule is for the selected hospital.
///
/// The same class serves both ways a patient arrives at a doctor:
///
///   browsing  hospital -> department -> doctors, where the hospital is already
///             known because the patient picked it, so [hospitalId] is null
///   searching one line that can span hospitals, so each result carries the
///             hospital it belongs to
///
/// That is why the hospital and profile fields below are all nullable - which
/// ones arrive depends on which screen asked.
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
    this.specialization,
    this.yearsExperience,
    this.experience,
    this.hospitalId,
    this.hospitalName,
    this.hospitalArea,
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

  /// What this doctor actually treats, in the words a patient would use, e.g.
  /// "Gastric, acidity and acid reflux; hunger and appetite problems". This is
  /// what the search ranks on, so it is worth showing.
  final String? specialization;

  /// Years in practice. Null for a doctor who has not filled it in.
  final int? yearsExperience;

  /// Career background, already joined by the API, e.g.
  /// "Associate Professor (Govt. Medical College) - Dhaka Medical College
  /// Hospital | Fellowship Trained Abroad - Royal Liverpool Hospital, UK".
  final String? experience;

  /// The hospital this sitting belongs to. Only sent by the search, since when
  /// browsing the patient already chose the hospital.
  final int? hospitalId;
  final String? hospitalName;
  final String? hospitalArea;

  /// How the doctor is addressed in the list.
  String get displayName => 'Dr. $fullName';

  /// The room, floor and lift as one thing, so the booking form names them
  /// exactly the way the doctor's own Chamber Info screen does.
  ///
  /// The doctor did not fill these in - the hospital assigned the room when
  /// this sitting was saved - so they are here on every listing rather than
  /// only on the ones a doctor has got round to completing.
  Chamber get chamber => Chamber(roomNo: chamberNo, floorNo: floorNo);

  /// The chamber line, when the doctor has filled it in.
  String? get chamberLine {
    final parts = <String>[
      if (chamberNo != null && chamberNo!.isNotEmpty) 'Chamber $chamberNo',
      if (floorNo != null && floorNo!.isNotEmpty) 'Floor $floorNo',
    ];
    return parts.isEmpty ? null : parts.join(', ');
  }

  /// Where this sitting is, as one line, e.g. "Ibne Sina Hospital, Badda".
  String? get hospitalLine {
    if (hospitalName == null || hospitalName!.isEmpty) return null;

    return hospitalArea == null || hospitalArea!.isEmpty
        ? hospitalName
        : '$hospitalName, $hospitalArea';
  }

  /// Years in practice, ready to print. Null when the doctor has not set it,
  /// so the line can be left out rather than showing a blank.
  String? get experienceLine {
    if (yearsExperience == null || yearsExperience! <= 0) return null;

    return yearsExperience == 1
        ? '1 year of experience'
        : '$yearsExperience years of experience';
  }

  /// The hospital this result belongs to, for handing to the booking screen.
  ///
  /// Null when browsing, because there the screen already holds the hospital
  /// the patient chose and does not need one rebuilt from the row.
  Hospital? get hospital {
    if (hospitalId == null) return null;

    return Hospital(
      id: hospitalId!,
      name: hospitalName ?? '',
      area: hospitalArea ?? '',
    );
  }

  factory DoctorListing.fromJson(Map<String, dynamic> json) {
    // hospital_id is absent when browsing and present when searching, so it is
    // read as "null unless the server sent one" rather than defaulting to 0.
    final rawHospitalId = json['hospital_id'];

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
      specialization: json['specialization'] as String?,
      yearsExperience: json['years_experience'] == null
          ? null
          : int.tryParse('${json['years_experience']}'),
      experience: json['experience'] as String?,
      hospitalId: rawHospitalId == null
          ? null
          : int.tryParse('$rawHospitalId'),
      hospitalName: json['hospital_name'] as String?,
      hospitalArea: json['area'] as String?,
    );
  }
}
