import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/api_response.dart';

/// All PATIENT table calls to the PHP API.
///
/// The screens never build URLs or parse JSON themselves - they call a method
/// here and get back an [ApiResponse] they can show.
class PatientService {
  // Only static helpers, never instantiated.
  PatientService._();
  /// Screen 3 - creates the account by inserting a row into PATIENT.
  ///
  /// Sends to `api/register_patient.php`. The password is sent as typed and
  /// hashed by PHP with password_hash() before it is stored.
  static Future<ApiResponse> register({
    required String fullName,
    required String phone,
    required String password,
    required String confirmPassword,
    required bool agreedToTerms,
  }) async {
    try {
      final response = await http
          .post(
            ApiConfig.endpoint('register_patient.php'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'full_name': fullName,
              'phone': phone,
              'password': password,
              'confirm_password': confirmPassword,
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