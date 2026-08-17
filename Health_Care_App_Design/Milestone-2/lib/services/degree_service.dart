import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/api_response.dart';
import '../models/degree_option.dart';

/// All DOCTOR_DEGREE calls to the PHP API.
class DegreeService {
  // Only static helpers, never instantiated.
  DegreeService._();

  /// The degrees on offer, together with the ones this doctor already holds.
  static Future<DegreeCatalogueResult> fetchFor(int doctorId) async {
    try {
      final uri = ApiConfig.endpoint('degrees.php').replace(
        queryParameters: {'doctor_id': '$doctorId'},
      );

      final response = await http.get(uri).timeout(ApiConfig.timeout);

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        return DegreeCatalogueResult.failure(
          'The server sent back something unexpected. Check the PHP error log.',
        );
      }

      final parsed = ApiResponse.fromJson(decoded);

      if (!parsed.success) {
        return DegreeCatalogueResult.failure(parsed.message);
      }

      final rows = decoded['data'];
      if (rows is! List) {
        return DegreeCatalogueResult.failure('No degrees were returned.');
      }

      // "selected" sits alongside "data" rather than inside it, so it is read
      // straight from the decoded body.
      final selected = decoded['selected'];

      return DegreeCatalogueResult.success(
        options: rows
            .whereType<Map<String, dynamic>>()
            .map(DegreeOption.fromJson)
            .toList(),
        selected: selected is List
            ? selected.map((name) => '$name').toSet()
            : <String>{},
      );
    } on SocketException {
      return DegreeCatalogueResult.failure(
        'Cannot reach the server at ${ApiConfig.baseUrl}.\n'
        'Check that Apache and MySQL are running in XAMPP.',
      );
    } on TimeoutException {
      return DegreeCatalogueResult.failure(
        'The server took too long to answer. Please try again.',
      );
    } on FormatException {
      return DegreeCatalogueResult.failure(
        'The server did not send valid JSON. Open the endpoint in a browser '
        'to see the PHP error.',
      );
    }
  }

  /// Replaces the doctor's saved degrees with exactly [degrees].
  static Future<ApiResponse> save({
    required int doctorId,
    required List<String> degrees,
  }) async {
    try {
      final response = await http
          .post(
            ApiConfig.endpoint('save_degrees.php'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'doctor_id': doctorId, 'degrees': degrees}),
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
/// Either the degree list plus what is ticked, or why it could not load.
class DegreeCatalogueResult {
  const DegreeCatalogueResult._(this.options, this.selected, this.error);

  const DegreeCatalogueResult.success({
    required List<DegreeOption> options,
    required Set<String> selected,
  }) : this._(options, selected, null);

  const DegreeCatalogueResult.failure(String error)
      : this._(const [], const {}, error);

  final List<DegreeOption> options;
  final Set<String> selected;
  final String? error;

  bool get isSuccess => error == null;
}