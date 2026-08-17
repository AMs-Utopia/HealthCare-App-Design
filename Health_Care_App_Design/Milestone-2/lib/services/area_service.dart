import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/api_response.dart';
import '../models/area.dart';

/// Reads the list of areas from the PHP API.
class AreaService {
  // Only static helpers, never instantiated.
  AreaService._();

  /// Loads every area that has a hospital, for the choose area screen.
  static Future<AreaResult> fetchAll() async {
    try {
      final response = await http
          .get(ApiConfig.endpoint('areas.php'))
          .timeout(ApiConfig.timeout);

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        return AreaResult.failure(
          'The server sent back something unexpected. Check the PHP error log.',
        );
      }

      final parsed = ApiResponse.fromJson(decoded);

      if (!parsed.success) {
        return AreaResult.failure(parsed.message);
      }

      final rows = decoded['data'];
      if (rows is! List) {
        return AreaResult.failure('No areas were returned.');
      }

      return AreaResult.success(
        rows.whereType<Map<String, dynamic>>().map(Area.fromJson).toList(),
      );
    } on SocketException {
      return AreaResult.failure(
        'Cannot reach the server at ${ApiConfig.baseUrl}.\n'
        'Check that Apache and MySQL are running in XAMPP.',
      );
    } on TimeoutException {
      return AreaResult.failure(
        'The server took too long to answer. Please try again.',
      );
    } on FormatException {
      return AreaResult.failure(
        'The server did not send valid JSON. Open the endpoint in a browser '
        'to see the PHP error.',
      );
    }
  }
}
/// Either the loaded areas, or the reason they could not be loaded.
class AreaResult {
  const AreaResult._(this.areas, this.error);

  const AreaResult.success(List<Area> areas) : this._(areas, null);

  const AreaResult.failure(String error) : this._(const [], error);

  final List<Area> areas;
  final String? error;

  bool get isSuccess => error == null;
}