import 'package:flutter/material.dart';

import '../models/degree_option.dart';
import '../models/signed_in_user.dart';
import '../services/degree_service.dart';
import '../theme/app_colors.dart';
import '../widgets/primary_button.dart';
import '../widgets/screen_header.dart';

/// Screen 9 (Doctor) - Add Degrees.
///
/// Reached from the "Add Degrees" box on the doctor dashboard. The doctor
/// ticks the degrees they hold and Update writes them to DOCTOR_DEGREE, which
/// is what a patient sees on the doctor's profile before booking.
///
/// The degrees are picked from a fixed list rather than typed, so no
/// documentation has to be checked and no two doctors write the same degree
/// two different ways.
class AddDegreesScreen extends StatefulWidget {
  const AddDegreesScreen({super.key, required this.doctor});

  final SignedInUser doctor;

  @override
  State<AddDegreesScreen> createState() => _AddDegreesScreenState();
}

///These keep track of the screen's changing state:
class _AddDegreesScreenState extends State<AddDegreesScreen> {
  List<DegreeOption> _options = []; ///all available degrees from the API
  Set<String> _selected = {};       ///degrees the doctor selected
  bool _isLoading = true;           ///whether degrees are currently loading
  String? _loadError;               ///stores an error if loading fails
  bool _isSaving = false;           ///prevents interaction while saving

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    ///This calls the DegreeService and asks the backend
    ///for the available degrees and the doctor's already-selected degrees.
    final result = await DegreeService.fetchFor(widget.doctor.id);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.isSuccess) {
        _options = result.options;
        // Starts from what is already saved, so Update never silently drops
        // a degree the doctor added earlier.
        _selected = {...result.selected};
      } else {
        _loadError = result.error;
      }
    });
  }

  void _toggle(String degreeName) {
    if (_isSaving) return;

    setState(() {                           ///this adds it to _selected. If it was already selected,
                                            ///removes it. setState() tells Flutter to rebuild the UI
      if (!_selected.remove(degreeName)) {
        _selected.add(degreeName);
      }
    });
  }

  Future<void> _onUpdatePressed() async {
    if (_selected.isEmpty) {
      return; // The button is disabled in this case anyway.
    }

    setState(() => _isSaving = true);

    ///When Update is pressed, the selected degree names are sent to DegreeService.save(),
    ///which handles communication with the backend.
    final response = await DegreeService.save(
      doctorId: widget.doctor.id,
      // Sent in catalogue order so the saved list always reads the same way.
      degrees: _options
          .map((option) => option.name)
          .where(_selected.contains)
          .toList(),
    );

    if (!mounted) return;

    setState(() => _isSaving = false);
    ///handling error message
    if (!response.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.message),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }
    await _showSuccessDialog(response.message);
  }

  Future<void> _showSuccessDialog(String message) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.logoGreen),
              SizedBox(width: 10),
              Expanded(child: Text('Successful')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 14),
              // What a patient will see under the doctor's name.
              Text(
                _options
                    .map((option) => option.name)
                    .where(_selected.contains)
                    .join(', '),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                  height: 1.35,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Lit up once at least one degree is ticked, like the other screens.
    final canUpdate = _selected.isNotEmpty && !_isSaving;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ScreenHeader(title: 'Add Degrees'),
              const SizedBox(height: 10),

              if (!_isLoading && _loadError == null)
                Text(
                  _selected.isEmpty
                      ? 'Tick every degree you hold.'
                      : '${_selected.length} selected',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textMuted,
                  ),
                ),
              const SizedBox(height: 12),

              Expanded(child: _buildList()),

              if (!_isLoading && _loadError == null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: PrimaryButton(
                    label: _isSaving ? 'Saving...' : 'Update',
                    onPressed: canUpdate ? _onUpdatePressed : null,
                    glow: canUpdate,
                    width: 160,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.logoGreen),
            SizedBox(height: 16),
            Text(
              'Loading degrees...',
              style: TextStyle(fontSize: 15, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    if (_loadError != null) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.red.shade900),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Try again'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.logoGreen,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // The list is long, so it is broken into the categories the API sends
    // rather than shown as one run of checkboxes.
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        for (final category in _categories) ...[
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 4, left: 4),
            child: Text(
              category,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.6,
                color: AppColors.textMuted,
              ),
            ),
          ),
          for (final option in _options.where((o) => o.category == category))
            _DegreeTile(
              name: option.name,
              selected: _selected.contains(option.name),
              enabled: !_isSaving,
              onTap: () => _toggle(option.name),
            ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  /// Categories in the order the API listed them, without repeats.
  List<String> get _categories {
    final seen = <String>[];
    for (final option in _options) {
      if (!seen.contains(option.category)) seen.add(option.category);
    }
    return seen;
  }
}

/// One tickable degree, lit up neon green while selected.
class _DegreeTile extends StatelessWidget {
  const _DegreeTile({
    required this.name,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String name;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF0FFEC) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.neonGreen : AppColors.fieldBorder,
              width: selected ? 3 : 1.5,
            ),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: AppColors.neonGreen,
                      blurRadius: 14,
                      spreadRadius: -2,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Checkbox(
                value: selected,
                onChanged: enabled ? (_) => onTap() : null,
                activeColor: AppColors.logoGreen,
                side: const BorderSide(color: AppColors.textDark, width: 2),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color:
                        selected ? AppColors.logoGreen : AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}