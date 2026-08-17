/// One area of Dhaka that has at least one hospital in it.
/// Areas are not a table of their own - they come from the `area` column of
/// HOSPITAL, grouped by `api/areas.php`.
class Area {
  const Area({required this.name, required this.hospitalCount});

  final String name;
  ///How many hospitals are in this area. Shown under the area name so
  ///user knows how much they will find there.
  final int hospitalCount;

  factory Area.fromJson(Map<String, dynamic> json) {
    return Area(
      name: (json['area'] as String?) ?? 'Unknown',
      hospitalCount: int.tryParse('${json['hospital_count']}') ?? 0,
    );
  }
}
