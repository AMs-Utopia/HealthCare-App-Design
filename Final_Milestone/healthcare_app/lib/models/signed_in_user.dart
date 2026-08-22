///Identifies whether the logged-in account belongs to a patient or doctor. Which table the signed in account came from.
enum SignedInAccountType { patient, doctor }

/// The account that signed in on screen 1.
/// PATIENT and DOCTOR have no shared users table, so this holds the fields
/// both have plus the ones only one of them has.
class SignedInUser {
  const SignedInUser({
    required this.accountType,
    required this.id,
    required this.fullName,
    required this.phone,
    this.token = '',
    this.patientUid,
    this.licenseNo,
    this.departmentName,
  });

  /// Proof that this account's password was checked, issued by `login.php`.
  ///
  /// Every later request carries it, and the server reads the account out of
  /// the token rather than out of the request - which is what stops one signed
  /// in patient from asking for another patient's records by changing a number.
  /// It is handed straight to [ApiClient] on sign in and read from there after;
  /// nothing else in the app needs to touch it.
  final String token;

  final SignedInAccountType accountType;
  /// patient_id or doctor_id, depending on accountType.
  final int id;
  final String fullName;
  final String phone;
  /// Patients only, e.g. PAT00001.
  final String? patientUid;
  /// Doctors only.
  final String? licenseNo;
  final String? departmentName;

  bool get isPatient => accountType == SignedInAccountType.patient;

  ///This creates the name shown in the dashboard/drawer., e.g. "Dr. Ashfaq".
  String get displayName => isPatient ? fullName : 'Dr. $fullName';
  ///The second line under the name in the drawer: the patient's UID, or the
  ///doctor's department, falling back to the phone number.
  String get accountSubtitle => patientUid ?? departmentName ?? phone;

  factory SignedInUser.fromJson(Map<String, dynamic> json) {
    final isDoctor = json['account_type'] == 'doctor';
    return SignedInUser(
      accountType: isDoctor
          ? SignedInAccountType.doctor
          : SignedInAccountType.patient,
      id: int.tryParse(
            '${isDoctor ? json['doctor_id'] : json['patient_id']}',
          ) ??
          0,
      fullName: (json['full_name'] as String?) ?? '',
      phone: (json['phone'] as String?) ?? '',
      token: (json['token'] as String?) ?? '',
      patientUid: json['patient_uid'] as String?,
      licenseNo: json['license_no'] as String?,
      departmentName: json['department_name'] as String?,
    );
  }
}