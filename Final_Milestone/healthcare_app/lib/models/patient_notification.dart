/// What sits behind the patient's bell.
///
/// Three different things light that bell - something happening to an
/// appointment, a medicine order being placed, and a lab test being booked -
/// and they come from three tables that have nothing to do with each other.
/// The API sends them merged into one list in time order, each row tagged with
/// its kind and carrying its own shape underneath, so none has to be squashed
/// into another's fields.
///
/// [PatientNotification] is that tagged row. Exactly one of [appointment],
/// [order] and [labTest] is ever set, decided by [kind].
library;

import 'appointment.dart';
import 'lab_test.dart';
import 'order.dart';

/// Which of the three kinds of thing a notification is.
enum NotificationKind {
  appointment('appointment'),
  order('order'),
  labTest('lab_test'),

  /// Anything the app does not recognise, which is only reachable if the API
  /// starts sending a fourth kind before the app knows about it. The row is
  /// still kept rather than silently dropped, so a patient is never left
  /// wondering why their bell showed a number with nothing under it.
  unknown('');

  const NotificationKind(this.code);

  final String code;

  static NotificationKind fromCode(String? code) {
    if (code == null) return NotificationKind.unknown;

    for (final kind in NotificationKind.values) {
      if (kind.code == code) return kind;
    }
    return NotificationKind.unknown;
  }
}

/// One row of the notifications list.
class PatientNotification {
  const PatientNotification({
    required this.kind,
    required this.at,
    required this.seen,
    this.appointment,
    this.order,
    this.labTest,
  });

  final NotificationKind kind;

  /// When it happened, as stored. This is what the list is ordered by, and the
  /// server has already sorted on it - the app does not re-sort, so what is
  /// shown is what the database decided.
  final String at;

  /// False while the patient has not opened this screen since it happened.
  /// This is the same thing the red dot counts, one row at a time.
  final bool seen;

  /// Set when [kind] is [NotificationKind.appointment].
  final AppointmentHistoryEntry? appointment;

  /// Set when [kind] is [NotificationKind.order].
  final OrderSummary? order;

  /// Set when [kind] is [NotificationKind.labTest].
  final LabBookingSummary? labTest;

  /// True when this row still counts towards the dot, which is what the "New"
  /// marker on the row is drawn from.
  bool get isNew => !seen;

  /// When it happened, as the patient reads it. The same wording the
  /// appointments screen already uses, so the two lists read alike.
  String get formattedTimestamp => formatHistoryTimestamp(at);

  factory PatientNotification.fromJson(Map<String, dynamic> json) {
    final kind = NotificationKind.fromCode(json['kind'] as String?);

    final appointmentJson = json['appointment'];
    final orderJson = json['order'];
    final labTestJson = json['lab_test'];

    return PatientNotification(
      kind: kind,
      at: (json['at'] as String?) ?? '',
      // Sent as 0 or 1, the way every other flag in this API is.
      seen: '${json['seen']}' == '1',
      appointment: appointmentJson is Map<String, dynamic>
          ? AppointmentHistoryEntry.fromJson(appointmentJson)
          : null,
      order: orderJson is Map<String, dynamic>
          ? OrderSummary.fromJson(orderJson)
          : null,
      labTest: labTestJson is Map<String, dynamic>
          ? LabBookingSummary.fromJson(labTestJson)
          : null,
    );
  }
}
