import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../config/api_client.dart';
import '../config/api_config.dart';
import '../models/api_response.dart';
import '../models/lab_test.dart';

/// The lab tests a patient can book.
class LabTestService {
  // Only static helpers, never instantiated.
  LabTestService._();

  /// Every test on offer, alphabetically.
  ///
  /// The whole list arrives in one call and is filtered nowhere: it is thirty
  /// odd rows of a name and a price, and a patient booking a test already
  /// knows which one they were told to have. No patient id is sent either -
  /// the list is the same for everyone, and who is booking matters at the next
  /// screen rather than this one.
  static Future<LabTestListResult> fetchAll() async {
    try {
      final response = await ApiClient
          .get(ApiConfig.endpoint('lab_tests.php'))
          .timeout(ApiConfig.timeout);

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        return LabTestListResult.failure(
          'The server sent back something unexpected. Check the PHP error log.',
        );
      }

      final parsed = ApiResponse.fromJson(decoded);

      if (!parsed.success) {
        return LabTestListResult.failure(parsed.message);
      }

      final rows = decoded['data'];

      return LabTestListResult.success(
        rows is List
            ? rows
                  .whereType<Map<String, dynamic>>()
                  .map(LabTest.fromJson)
                  .toList()
            : const [],
        parsed.message,
      );
    } on SocketException {
      return LabTestListResult.failure(
        'Cannot reach the server at ${ApiConfig.baseUrl}.\n'
        'Check that Apache and MySQL are running in XAMPP.',
      );
    } on TimeoutException {
      return LabTestListResult.failure(
        'The server took too long to answer. Please try again.',
      );
    } on FormatException {
      return LabTestListResult.failure(
        'The server did not send valid JSON. Open the endpoint in a browser '
        'to see the PHP error.',
      );
    }
  }

  /// Booking one test at one hospital - the Yes on "Are you sure?".
  ///
  /// Only the test and the hospital are sent. The price is deliberately NOT:
  /// the screen showed the patient a figure and quoted it back at them in the
  /// popup, but the figure that gets stored is read from LAB_TEST on the
  /// server. A price that travelled with the request would be a price the
  /// request could choose, and it ends up on the patient's record as what they
  /// agreed to pay.
  static Future<LabBookingResult> book({
    required int patientId,
    required int testId,
    required int hospitalId,
  }) async {
    try {
      final response = await ApiClient
          .post(
            ApiConfig.endpoint('book_lab_test.php'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'patient_id': patientId,
              'test_id': testId,
              'hospital_id': hospitalId,
            }),
          )
          .timeout(ApiConfig.timeout);

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        return LabBookingResult.failure(
          'The server sent back something unexpected. Check the PHP error log.',
        );
      }

      final parsed = ApiResponse.fromJson(decoded);

      if (!parsed.success || parsed.data == null) {
        return LabBookingResult.failure(parsed.message);
      }

      return LabBookingResult.success(
        LabBooking.fromJson(parsed.data!),
        parsed.message,
      );
    } on SocketException {
      return LabBookingResult.failure(
        'Cannot reach the server at ${ApiConfig.baseUrl}.\n'
        'Check that Apache and MySQL are running in XAMPP.',
      );
    } on TimeoutException {
      // Worded as "may not have gone through" rather than "failed": the
      // request could have reached the server and been written before the app
      // gave up waiting, and telling the patient it failed would invite them
      // to book the same test twice.
      return LabBookingResult.failure(
        'The server took too long to answer, so the booking may not have gone '
        'through. Check your notifications before booking again.',
      );
    } on FormatException {
      return LabBookingResult.failure(
        'The server did not send valid JSON. Open the endpoint in a browser '
        'to see the PHP error.',
      );
    }
  }
}

/// Either the booking that was made, or why it was not.
class LabBookingResult {
  const LabBookingResult._(this.booking, this.message, this.error);

  const LabBookingResult.success(LabBooking booking, String message)
    : this._(booking, message, null);

  const LabBookingResult.failure(String error) : this._(null, '', error);

  final LabBooking? booking;
  final String message;
  final String? error;

  bool get isSuccess => error == null && booking != null;
}

/// Either the tests on offer, or why they could not be loaded.
class LabTestListResult {
  const LabTestListResult._(this.tests, this.message, this.error);

  const LabTestListResult.success(List<LabTest> tests, String message)
    : this._(tests, message, null);

  const LabTestListResult.failure(String error) : this._(const [], '', error);

  final List<LabTest> tests;
  final String message;
  final String? error;

  bool get isSuccess => error == null;
}
