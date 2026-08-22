import 'chamber.dart';
import 'weekday.dart';

///Defines the three appointment/visit types available in app.
///Ensuring the Flutter values match what your PHP backend expects.
class VisitTypes {
  VisitTypes._();
  static const List<String> all = ['New', 'Follow-up', 'Report Check'];
}

///converts a database-style date such as:2026-08-18
///something user-friendly like:Tue, 18 Aug 2026
String formatAppointmentDate(String isoDate) {
  final date = DateTime.tryParse(isoDate);
  if (date == null) return isoDate;

  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  // DateTime.weekday is 1 for Monday through 7 for Sunday.
  return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} '
      '${date.year}';
}
///Used for the success popup.
class BookedAppointment {
  const BookedAppointment({
    required this.id,
    required this.serialNo,
    required this.date,
    required this.time,
    required this.visitType,
    this.doctorName,
    this.hospitalName,
    this.chamber = const Chamber(),
  });

  final int id;
  /// The patient's place in that day's clinic, and what decides [time].
  final int serialNo;
  /// Stored as yyyy-mm-dd.
  final String date;

  /// The quarter hour this serial was given, e.g. "4:15 PM" - not the whole
  /// sitting. This is the time the patient should actually turn up at.
  final String time;

  final String visitType;
  final String? doctorName;
  final String? hospitalName;

  /// Which room to go to on the day.
  final Chamber chamber;
  ///converts the JSON received from the PHP API into a BookedAppointment Dart object.
  factory BookedAppointment.fromJson(Map<String, dynamic> json) {
    return BookedAppointment(
      id: int.tryParse('${json['appointment_id']}') ?? 0,
      serialNo: int.tryParse('${json['serial_no']}') ?? 0,
      date: (json['appointment_date'] as String?) ?? '',
      time: (json['appointment_time'] as String?) ?? '',
      visitType: (json['visit_type'] as String?) ?? '',
      doctorName: json['doctor_name'] as String?,
      hospitalName: json['hospital_name'] as String?,
      chamber: Chamber.fromJson(json),
    );
  }
}
///One row of the doctor's appointments list.
class DoctorAppointment {
  const DoctorAppointment({
    required this.id,
    required this.serialNo,
    required this.patientName,
    required this.visitType,
    required this.status,
    required this.date,
    required this.time,
    this.patientUid,
    this.age,
    this.gender,
    this.bloodGroup,
    this.contactName,
    this.contactMobile,
    this.hospitalName,
    this.lastAction,
    this.lastActor,
    this.hasUnseen = false,
    this.lastActivity,
  });

  final int id;
  final int serialNo;

  ///The name on the patient's account, which is not always the name typed on
  ///the booking form - a patient can book for someone else.
  final String patientName;
  /// The business id, e.g. PAT00003.
  final String? patientUid;
  ///Null until the patient records a date of birth; there is nowhere to
  ///enter one yet, so this is normally null.
  final int? age;

  final String? gender;
  final String? bloodGroup;

  final String visitType;
  /// "Pending" until the doctor opens this list, then "Confirmed".
  final String status;

  final String date;
  final String time;

  final String? contactName;
  final String? contactMobile;
  final String? hospitalName;

  ///The most recent thing that happened to this appointment, so the doctor's
  ///list can say "this one was moved" rather than only showing the new date
  ///and leaving them to notice it changed.
  final AppointmentAction? lastAction;

  ///Who did that last thing, 'patient' or 'doctor'.
  final String? lastActor;

  ///True while the doctor has not opened their list since it happened. This
  ///is per row - the bell is the same thing counted across all of them.
  final bool hasUnseen;

  ///When this appointment was last acted on, as stored in APPOINTMENT_HISTORY.
  ///
  ///This is what the list is sorted by - most recently touched at the top - so
  ///the row prints it too, otherwise the order would look arbitrary to a doctor
  ///scanning down the screen.
  final String? lastActivity;

  ///That timestamp as the doctor reads it, or null when the appointment is
  ///older than the history table and has none.
  String? get lastActivityLine =>
      lastActivity == null ? null : formatHistoryTimestamp(lastActivity!);

  bool get isNew => status == 'Pending';

  ///Cancelled appointments stay on the doctor's list on purpose: a visit that
  ///was called off is something they need to see, not something to hide.
  bool get isCancelled => status == 'Cancelled';

  ///Worth calling out only when it is not just the original booking.
  bool get wasChanged =>
      lastAction == AppointmentAction.rescheduled ||
      lastAction == AppointmentAction.cancelled;

  factory DoctorAppointment.fromJson(Map<String, dynamic> json) {
    return DoctorAppointment(
      id: int.tryParse('${json['appointment_id']}') ?? 0,
      serialNo: int.tryParse('${json['serial_no']}') ?? 0,
      patientName: (json['patient_name'] as String?) ?? '',
      patientUid: json['patient_uid'] as String?,
      age: json['age'] == null ? null : int.tryParse('${json['age']}'),
      gender: json['gender'] as String?,
      bloodGroup: json['blood_group'] as String?,
      visitType: (json['visit_type'] as String?) ?? '',
      status: (json['status'] as String?) ?? '',
      date: (json['appointment_date'] as String?) ?? '',
      time: (json['appointment_time'] as String?) ?? '',
      contactName: json['contact_name'] as String?,
      contactMobile: json['contact_mobile'] as String?,
      hospitalName: json['hospital_name'] as String?,
      // Null on an appointment booked before history was being recorded.
      lastAction: json['last_action'] == null
          ? null
          : AppointmentAction.fromCode(json['last_action'] as String?),
      lastActor: json['last_actor'] as String?,
      // MySQL sends its booleans back as 0 and 1.
      hasUnseen: '${json['has_unseen']}' == '1',
      lastActivity: json['last_activity'] as String?,
    );
  }
}

///Turns a stored datetime such as 2026-08-19 14:30:00 into something readable
///like Wed, 19 Aug 2026 at 2:30 PM.
///
///The database sends a space between the date and the time, which
///[DateTime.tryParse] accepts, so nothing has to be split by hand.
String formatHistoryTimestamp(String raw) {
  final at = DateTime.tryParse(raw);
  if (at == null) return raw;

  // 0 and 12 both have to read as 12, since there is no 0 o'clock on a clock.
  final hour12 = at.hour % 12 == 0 ? 12 : at.hour % 12;
  final minute = at.minute.toString().padLeft(2, '0');
  final period = at.hour < 12 ? 'AM' : 'PM';

  return '${formatAppointmentDate(raw.split(' ').first)} '
      'at $hour12:$minute $period';
}

///What happened to an appointment. One entry on the patient's history list.
///
///The codes are exactly the strings written into APPOINTMENT_HISTORY.action by
///the API, so the two sides cannot drift apart.
enum AppointmentAction {
  booked('Booked', 'Booked'),
  rescheduled('Rescheduled', 'Rescheduled'),
  cancelled('Cancelled', 'Cancelled'),

  ///Anything the app does not recognise. Only reachable if the database gains
  ///a new action before the app knows about it, in which case the row is still
  ///shown rather than silently dropped.
  unknown('', 'Updated');

  const AppointmentAction(this.code, this.label);

  ///As stored in APPOINTMENT_HISTORY.action.
  final String code;

  ///What the patient reads on the row.
  final String label;

  static AppointmentAction fromCode(String? code) {
    if (code == null) return AppointmentAction.unknown;

    for (final action in AppointmentAction.values) {
      if (action.code == code) return action;
    }
    return AppointmentAction.unknown;
  }
}

///One appointment the patient still has ahead of them.
///
///"Current" is decided by the API, not here: today or later, and not
///cancelled. Anything older lives only in the history list further down the
///same screen.
class PatientAppointment {
  const PatientAppointment({
    required this.id,
    required this.serialNo,
    required this.date,
    required this.time,
    required this.visitType,
    required this.status,
    required this.scheduleId,
    required this.doctorId,
    required this.doctorName,
    required this.departmentName,
    required this.hospitalId,
    required this.hospitalName,
    this.area,
    this.contactName,
    this.contactMobile,
    this.chamber = const Chamber(),
  });

  final int id;

  ///The patient's place in that day's clinic, and what decides [time].
  final int serialNo;

  ///Stored as yyyy-mm-dd.
  final String date;
  final String time;
  final String visitType;

  ///"Pending" until the doctor opens their list, then "Confirmed".
  final String status;

  ///The sitting this was booked against. Manage will need it to reschedule
  ///within the same doctor's hours.
  final int scheduleId;

  final int doctorId;
  final String doctorName;
  final String departmentName;

  final int hospitalId;
  final String hospitalName;
  final String? area;

  ///Which room to go to on the day.
  final Chamber chamber;

  ///Who the visit is for. A patient can book on someone else's behalf, so this
  ///is not always the account holder's own name.
  final String? contactName;
  final String? contactMobile;

  ///How the doctor is addressed on the card.
  String get doctorDisplayName => 'Dr. $doctorName';

  ///Where the visit is, as one line, e.g. "Ibne Sina Hospital, Badda".
  String get hospitalLine =>
      area == null || area!.isEmpty ? hospitalName : '$hospitalName, $area';

  ///The date as the patient reads it.
  String get formattedDate => formatAppointmentDate(date);

  ///True while the doctor has not opened their list yet.
  bool get isAwaitingDoctor => status == 'Pending';

  factory PatientAppointment.fromJson(Map<String, dynamic> json) {
    return PatientAppointment(
      id: int.tryParse('${json['appointment_id']}') ?? 0,
      serialNo: int.tryParse('${json['serial_no']}') ?? 0,
      date: (json['appointment_date'] as String?) ?? '',
      time: (json['appointment_time'] as String?) ?? '',
      visitType: (json['visit_type'] as String?) ?? '',
      status: (json['status'] as String?) ?? '',
      scheduleId: int.tryParse('${json['schedule_id']}') ?? 0,
      doctorId: int.tryParse('${json['doctor_id']}') ?? 0,
      doctorName: (json['doctor_name'] as String?) ?? '',
      departmentName: (json['department_name'] as String?) ?? '',
      hospitalId: int.tryParse('${json['hospital_id']}') ?? 0,
      hospitalName: (json['hospital_name'] as String?) ?? '',
      area: json['area'] as String?,
      contactName: json['contact_name'] as String?,
      contactMobile: json['contact_mobile'] as String?,
      chamber: Chamber.fromJson(json),
    );
  }
}

///One line of the patient's appointment history.
///
///Each row is one thing that happened, not one appointment - a booking that
///was moved and then called off is three rows, which is the whole reason
///APPOINTMENT_HISTORY exists alongside APPOINTMENT.
class AppointmentHistoryEntry {
  const AppointmentHistoryEntry({
    required this.id,
    required this.appointmentId,
    required this.action,
    required this.happenedAt,
    required this.doctorName,
    required this.departmentName,
    required this.hospitalName,
    this.actor = 'patient',
    this.area,
    this.oldDate,
    this.oldTime,
    this.newDate,
    this.newTime,
    this.note,
    this.visitType,
  });

  final int id;
  final int appointmentId;
  final AppointmentAction action;

  ///When the action happened, as stored. This is what orders the list.
  final String happenedAt;

  ///Who did it: 'patient' or 'doctor'. A cancellation reads very differently
  ///depending on which, so the row says so rather than leaving the patient to
  ///wonder whether they called their own visit off.
  final String actor;

  ///True when the clinic did this, not the patient.
  bool get byDoctor => actor == 'doctor';

  final String doctorName;
  final String departmentName;
  final String hospitalName;
  final String? area;

  ///Only a reschedule fills these in, so the row can say what moved.
  final String? oldDate;
  final String? oldTime;
  final String? newDate;
  final String? newTime;

  final String? note;
  final String? visitType;

  String get doctorDisplayName => 'Dr. $doctorName';

  String get hospitalLine =>
      area == null || area!.isEmpty ? hospitalName : '$hospitalName, $area';

  ///When this happened, as the patient reads it.
  String get formattedTimestamp => formatHistoryTimestamp(happenedAt);

  ///One line saying what actually changed, which is different for each action:
  ///a booking has only a new date, a reschedule has both, and a cancellation
  ///names the date that was given up.
  String get description {
    switch (action) {
      case AppointmentAction.booked:
        return newDate == null
            ? 'Appointment booked.'
            : 'Booked for ${formatAppointmentDate(newDate!)}'
                  '${newTime == null ? '' : ', $newTime'}.';

      case AppointmentAction.rescheduled:
        if (oldDate == null || newDate == null) {
          return 'Appointment moved to another date.';
        }
        return 'Moved from ${formatAppointmentDate(oldDate!)} '
            'to ${formatAppointmentDate(newDate!)}'
            '${newTime == null ? '' : ', $newTime'}.';

      case AppointmentAction.cancelled:
        final was = oldDate ?? newDate;
        final who = byDoctor ? 'The doctor cancelled' : 'Cancelled';
        return was == null
            ? '$who this appointment.'
            : '$who the visit on ${formatAppointmentDate(was)}.';

      case AppointmentAction.unknown:
        return note ?? 'Appointment updated.';
    }
  }

  factory AppointmentHistoryEntry.fromJson(Map<String, dynamic> json) {
    return AppointmentHistoryEntry(
      id: int.tryParse('${json['history_id']}') ?? 0,
      appointmentId: int.tryParse('${json['appointment_id']}') ?? 0,
      action: AppointmentAction.fromCode(json['action'] as String?),
      actor: (json['actor'] as String?) ?? 'patient',
      happenedAt: (json['created_at'] as String?) ?? '',
      doctorName: (json['doctor_name'] as String?) ?? '',
      departmentName: (json['department_name'] as String?) ?? '',
      hospitalName: (json['hospital_name'] as String?) ?? '',
      area: json['area'] as String?,
      oldDate: json['old_date'] as String?,
      oldTime: json['old_time'] as String?,
      newDate: json['new_date'] as String?,
      newTime: json['new_time'] as String?,
      note: json['note'] as String?,
      visitType: json['visit_type'] as String?,
    );
  }
}

///One day the doctor sits, offered in the "Choose New Slot" dropdown.
///
///The list comes from the server rather than being worked out in the app, so
///the dropdown can only ever contain days the doctor really holds a chamber -
///an impossible date cannot be picked, which is why there is no "the doctor
///does not sit then" error to show on this screen.
class RescheduleOption {
  const RescheduleOption({
    required this.date,
    required this.weekday,
    required this.weekdayFull,
    this.nextSerial,
    this.nextTime,
    this.remaining,
    this.isFull = false,
  });

  ///Stored as yyyy-mm-dd, and what gets sent back to move the appointment.
  final String date;

  ///The short code, e.g. "Sun".
  final String weekday;

  ///The full name, e.g. "Sunday".
  final String weekdayFull;

  ///The place in that day's queue this patient would take if they moved to it,
  ///and the quarter hour that comes with it. Both null when the day is full.
  final int? nextSerial;
  final String? nextTime;

  ///How many slots that day has left.
  final int? remaining;

  ///True when that day's chamber hours are already used up. The day is still
  ///offered so the patient can see it exists, but it cannot be chosen.
  final bool isFull;

  ///What the dropdown row reads, e.g. "Sunday, 23 Aug 2026".
  String get label => formatAppointmentDate(date);

  ///The dropdown row with its slot, e.g. "Sun, 23 Aug 2026 - 4:15 PM".
  String get slotLabel {
    if (isFull) return '$label - full';
    if (nextTime == null) return label;

    return '$label - $nextTime';
  }

  factory RescheduleOption.fromJson(Map<String, dynamic> json) {
    return RescheduleOption(
      date: (json['date'] as String?) ?? '',
      weekday: (json['weekday'] as String?) ?? '',
      weekdayFull: (json['weekday_full'] as String?) ?? '',
      nextSerial: json['next_serial'] == null
          ? null
          : int.tryParse('${json['next_serial']}'),
      nextTime: json['next_time'] as String?,
      remaining: json['remaining'] == null
          ? null
          : int.tryParse('${json['remaining']}'),
      isFull: json['is_full'] == true || '${json['is_full']}' == '1',
    );
  }
}

///The "Current Schedule" block at the top of the reschedule screen.
///
///This is the appointment joined to the sitting behind it, which is where the
///hospital, the floor and the days the doctor sits all come from.
class RescheduleContext {
  const RescheduleContext({
    required this.appointmentId,
    required this.date,
    required this.time,
    required this.doctorName,
    required this.departmentName,
    required this.hospitalName,
    required this.weekday,
    this.area,
    this.chamberNo,
    this.floorNo,
    this.visitType,
  });

  final int appointmentId;

  ///Stored as yyyy-mm-dd.
  final String date;
  final String time;

  final String doctorName;
  final String departmentName;
  final String hospitalName;
  final String? area;

  ///The days this doctor sits, as stored, e.g. "Sun,Tue,Thu".
  final String weekday;

  ///The room the hospital gave this doctor. Blank only on a sitting saved
  ///before rooms were handed out, in which case the screen prints "Not set"
  ///rather than inventing one.
  final String? chamberNo;
  final String? floorNo;

  ///The same two values as one thing, so this screen names the room, the floor
  ///and the lift exactly the way the booking form did.
  Chamber get chamber => Chamber(roomNo: chamberNo, floorNo: floorNo);

  final String? visitType;

  String get doctorDisplayName => 'Dr. $doctorName';

  String get hospitalLine =>
      area == null || area!.isEmpty ? hospitalName : '$hospitalName, $area';

  String get formattedDate => formatAppointmentDate(date);

  ///The floor as the wireframe asks for it, or an honest blank.
  String get floorLine =>
      floorNo == null || floorNo!.isEmpty ? 'Not set' : floorNo!;

  String get chamberLine =>
      chamberNo == null || chamberNo!.isEmpty ? 'Not set' : chamberNo!;

  ///The days the doctor sits, spelled out, e.g. "Sunday, Tuesday, Thursday".
  String get sittingDays => Weekday.describe(Weekday.parseCsv(weekday));

  factory RescheduleContext.fromJson(Map<String, dynamic> json) {
    return RescheduleContext(
      appointmentId: int.tryParse('${json['appointment_id']}') ?? 0,
      date: (json['appointment_date'] as String?) ?? '',
      time: (json['appointment_time'] as String?) ?? '',
      doctorName: (json['doctor_name'] as String?) ?? '',
      departmentName: (json['department_name'] as String?) ?? '',
      hospitalName: (json['hospital_name'] as String?) ?? '',
      area: json['area'] as String?,
      weekday: (json['weekday'] as String?) ?? '',
      chamberNo: json['chamber_no'] as String?,
      floorNo: json['floor_no'] as String?,
      visitType: json['visit_type'] as String?,
    );
  }
}
