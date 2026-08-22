/// The doctor's EMR, as the app understands it.
///
/// The one idea these classes are built around:
///
///   A medical record is not something a doctor creates by filling a form in.
///   It comes into existence when a patient books, holding nothing but their
///   account details, and it gains its contents when the doctor writes up what
///   happened at each visit. So the record IS the list of visits, and the four
///   sections the wireframe asks for - medical history, diagnosis,
///   prescription, treatment records - are four readings of that one list.
///
/// That is why [EmrVisit] carries its own [record] and [prescription] rather
/// than the four sections being four separate lists: a visit with nothing
/// written against it is the "first visit" state, and the same visit read
/// again after the doctor has written it up is the "second visit" state, with
/// no separate object to keep in step.
library;

import '../config/api_config.dart';
import 'appointment.dart';
import 'patient_profile.dart';

/// One row of the list the doctor picks a patient from.
///
/// This list replaces the wireframe's Patient Name and Patient UID boxes. The
/// doctor is shown the patients who have actually booked them instead of being
/// asked to type an identity in, so a record cannot be opened by guessing a
/// UID and cannot be missed because a name was typed differently from the way
/// the account spells it.
class EmrPatient {
  const EmrPatient({
    required this.id,
    required this.fullName,
    required this.visitsWithMe,
    required this.recordedByMe,
    this.patientUid,
    this.age,
    this.gender,
    this.bloodGroup,
    this.profileImage,
    this.firstVisitDate,
    this.lastVisitDate,
  });

  final int id;
  final String fullName;

  /// The business id, e.g. PAT00006.
  final String? patientUid;

  /// Worked out by MySQL from the date of birth, so it is null for a patient
  /// who has never filled their Basic Info in.
  final int? age;

  final String? gender;
  final String? bloodGroup;

  /// File name only, the same as everywhere else in the app.
  final String? profileImage;

  /// Visits booked with THIS doctor, cancelled ones left out.
  final int visitsWithMe;

  /// How many of this patient's visits this doctor has written up.
  final int recordedByMe;

  final String? firstVisitDate;
  final String? lastVisitDate;

  /// True while the patient has never been seen twice by this doctor. Their
  /// record is still only their account details, which is exactly what a first
  /// visit is.
  bool get isFirstVisit => visitsWithMe <= 1;

  /// True once there is something in the record to read.
  bool get hasWrittenRecords => recordedByMe > 0;

  /// Visits this doctor has not written up yet.
  int get awaitingRecord {
    final left = visitsWithMe - recordedByMe;
    return left < 0 ? 0 : left;
  }

  /// Built here rather than stored, the same as everywhere else: the column
  /// holds only the file name so one row works on the emulator and the phone.
  Uri? get photoUrl => profileImage == null || profileImage!.isEmpty
      ? null
      : ApiConfig.uploadUrl(profileImage!);

  /// The line under the name: their UID, then how they are known medically.
  String get identityLine {
    final parts = <String>[
      if (patientUid != null && patientUid!.isNotEmpty) patientUid!,
      age == null ? 'Age not set' : '$age yrs',
      if (gender != null && gender!.isNotEmpty) gender!,
      if (bloodGroup != null && bloodGroup!.isNotEmpty) bloodGroup!,
    ];

    return parts.join('  ·  ');
  }

  factory EmrPatient.fromJson(Map<String, dynamic> json) {
    return EmrPatient(
      id: int.tryParse('${json['patient_id']}') ?? 0,
      fullName: (json['full_name'] as String?) ?? '',
      patientUid: json['patient_uid'] as String?,
      age: json['age'] == null ? null : int.tryParse('${json['age']}'),
      gender: json['gender'] as String?,
      bloodGroup: json['blood_group'] as String?,
      profileImage: json['profile_image'] as String?,
      visitsWithMe: int.tryParse('${json['visits_with_me']}') ?? 0,
      recordedByMe: int.tryParse('${json['recorded_by_me']}') ?? 0,
      firstVisitDate: json['first_visit_date'] as String?,
      lastVisitDate: json['last_visit_date'] as String?,
    );
  }
}

/// What the doctor wrote up after one visit - one row of MEDICAL_RECORD.
class VisitRecord {
  const VisitRecord({
    required this.id,
    required this.doctorId,
    this.diagnosis,
    this.treatmentPlan,
    this.notes,
    this.visitDate,
    this.doctorName,
  });

  final int id;
  final int doctorId;

  /// What the doctor concluded. Never empty on a saved record - the API
  /// refuses to save one without it, because a record with no diagnosis is not
  /// a record of anything.
  final String? diagnosis;

  /// How it is being treated.
  final String? treatmentPlan;

  /// Anything else worth keeping: symptoms, what the patient reported.
  final String? notes;

  final String? visitDate;
  final String? doctorName;

  bool get hasDiagnosis => diagnosis != null && diagnosis!.trim().isNotEmpty;

  bool get hasTreatment =>
      (treatmentPlan != null && treatmentPlan!.trim().isNotEmpty) ||
      (notes != null && notes!.trim().isNotEmpty);

  factory VisitRecord.fromJson(Map<String, dynamic> json) {
    return VisitRecord(
      id: int.tryParse('${json['medical_record_id']}') ?? 0,
      doctorId: int.tryParse('${json['doctor_id']}') ?? 0,
      diagnosis: json['diagnosis'] as String?,
      treatmentPlan: json['treatment_plan'] as String?,
      notes: json['notes'] as String?,
      visitDate: json['visit_date'] as String?,
      doctorName: json['doctor_name'] as String?,
    );
  }
}

/// One medicine on a prescription.
class PrescribedMedicine {
  const PrescribedMedicine({
    required this.medicineId,
    required this.medicineName,
    required this.dosageInstruction,
    this.dosage,
    this.remainingDoses,
  });

  final int medicineId;
  final String medicineName;

  /// The strength the medicine comes in, e.g. "20 mg capsule".
  final String? dosage;

  /// How to take it, e.g. "1+0+1 after meals".
  final String dosageInstruction;

  /// How many doses were prescribed. Null when the doctor did not say.
  final int? remainingDoses;

  /// The name as a pharmacist would read it.
  String get nameLine => dosage == null || dosage!.isEmpty
      ? medicineName
      : '$medicineName  $dosage';

  factory PrescribedMedicine.fromJson(Map<String, dynamic> json) {
    return PrescribedMedicine(
      medicineId: int.tryParse('${json['medicine_id']}') ?? 0,
      medicineName: (json['medicine_name'] as String?) ?? '',
      dosage: json['dosage'] as String?,
      dosageInstruction: (json['dosage_instruction'] as String?) ?? '',
      remainingDoses: json['remaining_doses'] == null
          ? null
          : int.tryParse('${json['remaining_doses']}'),
    );
  }
}

/// The prescription written at one visit.
class VisitPrescription {
  const VisitPrescription({
    required this.id,
    required this.items,
    this.prescribedDate,
    this.status,
    this.doctorName,
  });

  final int id;
  final List<PrescribedMedicine> items;
  final String? prescribedDate;
  final String? status;
  final String? doctorName;

  bool get isEmpty => items.isEmpty;

  factory VisitPrescription.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];

    return VisitPrescription(
      id: int.tryParse('${json['prescription_id']}') ?? 0,
      items: rawItems is List
          ? rawItems
                .whereType<Map<String, dynamic>>()
                .map(PrescribedMedicine.fromJson)
                .toList()
          : const [],
      prescribedDate: json['prescribed_date'] as String?,
      status: json['status'] as String?,
      doctorName: json['doctor_name'] as String?,
    );
  }
}

/// One visit, with whatever came out of it.
///
/// [record] and [prescription] are null until the doctor writes the visit up.
/// A visit in that state is not an error or a missing row - it is a visit that
/// has not happened yet, or one the doctor has still to fill in.
class EmrVisit {
  const EmrVisit({
    required this.appointmentId,
    required this.date,
    required this.time,
    required this.visitType,
    required this.status,
    required this.doctorId,
    required this.doctorName,
    required this.serialNo,
    required this.isMine,
    required this.canRecord,
    this.visitNo,
    this.departmentName,
    this.hospitalName,
    this.area,
    this.record,
    this.prescription,
  });

  final int appointmentId;

  /// The patient's nth visit to the doctor reading the record, counting from
  /// their first. Null on a cancelled visit and on another doctor's visit,
  /// neither of which is a visit to this doctor.
  final int? visitNo;

  /// Stored as yyyy-mm-dd.
  final String date;
  final String time;
  final String visitType;
  final String status;

  final int doctorId;
  final String doctorName;
  final String? departmentName;
  final String? hospitalName;
  final String? area;
  final int serialNo;

  /// True when this visit was booked with the doctor reading the record.
  final bool isMine;

  /// True when this doctor may write this visit up: theirs, and not cancelled.
  final bool canRecord;

  final VisitRecord? record;
  final VisitPrescription? prescription;

  bool get isCancelled => status == 'Cancelled';

  bool get isRecorded => record != null;

  bool get hasDiagnosis => record?.hasDiagnosis ?? false;

  bool get hasTreatment => record?.hasTreatment ?? false;

  bool get hasPrescription =>
      prescription != null && prescription!.items.isNotEmpty;

  /// A visit of this doctor's that is still waiting to be written up. This is
  /// what the Record button on the EMR screen acts on.
  bool get awaitingRecord => canRecord && !isRecorded;

  String get dateLine => formatAppointmentDate(date);

  /// Where the visit happened, as one line.
  String get placeLine {
    final parts = <String>[
      if (hospitalName != null && hospitalName!.isNotEmpty) hospitalName!,
      if (area != null && area!.isNotEmpty) area!,
    ];

    return parts.join(', ');
  }

  /// Who saw the patient, with their department when there is one.
  String get doctorLine => departmentName == null || departmentName!.isEmpty
      ? 'Dr. $doctorName'
      : 'Dr. $doctorName  ·  $departmentName';

  factory EmrVisit.fromJson(Map<String, dynamic> json) {
    final rawRecord = json['record'];
    final rawPrescription = json['prescription'];

    return EmrVisit(
      appointmentId: int.tryParse('${json['appointment_id']}') ?? 0,
      visitNo: json['visit_no'] == null
          ? null
          : int.tryParse('${json['visit_no']}'),
      date: (json['appointment_date'] as String?) ?? '',
      time: (json['appointment_time'] as String?) ?? '',
      visitType: (json['visit_type'] as String?) ?? '',
      status: (json['status'] as String?) ?? '',
      doctorId: int.tryParse('${json['doctor_id']}') ?? 0,
      doctorName: (json['doctor_name'] as String?) ?? '',
      departmentName: json['department_name'] as String?,
      hospitalName: json['hospital_name'] as String?,
      area: json['area'] as String?,
      serialNo: int.tryParse('${json['serial_no']}') ?? 0,
      // MySQL sends its booleans back as 0 and 1.
      isMine: '${json['is_mine']}' == '1',
      canRecord: '${json['can_record']}' == '1',
      record: rawRecord is Map<String, dynamic>
          ? VisitRecord.fromJson(rawRecord)
          : null,
      prescription: rawPrescription is Map<String, dynamic>
          ? VisitPrescription.fromJson(rawPrescription)
          : null,
    );
  }
}

/// The counts printed at the top of the EMR screen.
class EmrSummary {
  const EmrSummary({
    required this.totalVisits,
    required this.visitsWithMe,
    required this.recordedVisits,
    required this.isNewRecord,
    this.firstVisitDate,
    this.lastVisitDate,
  });

  /// Every visit the patient has had, this doctor's and everyone else's.
  final int totalVisits;

  /// Visits with the doctor reading the record, cancelled ones left out.
  final int visitsWithMe;

  /// Visits, by any doctor, that have been written up.
  final int recordedVisits;

  /// True while the record holds nothing but the patient's account details.
  final bool isNewRecord;

  final String? firstVisitDate;
  final String? lastVisitDate;

  factory EmrSummary.fromJson(Map<String, dynamic> json) {
    return EmrSummary(
      totalVisits: int.tryParse('${json['total_visits']}') ?? 0,
      visitsWithMe: int.tryParse('${json['visits_with_me']}') ?? 0,
      recordedVisits: int.tryParse('${json['recorded_visits']}') ?? 0,
      isNewRecord: '${json['is_new_record']}' == '1',
      firstVisitDate: json['first_visit_date'] as String?,
      lastVisitDate: json['last_visit_date'] as String?,
    );
  }
}

/// One patient's whole record.
class EmrDetails {
  const EmrDetails({
    required this.patient,
    required this.summary,
    required this.visits,
  });

  /// The header of the wireframe - name, UID and the rest - read from the
  /// PATIENT row rather than typed in, so it is right by construction.
  final PatientProfile patient;

  final EmrSummary summary;

  /// Newest visit first.
  final List<EmrVisit> visits;

  /// Section 1 of the wireframe. Every visit the patient has had, including
  /// visits to other doctors: a history that only showed this doctor their own
  /// work would tell them nothing they did not already know.
  List<EmrVisit> get medicalHistory => visits;

  /// Section 2. Visits with a diagnosis written against them.
  List<EmrVisit> get diagnoses =>
      visits.where((visit) => visit.hasDiagnosis).toList();

  /// Section 3. Visits a prescription came out of.
  List<EmrVisit> get prescriptions =>
      visits.where((visit) => visit.hasPrescription).toList();

  /// Section 4. Visits with a treatment plan or notes.
  List<EmrVisit> get treatments =>
      visits.where((visit) => visit.hasTreatment).toList();

  /// This doctor's visits, which are the only ones they may write up.
  List<EmrVisit> get myVisits =>
      visits.where((visit) => visit.isMine).toList();

  /// The visit the Record button acts on: the most recent one of this doctor's
  /// that has nothing written against it yet.
  EmrVisit? get visitAwaitingRecord {
    for (final visit in visits) {
      if (visit.awaitingRecord) return visit;
    }
    return null;
  }

  factory EmrDetails.fromJson(Map<String, dynamic> json) {
    final rawVisits = json['visits'];
    final rawPatient = json['patient'];
    final rawSummary = json['summary'];

    return EmrDetails(
      patient: rawPatient is Map<String, dynamic>
          ? PatientProfile.fromJson(rawPatient)
          : const PatientProfile(id: 0, fullName: '', phone: ''),
      summary: rawSummary is Map<String, dynamic>
          ? EmrSummary.fromJson(rawSummary)
          : const EmrSummary(
              totalVisits: 0,
              visitsWithMe: 0,
              recordedVisits: 0,
              isNewRecord: true,
            ),
      visits: rawVisits is List
          ? rawVisits
                .whereType<Map<String, dynamic>>()
                .map(EmrVisit.fromJson)
                .toList()
          : const [],
    );
  }
}

/// One brand the doctor can prescribe.
///
/// These come from MedEx as the doctor types, not from a list held here: a
/// doctor prescribes the brand they have in mind, and a local list could only
/// ever offer what somebody put into it.
///
/// [id] is therefore usually 0. It is the id of the row in our own MEDICINE
/// table, and a brand nobody here has prescribed before does not have one yet
/// - the server gives it one when the prescription is saved. A brand that came
/// back off a saved prescription, or out of the offline fallback, does carry
/// an id, and sending it back saves looking the brand up again.
class MedicineOption {
  const MedicineOption({
    required this.name,
    this.id = 0,
    this.medexId,
    this.strength,
    this.form,
    this.dosage,
    this.price,
    this.source = 'medex',
  });

  /// Our own MEDICINE.medicine_id, or 0 when this brand has never been
  /// prescribed through this app.
  final int id;

  /// MedEx's own id for the brand. Kept for the record; nothing depends on it.
  final int? medexId;

  /// The brand name on its own, e.g. "Rosuva".
  final String name;

  /// e.g. "10 mg".
  final String? strength;

  /// The dosage form, e.g. "Tablet" or "Gel". It matters as much as the
  /// strength - a 10 mg gel is not a 10 mg tablet.
  final String? form;

  /// Strength and form together, which is what MEDICINE.dosage holds.
  final String? dosage;

  final String? price;

  /// 'medex' for a live result, 'local' for one from the offline fallback.
  final String source;

  /// How the brand reads in the suggestion list and on a written line.
  String get label =>
      dosage == null || dosage!.isEmpty ? name : '$name  $dosage';

  factory MedicineOption.fromJson(Map<String, dynamic> json) {
    return MedicineOption(
      id: int.tryParse('${json['medicine_id']}') ?? 0,
      medexId: json['medex_id'] == null
          ? null
          : int.tryParse('${json['medex_id']}'),
      name: (json['medicine_name'] as String?) ?? '',
      strength: json['strength'] as String?,
      form: json['form'] as String?,
      dosage: json['dosage'] as String?,
      price: json['price'] as String?,
      source: (json['source'] as String?) ?? 'medex',
    );
  }

  /// The brand behind a line that was already saved, so a write up being
  /// corrected opens with its medicines already filled in and does not have to
  /// be searched for again.
  factory MedicineOption.fromPrescribed(PrescribedMedicine prescribed) {
    return MedicineOption(
      id: prescribed.medicineId,
      name: prescribed.medicineName,
      dosage: prescribed.dosage,
      source: 'local',
    );
  }
}

/// One line of the prescription while the doctor is still writing it.
///
/// Kept apart from [PrescribedMedicine], which is a saved line: this one holds
/// a medicine that may not have been chosen yet, which is what an empty row on
/// the form is.
class PrescriptionDraft {
  PrescriptionDraft({this.medicine, this.instruction = '', this.doses});

  MedicineOption? medicine;
  String instruction;
  int? doses;

  bool get isBlank =>
      medicine == null && instruction.trim().isEmpty && doses == null;

  /// What the API takes.
  ///
  /// The brand is sent by name and strength rather than only by id, because a
  /// brand just picked off MedEx has no id here yet - the server creates the
  /// MEDICINE row for it as the prescription is saved. The id goes along too
  /// when there is one, which is what a line that was already saved carries.
  Map<String, dynamic> toJson() => {
    'medicine_id': medicine?.id ?? 0,
    'medicine_name': medicine?.name ?? '',
    'dosage': medicine?.dosage ?? '',
    'dosage_instruction': instruction.trim(),
    'remaining_doses': doses,
  };
}
