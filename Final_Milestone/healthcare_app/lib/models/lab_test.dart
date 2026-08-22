/// A lab test a patient can book.
///
/// Worth noting how this differs from a medicine, because the two look alike
/// on screen and are nothing alike underneath:
///
///   A medicine is NOT picked from a list. The doctor or patient types a brand
///   and it is read live off MedEx, because a local list could only ever limit
///   what may be prescribed or bought.
///
///   A lab test IS picked from a list. A diagnostic centre offers the tests it
///   offers at the prices it charges, and a test nobody offers is a test
///   nobody can book. So LAB_TEST is the app's own priced list, seeded the way
///   the health tips in ARTICLE are.
///
/// That is why there is no search here and no MedEx anywhere near it.
library;

import 'appointment.dart';
import 'order.dart';

class LabTest {
  const LabTest({required this.id, required this.name, this.price});

  final int id;

  /// As the centre lists it, e.g. "CBC (Complete Blood Count)" or
  /// "Urine for R/M/E". Kept exactly as written rather than tidied, since
  /// these are the names a patient will have been told to ask for.
  final String name;

  /// What it costs. Null would mean a row somebody left unpriced, which the
  /// screen shows as "Price on request" rather than as free.
  final double? price;

  bool get hasPrice => price != null && price! > 0;

  /// The price as it reads on the row.
  String get priceLine => hasPrice ? formatTaka(price!) : 'Price on request';

  factory LabTest.fromJson(Map<String, dynamic> json) {
    return LabTest(
      id: int.tryParse('${json['test_id']}') ?? 0,
      name: (json['test_name'] as String?) ?? '',
      // Sent as a string so the decimal arrives exactly as MySQL holds it.
      price: json['price'] == null
          ? null
          : double.tryParse('${json['price']}'),
    );
  }
}

/// A lab test booking, as it comes back from confirming one.
class LabBooking {
  const LabBooking({
    required this.id,
    required this.testId,
    required this.testName,
    required this.price,
    this.hospitalId,
    this.bookingDate,
    this.status = 'Booked',
  });

  final int id;
  final int testId;
  final String testName;

  /// What the centre charges, read from LAB_TEST on the server. The app never
  /// sends a price - it only quotes one back to the patient in the popup.
  final double price;

  final int? hospitalId;
  final String? bookingDate;
  final String status;

  String get priceLine => formatTaka(price);

  factory LabBooking.fromJson(Map<String, dynamic> json) {
    return LabBooking(
      id: int.tryParse('${json['lab_order_id']}') ?? 0,
      testId: int.tryParse('${json['test_id']}') ?? 0,
      testName: (json['test_name'] as String?) ?? '',
      price: double.tryParse('${json['price']}') ?? 0,
      hospitalId: json['hospital_id'] == null
          ? null
          : int.tryParse('${json['hospital_id']}'),
      bookingDate: json['booking_date'] as String?,
      status: (json['status'] as String?) ?? 'Booked',
    );
  }
}

/// One of the patient's lab bookings, as their notifications list shows it.
class LabBookingSummary {
  const LabBookingSummary({
    required this.id,
    required this.totalCost,
    required this.testCount,
    this.bookingDate,
    this.status = 'Booked',
    this.tests,
    this.hospitalName,
    this.area,
  });

  final int id;
  final double totalCost;
  final int testCount;
  final String? bookingDate;
  final String status;

  /// The tests that were booked, as one line.
  final String? tests;

  /// Where to turn up. Null only for a booking made before the hospital
  /// column existed, which is why it is not assumed to be there.
  final String? hospitalName;
  final String? area;

  String get totalLine => formatTaka(totalCost);

  String? get bookedOnLine =>
      bookingDate == null ? null : formatHistoryTimestamp(bookingDate!);

  /// "Popular Diagnostic Centre, Dhanmondi".
  String? get hospitalLine {
    if (hospitalName == null || hospitalName!.isEmpty) return null;

    return area == null || area!.isEmpty
        ? hospitalName
        : '$hospitalName, $area';
  }

  factory LabBookingSummary.fromJson(Map<String, dynamic> json) {
    return LabBookingSummary(
      id: int.tryParse('${json['lab_order_id']}') ?? 0,
      totalCost: double.tryParse('${json['total_cost']}') ?? 0,
      testCount: int.tryParse('${json['test_count']}') ?? 0,
      bookingDate: json['booking_date'] as String?,
      status: (json['status'] as String?) ?? 'Booked',
      tests: json['tests'] as String?,
      hospitalName: json['hospital_name'] as String?,
      area: json['area'] as String?,
    );
  }
}
