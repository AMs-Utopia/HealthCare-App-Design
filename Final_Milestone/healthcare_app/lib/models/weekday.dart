/// The days of the week used for doctor schedules.
/// Short codes like "Sat" and "Sun" are stored in the database.
enum Weekday {
  sat('Sat', 'Saturday'),
  sun('Sun', 'Sunday'),
  mon('Mon', 'Monday'),
  tue('Tue', 'Tuesday'),
  wed('Wed', 'Wednesday'),
  thu('Thu', 'Thursday'),
  fri('Fri', 'Friday');

  const Weekday(this.code, this.fullName);

  /// Stored in the database, e.g. "Sat".
  final String code;
  /// Shown to the user, e.g. "Saturday".
  final String fullName;

  /// This takes a database code like "Mon" and finds the corresponding Weekday.mon.
  static Weekday? fromCode(String? code) {
    if (code == null || code.isEmpty) return null;
    for (final day in Weekday.values) {
      if (day.code == code) return day;
    }
    return null;
  }
  ///Turns a stored "Sat,Mon,Wed" back into days, keeping week order and
  ///quietly dropping anything unrecognised.
  static List<Weekday> parseCsv(String? csv) {
    if (csv == null || csv.trim().isEmpty) return [];

    final codes = csv.split(',').map((code) => code.trim()).toSet();
    return Weekday.values.where((day) => codes.contains(day.code)).toList();
  }
  /// Joins days back into the stored form, always in week order.
  static String toCsv(Iterable<Weekday> days) {
    final chosen = days.toSet();
    return Weekday.values
        .where(chosen.contains)
        .map((day) => day.code)
        .join(',');
  }
  /// A readable summary for the screen, e.g. "Saturday, Monday".
  static String describe(Iterable<Weekday> days) {
    final chosen = days.toSet();
    return Weekday.values
        .where(chosen.contains)
        .map((day) => day.fullName)
        .join(', ');
  }
}
/// The time slots doctors can choose for their schedules.
/// Keeps the available time options consistent across the app.
class TimeSlots {
  TimeSlots._();
  static const List<String> all = [
    '8:00 AM - 12:00 PM',
    '9:00 AM - 1:00 PM',
    '10:00 AM - 2:00 PM',
    '12:00 PM - 4:00 PM',
    '2:00 PM - 6:00 PM',
    '4:00 PM - 8:00 PM',
    '4:00 PM - 10:00 PM',
    '6:00 PM - 10:00 PM',
    '8:00 PM - 11:00 PM',
  ];
}