/// A document the patient has filed under Health Records.
///
/// Worth being clear about what this is NOT, because three things in this app
/// sound alike:
///
///   [PatientPrescription] is what a doctor wrote inside this app - a
///   medicine, a dose, a duration. The app created it and can read it.
///
///   [Emr] is the doctor's own write up of a visit, again created here.
///
///   A [HealthRecord] is a FILE the patient uploaded: the paper prescription
///   they were handed, the lab report the centre printed, the x-ray. The app
///   did not create it and cannot read inside it. It knows only what kind of
///   document the patient said it was, where it is kept, and when it arrived.
///
/// So there is nothing structured here and nothing to parse. This class is a
/// label and a pointer.
library;

import '../config/api_config.dart';

class HealthRecord {
  const HealthRecord({
    required this.id,
    required this.fileType,
    required this.typeLabel,
    required this.filePath,
    required this.displayName,
    required this.extension,
    required this.uploadDate,
  });

  final int id;

  /// The category code as stored, e.g. `lab_report`. Codes rather than labels
  /// are compared, so the wording on screen can change without breaking the
  /// filter.
  final String fileType;

  /// That category in the words the patient picked it by, e.g. "Lab Report".
  /// Worked out by the server from its own list, so the app never has to keep
  /// a copy of the categories in step with the backend's.
  final String typeLabel;

  /// Where the file lives, relative to the uploads folder, e.g.
  /// `records/record_26_1787398781_664d0e_cbc-report.pdf`.
  ///
  /// Never a full address. The emulator and a real phone reach the server at
  /// two different hosts, so the address is built by [ApiConfig] at the one
  /// place that knows which is in use - see [url].
  final String filePath;

  /// The name to show, e.g. "cbc-report.pdf" - the patient's own file name,
  /// with the server's bookkeeping prefix taken off.
  final String displayName;

  /// Lower case, no dot, e.g. `pdf`. Decides the icon and how the document
  /// opens.
  final String extension;

  /// The day it was filed. Only a date - the column holds no time.
  final DateTime? uploadDate;

  /// Where to fetch or open this document.
  Uri get url => ApiConfig.uploadUrl(filePath);

  /// Whether this one can be shown as a picture rather than handed to another
  /// app. Drives the thumbnail on the row.
  bool get isImage =>
      extension == 'jpg' ||
      extension == 'jpeg' ||
      extension == 'png' ||
      extension == 'webp';

  bool get isPdf => extension == 'pdf';

  bool get isDoc => extension == 'doc' || extension == 'docx';

  /// The date as it reads on the row, e.g. "22 Aug 2026". Empty when the row
  /// somehow has no date, so the row simply omits it rather than printing a
  /// placeholder date that was never true.
  String get formattedDate {
    final date = uploadDate;

    if (date == null) return '';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  factory HealthRecord.fromJson(Map<String, dynamic> json) {
    return HealthRecord(
      id: _asInt(json['record_id']),
      fileType: (json['file_type'] as String?) ?? 'other',
      typeLabel: (json['type_label'] as String?) ?? 'Document',
      filePath: (json['file_path'] as String?) ?? '',
      displayName: (json['display_name'] as String?) ?? 'Document',
      extension: ((json['extension'] as String?) ?? '').toLowerCase(),
      uploadDate: DateTime.tryParse('${json['upload_date']}'),
    );
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    return int.tryParse('$value') ?? 0;
  }
}

/// One of the kinds of document the upload dropdown offers, with how many the
/// patient has filed under it.
///
/// These come from the server rather than being an enum here on purpose: the
/// categories live in `healthcare_api/config/record_types.php`, and a new one
/// should appear on the dropdown by editing that file - not by shipping a new
/// build of the app.
class RecordCategory {
  const RecordCategory({
    required this.code,
    required this.label,
    required this.count,
  });

  /// What is stored in `health_record.file_type`, e.g. `lab_report`.
  final String code;

  /// What the patient sees, e.g. "Lab Report".
  final String label;

  /// How many documents this patient has filed under it. Zero is normal and is
  /// still drawn - the screen shows every category, not only the used ones.
  final int count;

  factory RecordCategory.fromJson(Map<String, dynamic> json) {
    return RecordCategory(
      code: (json['code'] as String?) ?? '',
      label: (json['label'] as String?) ?? '',
      count: HealthRecord._asInt(json['count']),
    );
  }
}
