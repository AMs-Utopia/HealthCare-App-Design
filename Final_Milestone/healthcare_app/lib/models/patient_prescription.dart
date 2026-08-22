/// The patient's own view of what they have been prescribed.
///
/// Kept apart from the doctor's classes in emr.dart on purpose. The doctor
/// reads a prescription as one outcome of a visit they wrote up; the patient
/// reads it as "what am I supposed to be taking, and have I got it yet". Those
/// are different questions, and folding them into one class would mean every
/// screen carrying fields meant for the other one.
library;

import 'appointment.dart';
import 'order.dart';

/// One medicine on a prescription, as the patient sees it in the list.
class PrescribedItem {
  const PrescribedItem({
    required this.prescriptionItemId,
    required this.medicineId,
    required this.name,
    required this.timesOrdered,
    this.dosage,
    this.price,
    this.dosageInstruction,
    this.remainingDoses,
  });

  final int prescriptionItemId;
  final int medicineId;
  final String name;

  /// Strength and dosage form together, e.g. "500 mg tablet". Also where the
  /// unit word comes from - three of a tablet is three tablets.
  final String? dosage;

  final double? price;

  /// How to take it, in the doctor's own words.
  final String? dosageInstruction;

  /// Null when the doctor never said how many, which is not the same as none
  /// left and must not read the same.
  final int? remainingDoses;

  /// How many times this patient has actually bought this medicine.
  ///
  /// Zero is the interesting case: a medicine that was prescribed and never
  /// filled. Before this screen existed the patient had no way of noticing
  /// one, because every route to a prescription started from an order.
  final int timesOrdered;

  /// True for a course the patient has been put on and has not bought.
  bool get isUnfilled => timesOrdered == 0;

  bool get isFinished => remainingDoses != null && remainingDoses! <= 0;

  /// "3 tablets left", or null when there is no count to give.
  String? get remainingLine {
    final left = remainingDoses;

    if (left == null) return null;
    if (left <= 0) return 'None left';

    final noun = unitNoun(dosage, left);

    return noun == null ? '$left left' : '$left $noun left';
  }

  factory PrescribedItem.fromJson(Map<String, dynamic> json) {
    return PrescribedItem(
      prescriptionItemId:
          int.tryParse('${json['prescription_item_id']}') ?? 0,
      medicineId: int.tryParse('${json['medicine_id']}') ?? 0,
      name: (json['medicine_name'] as String?) ?? '',
      dosage: json['dosage'] as String?,
      price: json['price'] == null
          ? null
          : double.tryParse('${json['price']}'),
      dosageInstruction: json['dosage_instruction'] as String?,
      remainingDoses: json['remaining_doses'] == null
          ? null
          : int.tryParse('${json['remaining_doses']}'),
      timesOrdered: int.tryParse('${json['times_ordered']}') ?? 0,
    );
  }
}

/// One prescription: the visit it came out of, and the medicines on it.
class PatientPrescription {
  const PatientPrescription({
    required this.id,
    required this.doctorName,
    required this.status,
    required this.items,
    this.departmentName,
    this.prescribedDate,
    this.diagnosis,
  });

  final int id;
  final String doctorName;

  /// 'Active' or 'Completed'.
  final String status;

  final String? departmentName;
  final String? prescribedDate;

  /// What the doctor was treating, from the write up of the same visit. A
  /// prescription on its own says what to take and never says what for.
  final String? diagnosis;

  final List<PrescribedItem> items;

  String get doctorDisplayName => 'Dr. $doctorName';

  bool get isCompleted => status == 'Completed';

  String? get prescribedOnLine =>
      prescribedDate == null ? null : formatAppointmentDate(prescribedDate!);

  /// The doctor's speciality and the date, on one line under their name.
  String get visitLine => [
    if (departmentName != null && departmentName!.isNotEmpty) departmentName!,
    ?prescribedOnLine,
  ].join('  ·  ');

  /// How many medicines on this prescription have never been bought.
  int get unfilledCount => items.where((item) => item.isUnfilled).length;

  factory PatientPrescription.fromJson(Map<String, dynamic> json) {
    final rows = json['items'];

    return PatientPrescription(
      id: int.tryParse('${json['prescription_id']}') ?? 0,
      doctorName: (json['doctor_name'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'Active',
      departmentName: json['department_name'] as String?,
      prescribedDate: json['prescribed_date'] as String?,
      diagnosis: json['diagnosis'] as String?,
      items: rows is List
          ? rows
                .whereType<Map<String, dynamic>>()
                .map(PrescribedItem.fromJson)
                .toList()
          : const [],
    );
  }
}
