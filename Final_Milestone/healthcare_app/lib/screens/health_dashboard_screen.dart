import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/health_metric.dart';
import '../models/signed_in_user.dart';
import '../services/health_metric_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/labeled_text_field.dart';
import '../widgets/primary_button.dart';
import '../widgets/screen_header.dart';

/// Screen 24 (User / Patient) - Health Dashboard.
///
/// Reached two ways, because it answers to two different intentions: "Monitor
/// Health" on the dashboard, and "Go To Interactive Dashboard" at the foot of
/// Health Records. Both land here.
///
/// What the screen is for: showing a reading NEXT TO the range it should be in,
/// so the patient can see for themselves where they stand. That is why every
/// metric is drawn as a bar of reference bands with a marker on it rather than
/// as a number with a verdict - a number alone says "6.2", and a number on a
/// bar says "6.2, which is past the top of normal but not by much".
///
/// Three rules this screen keeps:
///
///   Nothing is judged here. The status, the wording and the bands all come
///   from the server, which reads them from one config file - so a corrected
///   reference range takes effect everywhere at once.
///
///   A status is never colour alone. Two of the four status colours sit below
///   3:1 on these white cards, so each one is always drawn with an icon and the
///   server's own wording beside it. See [AppColors.statusWarning].
///
///   It never gives advice. It shows a reading, the range, and what the range
///   is called. "See a doctor" is not this screen's to say, and the note at the
///   foot says as much.
class HealthDashboardScreen extends StatefulWidget {
  const HealthDashboardScreen({super.key, required this.patient});

  final SignedInUser patient;

  @override
  State<HealthDashboardScreen> createState() => _HealthDashboardScreenState();
}

class _HealthDashboardScreenState extends State<HealthDashboardScreen> {
  HealthDashboard? _dashboard;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _isLoading = true);

    final result = await HealthMetricService.fetch(widget.patient.id);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.isSuccess) {
        _dashboard = result.dashboard;
        _error = null;
      } else {
        _error = result.error;
      }
    });
  }

  /// The form. Opened as a sheet rather than a screen because the numbers being
  /// typed belong to the dashboard behind them - it stays half visible, and
  /// closing is a swipe rather than a journey back.
  ///
  /// It comes back with the dashboard the save returned, so the screen redraws
  /// from the save itself and never has to fetch again.
  Future<void> _openForm() async {
    final current = _dashboard;

    final updated = await showModalBottomSheet<HealthDashboard>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReadingsSheet(
        patientId: widget.patient.id,
        current: current,
      ),
    );

    if (updated != null && mounted) {
      setState(() => _dashboard = updated);

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Readings saved.'),
            duration: Duration(seconds: 2),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: AppBottomNav(
        current: AppTab.health,
        patient: widget.patient,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ScreenHeader(title: 'Health Dashboard'),
              const SizedBox(height: 12),
              Expanded(child: _buildBody()),
              const SizedBox(height: 10),
              PrimaryButton(
                label: _dashboard?.hasReadings == true
                    ? 'Update my readings'
                    : 'Enter my readings',
                width: double.infinity,
                trailingIcon: Icons.edit_outlined,
                onPressed: _isLoading ? null : _openForm,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.logoGreen),
      );
    }

    if (_error != null) {
      return _Note(
        icon: Icons.wifi_off_outlined,
        title: 'Could not load your dashboard',
        detail: _error!,
        onRetry: _load,
      );
    }

    final dashboard = _dashboard;

    if (dashboard == null) return const SizedBox.shrink();

    return RefreshIndicator(
      color: AppColors.logoGreen,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 8),
        children: [
          _PatientStrip(patient: dashboard.patient),
          const SizedBox(height: 14),

          if (dashboard.hasReadings) ...[
            _SummaryCard(summary: dashboard.summary, message: dashboard.message),
            const SizedBox(height: 16),
            const _BarLegend(),
            const SizedBox(height: 10),
          ] else ...[
            _Note(
              icon: Icons.monitor_heart_outlined,
              title: 'No readings yet',
              detail:
                  'Enter whatever you know - your height and weight, a blood '
                  'pressure from a chemist, a fasting sugar. Each one you add '
                  'is shown against the range it should be in.',
            ),
            const SizedBox(height: 16),
          ],

          for (final metric in dashboard.metrics) ...[
            _MetricCard(metric: metric),
            const SizedBox(height: 10),
          ],

          const SizedBox(height: 4),
          const _Disclaimer(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Who this is
// ---------------------------------------------------------------------------

/// Name, age, gender and blood group along the top.
///
/// Age is worked out from the account's date of birth rather than being a
/// reading, so when it is missing the honest thing is to point at where it is
/// set - not to add a seventh box to the readings form and store a birthday
/// that was never given.
class _PatientStrip extends StatelessWidget {
  const _PatientStrip({required this.patient});

  final PatientVitals patient;

  @override
  Widget build(BuildContext context) {
    final facts = <_Fact>[
      _Fact(
        'Age',
        patient.age == null ? 'Not set' : '${patient.age}',
        isMissing: patient.age == null,
      ),
      if (patient.gender != null && patient.gender!.isNotEmpty)
        _Fact('Gender', patient.gender!),
      if (patient.bloodGroup != null && patient.bloodGroup!.isNotEmpty)
        _Fact('Blood group', patient.bloodGroup!),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.fieldBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            patient.fullName.isEmpty ? 'Your readings' : patient.fullName,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final fact in facts) ...[
                Expanded(child: fact),
              ],
            ],
          ),
          if (patient.age == null) ...[
            const SizedBox(height: 8),
            const Text(
              'Age comes from your date of birth — add it under Profile.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value, {this.isMissing = false});

  final String label;
  final String value;
  final bool isMissing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isMissing ? AppColors.textMuted : AppColors.textDark,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// The ring
// ---------------------------------------------------------------------------

/// How many metrics are in their normal range, as a hero number inside a ring.
///
/// The ring is NOT a two slice pie of "in range" against "out of range" - that
/// would be a chart with less information than the sentence beside it. It has
/// one segment per assessed metric, each painted with that metric's own status,
/// so it doubles as a row of four lights: at a glance you can see not only that
/// two are off, but that one of them is merely amber and the other is red.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary, required this.message});

  final MetricSummary summary;

  /// "Last recorded 22 Aug 2026."
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.fieldBorder, width: 1.5),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 108,
            height: 108,
            child: CustomPaint(
              painter: _RingPainter(summary: summary),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${summary.inRange}/${summary.assessed}',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                        height: 1.1,
                      ),
                    ),
                    const Text(
                      'in range',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  summary.outOfRange == 0
                      ? 'Everything measured is in range'
                      : '${summary.outOfRange} to look at',
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textMuted,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'One mark per measured reading.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textMuted.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Draws the ring: one arc per assessed metric, in that metric's status colour.
class _RingPainter extends CustomPainter {
  const _RingPainter({required this.summary});

  final MetricSummary summary;

  static const _stroke = 11.0;

  /// The gap between segments, in radians at the ring's radius. Keeps the
  /// segments from touching, which is what makes them read as separate lights
  /// rather than as one multicoloured band.
  static const _gap = 0.10;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - _stroke) / 2;
    final rect = Rect.fromCircle(center: centre, radius: radius);

    final track = Paint()
      ..color = AppColors.fieldBorder.withValues(alpha: 0.25)
      ..strokeWidth = _stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // The empty ring, so a dashboard with nothing measured still draws as a
    // ring rather than as blank space.
    canvas.drawCircle(centre, radius, track);

    final total = summary.assessed;

    if (total <= 0) return;

    final sweep = (2 * math.pi / total) - _gap;
    var start = -math.pi / 2 + _gap / 2;

    // In-range segments first, then the rest, so the good ones read as one run
    // and the tally beside them is easy to believe.
    final segments = <Color>[
      for (var i = 0; i < summary.inRange; i++) AppColors.statusGood,
      for (var i = 0; i < summary.outOfRange; i++) AppColors.statusWarning,
    ];

    for (final colour in segments) {
      final paint = Paint()
        ..color = colour
        ..strokeWidth = _stroke
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep + _gap;
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.summary.assessed != summary.assessed ||
      oldDelegate.summary.inRange != summary.inRange;
}

/// What the colours on the bars mean. Present because the bars carry two things
/// at once - the bands and the marker - and a reader should never have to infer
/// which is which.
class _BarLegend extends StatelessWidget {
  const _BarLegend();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 9,
          decoration: BoxDecoration(
            color: AppColors.statusGood.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        const Text(
          'normal band',
          style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
        ),
        const SizedBox(width: 14),

        Container(
          width: 13,
          height: 13,
          decoration: BoxDecoration(
            color: AppColors.textDark,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
        const SizedBox(width: 6),
        const Text(
          'your reading',
          style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// One metric
// ---------------------------------------------------------------------------

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final HealthMetricItem metric;

  @override
  Widget build(BuildContext context) {
    final missing = !metric.hasValue;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.fieldBorder,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      metric.label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 3),
                    // The value wears the text ink, not the status colour: the
                    // number is the reading, and the judgement is the chip
                    // beside it.
                    Text(
                      metric.valueLine,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: missing
                            ? AppColors.textMuted
                            : AppColors.textDark,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),

              if (metric.isAssessed)
                _StatusChip(status: metric.status, label: metric.statusLabel)
              else if (missing)
                const _StatusChip(
                  status: MetricStatus.unknown,
                  label: 'Not recorded',
                ),
            ],
          ),

          if (metric.reference.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.straighten,
                  size: 13,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Reference  ${metric.reference}${metric.unit.isEmpty ? '' : ' ${metric.unit}'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ],

          for (final track in metric.tracks) ...[
            const SizedBox(height: 12),
            if (track.label.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${track.label}  ${_tidy(track.value)}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            SizedBox(
              height: 26,
              child: CustomPaint(
                size: Size.infinite,
                painter: _RangeBarPainter(track: track),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _tidy(track.scaleLow),
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                  Text(
                    _tidy(track.scaleHigh),
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (metric.hasValue && metric.formattedDate.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Recorded ${metric.formattedDate}',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textMuted.withValues(alpha: 0.85),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _tidy(double value) {
    if (value == value.roundToDouble()) return '${value.round()}';
    return value.toStringAsFixed(1);
  }
}

/// A status, always as an icon AND a word. Never colour alone - see the note on
/// [AppColors.statusWarning] for why that rule is absolute here.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.label});

  final MetricStatus status;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: status.color, width: 1.3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 14, color: status.color),
          const SizedBox(width: 5),
          // The word is in text ink rather than the status colour, so it stays
          // legible even where the colour itself is below 3:1 on white.
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}

/// The reference bar: the bands as tinted stretches, the reading as a marker.
class _RangeBarPainter extends CustomPainter {
  const _RangeBarPainter({required this.track});

  final MetricTrack track;

  static const _barHeight = 10.0;
  static const _gap = 2.0;
  static const _markerRadius = 7.0;

  @override
  void paint(Canvas canvas, Size size) {
    final top = (size.height - _barHeight) / 2;
    final radius = const Radius.circular(4);
    final span = track.scaleHigh - track.scaleLow;

    if (span <= 0 || size.width <= 0) return;

    double xFor(double value) =>
        ((value - track.scaleLow) / span).clamp(0.0, 1.0) * size.width;

    // The bands, each in a tint of its own status, with a 2px gap between them
    // so two neighbouring bands never bleed into one shape.
    for (final band in track.bands) {
      final left = xFor(band.from);
      final right = xFor(band.to);
      final width = right - left - _gap;

      if (width <= 0) continue;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, width, _barHeight),
          radius,
        ),
        Paint()..color = band.status.bandColor,
      );
    }

    // The marker last, so it is never painted over, with a white ring that
    // separates it from whichever band it happens to be standing on.
    final x = xFor(track.value).clamp(_markerRadius, size.width - _markerRadius);
    final centre = Offset(x, top + _barHeight / 2);

    canvas.drawCircle(
      centre,
      _markerRadius + 2,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      centre,
      _markerRadius,
      Paint()..color = track.status.color,
    );
  }

  @override
  bool shouldRepaint(_RangeBarPainter oldDelegate) =>
      oldDelegate.track.value != track.value ||
      oldDelegate.track.status != track.status;
}

/// The line that keeps this screen honest about what it is.
class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.logoBlue.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: AppColors.logoBlue),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'These are general adult reference ranges, the kind printed beside '
              'a lab result. They are not a diagnosis and take no account of '
              'pregnancy, medication or a condition you already have. Talk to '
              'your doctor about what your readings mean for you.',
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.textMuted,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The middle of the screen when there is nothing to draw.
class _Note extends StatelessWidget {
  const _Note({
    required this.icon,
    required this.title,
    required this.detail,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.fieldBorder, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
              height: 1.35,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.logoGreen,
                side: const BorderSide(color: AppColors.logoGreen, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Try again'),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The form
// ---------------------------------------------------------------------------

/// Where the patient types readings in by hand.
///
/// Every box is optional. Somebody who has just been weighed and knows nothing
/// else should be able to record that alone, so the only rule is that at least
/// one box is filled - which the server enforces too, since it is the one that
/// would otherwise store a dated row saying nothing.
///
/// The boxes start filled with what is already on record, so "update my
/// readings" means changing a number rather than retyping six.
class _ReadingsSheet extends StatefulWidget {
  const _ReadingsSheet({required this.patientId, required this.current});

  final int patientId;
  final HealthDashboard? current;

  @override
  State<_ReadingsSheet> createState() => _ReadingsSheetState();
}

class _ReadingsSheetState extends State<_ReadingsSheet> {
  late final TextEditingController _height;
  late final TextEditingController _weight;
  late final TextEditingController _systolic;
  late final TextEditingController _diastolic;
  late final TextEditingController _sugar;
  late final TextEditingController _rate;

  bool _isSaving = false;

  /// What the server said was wrong, by field, so each message sits under the
  /// box it belongs to instead of in one snackbar listing all of them.
  Map<String, String> _fieldErrors = {};

  String? _formError;

  @override
  void initState() {
    super.initState();

    String valueOf(String code) {
      final metrics = widget.current?.metrics ?? const <HealthMetricItem>[];

      for (final metric in metrics) {
        if (metric.code == code) return metric.display ?? '';
      }

      return '';
    }

    // Blood pressure is stored as one string but typed as two numbers, so it is
    // split back apart here.
    final pressure = valueOf('blood_pressure');
    final parts = pressure.split('/');

    _height = TextEditingController(text: valueOf('height'));
    _weight = TextEditingController(text: valueOf('weight'));
    _systolic = TextEditingController(text: parts.length == 2 ? parts[0] : '');
    _diastolic = TextEditingController(text: parts.length == 2 ? parts[1] : '');
    _sugar = TextEditingController(text: valueOf('blood_sugar'));
    _rate = TextEditingController(text: valueOf('heart_rate'));
  }

  @override
  void dispose() {
    _height.dispose();
    _weight.dispose();
    _systolic.dispose();
    _diastolic.dispose();
    _sugar.dispose();
    _rate.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _fieldErrors = {};
      _formError = null;
    });

    final result = await HealthMetricService.save(
      patientId: widget.patientId,
      height: _height.text,
      weight: _weight.text,
      systolic: _systolic.text,
      diastolic: _diastolic.text,
      bloodSugar: _sugar.text,
      heartRate: _rate.text,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      Navigator.of(context).pop(result.dashboard);
      return;
    }

    setState(() {
      _isSaving = false;
      _fieldErrors = result.fieldErrors;
      // A reason with no field of its own - "Enter at least one reading."
      _formError = result.fieldErrors.isEmpty ? result.error : result.fieldErrors['form'];
    });
  }

  @override
  Widget build(BuildContext context) {
    // Lifts the sheet clear of the keyboard, so the box being typed into is
    // never underneath it.
    final inset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.fieldBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              const Text(
                'My readings',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Fill in whatever you know. Anything you leave blank keeps the '
                'reading already on record.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textMuted,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 16),

              _field('Height', _height, 'cm', 'height'),
              _field('Weight', _weight, 'kg', 'weight'),

              // BMI is not a box. It is height and weight divided, worked out on
              // the server, so it can never disagree with the two above it.
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calculate_outlined,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'BMI is worked out from these two.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textMuted.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),

              _pressureRow(),
              _field('Blood sugar', _sugar, 'mmol/L fasting', 'blood_sugar'),
              _field('Heart rate', _rate, 'bpm resting', 'heart_rate'),

              if (_formError != null) ...[
                const SizedBox(height: 4),
                Text(
                  _formError!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.historyCancelled,
                  ),
                ),
              ],

              const SizedBox(height: 10),
              PrimaryButton(
                label: _isSaving ? 'Saving…' : 'Save readings',
                width: double.infinity,
                onPressed: _isSaving ? null : _save,
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textMuted,
                ),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller,
    String hint,
    String errorKey,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LabeledTextField(
            label: label,
            controller: controller,
            labelWidth: 118,
            enabled: !_isSaving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            errorText: _fieldErrors[errorKey],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 124, top: 2),
            child: Text(
              hint,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  /// Blood pressure as two boxes with a slash between them, because that is how
  /// it is read off a machine and how a patient says it out loud.
  Widget _pressureRow() {
    final error = _fieldErrors['blood_pressure'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 118,
                child: Text(
                  'Blood pressure',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              Expanded(child: _numberBox(_systolic, '120')),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '/',
                  style: TextStyle(
                    fontSize: 20,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              Expanded(child: _numberBox(_diastolic, '80')),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 124, top: 2),
            child: Text(
              error ?? 'mmHg — upper over lower',
              style: TextStyle(
                fontSize: 11,
                color: error == null
                    ? AppColors.textMuted
                    : AppColors.historyCancelled,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _numberBox(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      enabled: !_isSaving,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 16, color: AppColors.textDark),
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: AppColors.fieldBorder,
            width: 1.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: AppColors.fieldBorder,
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.logoGreen, width: 2),
        ),
      ),
    );
  }
}
