import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../config/api_client.dart';

import '../config/api_config.dart';
import '../models/api_response.dart';
import '../models/emr.dart';

/// All EMR calls to the PHP API - the doctor's patients, one patient's record,
/// and writing a visit up.
///
/// Note what is NOT here: there is no "find a patient by name" and no "find a
/// patient by UID". A doctor reaches a record through the patients who have
/// booked them, so every call carries the doctor's own id and the API checks it
/// against the APPOINTMENT table. A screen that could look a patient up by
/// typed identity would be able to open the record of someone the doctor has
/// never treated.
class EmrService {
  // Only static helpers, never instantiated.
  EmrService._();

  /// The patients this doctor may open a record for.
  ///
  /// [search] narrows that same list by name or UID. It is sent to the server
  /// rather than filtered here so a long list does not have to be downloaded
  /// whole on a phone.
  static Future<EmrPatientsResult> fetchPatients(
    int doctorId, {
    String search = '',
  }) async {
    try {
      final uri = ApiConfig.endpoint('emr_patients.php').replace(
        queryParameters: {
          'doctor_id': '$doctorId',
          if (search.trim().isNotEmpty) 'q': search.trim(),
        },
      );

      final response = await ApiClient.get(uri).timeout(ApiConfig.timeout);

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        return EmrPatientsResult.failure(
          'The server sent back something unexpected. Check the PHP error log.',
        );
      }

      final parsed = ApiResponse.fromJson(decoded);

      if (!parsed.success) {
        return EmrPatientsResult.failure(parsed.message);
      }

      final rows = decoded['data'];

      // An empty list is a normal answer - a doctor nobody has booked, or a
      // search that matched none of their patients - so it is a success with
      // the server's own wording rather than an error.
      return EmrPatientsResult.success(
        rows is List
            ? rows
                  .whereType<Map<String, dynamic>>()
                  .map(EmrPatient.fromJson)
                  .toList()
            : const [],
        parsed.message,
      );
    } on SocketException {
      return EmrPatientsResult.failure(
        'Cannot reach the server at ${ApiConfig.baseUrl}.\n'
        'Check that Apache and MySQL are running in XAMPP.',
      );
    } on TimeoutException {
      return EmrPatientsResult.failure(
        'The server took too long to answer. Please try again.',
      );
    } on FormatException {
      return EmrPatientsResult.failure(
        'The server did not send valid JSON. Open the endpoint in a browser '
        'to see the PHP error.',
      );
    }
  }

  /// One patient's whole record: their account details, every visit, and
  /// whatever each visit left behind.
  ///
  /// The doctor's id travels with the request because the API will only hand
  /// back the record of a patient who has booked this doctor.
  static Future<EmrDetailsResult> fetchDetails({
    required int doctorId,
    required int patientId,
  }) async {
    try {
      final uri = ApiConfig.endpoint('emr_details.php').replace(
        queryParameters: {
          'doctor_id': '$doctorId',
          'patient_id': '$patientId',
        },
      );

      final response = await ApiClient.get(uri).timeout(ApiConfig.timeout);

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        return EmrDetailsResult.failure(
          'The server sent back something unexpected. Check the PHP error log.',
        );
      }

      final parsed = ApiResponse.fromJson(decoded);

      if (!parsed.success || parsed.data == null) {
        return EmrDetailsResult.failure(parsed.message);
      }

      return EmrDetailsResult.success(
        EmrDetails.fromJson(parsed.data!),
        parsed.message,
      );
    } on SocketException {
      return EmrDetailsResult.failure(
        'Cannot reach the server at ${ApiConfig.baseUrl}.\n'
        'Check that Apache and MySQL are running in XAMPP.',
      );
    } on TimeoutException {
      return EmrDetailsResult.failure(
        'The server took too long to answer. Please try again.',
      );
    } on FormatException {
      return EmrDetailsResult.failure(
        'The server did not send valid JSON. Open the endpoint in a browser '
        'to see the PHP error.',
      );
    }
  }

  /// The doctor writing one visit up - the step that fills the record in.
  ///
  /// Only the visit is sent, never the patient or the date: the API reads both
  /// from the appointment, which is also how it proves the visit belongs to
  /// this doctor. Sending the same visit again corrects it rather than adding
  /// a second write up of the same consultation.
  static Future<ApiResponse> saveVisitRecord({
    required int doctorId,
    required int appointmentId,
    required String diagnosis,
    String treatmentPlan = '',
    String notes = '',
    List<PrescriptionDraft> medicines = const [],
  }) async {
    try {
      final response = await ApiClient
          .post(
            ApiConfig.endpoint('save_medical_record.php'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'doctor_id': doctorId,
              'appointment_id': appointmentId,
              'diagnosis': diagnosis,
              'treatment_plan': treatmentPlan,
              'notes': notes,
              // Blank rows are dropped here rather than being sent and
              // refused: a doctor who added a row and changed their mind
              // should not be shown an error about it.
              'medicines': medicines
                  .where((line) => !line.isBlank)
                  .map((line) => line.toJson())
                  .toList(),
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

  /// Brands matching what the doctor has typed, looked up on MedEx.
  ///
  /// Called on every pause in typing, so it is deliberately cheap to fail:
  /// there is no "load the whole catalogue" call anywhere, because there is no
  /// catalogue here to load. What comes back is whatever MedEx answered.
  ///
  /// If PHP could not reach MedEx it answers with the brands already
  /// prescribed through this app and says so in [MedicineSearchResult.source];
  /// the form shows that message rather than passing off a handful of local
  /// rows as the real catalogue.
  static Future<MedicineSearchResult> searchMedicines(String query) async {
    try {
      final uri = ApiConfig.endpoint(
        'medicine_search.php',
      ).replace(queryParameters: {'q': query.trim()});

      final response = await ApiClient.get(uri).timeout(ApiConfig.timeout);

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        return MedicineSearchResult.failure(
          'The server sent back something unexpected. Check the PHP error log.',
        );
      }

      final parsed = ApiResponse.fromJson(decoded);

      if (!parsed.success) {
        return MedicineSearchResult.failure(parsed.message);
      }

      final rows = decoded['data'];

      return MedicineSearchResult.success(
        medicines: rows is List
            ? rows
                  .whereType<Map<String, dynamic>>()
                  .map(MedicineOption.fromJson)
                  .toList()
            : const [],
        message: parsed.message,
        source: (decoded['source'] as String?) ?? 'medex',
      );
    } on SocketException {
      return MedicineSearchResult.failure(
        'Cannot reach the server at ${ApiConfig.baseUrl}.',
      );
    } on TimeoutException {
      return MedicineSearchResult.failure(
        'The medicine search took too long. Try again.',
      );
    } on FormatException {
      return MedicineSearchResult.failure(
        'The server did not send valid JSON for the medicine search.',
      );
    }
  }
}

/// What one medicine search came back with.
///
/// [source] is 'medex' for a live lookup and 'local' when PHP could not reach
/// MedEx and fell back to brands prescribed here before. The difference is
/// worth showing: a doctor who sees three suggestions needs to know whether
/// that is all MedEx has or all this app happens to remember.
class MedicineSearchResult {
  const MedicineSearchResult._({
    required this.medicines,
    required this.message,
    required this.source,
    this.error,
  });

  const MedicineSearchResult.success({
    required List<MedicineOption> medicines,
    required String message,
    required String source,
  }) : this._(medicines: medicines, message: message, source: source);

  const MedicineSearchResult.failure(String error)
    : this._(
        medicines: const [],
        message: '',
        source: 'medex',
        error: error,
      );

  final List<MedicineOption> medicines;
  final String message;
  final String source;
  final String? error;

  bool get isSuccess => error == null;

  /// True when this came off MedEx rather than out of the local fallback.
  bool get isLive => source == 'medex';
}

/// Either the doctor's patient list, or why it could not be loaded.
///
/// An empty list is a success: a doctor nobody has booked has no records to
/// open, and that is a normal screen rather than a broken one. [message] is
/// the server's own wording for it.
class EmrPatientsResult {
  const EmrPatientsResult._(this.patients, this.message, this.error);

  const EmrPatientsResult.success(List<EmrPatient> patients, String message)
    : this._(patients, message, null);

  const EmrPatientsResult.failure(String error) : this._(const [], '', error);

  final List<EmrPatient> patients;
  final String message;
  final String? error;

  bool get isSuccess => error == null;
}

/// Either one patient's record, or why it could not be loaded.
class EmrDetailsResult {
  const EmrDetailsResult._(this.details, this.message, this.error);

  const EmrDetailsResult.success(EmrDetails details, String message)
    : this._(details, message, null);

  const EmrDetailsResult.failure(String error) : this._(null, '', error);

  final EmrDetails? details;
  final String message;
  final String? error;

  bool get isSuccess => error == null && details != null;
}
