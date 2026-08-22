import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../config/api_client.dart';

import '../config/api_config.dart';
import '../models/api_response.dart';
import '../models/doctor_listing.dart';
import '../models/search_match.dart';

/// Doctor search, for the search bar on the patient dashboard.
///
/// One call covers all five ways of searching - speciality, hospital, location,
/// experience and availability - because the server reads the typed line and
/// works out which of them the patient meant. The app does not try to guess.
class SearchService {
  // Only static helpers, never instantiated.
  SearchService._();

  /// Searches doctors from a typed line, optionally narrowed by a chip.
  ///
  /// [query] is what the patient typed. The named filters are for the chips on
  /// the results screen, and are sent as well as the query when both are set.
  static Future<DoctorSearchResult> search({
    String query = '',
    String? conditionCode,
    String? experienceCode,
    int? departmentId,
    int? hospitalId,
    String? area,
    String? weekday,
    int? minYears,
  }) async {
    try {
      // Only the filters that are actually set are sent, so the server does
      // not have to tell an empty string apart from a missing one.
      final params = <String, String>{
        if (query.trim().isNotEmpty) 'q': query.trim(),
        if (conditionCode != null) 'condition': conditionCode,
        if (experienceCode != null) 'experience': experienceCode,
        if (departmentId != null) 'department_id': '$departmentId',
        if (hospitalId != null) 'hospital_id': '$hospitalId',
        if (area != null) 'area': area,
        if (weekday != null) 'weekday': weekday,
        if (minYears != null) 'min_years': '$minYears',
      };

      final uri = ApiConfig.endpoint(
        'search_doctors.php',
      ).replace(queryParameters: params);

      final response = await ApiClient.get(uri).timeout(ApiConfig.timeout);

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        return DoctorSearchResult.failure(
          'The server sent back something unexpected. Check the PHP error log.',
        );
      }

      final parsed = ApiResponse.fromJson(decoded);

      // A 422 here is not a crash - it is the server saying the words were
      // not enough to search on, and its message says what to try instead.
      if (!parsed.success) {
        return DoctorSearchResult.failure(parsed.message);
      }

      final rows = decoded['data'];
      final matches = decoded['matched'];

      return DoctorSearchResult.success(
        doctors: rows is List
            ? rows
                  .whereType<Map<String, dynamic>>()
                  .map(DoctorListing.fromJson)
                  .toList()
            : const [],
        matches: matches is List
            ? matches
                  .whereType<Map<String, dynamic>>()
                  .map(SearchMatch.fromJson)
                  .toList()
            : const [],
        message: parsed.message,
      );
    } on SocketException {
      return DoctorSearchResult.failure(
        'Cannot reach the server at ${ApiConfig.baseUrl}.\n'
        'Check that Apache and MySQL are running in XAMPP.',
      );
    } on TimeoutException {
      return DoctorSearchResult.failure(
        'The server took too long to answer. Please try again.',
      );
    } on FormatException {
      return DoctorSearchResult.failure(
        'The server did not send valid JSON. Open the endpoint in a browser '
        'to see the PHP error.',
      );
    }
  }
}

/// Either the doctors a search found, or why it could not be run.
///
/// Finding nothing is a success with an empty list, not a failure - "no
/// gastroenterologist sits in Uttara" is a real answer to a real question.
class DoctorSearchResult {
  const DoctorSearchResult._({
    required this.isSuccess,
    required this.doctors,
    required this.matches,
    required this.message,
    this.error,
  });

  final bool isSuccess;
  final List<DoctorListing> doctors;

  /// What the server understood the query to mean.
  final List<SearchMatch> matches;

  /// The server's own wording, e.g. "3 doctors found."
  final String message;

  final String? error;

  factory DoctorSearchResult.success({
    required List<DoctorListing> doctors,
    required List<SearchMatch> matches,
    required String message,
  }) {
    return DoctorSearchResult._(
      isSuccess: true,
      doctors: doctors,
      matches: matches,
      message: message,
    );
  }

  factory DoctorSearchResult.failure(String error) {
    return DoctorSearchResult._(
      isSuccess: false,
      doctors: const [],
      matches: const [],
      message: '',
      error: error,
    );
  }
}
