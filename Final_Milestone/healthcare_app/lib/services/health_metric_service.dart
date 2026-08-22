import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../config/api_client.dart';
import '../config/api_config.dart';
import '../models/api_response.dart';
import '../models/health_metric.dart';

/// The Health Dashboard's readings.
class HealthMetricService {
  // Only static helpers, never instantiated.
  HealthMetricService._();

  /// The dashboard: the newest reading of each metric, already measured against
  /// its reference range by the server.
  static Future<DashboardResult> fetch(int patientId) async {
    try {
      final response = await ApiClient
          .get(ApiConfig.endpoint('health_metrics.php?patient_id=$patientId'))
          .timeout(ApiConfig.timeout);

      return _read(response.body);
    } on SocketException {
      return DashboardResult.failure(
        'Cannot reach the server at ${ApiConfig.baseUrl}.\n'
        'Check that Apache and MySQL are running in XAMPP.',
      );
    } on TimeoutException {
      return DashboardResult.failure(
        'The server took too long to answer. Please try again.',
      );
    } on FormatException {
      return DashboardResult.failure(
        'The server did not send valid JSON. Open the endpoint in a browser '
        'to see the PHP error.',
      );
    }
  }

  /// Records what the patient typed in, and answers with the dashboard as it
  /// now stands.
  ///
  /// Every reading is optional - somebody who only knows their weight today
  /// should be able to record that alone - so each is sent only when it was
  /// filled in. BMI is deliberately never sent: the server works it out from
  /// height and weight, so the figure on the card can never disagree with the
  /// two above it.
  ///
  /// The reply is the whole dashboard rather than an acknowledgement, which
  /// saves a second round trip and means the screen can never draw a state that
  /// the save had already moved past.
  static Future<DashboardResult> save({
    required int patientId,
    String? height,
    String? weight,
    String? systolic,
    String? diastolic,
    String? bloodSugar,
    String? heartRate,
  }) async {
    final body = <String, dynamic>{'patient_id': patientId};

    void put(String key, String? value) {
      final typed = value?.trim() ?? '';

      if (typed.isNotEmpty) body[key] = typed;
    }

    put('height', height);
    put('weight', weight);
    put('systolic', systolic);
    put('diastolic', diastolic);
    put('blood_sugar', bloodSugar);
    put('heart_rate', heartRate);

    try {
      final response = await ApiClient
          .post(
            ApiConfig.endpoint('save_health_metrics.php'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(ApiConfig.timeout);

      return _read(response.body);
    } on SocketException {
      return DashboardResult.failure(
        'Cannot reach the server at ${ApiConfig.baseUrl}.\n'
        'Check that Apache and MySQL are running in XAMPP.',
      );
    } on TimeoutException {
      return DashboardResult.failure(
        'The server took too long to answer. Please try again.',
      );
    } on FormatException {
      return DashboardResult.failure(
        'The server did not send valid JSON. Open the endpoint in a browser '
        'to see the PHP error.',
      );
    }
  }

  /// Both endpoints answer with the same shape, so both are read the same way.
  ///
  /// A 422 carries per field reasons, and those are kept rather than flattened
  /// into one message: the form puts each one under the box it belongs to.
  static DashboardResult _read(String body) {
    final decoded = jsonDecode(body);

    if (decoded is! Map<String, dynamic>) {
      return DashboardResult.failure(
        'The server sent back something unexpected. Check the PHP error log.',
      );
    }

    final parsed = ApiResponse.fromJson(decoded);

    if (!parsed.success) {
      return DashboardResult.rejected(parsed.message, parsed.fieldErrors);
    }

    return DashboardResult.success(HealthDashboard.fromJson(decoded));
  }
}

/// What came back from either call.
class DashboardResult {
  const DashboardResult._({
    this.dashboard,
    this.error,
    this.fieldErrors = const {},
  });

  const DashboardResult.success(HealthDashboard dashboard)
    : this._(dashboard: dashboard);

  const DashboardResult.failure(String error) : this._(error: error);

  /// The server understood the request and refused it - a mistyped reading,
  /// most often. [fieldErrors] says which box was wrong and why.
  const DashboardResult.rejected(String error, Map<String, String> fieldErrors)
    : this._(error: error, fieldErrors: fieldErrors);

  final HealthDashboard? dashboard;
  final String? error;
  final Map<String, String> fieldErrors;

  bool get isSuccess => dashboard != null;
}
