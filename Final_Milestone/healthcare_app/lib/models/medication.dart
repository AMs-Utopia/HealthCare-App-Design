/// One medicine, as the patient taking it needs to see it.
///
/// The idea these classes are built around:
///
///   A medicine a patient holds has two histories that know nothing about each
///   other. A doctor prescribed it - PRESCRIPTION and PRESCRIPTION_ITEM,
///   written by the EMR write up screen. The patient bought it - ORDER_HEADER
///   and ORDER_ITEM, written by the order screen. The only thing the two share
///   is MEDICINE.medicine_id.
///
/// [Medication] is those two brought together, and either half may be missing.
/// That is why [prescription] is nullable rather than the screen assuming a
/// doctor is behind every box: a patient can buy a medicine over the counter,
/// and showing them a dosage instruction nobody wrote would be worse than
/// showing none.
library;

import 'appointment.dart';
import 'order.dart';

/// What a doctor put this patient on, if anyone did.
class MedicationPrescription {
  const MedicationPrescription({
    required this.prescriptionItemId,
    required this.prescriptionId,
    required this.doctorName,
    required this.status,
    this.dosageInstruction,
    this.remainingDoses,
    this.prescribedDate,
    this.departmentName,
  });

  /// The line this screen is about - one medicine on one prescription. This is
  /// what Completed acts on, not the whole prescription.
  final int prescriptionItemId;

  final int prescriptionId;

  /// The doctor's name as the DOCTOR table holds it, without the title.
  final String doctorName;

  /// 'Active' or 'Completed', on the prescription as a whole.
  final String status;

  /// How to take it, e.g. "1-0-1 after meal". Written by the doctor in their
  /// own words rather than picked from a list, so it is shown exactly as they
  /// typed it.
  final String? dosageInstruction;

  /// How many are left to take. Null when the doctor never said how many,
  /// which is NOT the same as none left - so it is kept apart from 0.
  final int? remainingDoses;

  final String? prescribedDate;
  final String? departmentName;

  /// The name with the title on, which is how a patient reads it.
  String get doctorDisplayName => 'Dr. $doctorName';

  bool get isCompleted => status == 'Completed';

  /// True once the doctor's count has run out.
  bool get isFinished => remainingDoses != null && remainingDoses! <= 0;

  /// True when the doctor did not say how many, so no count can be shown.
  bool get hasNoDoseCount => remainingDoses == null;

  /// "on Sat, 22 Aug 2026", or null when the date is missing.
  String? get prescribedOnLine =>
      prescribedDate == null ? null : formatAppointmentDate(prescribedDate!);

  /// The doctor and their speciality on one line.
  String get prescriberLine => departmentName == null || departmentName!.isEmpty
      ? doctorDisplayName
      : '$doctorDisplayName  ·  $departmentName';

  factory MedicationPrescription.fromJson(Map<String, dynamic> json) {
    return MedicationPrescription(
      prescriptionItemId:
          int.tryParse('${json['prescription_item_id']}') ?? 0,
      prescriptionId: int.tryParse('${json['prescription_id']}') ?? 0,
      doctorName: (json['doctor_name'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'Active',
      dosageInstruction: json['dosage_instruction'] as String?,
      remainingDoses: json['remaining_doses'] == null
          ? null
          : int.tryParse('${json['remaining_doses']}'),
      prescribedDate: json['prescribed_date'] as String?,
      departmentName: json['department_name'] as String?,
    );
  }
}

/// One time this patient bought this medicine.
class RefillRecord {
  const RefillRecord({
    required this.orderId,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    this.orderDate,
    this.status = 'Placed',
  });

  final int orderId;
  final int quantity;

  /// What it cost that day, off the ORDER_ITEM row - not what it costs now.
  /// The whole point of storing it on the line is that a patient can see the
  /// same medicine cost them differently in June and in August.
  final double unitPrice;

  final double lineTotal;
  final String? orderDate;
  final String status;

  String get totalLine => formatTaka(lineTotal);

  String? get boughtOnLine =>
      orderDate == null ? null : formatHistoryTimestamp(orderDate!);

  /// "10 capsules", worded from the medicine's own dosage form.
  String quantityLine(String? dosage) {
    final noun = unitNoun(dosage, quantity);

    return noun == null ? 'x $quantity' : '$quantity $noun';
  }

  factory RefillRecord.fromJson(Map<String, dynamic> json) {
    return RefillRecord(
      orderId: int.tryParse('${json['order_id']}') ?? 0,
      quantity: int.tryParse('${json['quantity']}') ?? 0,
      unitPrice: double.tryParse('${json['unit_price']}') ?? 0,
      lineTotal: double.tryParse('${json['line_total']}') ?? 0,
      orderDate: json['order_date'] as String?,
      status: (json['status'] as String?) ?? 'Placed',
    );
  }
}

/// Everything known about one medicine for one patient.
class Medication {
  const Medication({
    required this.medicineId,
    required this.name,
    required this.canComplete,
    required this.refills,
    this.dosage,
    this.price,
    this.prescription,
  });

  final int medicineId;
  final String name;

  /// Strength and dosage form together, e.g. "200 mg Capsule (Sustained
  /// Release)". This is also where the unit word on screen comes from - ten of
  /// a capsule is ten capsules, ten of a cream is ten tubes.
  final String? dosage;

  /// What one costs today, for the Refill button. Null when nobody has ever
  /// looked a price up for this brand, which is the normal state of a medicine
  /// that was prescribed but never ordered.
  final double? price;

  /// Null when no doctor here has prescribed this. An ordinary answer, not a
  /// fault - medicine can be bought without a prescription.
  final MedicationPrescription? prescription;

  /// Every time it has been bought, newest first.
  final List<RefillRecord> refills;

  /// Whether there is anything left to mark completed. Decided by the server,
  /// so the button and the endpoint behind it cannot disagree.
  final bool canComplete;

  bool get isPrescribed => prescription != null;

  bool get hasRefills => refills.isNotEmpty;

  /// How the medicine reads as a heading.
  String get label => dosage == null || dosage!.isEmpty ? name : dosage!;

  /// "3 tablets", "12 capsules" - the remaining doses in the medicine's own
  /// units, which is exactly how the wireframe writes it. Null when there is
  /// no prescription or the doctor never gave a count.
  String? get remainingDosesLine {
    final left = prescription?.remainingDoses;

    if (left == null) return null;

    final noun = unitNoun(dosage, left);

    return noun == null ? '$left left' : '$left $noun';
  }

  factory Medication.fromJson(Map<String, dynamic> json) {
    final medicine = json['medicine'];
    final prescription = json['prescription'];
    final refills = json['refills'];

    final medicineMap = medicine is Map<String, dynamic>
        ? medicine
        : const <String, dynamic>{};

    return Medication(
      medicineId: int.tryParse('${medicineMap['medicine_id']}') ?? 0,
      name: (medicineMap['medicine_name'] as String?) ?? '',
      dosage: medicineMap['dosage'] as String?,
      price: medicineMap['price'] == null
          ? null
          : double.tryParse('${medicineMap['price']}'),
      prescription: prescription is Map<String, dynamic>
          ? MedicationPrescription.fromJson(prescription)
          : null,
      refills: refills is List
          ? refills
                .whereType<Map<String, dynamic>>()
                .map(RefillRecord.fromJson)
                .toList()
          : const [],
      canComplete: '${json['can_complete']}' == '1',
    );
  }
}
