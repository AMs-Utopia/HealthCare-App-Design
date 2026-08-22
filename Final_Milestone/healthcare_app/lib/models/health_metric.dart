/// The Health Dashboard: readings, and what they mean.
///
/// Nothing in this file decides whether a reading is high. That judgement is
/// made by the server from `healthcare_api/config/metric_references.php`, and
/// arrives already made - a status, the words to print, and the numbers to draw
/// the bar with. The app is deliberately not a second opinion: if it judged too,
/// a corrected reference range would need a new build of the app before it took
/// effect, and until everyone installed it two patients could see the same
/// reading called two different things.
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// How a reading compares with its reference range.
///
/// The colour is only ever half of it. Two of these four are below 3:1 against
/// the white cards they sit on, so every place that shows a status shows
/// [icon] and the server's wording as well - see [AppColors.statusWarning].
enum MetricStatus {
  good('good', AppColors.statusGood, Icons.check_circle_outline),
  warning('warning', AppColors.statusWarning, Icons.error_outline),
  serious('serious', AppColors.statusSerious, Icons.warning_amber_outlined),
  critical('critical', AppColors.statusCritical, Icons.report_problem_outlined),
  unknown('unknown', AppColors.statusUnknown, Icons.remove_circle_outline);

  const MetricStatus(this.code, this.color, this.icon);

  final String code;
  final Color color;
  final IconData icon;

  /// The tint the reference bands are painted in. The bands are context rather
  /// than the reading itself, so they stay recessive and let the marker - which
  /// is the actual answer - be the thing the eye lands on.
  Color get bandColor => color.withValues(alpha: 0.28);

  bool get isGood => this == MetricStatus.good;

  static MetricStatus fromCode(String? code) {
    for (final status in MetricStatus.values) {
      if (status.code == code) return status;
    }
    return MetricStatus.unknown;
  }
}

/// One stretch of a reference bar, e.g. BMI 18.5 to 25 being "Normal".
class MetricBand {
  const MetricBand({
    required this.from,
    required this.to,
    required this.status,
    required this.label,
  });

  final double from;
  final double to;
  final MetricStatus status;
  final String label;

  factory MetricBand.fromJson(Map<String, dynamic> json) {
    return MetricBand(
      from: _toDouble(json['from']) ?? 0,
      to: _toDouble(json['to']) ?? 0,
      status: MetricStatus.fromCode(json['status'] as String?),
      label: (json['label'] as String?) ?? '',
    );
  }
}

/// One bar. Most metrics have exactly one; blood pressure has two, because two
/// numbers cannot honestly share a single scale.
class MetricTrack {
  const MetricTrack({
    required this.label,
    required this.value,
    required this.status,
    required this.scaleLow,
    required this.scaleHigh,
    required this.bands,
  });

  /// "" for a single track, "Systolic"/"Diastolic" when there are two.
  final String label;

  final double value;
  final MetricStatus status;
  final double scaleLow;
  final double scaleHigh;
  final List<MetricBand> bands;

  /// Where the marker sits along the bar, 0 to 1.
  ///
  /// Clamped, so a reading past the end of the scale is drawn at the end rather
  /// than off the edge of the card - and the number printed beside it still
  /// says what it really was.
  double get position {
    final span = scaleHigh - scaleLow;

    if (span <= 0) return 0;

    return ((value - scaleLow) / span).clamp(0.0, 1.0);
  }

  factory MetricTrack.fromJson(Map<String, dynamic> json) {
    final bands = json['bands'];

    return MetricTrack(
      label: (json['label'] as String?) ?? '',
      value: _toDouble(json['value']) ?? 0,
      status: MetricStatus.fromCode(json['status'] as String?),
      scaleLow: _toDouble(json['scale_low']) ?? 0,
      scaleHigh: _toDouble(json['scale_high']) ?? 1,
      bands: bands is List
          ? bands
                .whereType<Map<String, dynamic>>()
                .map(MetricBand.fromJson)
                .toList()
          : const [],
    );
  }
}

/// One metric as the dashboard draws it.
class HealthMetricItem {
  const HealthMetricItem({
    required this.code,
    required this.label,
    required this.unit,
    required this.kind,
    required this.reference,
    required this.display,
    required this.status,
    required this.statusLabel,
    required this.isAssessed,
    required this.recordedAt,
    required this.tracks,
  });

  final String code;
  final String label;

  /// "kg/m2", "mmHg", "" - printed after the value, never inside it.
  final String unit;

  /// `number`, `pressure` or `plain`. A plain metric (height, weight) is shown
  /// but never judged: a weight is only high or low against a height, and that
  /// is what BMI is for.
  final String kind;

  /// The range in words, e.g. "18.5 - 24.9". Empty for a plain metric.
  final String reference;

  /// The value as it should read, e.g. "23.5" or "138/88". Null when nothing
  /// has been recorded.
  final String? display;

  final MetricStatus status;

  /// The server's wording: "Normal", "Above normal", "High - stage 1". Shown
  /// beside [MetricStatus.icon] so the status never rests on colour.
  final String statusLabel;

  /// Whether this metric was measured against a range at all. Height and weight
  /// are never assessed, and neither is anything unrecorded - so this is what
  /// the ring counts, rather than the number of metrics on screen.
  final bool isAssessed;

  /// When THIS reading was taken, which need not be the newest date on the
  /// screen: a height recorded last month is still the patient's height.
  final DateTime? recordedAt;

  /// One bar, or two for blood pressure. Empty when there is nothing to draw.
  final List<MetricTrack> tracks;

  bool get hasValue => display != null && display!.isNotEmpty;

  /// The value and its unit as one string, for the big figure on the card.
  String get valueLine {
    if (!hasValue) return '—';
    return unit.isEmpty ? display! : '$display $unit';
  }

  String get formattedDate {
    final date = recordedAt;

    if (date == null) return '';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  factory HealthMetricItem.fromJson(Map<String, dynamic> json) {
    final kind = (json['kind'] as String?) ?? 'number';

    // Blood pressure arrives with a "tracks" list of two; everything else
    // carries its scale and bands at the top level. Both become tracks here, so
    // the card draws one thing rather than branching on the kind.
    final rawTracks = json['tracks'];
    final tracks = <MetricTrack>[];

    if (rawTracks is List) {
      tracks.addAll(
        rawTracks.whereType<Map<String, dynamic>>().map(MetricTrack.fromJson),
      );
    } else if (json['bands'] is List && json['value'] != null) {
      tracks.add(
        MetricTrack.fromJson({
          'label': '',
          'value': json['value'],
          'status': json['status'],
          'scale_low': json['scale_low'],
          'scale_high': json['scale_high'],
          'bands': json['bands'],
        }),
      );
    }

    return HealthMetricItem(
      code: (json['code'] as String?) ?? '',
      label: (json['label'] as String?) ?? '',
      unit: (json['unit'] as String?) ?? '',
      kind: kind,
      reference: (json['reference'] as String?) ?? '',
      display: json['display'] as String?,
      status: MetricStatus.fromCode(json['status'] as String?),
      statusLabel: (json['status_label'] as String?) ?? '',
      isAssessed: json['is_assessed'] == true,
      recordedAt: DateTime.tryParse('${json['recorded_at']}'),
      tracks: tracks,
    );
  }
}

/// Who the readings belong to. Drawn along the top so a printed or shown
/// dashboard says whose it is.
class PatientVitals {
  const PatientVitals({
    required this.fullName,
    this.age,
    this.gender,
    this.bloodGroup,
  });

  final String fullName;

  /// Whole years, worked out from the account's date of birth. Null when the
  /// account has none - which is not an error, and the screen offers the way to
  /// set it rather than inventing one.
  final int? age;

  final String? gender;
  final String? bloodGroup;

  factory PatientVitals.fromJson(Map<String, dynamic> json) {
    return PatientVitals(
      fullName: (json['full_name'] as String?) ?? '',
      age: json['age'] == null ? null : int.tryParse('${json['age']}'),
      gender: json['gender'] as String?,
      bloodGroup: json['blood_group'] as String?,
    );
  }
}

/// The tally the ring is drawn from.
class MetricSummary {
  const MetricSummary({
    required this.assessed,
    required this.inRange,
    required this.outOfRange,
  });

  /// How many metrics were measured against a range at all.
  final int assessed;

  final int inRange;
  final int outOfRange;

  bool get hasAnything => assessed > 0;

  factory MetricSummary.fromJson(Map<String, dynamic> json) {
    return MetricSummary(
      assessed: _toInt(json['assessed']),
      inRange: _toInt(json['in_range']),
      outOfRange: _toInt(json['out_of_range']),
    );
  }
}

/// The whole screen's worth of data.
class HealthDashboard {
  const HealthDashboard({
    required this.message,
    required this.patient,
    required this.summary,
    required this.metrics,
    required this.hasReadings,
  });

  final String message;
  final PatientVitals patient;
  final MetricSummary summary;
  final List<HealthMetricItem> metrics;

  /// False when this patient has never recorded anything - the screen then
  /// leads with the form rather than with an empty ring.
  final bool hasReadings;

  /// The metrics that carry a judgement, in the order the server sent them.
  List<HealthMetricItem> get assessed =>
      metrics.where((metric) => metric.isAssessed).toList();

  factory HealthDashboard.fromJson(Map<String, dynamic> json) {
    final rows = json['data'];
    final patient = json['patient'];
    final summary = json['summary'];

    return HealthDashboard(
      message: (json['message'] as String?) ?? '',
      patient: patient is Map<String, dynamic>
          ? PatientVitals.fromJson(patient)
          : const PatientVitals(fullName: ''),
      summary: summary is Map<String, dynamic>
          ? MetricSummary.fromJson(summary)
          : const MetricSummary(assessed: 0, inRange: 0, outOfRange: 0),
      metrics: rows is List
          ? rows
                .whereType<Map<String, dynamic>>()
                .map(HealthMetricItem.fromJson)
                .toList()
          : const [],
      hasReadings: json['has_readings'] == true,
    );
  }
}

double? _toDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse('$value');
}

int _toInt(Object? value) {
  if (value is int) return value;
  return int.tryParse('$value') ?? 0;
}
