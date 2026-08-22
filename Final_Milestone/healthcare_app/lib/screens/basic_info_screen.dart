import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/patient_profile.dart';
import '../models/signed_in_user.dart';
import '../services/patient_service.dart';
import '../theme/app_colors.dart';
import '../widgets/labeled_text_field.dart';
import '../widgets/primary_button.dart';
import '../widgets/screen_header.dart';

/// Basic Info (Patient) - reached from Edit on the My Account screen.
///
/// The one screen where a patient fills in the details registration never
/// asked for. Registration only takes a name, a phone number and a password,
/// so date of birth, gender and blood group have been NULL on every account
/// since the app was built - which is why the doctor's appointments list has
/// always printed "Not set" for age. This is what fills them in.
///
/// Two tables are written, and the API keeps them in step: PATIENT holds the
/// name, phone, date of birth, gender, blood group and photo; ADDRESS holds
/// the present address. The form does not show the seam.
///
/// The photo is the exception to "nothing is saved until Save changes": it
/// goes up on its own the moment it is picked, through its own endpoint. A
/// file cannot travel in the JSON body the rest of the form uses, and keeping
/// it separate means saving the form can never wipe a picture by accident.
class BasicInfoScreen extends StatefulWidget {
  const BasicInfoScreen({super.key, required this.patient});

  final SignedInUser patient;

  @override
  State<BasicInfoScreen> createState() => _BasicInfoScreenState();
}

class _BasicInfoScreenState extends State<BasicInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  /// Set by the date picker, and what the age box is worked out from.
  DateTime? _dateOfBirth;
  String? _gender;
  String? _bloodGroup;

  /// The photo as it stands on the server, so the avatar can show it.
  PatientProfile? _profile;

  bool _isLoading = true;
  String? _loadError;
  bool _isSaving = false;
  bool _isUploading = false;
  Map<String, String> _serverErrors = {};

  /// True once anything has actually been written, so My Account knows to
  /// read itself again when this screen closes.
  bool _didChange = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  /// Fills the form in with what the account already holds.
  ///
  /// Read from the server rather than from the signed in account, which only
  /// ever carried the name and the phone number.
  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    final result = await PatientService.fetchProfile(widget.patient.id);

    if (!mounted) return;

    setState(() {
      _isLoading = false;

      if (!result.isSuccess) {
        _loadError = result.error;
        return;
      }

      _applyProfile(result.profile!);
    });
  }

  /// Puts a profile from the server into the form.
  ///
  /// Called on the first load and again after every save, so what is on screen
  /// is always what the database really holds rather than what was typed.
  void _applyProfile(PatientProfile profile) {
    _profile = profile;
    _nameController.text = profile.fullName;
    _phoneController.text = profile.phone;
    _addressController.text = profile.presentAddress ?? '';
    _dateOfBirth = profile.dateOfBirthDate;
    _gender = Genders.all.contains(profile.gender) ? profile.gender : null;
    _bloodGroup = BloodGroups.all.contains(profile.bloodGroup)
        ? profile.bloodGroup
        : null;
  }

  /// The age box. Worked out here rather than typed, so it cannot disagree
  /// with the date of birth above it, and it updates the moment a date is
  /// picked instead of waiting for the save.
  String get _ageText =>
      _dateOfBirth == null ? '' : '${ageFrom(_dateOfBirth!)}';

  Future<void> _pickDateOfBirth() async {
    if (_isSaving) return;

    final today = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(today.year - 25, today.month, today.day),
      // Nobody alive is older than this, and a birthday cannot be ahead of
      // today, so the picker cannot produce a date the API would refuse.
      firstDate: DateTime(today.year - 120),
      lastDate: today,
      helpText: 'Select date of birth',
    );

    if (picked == null || !mounted) return;

    setState(() {
      _dateOfBirth = picked;
      _serverErrors.remove('date_of_birth');
    });
  }

  /// Where the picture should come from. Camera and gallery both end up in the
  /// same place, so the choice is the only thing this asks.
  Future<void> _pickPhoto() async {
    if (_isUploading || _isSaving) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Text(
                'Profile picture',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: AppColors.logoGreen,
              ),
              title: const Text('Choose from gallery'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_camera_outlined,
                color: AppColors.logoGreen,
              ),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null || !mounted) return;

    // Shrunk before it leaves the phone. A modern camera picture is several
    // megabytes, which is over the API's limit and pointless for something
    // drawn at 100 pixels across.
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (picked == null || !mounted) return;

    setState(() => _isUploading = true);

    final result = await PatientService.uploadProfileImage(
      patientId: widget.patient.id,
      filePath: picked.path,
    );

    if (!mounted) return;

    setState(() {
      _isUploading = false;
      if (result.isSuccess) {
        _profile = result.profile;
        _didChange = true;
      }
    });

    _showSnack(
      result.isSuccess ? result.message : result.error!,
      isError: !result.isSuccess,
    );
  }

  Future<void> _onSavePressed() async {
    setState(() => _serverErrors = {});

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final response = await PatientService.updateProfile(
      patientId: widget.patient.id,
      fullName: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      dateOfBirth: _dateOfBirth == null ? null : toIsoDate(_dateOfBirth!),
      gender: _gender,
      bloodGroup: _bloodGroup,
      presentAddress: _addressController.text.trim(),
    );

    if (!mounted) return;

    setState(() {
      _isSaving = false;
      _serverErrors = response.fieldErrors;
    });

    if (!response.success) {
      _showSnack(response.message, isError: true);
      return;
    }

    // The reply carries the saved row back, age included, so the form is
    // refilled from the database rather than from what was typed.
    if (response.data != null) {
      setState(() => _applyProfile(PatientProfile.fromJson(response.data!)));
    }

    _didChange = true;
    await _showSuccessDialog(response.message);
  }

  Future<void> _showSuccessDialog(String message) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.logoGreen, size: 26),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Update Successful',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message.isEmpty ? 'Your details have been saved.' : message,
          style: const TextStyle(
            fontSize: 15,
            color: AppColors.textMuted,
            height: 1.35,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: TextButton.styleFrom(foregroundColor: AppColors.logoGreen),
            child: const Text(
              'OK',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red.shade700 : null,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    // Back must carry the same answer the Save button does, or My Account
    // would keep showing the old name after a save followed by a back tap.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_didChange);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ScreenHeader(
                  title: 'Basic Info',
                  onBack: () => Navigator.of(context).pop(_didChange),
                ),
                const SizedBox(height: 16),

                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.logoGreen),
            SizedBox(height: 16),
            Text(
              'Loading your details...',
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

    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPhotoPicker(),
            const SizedBox(height: 24),

            LabeledTextField(
              label: 'Full Name',
              controller: _nameController,
              isRequired: true,
              enabled: !_isSaving,
              textInputAction: TextInputAction.next,
              errorText: _serverErrors['full_name'],
              validator: (value) {
                final name = value?.trim() ?? '';
                if (name.isEmpty) return 'Please enter your full name';
                if (name.length > 150) return 'That name is too long';
                return null;
              },
            ),
            const SizedBox(height: 16),

            LabeledTextField(
              label: 'Phone',
              controller: _phoneController,
              isRequired: true,
              enabled: !_isSaving,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              errorText: _serverErrors['phone'],
              validator: (value) {
                final phone = value?.trim() ?? '';
                if (phone.isEmpty) return 'Please enter a phone number';
                if (!RegExp(r'^01[0-9]{9}$').hasMatch(phone)) {
                  return 'Enter an 11 digit number, e.g. 01712345678';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),

            // The wireframe pairs these two, and they belong together: one is
            // worked out from the other.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _buildDateOfBirthField()),
                const SizedBox(width: 14),
                Expanded(flex: 2, child: _buildAgeField()),
              ],
            ),
            const SizedBox(height: 18),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _StackedField(
                    label: 'Blood group',
                    child: _buildDropdown(
                      value: _bloodGroup,
                      items: BloodGroups.all,
                      hint: 'Select',
                      errorText: _serverErrors['blood_group'],
                      onChanged: (value) =>
                          setState(() => _bloodGroup = value),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _StackedField(
                    label: 'Gender',
                    child: _buildDropdown(
                      value: _gender,
                      items: Genders.all,
                      hint: 'Select',
                      errorText: _serverErrors['gender'],
                      onChanged: (value) => setState(() => _gender = value),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            _StackedField(
              label: 'Present Address',
              child: TextFormField(
                controller: _addressController,
                enabled: !_isSaving,
                maxLines: 3,
                maxLength: 255,
                textInputAction: TextInputAction.newline,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textDark,
                ),
                decoration: _boxDecoration(
                  hint: 'House, road, area, city',
                  errorText: _serverErrors['present_address'],
                ).copyWith(counterText: ''),
              ),
            ),
            const SizedBox(height: 26),

            Center(
              child: PrimaryButton(
                label: _isSaving ? 'Saving...' : 'Save changes',
                onPressed: _isSaving ? null : _onSavePressed,
                glow: !_isSaving,
                width: 220,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// The avatar, with a camera badge that opens the picker.
  Widget _buildPhotoPicker() {
    final photo = _profile?.photoUrl;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 52,
                backgroundColor: AppColors.logoGreen.withValues(alpha: 0.15),
                // A NetworkImage keyed on the file name, which PHP changes on
                // every upload, so a new picture never shows the old one from
                // the image cache.
                backgroundImage: photo == null
                    ? null
                    : NetworkImage(photo.toString()),
                child: photo != null
                    ? null
                    : const Icon(
                        Icons.person,
                        size: 56,
                        color: AppColors.logoGreen,
                      ),
              ),

              // Sits over the avatar while the file is on its way up.
              if (_isUploading)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.35),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
                ),

              Positioned(
                right: 0,
                bottom: 0,
                child: Material(
                  color: AppColors.logoGreen,
                  shape: const CircleBorder(),
                  elevation: 2,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _pickPhoto,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.photo_camera,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _pickPhoto,
            style: TextButton.styleFrom(foregroundColor: AppColors.logoGreen),
            child: Text(
              _profile?.hasPhoto == true
                  ? 'Change profile picture'
                  : 'Add a profile picture',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  /// The date box, which opens the picker instead of a keyboard.
  Widget _buildDateOfBirthField() {
    return _StackedField(
      label: 'Date of Birth',
      child: InkWell(
        onTap: _pickDateOfBirth,
        borderRadius: BorderRadius.circular(6),
        child: InputDecorator(
          decoration: _boxDecoration(
            errorText: _serverErrors['date_of_birth'],
          ).copyWith(suffixIcon: const Icon(Icons.calendar_month_outlined)),
          child: Text(
            _dateOfBirth == null
                ? 'dd/mm/yyyy'
                : formatDateOfBirth(toIsoDate(_dateOfBirth!)),
            style: TextStyle(
              fontSize: 16,
              color: _dateOfBirth == null
                  ? AppColors.textMuted
                  : AppColors.textDark,
            ),
          ),
        ),
      ),
    );
  }

  /// Filled in by the date of birth above it, never typed.
  Widget _buildAgeField() {
    return _StackedField(
      label: 'Age (years)',
      child: InputDecorator(
        decoration: _boxDecoration().copyWith(
          // Greyed so it reads as something the app worked out, not something
          // waiting to be filled in.
          fillColor: AppColors.background,
        ),
        child: Text(
          _ageText.isEmpty ? '-' : _ageText,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _ageText.isEmpty
                ? AppColors.textMuted
                : AppColors.textDark,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    required String hint,
    required ValueChanged<String?> onChanged,
    String? errorText,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      style: const TextStyle(fontSize: 16, color: AppColors.textDark),
      hint: Text(
        hint,
        style: const TextStyle(fontSize: 16, color: AppColors.textMuted),
      ),
      items: items
          .map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(item, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: _isSaving ? null : onChanged,
      decoration: _boxDecoration(errorText: errorText),
    );
  }

  /// The same box as [LabeledTextField] draws, so the stacked fields below do
  /// not look like they came from a different form than the two above them.
  InputDecoration _boxDecoration({String? hint, String? errorText}) {
    OutlineInputBorder border(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 16, color: AppColors.textMuted),
      errorText: errorText,
      errorMaxLines: 2,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 14,
      ),
      enabledBorder: border(AppColors.fieldBorder),
      disabledBorder: border(AppColors.fieldBorder.withValues(alpha: 0.4)),
      focusedBorder: border(AppColors.logoGreen, 2),
      errorBorder: border(Colors.red),
      focusedErrorBorder: border(Colors.red, 2),
    );
  }
}

/// A label sitting above its field, the way the wireframe draws the bottom
/// half of this form.
///
/// The two fields at the top keep their label on the left instead, because
/// that is how the wireframe draws them and how every other form in the app
/// already looks.
class _StackedField extends StatelessWidget {
  const _StackedField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}
