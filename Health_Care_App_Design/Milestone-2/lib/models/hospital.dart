/// One row of the HOSPITAL table.
class Hospital {
  const Hospital({
    required this.id,
    required this.name,
    required this.area,
    this.phone,
    this.address,
  });

  final int id;
  final String name;
  final String area;

  ///Null for every seeded hospital - real numbers have not been added yet,***
  ///so the app must not offer to call one.[for now]
  final String? phone;
  final String? address;

  factory Hospital.fromJson(Map<String, dynamic> json) {
    return Hospital(
      id: int.tryParse('${json['hospital_id']}') ?? 0,
      name: (json['hospital_name'] as String?) ?? 'Unknown',
      area: (json['area'] as String?) ?? '',
      phone: json['phone'] as String?,
      address: json['address'] as String?,
    );
  }
}
