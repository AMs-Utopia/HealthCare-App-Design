import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../config/api_client.dart';

import '../config/api_config.dart';
import '../models/api_response.dart';
import '../models/doctor_listing.dart';

/// All DOCTOR table calls to the PHP API.
///
/// Mirrors [PatientService] so both registration screens work the same way.
class DoctorService {
  // Only static helpers, never instantiated.
  DoctorService._();

  /// The doctors of one department who sit at one hospital, for the patient's
  /// doctors list. An empty list is a normal answer.
  static Future<DoctorListResult> fetchForHospitalDepartment({
    required int hospitalId,
    required int departmentId,
  }) async {
    try {
      final uri = ApiConfig.endpoint('doctors.php').replace(
        queryParameters: {
          'hospital_id': '$hospitalId',
          'department_id': '$departmentId',
        },
      );

      final response = await ApiClient.get(uri).timeout(ApiConfig.timeout);

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        return DoctorListResult.failure(
          'The server sent back something unexpected. Check the PHP error log.',
        );
      }

      final parsed = ApiResponse.fromJson(decoded);

      if (!parsed.success) {
        return DoctorListResult.failure(parsed.message);
      }

      final rows = decoded['data'];
      if (rows is! List) {
        return DoctorListResult.failure('No doctors were returned.');
      }

      return DoctorListResult.success(
        rows
            .whereType<Map<String, dynamic>>()
            .map(DoctorListing.fromJson)
            .toList(),
      );
    } on SocketException {
      return DoctorListResult.failure(
        'Cannot reach the server at ${ApiConfig.baseUrl}.\n'
        'Check that Apache and MySQL are running in XAMPP.',
      );
    } on TimeoutException {
      return DoctorListResult.failure(
        'The server took too long to answer. Please try again.',
      );
    } on FormatException {
      return DoctorListResult.failure(
        'The server did not send valid JSON. Open the endpoint in a browser '
        'to see the PHP error.',
      );
    }
  }
  /// Screen 3 (Doctor) - creates the account by inserting a row into DOCTOR.
  ///
  /// Sends to `api/register_doctor.php`. The password is sent as typed and
  /// hashed by PHP with password_hash() before it is stored.
  static Future<ApiResponse> register({
    required String fullName,
    required String licenseNo,
    required String phone,
    required String password,
    required String confirmPassword,
    required int departmentId,
    required bool agreedToTerms,
  }) async {
    try {
      final response = await ApiClient
          .post(
            ApiConfig.endpoint('register_doctor.php'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'full_name': fullName,
              'license_no': licenseNo,
              'phone': phone,
              'password': password,
              'confirm_password': confirmPassword,
              'department_id': departmentId,
              'agreed_to_terms': agreedToTerms,
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
      // No route to the PC at all: XAMPP is off, or the phone is on a
      // different network than the PC.
      return ApiResponse.failure(
        'Cannot reach the server at ${ApiConfig.baseUrl}.\n'
        'Check that Apache and MySQL are running in XAMPP.',
      );
    } on TimeoutException {
      return const ApiResponse.failure(
        'The server took too long to answer. Please try again.',
      );
    } on FormatException {
      // Valid HTTP reply, but not JSON - usually a PHP warning or fatal error
      // printed before the real response.
      return const ApiResponse.failure(
        'The server did not send valid JSON. Open the endpoint in a browser '
        'to see the PHP error.',
      );
    }
  }
}
/// Either the loaded doctors, or the reason they could not be loaded.
class DoctorListResult {
  const DoctorListResult._(this.doctors, this.error);

  const DoctorListResult.success(List<DoctorListing> doctors)
      : this._(doctors, null);

  const DoctorListResult.failure(String error) : this._(const [], error);

  final List<DoctorListing> doctors;
  final String? error;

  bool get isSuccess => error == null;
}