import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../config/api_client.dart';

import '../config/api_config.dart';
import '../models/api_response.dart';
import '../models/appointment.dart';
import '../models/slot_availability.dart';

/// All APPOINTMENT calls to the PHP API.
class AppointmentService {
  // Only static helpers, never instantiated.
  AppointmentService._();

  /// Books one slot from the patient's book a slot form.

  /// Only the schedule is sent, not the doctor or hospital - PHP reads those
  /// from the schedule so they cannot disagree.
  static Future<ApiResponse> book({
    required int patientId,
    required int scheduleId,
    required String contactName,
    required String contactMobile,
    required String appointmentDate,
    required String visitType,
  }) async {
    try {
      final response = await ApiClient
          .post(
            ApiConfig.endpoint('book_appointment.php'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'patient_id': patientId,
              'schedule_id': scheduleId,
              'contact_name': contactName,
              'contact_mobile': contactMobile,
              'appointment_date': appointmentDate,
              'visit_type': visitType,
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
  /// Where the doctor's chamber is, and which slot the patient would be given
  /// on [date].
  ///
  /// Asked for again every time the date changes, because the answer depends on
  /// how many people have already booked that day and that can move while the
  /// form is open. Leaving [date] off asks only about the chamber, which is
  /// what the form needs before a date has been picked.
  static Future<SlotResult> slotAvailability({
    required int scheduleId,
    String? date,
  }) async {
    try {
      final uri = ApiConfig.endpoint('slot_availability.php').replace(
        queryParameters: {
          'schedule_id': '$scheduleId',
          'date': ?date,
        },
      );

      final response = await ApiClient.get(uri).timeout(ApiConfig.timeout);

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        return SlotResult.failure(
          'The server sent back something unexpected. Check the PHP error log.',
        );
      }

      final parsed = ApiResponse.fromJson(decoded);
      final data = decoded['data'];

      // A full day still comes back as success:true with is_full set, so the
      // only real failures here are a missing schedule or a bad date.
      if (!parsed.success || data is! Map<String, dynamic>) {
        return SlotResult.failure(parsed.message);
      }

      return SlotResult.success(SlotAvailability.fromJson(data));
    } on SocketException {
      return SlotResult.failure(
        'Cannot reach the server at ${ApiConfig.baseUrl}.\n'
        'Check that Apache and MySQL are running in XAMPP.',
      );
    } on TimeoutException {
      return SlotResult.failure(
        'The server took too long to answer. Please try again.',
      );
    } on FormatException {
      return SlotResult.failure(
        'The server did not send valid JSON. Open the endpoint in a browser '
        'to see the PHP error.',
      );
    }
  }

  /// The red dot on the doctor's bell: how many changes to their appointments
  /// they have not opened their list to see. Covers new bookings, reschedules
  /// and cancellations alike, because all three are rows of the same history.
  static Future<int> doctorNotificationCount(int doctorId) =>
      _notificationCount(
        ApiConfig.endpoint(
          'appointment_count.php',
        ).replace(queryParameters: {'doctor_id': '$doctorId'}),
      );

  /// The patient's bell is NOT here. It stopped being an appointment count the
  /// moment a medicine order could light it too, so it lives on
  /// NotificationService with the list that explains it.
  ///
  /// Any problem answers zero rather than an error: a dashboard should still
  /// open when the count cannot be fetched, and a missing dot is a far smaller
  /// problem than a dashboard that refuses to load.
  static Future<int> _notificationCount(Uri uri) async {
    try {
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
  /// The doctor's appointments list.
  ///
  /// markSeen is true when the doctor opened the list through Check
  /// Appointments, which is what clears the dot on the bell.
  static Future<AppointmentListResult> fetchForDoctor(
    int doctorId, {
    bool markSeen = false,
  }) async {
    try {
      final uri = ApiConfig.endpoint('doctor_appointments.php').replace(
        queryParameters: {
          'doctor_id': '$doctorId',
          if (markSeen) 'mark_seen': '1',
        },
      );

      final response = await ApiClient.get(uri).timeout(ApiConfig.timeout);

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        return AppointmentListResult.failure(
          'The server sent back something unexpected. Check the PHP error log.',
        );
      }

      final parsed = ApiResponse.fromJson(decoded);

      if (!parsed.success) {
        return AppointmentListResult.failure(parsed.message);
      }

      final rows = decoded['data'];
      if (rows is! List) {
        return AppointmentListResult.failure('No appointments were returned.');
      }

      return AppointmentListResult.success(
        rows
            .whereType<Map<String, dynamic>>()
            .map(DoctorAppointment.fromJson)
            .toList(),
      );
    } on SocketException {
      return AppointmentListResult.failure(
        'Cannot reach the server at ${ApiConfig.baseUrl}.\n'
        'Check that Apache and MySQL are running in XAMPP.',
      );
    } on TimeoutException {
      return AppointmentListResult.failure(
        'The server took too long to answer. Please try again.',
      );
    } on FormatException {
      return AppointmentListResult.failure(
        'The server did not send valid JSON. Open the endpoint in a browser '
        'to see the PHP error.',
      );
    }
  }

  /// The patient's appointments screen: the visits still ahead of them, plus
  /// the trail of everything that has ever happened to their bookings.
  ///
  /// One call fetches both, because the screen draws them one above the other
  /// and two calls would make it load in twice.
  ///
  /// [markSeen] is true when the patient actually opened the screen, which is
  /// what clears the red dot on their bell. A silent refresh leaves it off.
  static Future<PatientAppointmentsResult> fetchForPatient(
    int patientId, {
    bool markSeen = false,
  }) async {
    try {
      final uri = ApiConfig.endpoint('patient_appointments.php').replace(
        queryParameters: {
          'patient_id': '$patientId',
          if (markSeen) 'mark_seen': '1',
        },
      );

      final response = await ApiClient.get(uri).timeout(ApiConfig.timeout);

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        return PatientAppointmentsResult.failure(
          'The server sent back something unexpected. Check the PHP error log.',
        );
      }

      final parsed = ApiResponse.fromJson(decoded);

      if (!parsed.success) {
        return PatientAppointmentsResult.failure(parsed.message);
      }

      // A missing list is read as an empty one rather than as an error: a
      // patient who has never booked has nothing in either, and that is a
      // normal screen rather than a broken one.
      final current = parsed.data?['current'];
      final history = parsed.data?['history'];

      return PatientAppointmentsResult.success(
        current: current is List
            ? current
                  .whereType<Map<String, dynamic>>()
                  .map(PatientAppointment.fromJson)
                  .toList()
            : const [],
        history: history is List
            ? history
                  .whereType<Map<String, dynamic>>()
                  .map(AppointmentHistoryEntry.fromJson)
                  .toList()
            : const [],
        message: parsed.message,
      );
    } on SocketException {
      return PatientAppointmentsResult.failure(
        'Cannot reach the server at ${ApiConfig.baseUrl}.\n'
        'Check that Apache and MySQL are running in XAMPP.',
      );
    } on TimeoutException {
      return PatientAppointmentsResult.failure(
        'The server took too long to answer. Please try again.',
      );
    } on FormatException {
      return PatientAppointmentsResult.failure(
        'The server did not send valid JSON. Open the endpoint in a browser '
        'to see the PHP error.',
      );
    }
  }

  /// Calls one appointment off - Yes on the Manage screen's popup.
  ///
  /// The patient id travels with the request because the API will only cancel
  /// an appointment that belongs to the patient asking, so an appointment id
  /// on its own is not enough to call somebody else's visit off.
  ///
  /// On success the API has already written the red line into the patient's
  /// history, so the screen underneath only has to reload.
  static Future<ApiResponse> cancel({
    required int patientId,
    required int appointmentId,
  }) async {
    try {
      final response = await ApiClient
          .post(
            ApiConfig.endpoint('cancel_appointment.php'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'patient_id': patientId,
              'appointment_id': appointmentId,
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

  /// The reschedule screen: the sitting as it stands, plus the days the doctor
  /// actually sits, to fill the "Choose New Slot" dropdown.
  static Future<RescheduleOptionsResult> rescheduleOptions({
    required int patientId,
    required int appointmentId,
  }) async {
    try {
      final uri = ApiConfig.endpoint('reschedule_options.php').replace(
        queryParameters: {
          'patient_id': '$patientId',
          'appointment_id': '$appointmentId',
        },
      );

      final response = await ApiClient.get(uri).timeout(ApiConfig.timeout);

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        return RescheduleOptionsResult.failure(
          'The server sent back something unexpected. Check the PHP error log.',
        );
      }

      final parsed = ApiResponse.fromJson(decoded);

      if (!parsed.success) {
        return RescheduleOptionsResult.failure(parsed.message);
      }

      final current = parsed.data?['current'];
      final options = parsed.data?['options'];

      if (current is! Map<String, dynamic>) {
        return RescheduleOptionsResult.failure(
          'The server did not say which appointment this is.',
        );
      }

      // An empty list is not a failure - it means this doctor has no sittings
      // coming up, which the screen says in words rather than as an error.
      return RescheduleOptionsResult.success(
        current: RescheduleContext.fromJson(current),
        options: options is List
            ? options
                  .whereType<Map<String, dynamic>>()
                  .map(RescheduleOption.fromJson)
                  .toList()
            : const [],
      );
    } on SocketException {
      return RescheduleOptionsResult.failure(
        'Cannot reach the server at ${ApiConfig.baseUrl}.\n'
        'Check that Apache and MySQL are running in XAMPP.',
      );
    } on TimeoutException {
      return RescheduleOptionsResult.failure(
        'The server took too long to answer. Please try again.',
      );
    } on FormatException {
      return RescheduleOptionsResult.failure(
        'The server did not send valid JSON. Open the endpoint in a browser '
        'to see the PHP error.',
      );
    }
  }

  /// Moves one appointment to a date picked from the dropdown.
  ///
  /// On success the API has already written the yellow line into the patient's
  /// history and put the red dot on the doctor's bell.
  static Future<ApiResponse> reschedule({
    required int patientId,
    required int appointmentId,
    required String newDate,
  }) async {
    return _post('reschedule_appointment.php', {
      'patient_id': patientId,
      'appointment_id': appointmentId,
      'new_date': newDate,
    });
  }

  /// The doctor calling one of their own appointments off.
  ///
  /// Recorded as the doctor's doing, so it lights the patient's bell and
  /// leaves the doctor's own alone.
  static Future<ApiResponse> cancelByDoctor({
    required int doctorId,
    required int appointmentId,
  }) async {
    return _post('doctor_cancel_appointment.php', {
      'doctor_id': doctorId,
      'appointment_id': appointmentId,
    });
  }

  /// One JSON POST that answers in the standard reply shape.
  ///
  /// The three writing calls on this service differ only in their endpoint and
  /// their body, so the error handling lives here once rather than three times.
  static Future<ApiResponse> _post(
    String fileName,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await ApiClient
          .post(
            ApiConfig.endpoint(fileName),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
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
/// Either the loaded appointments, or why they could not be loaded.
class AppointmentListResult {
  const AppointmentListResult._(this.appointments, this.error);

  const AppointmentListResult.success(List<DoctorAppointment> appointments)
      : this._(appointments, null);

  const AppointmentListResult.failure(String error)
      : this._(const [], error);

  final List<DoctorAppointment> appointments;
  final String? error;

  bool get isSuccess => error == null;
}
/// Either the patient's appointments screen, or why it could not be loaded.
///
/// Both halves arrive together because the API sends them in one reply. Two
/// empty lists is a success, not a failure - it is what a patient who has
/// never booked anything should see.
class PatientAppointmentsResult {
  const PatientAppointmentsResult._({
    required this.current,
    required this.history,
    required this.message,
    this.error,
  });

  /// The appointments still ahead of them, soonest first.
  final List<PatientAppointment> current;

  /// Everything that has ever happened to their bookings, newest first.
  final List<AppointmentHistoryEntry> history;

  /// The server's own wording, e.g. "2 upcoming appointments."
  final String message;

  final String? error;

  bool get isSuccess => error == null;

  factory PatientAppointmentsResult.success({
    required List<PatientAppointment> current,
    required List<AppointmentHistoryEntry> history,
    required String message,
  }) {
    return PatientAppointmentsResult._(
      current: current,
      history: history,
      message: message,
    );
  }

  factory PatientAppointmentsResult.failure(String error) {
    return PatientAppointmentsResult._(
      current: const [],
      history: const [],
      message: '',
      error: error,
    );
  }
}

/// Either the reschedule screen's contents, or why they could not be loaded.
class RescheduleOptionsResult {
  const RescheduleOptionsResult._({
    required this.options,
    this.current,
    this.error,
  });

  /// The appointment as it stands, for the "Current Schedule" block.
  final RescheduleContext? current;

  /// The days that can be moved to. Empty means the doctor has no sittings
  /// coming up, which is an answer rather than a failure.
  final List<RescheduleOption> options;

  final String? error;

  bool get isSuccess => error == null;

  factory RescheduleOptionsResult.success({
    required RescheduleContext current,
    required List<RescheduleOption> options,
  }) {
    return RescheduleOptionsResult._(current: current, options: options);
  }

  factory RescheduleOptionsResult.failure(String error) {
    return RescheduleOptionsResult._(options: const [], error: error);
  }
}

/// Either the sitting's chamber and slot, or why they could not be loaded.
class SlotResult {
  const SlotResult._(this.slot, this.error);

  const SlotResult.success(SlotAvailability slot) : this._(slot, null);

  const SlotResult.failure(String error) : this._(null, error);

  final SlotAvailability? slot;
  final String? error;

  bool get isSuccess => slot != null;
}
