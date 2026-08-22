import 'chamber.dart';

/// What the booking form is told about one sitting, and about one date of it.
///
/// A doctor's sitting is stored as a stretch of hours - "4:00 PM - 10:00 PM" -
/// which is when the doctor is in the chamber, not when any one patient should
/// arrive. The clinic is cut into fifteen minute slots and handed out in serial
/// order, so the first patient to book that day is told 4:15 PM, the second
/// 4:30 PM, and so on until the closing time is reached and there is nothing
/// left to give.
///
/// Which slot a patient would get depends on how many people have already
/// booked that day, so it cannot be worked out in the app - it is asked for
/// from the API every time the date changes.
class SlotAvailability {
  const SlotAvailability({
    required this.scheduleId,
    required this.timeSlot,
    required this.chamber,
    required this.slotMinutes,
    required this.capacity,
    this.hospitalName,
    this.area,
    this.closingTime,
    this.date,
    this.bookedCount,
    this.remaining,
    this.nextSerial,
    this.nextTime,
    this.isFull = false,
  });

  final int scheduleId;

  /// The whole sitting, as the doctor entered it.
  final String timeSlot;

  final Chamber chamber;
  final String? hospitalName;
  final String? area;

  /// How long one patient is given, always 15 as things stand.
  final int slotMinutes;

  /// How many patients this sitting can take in a day. 0 when the hours could
  /// not be read, which is the app's signal to stop talking about slots at all
  /// rather than to claim the day is full.
  final int capacity;

  /// The end of the sitting, e.g. "10:00 PM".
  final String? closingTime;

  /// The date this was asked about, or null when only the chamber was.
  final String? date;

  final int? bookedCount;
  final int? remaining;

  /// The place in the queue the patient booking now would take, and the time
  /// that comes with it. Both null once the day is full.
  final int? nextSerial;
  final String? nextTime;

  /// True when every slot of that date has been handed out.
  final bool isFull;

  /// True when the API answered about a specific date, rather than only about
  /// the chamber.
  bool get hasDate => date != null;

  /// True when the sitting's hours were readable, so there is a slot ladder to
  /// talk about at all.
  bool get hasSlots => capacity > 0;

  /// The line under the date on the booking form.
  String get summary {
    if (!hasSlots) return timeSlot;
    if (isFull) {
      return closingTime == null
          ? 'Fully booked on this date.'
          : 'Fully booked - the last slot was $closingTime.';
    }

    return 'Serial $nextSerial · report at $nextTime';
  }

  /// How much of the day is left, for the line under the serial.
  String get remainingLine {
    if (!hasSlots || remaining == null) return '';
    if (remaining == 0) return 'No slots left.';

    return remaining == 1
        ? '1 slot left out of $capacity.'
        : '$remaining slots left out of $capacity.';
  }

  factory SlotAvailability.fromJson(Map<String, dynamic> json) {
    return SlotAvailability(
      scheduleId: int.tryParse('${json['schedule_id']}') ?? 0,
      timeSlot: (json['time_slot'] as String?) ?? '',
      chamber: Chamber.fromJson(json),
      hospitalName: json['hospital_name'] as String?,
      area: json['area'] as String?,
      slotMinutes: int.tryParse('${json['slot_minutes']}') ?? 15,
      capacity: int.tryParse('${json['capacity']}') ?? 0,
      closingTime: json['closing_time'] as String?,
      date: json['date'] as String?,
      bookedCount: json['booked_count'] == null
          ? null
          : int.tryParse('${json['booked_count']}'),
      remaining: json['remaining'] == null
          ? null
          : int.tryParse('${json['remaining']}'),
      nextSerial: json['next_serial'] == null
          ? null
          : int.tryParse('${json['next_serial']}'),
      nextTime: json['next_time'] as String?,
      // PHP sends a real boolean here, but a plain form post would send "1",
      // so both are accepted.
      isFull: json['is_full'] == true || '${json['is_full']}' == '1',
    );
  }
}
