import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/api_client.dart';

import '../config/api_config.dart';
import '../models/api_response.dart';
import '../models/health_record.dart';

/// The documents a patient has filed under Health Records.
class HealthRecordService {
  // Only static helpers, never instantiated.
  HealthRecordService._();

  /// Everything this patient has filed, newest first, together with the
  /// categories the upload dropdown offers.
  ///
  /// The categories come down with the list rather than being an enum in the
  /// app, so adding a kind of document is an edit to
  /// `healthcare_api/config/record_types.php` and not a new build. That also
  /// means the dropdown and the counts can never disagree with each other -
  /// they were counted in the same query the list came from.
  static Future<RecordListResult> fetchAll(int patientId) async {
    try {
      final response = await ApiClient
          .get(
            ApiConfig.endpoint('health_records.php?patient_id=$patientId'),
          )
          .timeout(ApiConfig.timeout);

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        return RecordListResult.failure(
          'The server sent back something unexpected. Check the PHP error log.',
        );
      }

      final parsed = ApiResponse.fromJson(decoded);

      if (!parsed.success) {
        return RecordListResult.failure(parsed.message);
      }

      final rows = decoded['data'];
      final categories = decoded['categories'];

      return RecordListResult.success(
        records: rows is List
            ? rows
                  .whereType<Map<String, dynamic>>()
                  .map(HealthRecord.fromJson)
                  .toList()
            : const [],
        categories: categories is List
            ? categories
                  .whereType<Map<String, dynamic>>()
                  .map(RecordCategory.fromJson)
                  .toList()
            : const [],
        message: parsed.message,
      );
    } on SocketException {
      return RecordListResult.failure(
        'Cannot reach the server at ${ApiConfig.baseUrl}.\n'
        'Check that Apache and MySQL are running in XAMPP.',
      );
    } on TimeoutException {
      return RecordListResult.failure(
        'The server took too long to answer. Please try again.',
      );
    } on FormatException {
      return RecordListResult.failure(
        'The server did not send valid JSON. Open the endpoint in a browser '
        'to see the PHP error.',
      );
    }
  }

  /// Files one document.
  ///
  /// Takes the file's [bytes] rather than a path on purpose. On Android the
  /// picker usually hands back a `content://` URI rather than a file on disk -
  /// a document in Drive or Downloads has no path this app may open - and
  /// `MultipartFile.fromPath` cannot read one. Reading the bytes works whatever
  /// the picker returned, at the cost of holding the file in memory, which the
  /// 10 MB limit keeps reasonable.
  ///
  /// [fileName] travels only so the stored name can end in something the
  /// patient recognises. The server does not trust it: it decides what the
  /// file actually is by reading its first bytes, and rebuilds the name and
  /// the extension itself.
  static Future<RecordUploadResult> upload({
    required int patientId,
    required String fileType,
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      final request = ApiClient.multipart(
        'POST',
        ApiConfig.endpoint('upload_health_record.php'),
      );

      request.fields['patient_id'] = '$patientId';
      request.fields['file_type'] = fileType;
      request.files.add(
        http.MultipartFile.fromBytes('document', bytes, filename: fileName),
      );

      // Deliberately longer than ApiConfig.timeout. That one is sized for a
      // JSON round trip; this is up to 10 MB going up a phone connection, and
      // giving up on it after fifteen seconds would fail uploads that were
      // going to succeed.
      final streamed = await request.send().timeout(uploadTimeout);
      final body = await streamed.stream.bytesToString();

      final decoded = jsonDecode(body);

      if (decoded is! Map<String, dynamic>) {
        return RecordUploadResult.failure(
          'The server sent back something unexpected. Check the PHP error log.',
        );
      }

      final parsed = ApiResponse.fromJson(decoded);

      if (!parsed.success || parsed.data == null) {
        return RecordUploadResult.failure(parsed.message);
      }

      return RecordUploadResult.success(
        HealthRecord.fromJson(parsed.data!),
        parsed.message,
      );
    } on SocketException {
      return RecordUploadResult.failure(
        'Cannot reach the server at ${ApiConfig.baseUrl}.\n'
        'Check that Apache and MySQL are running in XAMPP.',
      );
    } on TimeoutException {
      return RecordUploadResult.failure(
        'The upload took too long. Check your connection and try again.',
      );
    } on FormatException {
      return RecordUploadResult.failure(
        'The server did not send valid JSON. Open the endpoint in a browser '
        'to see the PHP error.',
      );
    }
  }

  /// How long an upload may take. See [upload].
  static const Duration uploadTimeout = Duration(seconds: 60);
}

/// What came back from [HealthRecordService.fetchAll].
class RecordListResult {
  const RecordListResult._({
    required this.records,
    required this.categories,
    required this.message,
    this.error,
  });

  const RecordListResult.success({
    required List<HealthRecord> records,
    required List<RecordCategory> categories,
    required String message,
  }) : this._(records: records, categories: categories, message: message);

  const RecordListResult.failure(String error)
    : this._(
        records: const [],
        categories: const [],
        message: '',
        error: error,
      );

  final List<HealthRecord> records;
  final List<RecordCategory> categories;
  final String message;
  final String? error;

  bool get isSuccess => error == null;
}

/// What came back from [HealthRecordService.upload].
class RecordUploadResult {
  const RecordUploadResult._({this.record, required this.message, this.error});

  const RecordUploadResult.success(HealthRecord record, String message)
    : this._(record: record, message: message);

  const RecordUploadResult.failure(String error)
    : this._(message: '', error: error);

  /// The row as it was stored. Used to slot the new document straight into the
  /// list without another round trip.
  final HealthRecord? record;

  final String message;
  final String? error;

  bool get isSuccess => error == null && record != null;
}
