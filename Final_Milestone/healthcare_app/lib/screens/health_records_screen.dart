import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/health_record.dart';
import '../models/signed_in_user.dart';
import '../services/health_record_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/form_dropdown.dart';
import '../widgets/primary_button.dart';
import '../widgets/screen_header.dart';
import 'health_dashboard_screen.dart';

/// Screen 23 (User / Patient) - Health Records.
///
/// Reached from Health Records in the drawer.
///
/// The patient's own filing cabinet: the prescriptions, lab reports and x-rays
/// they were handed on paper, kept here so they are not in a drawer at home
/// when a doctor asks for them.
///
/// The wireframe's three parts are all here and in its order - the File Type
/// dropdown, the dashed upload box, and Go To Interactive Dashboard along the
/// bottom - with the filed documents listed between the box and that button,
/// because a cabinet nobody can open is only half of "upload, organize and
/// access".
///
/// Two things worth knowing about how it behaves:
///
///   The dropdown says what the NEXT upload is, and it is required before the
///   upload box will open a picker. A file with no category would be a row
///   that can never be grouped or found again, and the server refuses one
///   anyway - asking first is kinder than uploading 8 MB and then explaining.
///
///   The chips under "Your documents" filter what is listed. They are separate
///   from the dropdown on purpose: one chooses where a new document goes, the
///   other chooses what you are looking at, and a single control doing both
///   would change the list every time somebody set up an upload.
class HealthRecordsScreen extends StatefulWidget {
  const HealthRecordsScreen({super.key, required this.patient});

  final SignedInUser patient;

  @override
  State<HealthRecordsScreen> createState() => _HealthRecordsScreenState();
}

class _HealthRecordsScreenState extends State<HealthRecordsScreen> {
  /// What the app will accept. Kept in step with the server's own list in
  /// HealthRecordController - this one only narrows what the picker offers, and
  /// the server still decides by reading the file's first bytes.
  static const _allowedExtensions = [
    'jpg',
    'jpeg',
    'png',
    'webp',
    'pdf',
    'doc',
    'docx',
  ];

  List<HealthRecord> _records = [];
  List<RecordCategory> _categories = [];

  bool _isLoading = true;
  String _message = '';
  String? _error;

  /// The category the next upload will be filed under, held as its code rather
  /// than as the object off the list.
  ///
  /// This matters: every reload builds fresh [RecordCategory] objects, and
  /// their counts change as documents are filed. Holding the object would leave
  /// the dropdown pointing at an instance that is no longer in its own item
  /// list - which is not a stale label but an assertion, because
  /// DropdownButton requires its value to match exactly one item. A code
  /// survives any reload.
  String? _uploadTypeCode;

  /// That code resolved against the list as it stands now. Null when nothing is
  /// chosen, or when a chosen category has since disappeared from the server's
  /// list - in which case the dropdown correctly falls back to its hint.
  RecordCategory? get _uploadType {
    final code = _uploadTypeCode;

    if (code == null) return null;

    for (final category in _categories) {
      if (category.code == code) return category;
    }

    return null;
  }

  /// Shown under the dropdown when the upload box was tapped with no category
  /// chosen. Cleared as soon as one is.
  String? _typeError;

  /// Which chip is lit. Null means All.
  String? _filterCode;

  /// True from the moment a file is chosen until the server has answered, so
  /// the box can show a spinner and refuse a second tap.
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _isLoading = true);

    final result = await HealthRecordService.fetchAll(widget.patient.id);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.isSuccess) {
        _records = result.records;
        _categories = result.categories;
        _message = result.message;
        _error = null;
      } else {
        _error = result.error;
      }
    });
  }

  /// The documents the chips say to show.
  List<HealthRecord> get _visibleRecords {
    final code = _filterCode;

    if (code == null) return _records;

    return _records.where((record) => record.fileType == code).toList();
  }

  /// Pick a file, then send it.
  ///
  /// The category is checked first so the picker never opens for an upload
  /// that cannot be filed. Cancelling the picker is not a failure and says
  /// nothing - the patient knows they cancelled.
  Future<void> _onUploadTapped() async {
    if (_isUploading) return;

    if (_uploadType == null) {
      setState(
        () => _typeError = 'Choose what kind of document this is first.',
      );
      return;
    }

    final PlatformFile? picked;

    try {
      picked = await FilePicker.pickFile(
        dialogTitle: 'Choose a document',
        type: FileType.custom,
        allowedExtensions: _allowedExtensions,
      );
    } on Exception {
      // Some Android builds have no document provider the picker can reach.
      if (mounted) _say('No file manager on this device to pick a file with.');
      return;
    }

    if (picked == null || !mounted) return;

    setState(() => _isUploading = true);

    try {
      final bytes = await picked.readAsBytes();

      if (!mounted) return;

      final result = await HealthRecordService.upload(
        patientId: widget.patient.id,
        fileType: _uploadType!.code,
        bytes: bytes,
        fileName: picked.name,
      );

      if (!mounted) return;

      setState(() => _isUploading = false);

      if (!result.isSuccess) {
        _say(result.error ?? 'That document could not be filed.');
        return;
      }

      _say('${result.record!.displayName} filed under '
          '${result.record!.typeLabel}.');

      // Read the list again rather than slotting the new row in by hand: the
      // counts on the chips were counted by the same query, and a count that
      // drifts from the list is worse than one more round trip.
      await _load();
    } on Exception {
      // The picker handed back something that could not be read - a cached
      // file cleaned up behind us, or a provider that died mid-read.
      if (!mounted) return;

      setState(() => _isUploading = false);
      _say('That file could not be read. Please choose it again.');
    }
  }

  /// Opens one document in whatever app the phone uses for it.
  ///
  /// The file is served by XAMPP over plain http, so this is an http:// link
  /// and Android 11+ needs the VIEW intent for http declared in the manifest -
  /// the same rule the MedEx link on the dashboard runs into.
  Future<void> _openRecord(HealthRecord record) async {
    try {
      final opened = await launchUrl(
        record.url,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        _say('Nothing on this phone can open a .${record.extension} file.');
      }
    } on Exception {
      if (mounted) {
        _say('Nothing on this phone can open a .${record.extension} file.');
      }
    }
  }

  /// The button along the foot of the wireframe.
  ///
  /// Documents and readings are two halves of the same record - the lab report
  /// filed here is where a blood sugar came from - so this leads to the Health
  /// Dashboard rather than to anything of its own. It is the same screen
  /// Monitor Health opens from the home dashboard.
  Future<void> _openDashboard() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HealthDashboardScreen(patient: widget.patient),
      ),
    );
  }

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: AppBottomNav(
        current: AppTab.records,
        patient: widget.patient,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ScreenHeader(title: 'Health Records'),
              const SizedBox(height: 16),

              _buildTypeDropdown(),
              const SizedBox(height: 16),

              _UploadBox(
                isUploading: _isUploading,
                categoryLabel: _uploadType?.label,
                onTap: _onUploadTapped,
              ),
              const SizedBox(height: 20),

              // The cabinet itself. Takes whatever room is left, so the button
              // below stays put while this scrolls.
              Expanded(child: _buildFiledSection()),

              const SizedBox(height: 12),

              // Pinned along the bottom exactly as the wireframe draws it, so
              // it is reachable without scrolling past every document.
              Center(
                child: PrimaryButton(
                  label: 'Go To Interactive Dashboard',
                  width: double.infinity,
                  trailingIcon: Icons.arrow_forward,
                  onPressed: _openDashboard,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        FormDropdown<RecordCategory>(
          hint: 'File Type',
          icon: Icons.folder_open_outlined,
          value: _uploadType,
          items: _categories,
          itemLabel: (category) => category.label,
          errorText: _typeError,
          // Nothing to choose from until the first load has answered.
          onChanged: _categories.isEmpty
              ? null
              : (chosen) => setState(() {
                  _uploadTypeCode = chosen?.code;
                  _typeError = null;
                }),
        ),
      ],
    );
  }

  Widget _buildFiledSection() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.logoGreen),
      );
    }

    if (_error != null) {
      return _Note(
        icon: Icons.wifi_off_outlined,
        title: 'Could not load your documents',
        detail: _error!,
        onRetry: _load,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text(
              'Your documents',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const Spacer(),
            Text(
              _message,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (_records.isNotEmpty) ...[_buildChips(), const SizedBox(height: 12)],

        Expanded(child: _buildList()),
      ],
    );
  }

  /// One chip per category, plus All. Only categories that have something in
  /// them are drawn - a row of six empty chips would be a filter for nothing.
  Widget _buildChips() {
    final used = _categories.where((category) => category.count > 0).toList();

    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _FilterChip(
            label: 'All',
            count: _records.length,
            selected: _filterCode == null,
            onTap: () => setState(() => _filterCode = null),
          ),
          for (final category in used) ...[
            const SizedBox(width: 8),
            _FilterChip(
              label: category.label,
              count: category.count,
              selected: _filterCode == category.code,
              onTap: () => setState(() => _filterCode = category.code),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_records.isEmpty) {
      return _Note(
        icon: Icons.folder_off_outlined,
        title: 'Nothing filed yet',
        detail: 'Pick a file type above, then tap the box to upload your '
            'first prescription, lab report or x-ray.',
      );
    }

    final visible = _visibleRecords;

    if (visible.isEmpty) {
      return _Note(
        icon: Icons.filter_alt_off_outlined,
        title: 'Nothing under this type',
        detail: 'Tap All to see everything you have filed.',
      );
    }

    return RefreshIndicator(
      color: AppColors.logoGreen,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 8),
        itemCount: visible.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, index) => _RecordRow(
          record: visible[index],
          onTap: () => _openRecord(visible[index]),
        ),
      ),
    );
  }
}

/// The dashed box from the wireframe: an arrow in a circle, the words, and a
/// dashed outline drawn rather than faked with an image so it scales.
class _UploadBox extends StatelessWidget {
  const _UploadBox({
    required this.isUploading,
    required this.categoryLabel,
    required this.onTap,
  });

  final bool isUploading;

  /// What the dropdown says, echoed here so the patient can see where the file
  /// is about to go without looking back up.
  final String? categoryLabel;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isUploading ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: isUploading ? AppColors.logoGreen : AppColors.fieldBorder,
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isUploading
                          ? AppColors.logoGreen
                          : AppColors.textMuted,
                      width: 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: isUploading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.logoGreen,
                          ),
                        )
                      : const Icon(
                          Icons.arrow_upward,
                          size: 28,
                          color: AppColors.textMuted,
                        ),
                ),
                const SizedBox(height: 12),

                Text(
                  isUploading ? 'Uploading…' : 'Upload file',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),

                Text(
                  isUploading
                      ? 'Please keep this screen open.'
                      : categoryLabel == null
                      ? 'JPG · PNG · PDF · DOC — up to 10 MB'
                      : 'Filed under $categoryLabel  ·  up to 10 MB',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Draws the dashed rounded rectangle around the upload box.
///
/// Flutter has no dashed border, and the alternative is a package for one
/// rectangle. The path is walked in fixed steps and every other step is drawn,
/// which is all a dash is.
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});

  final Color color;

  static const _dash = 7.0;
  static const _gap = 5.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(12),
        ),
      );

    for (final metric in outline.computeMetrics()) {
      var distance = 0.0;

      while (distance < metric.length) {
        final next = distance + _dash;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0.0, metric.length)),
          paint,
        );
        distance = next + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// One filed document: what it is, when it arrived, and a tap to open it.
class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.record, required this.onTap});

  final HealthRecord record;
  final VoidCallback onTap;

  /// A different icon per kind, so a PDF and a photograph are told apart
  /// before the name is read.
  IconData get _icon {
    if (record.isImage) return Icons.image_outlined;
    if (record.isPdf) return Icons.picture_as_pdf_outlined;
    if (record.isDoc) return Icons.description_outlined;
    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.fieldBorder, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.logoGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(_icon, size: 22, color: AppColors.logoGreen),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      record.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      record.formattedDate.isEmpty
                          ? record.typeLabel
                          : '${record.typeLabel}  ·  ${record.formattedDate}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons.open_in_new,
                size: 20,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

/// One filter chip, with how many sit under it.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.logoGreen.withValues(alpha: 0.14)
                : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppColors.logoGreen : AppColors.fieldBorder,
              width: selected ? 2 : 1.2,
            ),
          ),
          child: Text(
            '$label  $count',
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              color: selected ? AppColors.logoGreen : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

/// The middle of the list when there is nothing to draw in it.
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: AppColors.textMuted),
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
      ),
    );
  }
}
