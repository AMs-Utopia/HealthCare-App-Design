import '../config/api_config.dart';

/// The two options the Basic Info screen offers.
///
/// Kept as a list rather than an enum because the strings are exactly what
/// PATIENT.gender stores and exactly what the API validates against, so there
/// is nothing to translate between the two sides.
class Genders {
  Genders._();

  static const List<String> all = ['Male', 'Female'];
}

/// The eight ABO/Rh groups, as stored in PATIENT.blood_group.
class BloodGroups {
  BloodGroups._();

  static const List<String> all = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];
}

/// One patient's account as the Basic Info screen edits it.
///
/// This is two tables joined by the API into one object: the name, phone, date
/// of birth, gender, blood group and photo live in PATIENT, and the present
/// address lives in ADDRESS. The screen draws one form and does not need to
/// know that.
///
/// [age] is not stored anywhere. There is no age column in the schema, because
/// an age and a date of birth kept side by side would disagree the moment the
/// patient had a birthday - so MySQL works it out from [dateOfBirth] on every
/// read, and the form shows it without ever sending it back.
class PatientProfile {
  const PatientProfile({
    required this.id,
    required this.fullName,
    required this.phone,
    this.patientUid,
    this.dateOfBirth,
    this.age,
    this.gender,
    this.bloodGroup,
    this.profileImage,
    this.presentAddress,
  });

  final int id;
  final String fullName;
  final String phone;

  /// The business id, e.g. PAT00006.
  final String? patientUid;

  /// Stored as yyyy-mm-dd. Null until the patient gives one.
  final String? dateOfBirth;

  /// Worked out by the server from [dateOfBirth], never sent back to it.
  final int? age;

  /// 'Male' or 'Female'.
  final String? gender;
  final String? bloodGroup;

  /// The file name only, e.g. "patient_6_1787234322.jpg" - never a full
  /// address. See [photoUrl].
  final String? profileImage;

  final String? presentAddress;

  /// True once the patient has uploaded a photo.
  bool get hasPhoto => profileImage != null && profileImage!.isNotEmpty;

  /// Where to fetch the photo from, built from whichever host this build is
  /// pointed at. Null when there is no photo to fetch.
  Uri? get photoUrl =>
      hasPhoto ? ApiConfig.uploadUrl(profileImage!) : null;

  /// [dateOfBirth] as a real date, for handing to the date picker.
  DateTime? get dateOfBirthDate =>
      dateOfBirth == null ? null : DateTime.tryParse(dateOfBirth!);

  /// The age as the form shows it, or a blank the patient can fill by setting
  /// a date of birth.
  String get ageLine => age == null ? '' : '$age';

  factory PatientProfile.fromJson(Map<String, dynamic> json) {
    return PatientProfile(
      id: int.tryParse('${json['patient_id']}') ?? 0,
      fullName: (json['full_name'] as String?) ?? '',
      phone: (json['phone'] as String?) ?? '',
      patientUid: json['patient_uid'] as String?,
      dateOfBirth: json['date_of_birth'] as String?,
      age: json['age'] == null ? null : int.tryParse('${json['age']}'),
      gender: json['gender'] as String?,
      bloodGroup: json['blood_group'] as String?,
      profileImage: json['profile_image'] as String?,
      presentAddress: json['present_address'] as String?,
    );
  }
}

/// Turns a stored yyyy-mm-dd into the dd/mm/yyyy the wireframe asks for.
String formatDateOfBirth(String? isoDate) {
  if (isoDate == null || isoDate.isEmpty) return '';

  final date = DateTime.tryParse(isoDate);
  if (date == null) return isoDate;

  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');

  return '$day/$month/${date.year}';
}

/// A picked date back into the yyyy-mm-dd the date column takes.
String toIsoDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');

  return '${date.year}-$month-$day';
}

/// How old somebody born on [birthday] is today.
///
/// Worked out in the app as well as by MySQL, so the age box updates the
/// instant a date is picked rather than only after the form has been saved and
/// read back. The two agree: both count whole years, and both take away one
/// when this year's birthday has not come round yet.
int ageFrom(DateTime birthday) {
  final today = DateTime.now();
  var years = today.year - birthday.year;

  final hadBirthday =
      today.month > birthday.month ||
      (today.month == birthday.month && today.day >= birthday.day);

  if (!hadBirthday) years--;

  return years < 0 ? 0 : years;
}
