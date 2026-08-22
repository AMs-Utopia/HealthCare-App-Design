import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../config/api_client.dart';

import '../config/api_config.dart';
import '../models/api_response.dart';
import '../models/department.dart';

/// Reads the DEPARTMENT lookup table from the PHP API.
class DepartmentService {
  // Only static helpers, never instantiated.
  DepartmentService._();
  /// Loads every department for the dropdown on the doctor details screen.
  ///
  /// Returns the list on success, or an [ApiResponse] describing what went
  /// wrong so the screen can show a retry message.
  static Future<DepartmentResult> fetchAll() =>
      _fetch(ApiConfig.endpoint('departments.php'));
  /// Loads only the departments that have a doctor sitting at [hospitalId],
  /// for the choose department screen.
  ///
  /// An empty list is a normal answer - it means no doctor has added a
  /// schedule at that hospital yet.
  static Future<DepartmentResult> fetchForHospital(int hospitalId) => _fetch(
        ApiConfig.endpoint('hospital_departments.php').replace(
          queryParameters: {'hospital_id': '$hospitalId'},
        ),
      );

  static Future<DepartmentResult> _fetch(Uri uri) async {
    try {
      final response = await ApiClient.get(uri).timeout(ApiConfig.timeout);

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        return DepartmentResult.failure(
          'The server sent back something unexpected. Check the PHP error log.',
        );
      }

      final parsed = ApiResponse.fromJson(decoded);

      if (!parsed.success) {
        return DepartmentResult.failure(parsed.message);
      }

      final rows = decoded['data'];
      if (rows is! List) {
        return DepartmentResult.failure('No departments were returned.');
      }

      return DepartmentResult.success(
        rows
            .whereType<Map<String, dynamic>>()
            .map(Department.fromJson)
            .toList(),
      );
    } on SocketException {
      return DepartmentResult.failure(
        'Cannot reach the server at ${ApiConfig.baseUrl}.\n'
        'Check that Apache and MySQL are running in XAMPP.',
      );
    } on TimeoutException {
      return DepartmentResult.failure(
        'The server took too long to answer. Please try again.',
      );
    } on FormatException {
      return DepartmentResult.failure(
        'The server did not send valid JSON. Open the endpoint in a browser '
        'to see the PHP error.',
      );
    }
  }
}

/// Either the loaded departments, or the reason they could not be loaded.
class DepartmentResult {
  const DepartmentResult._(this.departments, this.error);

  const DepartmentResult.success(List<Department> departments)
      : this._(departments, null);

  const DepartmentResult.failure(String error) : this._(const [], error);

  final List<Department> departments;
  final String? error;

  bool get isSuccess => error == null;
}