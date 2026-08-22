///One degree the add degrees screen offers.
///The list is not a table - it comes from `config/degrees.php` through
///api/degrees.php`, so the app and the server always offer the same options.
class DegreeOption {
  const DegreeOption({required this.name, required this.category});
  ///Each Degree has name & category
  final String name;
  final String category;

  ///converts the JSON received from the PHP API into a DegreeOption Dart object.
  factory DegreeOption.fromJson(Map<String, dynamic> json) {
    return DegreeOption(
      name: (json['name'] as String?) ?? '',
      category: (json['category'] as String?) ?? 'Other',
    );
  }
}
