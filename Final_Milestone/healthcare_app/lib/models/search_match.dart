/// One thing the server understood from what the patient typed.
///
/// A search line can carry several of these at once - "gastric doctor in
/// Dhanmondi on Saturday" comes back as a speciality, a location and an
/// availability. The results screen shows them as chips, so the patient can see
/// what was actually searched for rather than having to trust that their words
/// were read the way they meant them.
class SearchMatch {
  const SearchMatch({required this.type, required this.label, this.code});

  /// One of: speciality, experience, location, hospital, availability, text.
  /// `text` means nothing in the catalogues matched and the words were tried
  /// against doctor and hospital names instead.
  final String type;

  /// What to show on the chip, e.g. "Gastric & acidity".
  final String label;

  /// The catalogue code, when the match came from one. Null for free text.
  final String? code;

  factory SearchMatch.fromJson(Map<String, dynamic> json) {
    return SearchMatch(
      type: (json['type'] as String?) ?? 'text',
      label: (json['label'] as String?) ?? '',
      code: json['code'] as String?,
    );
  }
}
