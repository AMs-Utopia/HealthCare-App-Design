import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../config/api_client.dart';

import '../config/api_config.dart';
import '../models/api_response.dart';
import '../models/patient_notification.dart';

/// The patient's bell: the number on it, and the list behind it.
///
/// Both halves come from one place because the bell means one thing to the
/// patient. What lights it happens to live in two tables - APPOINTMENT_HISTORY
/// and ORDER_HEADER - but that is the server's problem, and it is the server
/// that merges them.
class NotificationService {
  // Only static helpers, never instantiated.
  NotificationService._();

  /// How many things the patient has not opened the bell to see.
  ///
  /// Any problem answers zero rather than an error: a dashboard should still
  /// open when the count cannot be fetched, and a missing dot is a far smaller
  /// problem than a dashboard that refuses to load.
  static Future<int> unseenCount(int patientId) async {
    try {
      final uri = ApiConfig.endpoint(
        'patient_notification_count.php',
      ).replace(queryParameters: {'patient_id': '$patientId'});

      final response = await ApiClient.get(uri).timeout(ApiConfig.timeout);

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return 0;

      final parsed = ApiResponse.fromJson(decoded);
      if (!parsed.success) return 0;

      return int.tryParse('${parsed.data?['unseen_count']}') ?? 0;
    } on SocketException {
      return 0;
    } on TimeoutException {
      return 0;
    } on FormatException {
      return 0;
    }
  }

  /// The list behind the bell, newest first.
  ///
  /// [markSeen] says the patient actually opened the screen, which is what
  /// clears the dot. It is sent only from the notifications screen itself and
  /// never from a background refresh, or the dot would go out without anyone
  /// having looked. The reply still shows which rows were new when it opened,
  /// because the server reads before it marks.
  static Future<NotificationFeedResult> fetchFeed(
    int patientId, {
    bool markSeen = false,
  }) async {
    try {
      final uri = ApiConfig.endpoint('notifications.php').replace(
        queryParameters: {
          'patient_id': '$patientId',
          if (markSeen) 'mark_seen': '1',
        },
      );

      final response = await ApiClient.get(uri).timeout(ApiConfig.timeout);

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        return NotificationFeedResult.failure(
          'The server sent back something unexpected. Check the PHP error log.',
        );
      }

      final parsed = ApiResponse.fromJson(decoded);

      if (!parsed.success) {
        return NotificationFeedResult.failure(parsed.message);
      }

      final rows = parsed.data?['items'];

      // An empty list is a normal answer - a patient who has never booked or
      // ordered anything - so it is a success carrying the server's own
      // wording rather than an error.
      return NotificationFeedResult.success(
        rows is List
            ? rows
                  .whereType<Map<String, dynamic>>()
                  .map(PatientNotification.fromJson)
                  .toList()
            : const [],
        parsed.message,
      );
    } on SocketException {
      return NotificationFeedResult.failure(
        'Cannot reach the server at ${ApiConfig.baseUrl}.\n'
        'Check that Apache and MySQL are running in XAMPP.',
      );
    } on TimeoutException {
      return NotificationFeedResult.failure(
        'The server took too long to answer. Please try again.',
      );
    } on FormatException {
      return NotificationFeedResult.failure(
        'The server did not send valid JSON. Open the endpoint in a browser '
        'to see the PHP error.',
      );
    }
  }
}

/// Either the notifications list, or why it could not be loaded.
class NotificationFeedResult {
  const NotificationFeedResult._(this.items, this.message, this.error);

  const NotificationFeedResult.success(
    List<PatientNotification> items,
    String message,
  ) : this._(items, message, null);

  const NotificationFeedResult.failure(String error)
    : this._(const [], '', error);

  final List<PatientNotification> items;
  final String message;
  final String? error;

  bool get isSuccess => error == null;
}
