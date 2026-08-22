import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../config/api_client.dart';

import '../config/api_config.dart';
import '../models/api_response.dart';
import '../models/doctor_schedule.dart';
import '../models/weekday.dart';

/// All DOCTOR_SCHEDULE calls to the PHP API.
class ScheduleService {
  // Only static helpers, never instantiated.
  ScheduleService._();
  /// Every schedule this doctor has already saved, so the add schedule screen
  /// can show what is set when a hospital is picked.
  static Future<ScheduleListResult> fetchForDoctor(int doctorId) async {
    try {
      final uri = ApiConfig.endpoint('doctor_schedules.php').replace(
        queryParameters: {'doctor_id': '$doctorId'},
      );

      final response = await ApiClient.get(uri).timeout(ApiConfig.timeout);

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        return ScheduleListResult.failure(
          'The server sent back something unexpected. Check the PHP error log.',
        );
      }

      final parsed = ApiResponse.fromJson(decoded);

      if (!parsed.success) {
        return ScheduleListResult.failure(parsed.message);
      }

      final rows = decoded['data'];
      if (rows is! List) {
        return ScheduleListResult.failure('No schedules were returned.');
      }

      return ScheduleListResult.success(
        rows
            .whereType<Map<String, dynamic>>()
            .map(DoctorSchedule.fromJson)
            .toList(),
      );
    } on SocketException {
      return ScheduleListResult.failure(
        'Cannot reach the server at ${ApiConfig.baseUrl}.\n'
        'Check that Apache and MySQL are running in XAMPP.',
      );
    } on TimeoutException {
      return ScheduleListResult.failure(
        'The server took too long to answer. Please try again.',
      );
    } on FormatException {
      return ScheduleListResult.failure(
        'The server did not send valid JSON. Open the endpoint in a browser '
        'to see the PHP error.',
      );
    }
  }
  /// Saves the doctor's sitting at one hospital.
  ///
  /// The doctor keeps one schedule per hospital, so sending a hospital they
  /// already have updates that row rather than adding another.
  static Future<ApiResponse> save({
    required int doctorId,
    required int hospitalId,
    required List<Weekday> weekdays,
    required String timeSlot,
    Weekday? offday,
  }) async {
    try {
      final response = await ApiClient
          .post(
            ApiConfig.endpoint('save_schedule.php'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'doctor_id': doctorId,
              'hospital_id': hospitalId,
              'weekday': weekdays.map((day) => day.code).toList(),
              'time_slot': timeSlot,
              'offday': offday?.code ?? '',
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
/// Either the loaded schedules, or the reason they could not be loaded.
class ScheduleListResult {
  const ScheduleListResult._(this.schedules, this.error);

  const ScheduleListResult.success(List<DoctorSchedule> schedules)
      : this._(schedules, null);

  const ScheduleListResult.failure(String error) : this._(const [], error);

  final List<DoctorSchedule> schedules;
  final String? error;

  bool get isSuccess => error == null;
}