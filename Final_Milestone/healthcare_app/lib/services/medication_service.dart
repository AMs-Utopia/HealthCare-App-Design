import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../config/api_client.dart';

import '../config/api_config.dart';
import '../models/api_response.dart';
import '../models/medication.dart';
import '../models/patient_prescription.dart';

/// The patient's side of prescriptions and medication: everything a doctor has
/// put them on, and each medicine in detail.
class MedicationService {
  // Only static helpers, never instantiated.
  MedicationService._();

  /// Every prescription this patient has been given, newest first.
  ///
  /// This is the only route to a prescription that does not start from an
  /// order. Without it a patient could see a prescription only for a medicine
  /// they had already bought, which hid the courses they had been put on and
  /// never filled - the ones most worth showing them.
  static Future<PrescriptionListResult> fetchPrescriptions(
    int patientId,
  ) async {
    try {
      final uri = ApiConfig.endpoint(
        'prescriptions.php',
      ).replace(queryParameters: {'patient_id': '$patientId'});

      final response = await ApiClient.get(uri).timeout(ApiConfig.timeout);

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        return PrescriptionListResult.failure(
          'The server sent back something unexpected. Check the PHP error log.',
        );
      }

      final parsed = ApiResponse.fromJson(decoded);

      if (!parsed.success) {
        return PrescriptionListResult.failure(parsed.message);
      }

      final rows = parsed.data?['prescriptions'];

      // An empty list is a normal answer - a patient nobody has written up
      // yet - so it is a success carrying the server's own wording.
      return PrescriptionListResult.success(
        rows is List
            ? rows
                  .whereType<Map<String, dynamic>>()
                  .map(PatientPrescription.fromJson)
                  .toList()
            : const [],
        parsed.message,
        int.tryParse('${parsed.data?['unfilled_count']}') ?? 0,
      );
    } on SocketException {
      return PrescriptionListResult.failure(
        'Cannot reach the server at ${ApiConfig.baseUrl}.\n'
        'Check that Apache and MySQL are running in XAMPP.',
      );
    } on TimeoutException {
      return PrescriptionListResult.failure(
        'The server took too long to answer. Please try again.',
      );
    } on FormatException {
      return PrescriptionListResult.failure(
        'The server did not send valid JSON. Open the endpoint in a browser '
        'to see the PHP error.',
      );
    }
  }

  /// Everything known about one medicine for one patient.
  ///
  /// The reply carries both halves of what a medicine is - the prescription
  /// behind it and the orders that filled it - and either may be absent. That
  /// is a normal answer rather than an error, so a medicine bought without a
  /// prescription still loads, with [Medication.prescription] null.
  static Future<MedicationResult> fetch({
    required int patientId,
    required int medicineId,
  }) async {
    try {
      final uri = ApiConfig.endpoint('medication.php').replace(
        queryParameters: {
          'patient_id': '$patientId',
          'medicine_id': '$medicineId',
        },
      );

      final response = await ApiClient.get(uri).timeout(ApiConfig.timeout);

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        return MedicationResult.failure(
          'The server sent back something unexpected. Check the PHP error log.',
        );
      }

      final parsed = ApiResponse.fromJson(decoded);

      if (!parsed.success || parsed.data == null) {
        return MedicationResult.failure(parsed.message);
      }

      return MedicationResult.success(
        Medication.fromJson(parsed.data!),
        parsed.message,
      );
    } on SocketException {
      return MedicationResult.failure(
        'Cannot reach the server at ${ApiConfig.baseUrl}.\n'
        'Check that Apache and MySQL are running in XAMPP.',
      );
    } on TimeoutException {
      return MedicationResult.failure(
        'The server took too long to answer. Please try again.',
      );
    } on FormatException {
      return MedicationResult.failure(
        'The server did not send valid JSON. Open the endpoint in a browser '
        'to see the PHP error.',
      );
    }
  }

  /// The patient saying they have finished this medicine.
  ///
  /// Only the prescribed line is sent, never a dose count: the server sets it
  /// to nought and decides for itself whether that finishes the whole
  /// prescription. The patient's id travels with it and is what proves the
  /// prescription is theirs.
  static Future<ApiResponse> markCompleted({
    required int patientId,
    required int prescriptionItemId,
  }) async {
    try {
      final response = await ApiClient
          .post(
            ApiConfig.endpoint('complete_medication.php'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'patient_id': patientId,
              'prescription_item_id': prescriptionItemId,
            }),
          )
          .timeout(ApiConfig.timeout);

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        return const ApiResponse.failure(
          'The server sent back something unexpected. Check the PHP error log.',
        );
      }

      return ApiResponse.fromJson(decoded);
    } on SocketException {
      return ApiResponse.failure(
        'Cannot reach the server at ${ApiConfig.baseUrl}.\n'
        'Check that Apache and MySQL are running in XAMPP.',
      );
    } on TimeoutException {
      return const ApiResponse.failure(
        'The server took too long to answer. Please try again.',
      );
    } on FormatException {
      return const ApiResponse.failure(
        'The server did not send valid JSON. Open the endpoint in a browser '
        'to see the PHP error.',
      );
    }
  }
}

/// Either the patient's prescriptions, or why they could not be loaded.
class PrescriptionListResult {
  const PrescriptionListResult._(
    this.prescriptions,
    this.message,
    this.unfilledCount,
    this.error,
  );

  const PrescriptionListResult.success(
    List<PatientPrescription> prescriptions,
    String message,
    int unfilledCount,
  ) : this._(prescriptions, message, unfilledCount, null);

  const PrescriptionListResult.failure(String error)
    : this._(const [], '', 0, error);

  final List<PatientPrescription> prescriptions;
  final String message;

  /// Medicines prescribed and never bought, counted across all of them.
  final int unfilledCount;

  final String? error;

  bool get isSuccess => error == null;
}

/// Either one medicine's details, or why they could not be loaded.
class MedicationResult {
  const MedicationResult._(this.medication, this.message, this.error);

  const MedicationResult.success(Medication medication, String message)
    : this._(medication, message, null);

  const MedicationResult.failure(String error) : this._(null, '', error);

  final Medication? medication;
  final String message;
  final String? error;

  bool get isSuccess => error == null && medication != null;
}
