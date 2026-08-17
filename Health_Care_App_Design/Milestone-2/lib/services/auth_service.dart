import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/api_response.dart';
import '../models/signed_in_user.dart';

/// Sign in, for both patients and doctors.
class AuthService {
  // Only static helpers, never instantiated.
  AuthService._();
  /// Screen 1 - checks the phone and password against PATIENT, then DOCTOR.
  ///
  /// Sends to `api/login.php`. The password is checked on the server with
  /// password_verify() - the stored hash never leaves PHP.
  static Future<LoginResult> login({
    required String phone,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            ApiConfig.endpoint('login.php'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'phone': phone, 'password': password}),
          )
          .timeout(ApiConfig.timeout);

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        return LoginResult.failure(
          const ApiResponse.failure(
            'The server sent back something unexpected. Check the PHP error log.',
          ),
        );
      }

      final parsed = ApiResponse.fromJson(decoded);

      if (!parsed.success || parsed.data == null) {
        return LoginResult.failure(parsed);
      }

      return LoginResult.success(SignedInUser.fromJson(parsed.data!));
    } on SocketException {
      // No route to the PC at all: XAMPP is off, or the phone is on a
      // different network than the PC.
      return LoginResult.failure(
        ApiResponse.failure(
          'Cannot reach the server at ${ApiConfig.baseUrl}.\n'
          'Check that Apache and MySQL are running in XAMPP.',
        ),
      );
    } on TimeoutException {
      return LoginResult.failure(
        const ApiResponse.failure(
          'The server took too long to answer. Please try again.',
        ),
      );
    } on FormatException {
      // Valid HTTP reply, but not JSON - usually a PHP warning or fatal error
      // printed before the real response.
      return LoginResult.failure(
        const ApiResponse.failure(
          'The server did not send valid JSON. Open the endpoint in a browser '
          'to see the PHP error.',
        ),
      );
    }
  }
}
/// Either the signed in account, or why sign in did not work.
class LoginResult {
  const LoginResult._(this.user, this.error);

  const LoginResult.success(SignedInUser user) : this._(user, null);

  const LoginResult.failure(ApiResponse error) : this._(null, error);

  final SignedInUser? user;
  final ApiResponse? error;

  bool get isSuccess => user != null;
}