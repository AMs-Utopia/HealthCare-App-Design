///Defines the three appointment/visit types available in app.
///Ensuring the Flutter values match what your PHP backend expects.
class VisitTypes {
  VisitTypes._();
  static const List<String> all = ['New', 'Follow-up', 'Report Check'];
}

///converts a database-style date such as:2026-08-18
///something user-friendly like:Tue, 18 Aug 2026
String formatAppointmentDate(String isoDate) {
  final date = DateTime.tryParse(isoDate);
  if (date == null) return isoDate;

  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  // DateTime.weekday is 1 for Monday through 7 for Sunday.
  return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} '
      '${date.year}';
}
///Used for the success popup.
class BookedAppointment {
  const BookedAppointment({
    required this.id,
    required this.serialNo,
    required this.date,
    required this.time,
    required this.visitType,
    this.doctorName,
    this.hospitalName,
  });

  final int id;
  /// The patient's place in that day's clinic.
  final int serialNo;
  /// Stored as yyyy-mm-dd.
  final String date;

  final String time;
  final String visitType;
  final String? doctorName;
  final String? hospitalName;
  ///converts the JSON received from the PHP API into a BookedAppointment Dart object.
  factory BookedAppointment.fromJson(Map<String, dynamic> json) {
    return BookedAppointment(
      id: int.tryParse('${json['appointment_id']}') ?? 0,
      serialNo: int.tryParse('${json['serial_no']}') ?? 0,
      date: (json['appointment_date'] as String?) ?? '',
      time: (json['appointment_time'] as String?) ?? '',
      visitType: (json['visit_type'] as String?) ?? '',
      doctorName: json['doctor_name'] as String?,
      hospitalName: json['hospital_name'] as String?,
    );
  }
}
///One row of the doctor's appointments list.
class DoctorAppointment {
  const DoctorAppointment({
    required this.id,
    required this.serialNo,
    required this.patientName,
    required this.visitType,
    required this.status,
    required this.date,
    required this.time,
    this.patientUid,
    this.age,
    this.gender,
    this.bloodGroup,
    this.contactName,
    this.contactMobile,
    this.hospitalName,
  });

  final int id;
  final int serialNo;

  ///The name on the patient's account, which is not always the name typed on
  ///the booking form - a patient can book for someone else.
  final String patientName;
  /// The business id, e.g. PAT00003.
  final String? patientUid;
  ///Null until the patient records a date of birth; there is nowhere to
  ///enter one yet, so this is normally null.
  final int? age;

  final String? gender;
  final String? bloodGroup;

  final String visitType;
  /// "Pending" until the doctor opens this list, then "Confirmed".
  final String status;

  final String date;
  final String time;

  final String? contactName;
  final String? contactMobile;
  final String? hospitalName;

  bool get isNew => status == 'Pending';

  factory DoctorAppointment.fromJson(Map<String, dynamic> json) {
    return DoctorAppointment(
      id: int.tryParse('${json['appointment_id']}') ?? 0,
      serialNo: int.tryParse('${json['serial_no']}') ?? 0,
      patientName: (json['patient_name'] as String?) ?? '',
      patientUid: json['patient_uid'] as String?,
      age: json['age'] == null ? null : int.tryParse('${json['age']}'),
      gender: json['gender'] as String?,
      bloodGroup: json['blood_group'] as String?,
      visitType: (json['visit_type'] as String?) ?? '',
      status: (json['status'] as String?) ?? '',
      date: (json['appointment_date'] as String?) ?? '',
      time: (json['appointment_time'] as String?) ?? '',
      contactName: json['contact_name'] as String?,
      contactMobile: json['contact_mobile'] as String?,
      hospitalName: json['hospital_name'] as String?,
    );
  }
}
