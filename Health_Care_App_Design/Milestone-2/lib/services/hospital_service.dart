import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/api_response.dart';
import '../models/hospital.dart';

/// Reads the HOSPITAL table from the PHP API.
class HospitalService {
  // Only static helpers, never instantiated.
  HospitalService._();

  /// Loads every hospital in one area, for the hospitals screen.
  static Future<HospitalResult> fetchByArea(String area) => _fetch(area);
  /// Loads every hospital there is, for the doctor's add schedule screen.
  static Future<HospitalResult> fetchAll() => _fetch(null);
  /// Passing no area asks the endpoint for all hospitals.
  static Future<HospitalResult> _fetch(String? area) async {
    try {
      final uri = ApiConfig.endpoint('hospitals.php').replace(
        // Areas like "Green Road" have a space in them, so the name has to be
        // encoded rather than pasted into the URL.
        queryParameters: area == null ? null : {'area': area},
      );
      final response = await http.get(uri).timeout(ApiConfig.timeout);
      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        return HospitalResult.failure(
          'The server sent back something unexpected. Check the PHP error log.',
        );
      }

      final parsed = ApiResponse.fromJson(decoded);

      if (!parsed.success) {
        return HospitalResult.failure(parsed.message);
      }

      final rows = decoded['data'];
      if (rows is! List) {
        return HospitalResult.failure('No hospitals were returned.');
      }

      return HospitalResult.success(
        rows.whereType<Map<String, dynamic>>().map(Hospital.fromJson).toList(),
      );
    } on SocketException {
      return HospitalResult.failure(
        'Cannot reach the server at ${ApiConfig.baseUrl}.\n'
        'Check that Apache and MySQL are running in XAMPP.',
      );
    } on TimeoutException {
      return HospitalResult.failure(
        'The server took too long to answer. Please try again.',
      );
    } on FormatException {
      return HospitalResult.failure(
        'The server did not send valid JSON. Open the endpoint in a browser '
        'to see the PHP error.',
      );
    }
  }
}
/// Either the loaded hospitals, or the reason they could not be loaded.
class HospitalResult {
  const HospitalResult._(this.hospitals, this.error);

  const HospitalResult.success(List<Hospital> hospitals)
      : this._(hospitals, null);

  const HospitalResult.failure(String error) : this._(const [], error);

  final List<Hospital> hospitals;
  final String? error;

  bool get isSuccess => error == null;
}