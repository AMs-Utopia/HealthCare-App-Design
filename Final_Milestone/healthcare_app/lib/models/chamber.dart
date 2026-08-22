/// Where a doctor actually sits at one hospital: the room, the floor it is on,
/// and the lift that reaches it.
///
/// Nobody types any of this in. There is no hospital login and no admin screen
/// anywhere in the app, so the hospital assigns a free room itself the moment a
/// doctor saves a sitting there, and it is stored on that DOCTOR_SCHEDULE row
/// from then on. Both sides read the same two columns, which is what stops the
/// doctor's Chamber Info screen and the patient's booking form ever naming
/// different rooms.
///
/// The lift is not stored. Rooms are numbered floor first - 308 is room 8 on
/// floor 3 - and each floor is served by the lift of the same number, so the
/// lift follows from the floor rather than being a third thing that could drift
/// out of step with it.
class Chamber {
  const Chamber({this.roomNo, this.floorNo});

  /// The room number as stored, e.g. "308". Null on a sitting saved before the
  /// hospital started handing rooms out.
  final String? roomNo;

  /// The floor the room is on, e.g. "3".
  final String? floorNo;

  factory Chamber.fromJson(Map<String, dynamic> json) => Chamber(
    roomNo: _clean(json['chamber_no']),
    floorNo: _clean(json['floor_no']),
  );

  /// Blank strings from the database mean the same as no value at all, so both
  /// arrive here as null and every check below only has to test for one thing.
  static String? _clean(Object? value) {
    if (value == null) return null;

    final text = '$value'.trim();
    return text.isEmpty ? null : text;
  }

  /// True once the hospital has given this sitting a room.
  bool get isAssigned => roomNo != null;

  /// The floor, worked out from the room number when it was not stored.
  ///
  /// Room 308 is on floor 3 whether or not floor_no was filled in, so reading
  /// it back out of the room is better than showing nothing.
  String? get floor {
    if (floorNo != null) return floorNo;
    if (roomNo == null || roomNo!.length < 3) return null;

    return roomNo!.substring(0, roomNo!.length - 2);
  }

  String get roomLabel => isAssigned ? 'Room $roomNo' : 'Not assigned yet';

  String get floorLabel => floor == null ? 'Not set' : 'Floor ${floor!}';

  /// Each floor is served by the lift of the same number.
  String get liftLabel => floor == null ? 'Not set' : 'Lift-${floor!}';

  /// The whole thing on one line, e.g. "Room 308 · Floor 3 · Lift-3".
  ///
  /// Null rather than a half filled line when there is no room yet, so callers
  /// can leave the row out instead of printing something that says nothing.
  String? get summary {
    if (!isAssigned) return null;

    return '$roomLabel · $floorLabel · $liftLabel';
  }
}
