import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/api_response.dart';
import '../models/appointment.dart';

/// All APPOINTMENT calls to the PHP API.
class AppointmentService {
  // Only static helpers, never instantiated.
  AppointmentService._();

  /// Books one slot from the patient's book a slot form.

  /// Only the schedule is sent, not the doctor or hospital - PHP reads those
  /// from the schedule so they cannot disagree.
  static Future<ApiResponse> book({
    required int patientId,
    required int scheduleId,
    required String contactName,
    required String contactMobile,
    required String appointmentDate,
    required String visitType,
  }) async {
    try {
      final response = await http
          .post(
            ApiConfig.endpoint('book_appointment.php'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'patient_id': patientId,
              'schedule_id': scheduleId,
              'contact_name': contactName,
              'contact_mobile': contactMobile,
              'appointment_date': appointmentDate,
              'visit_type': visitType,
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
  /// How many appointments the doctor has not looked at yet, for the dot on
  /// the bell. Any problem answers zero rather than an error, because a
  /// dashboard should still open when the count cannot be fetched.
  static Future<int> pendingCount(int doctorId) async {
    try {
      final uri = ApiConfig.endpoint('appointment_count.php').replace(
        queryParameters: {'doctor_id': '$doctorId'},
      );

      final response = await http.get(uri).timeout(ApiConfig.timeout);

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return 0;

      final parsed = ApiResponse.fromJson(decoded);
      if (!parsed.success) return 0;

      return int.tryParse('${parsed.data?['pending_count']}') ?? 0;
    } on SocketException {
      return 0;
    } on TimeoutException {
      return 0;
    } on FormatException {
      return 0;
    }
  }
  /// The doctor's appointments list.
  ///
  /// markSeen is true when the doctor opened the list through Check
  /// Appointments, which is what clears the dot on the bell.
  static Future<AppointmentListResult> fetchForDoctor(
    int doctorId, {
    bool markSeen = false,
  }) async {
    try {
      final uri = ApiConfig.endpoint('doctor_appointments.php').replace(
        queryParameters: {
          'doctor_id': '$doctorId',
          if (markSeen) 'mark_seen': '1',
        },
      );

      final response = await http.get(uri).timeout(ApiConfig.timeout);

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        return AppointmentListResult.failure(
          'The server sent back something unexpected. Check the PHP error log.',
        );
      }

      final parsed = ApiResponse.fromJson(decoded);

      if (!parsed.success) {
        return AppointmentListResult.failure(parsed.message);
      }

      final rows = decoded['data'];
      if (rows is! List) {
        return AppointmentListResult.failure('No appointments were returned.');
      }

      return AppointmentListResult.success(
        rows
            .whereType<Map<String, dynamic>>()
            .map(DoctorAppointment.fromJson)
            .toList(),
      );
    } on SocketException {
      return AppointmentListResult.failure(
        'Cannot reach the server at ${ApiConfig.baseUrl}.\n'
        'Check that Apache and MySQL are running in XAMPP.',
      );
    } on TimeoutException {
      return AppointmentListResult.failure(
        'The server took too long to answer. Please try again.',
      );
    } on FormatException {
      return AppointmentListResult.failure(
        'The server did not send valid JSON. Open the endpoint in a browser '
        'to see the PHP error.',
      );
    }
  }
}
/// Either the loaded appointments, or why they could not be loaded.
class AppointmentListResult {
  const AppointmentListResult._(this.appointments, this.error);

  const AppointmentListResult.success(List<DoctorAppointment> appointments)
      : this._(appointments, null);

  const AppointmentListResult.failure(String error)
      : this._(const [], error);

  final List<DoctorAppointment> appointments;
  final String? error;

  bool get isSuccess => error == null;
}