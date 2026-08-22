///One row of the DEPARTMENT lookup table.
///Used by the department dropdown on the doctor registration screen. The
///id is what gets sent back to the API as `department_id`.
class Department {
  const Department({
    required this.id,
    required this.name,
    this.doctorCount = 0,
  });
  final int id;
  final String name;
  ///How many doctors sit in this department at the hospital being browsed.
  final int doctorCount;

  factory Department.fromJson(Map<String, dynamic> json) {
    return Department(
      //The API sends this as a number, but a string would still parse, so
      //this stays safe if the column is ever read back as text.
      id: int.tryParse('${json['department_id']}') ?? 0,
      name: (json['department_name'] as String?) ?? 'Unknown',
      doctorCount: int.tryParse('${json['doctor_count']}') ?? 0,
    );
  }

  // Makes departments with the same ID count as the same department,
  // so Flutter dropdowns can correctly keep the selected department.
  @override
  bool operator ==(Object other) =>
      other is Department && other.id == id;
  @override
  int get hashCode => id.hashCode;
}