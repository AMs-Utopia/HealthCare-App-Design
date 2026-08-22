/// One row of ADDRESS: an address the patient has saved.
///
/// A patient keeps as many as they like, and exactly one of them is their
/// present address - the one flagged [isPresent]. That flag is what the radio
/// button on the Saved Address screen sets, and it is the same flag the Basic
/// Info screen reads its "Present Address" box from, so the two screens can
/// never disagree about which address the patient is using.
class SavedAddress {
  const SavedAddress({
    required this.id,
    required this.text,
    required this.isPresent,
  });

  final int id;

  /// The address itself, as stored in ADDRESS.present_address.
  final String text;

  /// True for the one the patient is currently using.
  final bool isPresent;

  factory SavedAddress.fromJson(Map<String, dynamic> json) {
    return SavedAddress(
      id: int.tryParse('${json['address_id']}') ?? 0,
      text: (json['present_address'] as String?) ?? '',
      // MySQL sends its booleans back as 0 and 1.
      isPresent: '${json['is_present']}' == '1',
    );
  }
}
