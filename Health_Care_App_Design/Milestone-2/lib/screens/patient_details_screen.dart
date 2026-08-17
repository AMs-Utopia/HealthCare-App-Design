import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../services/patient_service.dart';
import '../theme/app_colors.dart';
import '../widgets/labeled_text_field.dart';
import '../widgets/primary_button.dart';
import '../widgets/screen_header.dart';
import 'terms_screen.dart';

/// Screen 3 (User / Patient) - Details.

/// Reached from the create account screen when "User / Patient" is chosen.
/// Submitting inserts one row into the PATIENT table through
/// `api/register_patient.php`.
class PatientDetailsScreen extends StatefulWidget {
  const PatientDetailsScreen({super.key});

  @override
  State<PatientDetailsScreen> createState() => _PatientDetailsScreenState();
}

class _PatientDetailsScreenState extends State<PatientDetailsScreen> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  /// Makes the underlined part of the checkbox label tappable.
  late final TapGestureRecognizer _termsRecognizer;
  /// The Submit button stays dull until this is ticked.
  bool _agreedToTerms = false;
  /// True while the API call is running, so the form cannot be submitted twice.
  bool _isSaving = false;
  /// Errors sent back by PHP, keyed by the field name in the request.
  Map<String, String> _serverErrors = {};

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()..onTap = _openTerms;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _termsRecognizer.dispose();
    super.dispose();
  }

  void _openTerms() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const TermsScreen(audience: TermsAudience.patient),
      ),
    );
  }

  Future<void> _onSubmitPressed() async {
    // A server error is about the values as they were when it was sent, so
    // clear it before checking the form again.
    setState(() => _serverErrors = {});

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    final response = await PatientService.register(
      fullName: _fullNameController.text.trim(),
      phone: _phoneController.text.trim(),
      password: _passwordController.text,
      confirmPassword: _confirmPasswordController.text,
      agreedToTerms: _agreedToTerms,
    );

    // The screen can be gone by the time the reply arrives.
    if (!mounted) return;

    setState(() {
      _isSaving = false;
      _serverErrors = response.fieldErrors;
    });

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

    await _showSuccessDialog(response.data);
  }
  /// Shows what was actually written to the database, then returns the user to
  /// the sign in screen.
  Future<void> _showSuccessDialog(Map<String, dynamic>? data) async {
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
              Text('Account created'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your details were saved to the database.'),
              if (data != null) ...[
                const SizedBox(height: 14),
                Text(
                  'Patient ID : ${data['patient_uid'] ?? data['patient_id']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Phone : ${data['phone'] ?? ''}',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ],
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

    if (!mounted) return;

    // Back to the sign in screen, which is the first route of the app.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    // Same rule as the Continue button on the create account screen: dull and
    // unusable until the user has made the required choice.
    final canSubmit = _agreedToTerms && !_isSaving;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 24,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const ScreenHeader(title: 'Details'),
                      const SizedBox(height: 28),

                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            LabeledTextField(
                              label: 'Full Name',
                              controller: _fullNameController,
                              isRequired: true,
                              enabled: !_isSaving,
                              labelWidth: 120,
                              keyboardType: TextInputType.name,
                              textInputAction: TextInputAction.next,
                              errorText: _serverErrors['full_name'],
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your full name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 18),

                            LabeledTextField(
                              label: 'Phone',
                              controller: _phoneController,
                              isRequired: true,
                              enabled: !_isSaving,
                              labelWidth: 120,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                              errorText: _serverErrors['phone'],
                              validator: (value) {
                                final phone = value?.trim() ?? '';
                                if (phone.isEmpty) {
                                  return 'Please enter your phone number';
                                }
                                // Same rule as the PHP side, so the user gets
                                // the message without waiting for the server.
                                if (!RegExp(r'^01[0-9]{9}$').hasMatch(phone)) {
                                  return 'Enter an 11 digit number, e.g. 01712345678';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 18),

                            LabeledTextField(
                              label: 'Password',
                              controller: _passwordController,
                              isRequired: true,
                              enabled: !_isSaving,
                              labelWidth: 120,
                              obscureText: true,
                              textInputAction: TextInputAction.next,
                              errorText: _serverErrors['password'],
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a password';
                                }
                                if (value.length < 6) {
                                  return 'Use at least 6 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 18),

                            LabeledTextField(
                              label: 'Confirm\npassword',
                              controller: _confirmPasswordController,
                              isRequired: true,
                              enabled: !_isSaving,
                              labelWidth: 120,
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              errorText: _serverErrors['confirm_password'],
                              onFieldSubmitted: (_) {
                                if (canSubmit) _onSubmitPressed();
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please confirm your password';
                                }
                                if (value != _passwordController.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 26),

                      _buildTermsRow(),
                      const SizedBox(height: 26),

                      Align(
                        alignment: Alignment.centerRight,
                        child: PrimaryButton(
                          label: _isSaving ? 'Saving...' : 'Submit',
                          onPressed: canSubmit ? _onSubmitPressed : null,
                          glow: canSubmit,
                          width: 160,
                        ),
                      ),

                      const Expanded(child: SizedBox(height: 20)),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
  /// The checkbox and its label, where only "terms & conditions" is a link.
  Widget _buildTermsRow() {
    void toggle() {
      if (_isSaving) return;
      setState(() => _agreedToTerms = !_agreedToTerms);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 28,
          height: 28,
          child: Checkbox(
            value: _agreedToTerms,
            onChanged: _isSaving ? null : (_) => toggle(),
            activeColor: AppColors.logoGreen,
            side: const BorderSide(color: AppColors.textDark, width: 2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            // Tapping the sentence ticks the box; the underlined part has its
            // own recognizer and opens the terms instead.
            onTap: toggle,
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text.rich(
                TextSpan(
                  text: 'I agree with the ',
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textDark,
                    height: 1.35,
                  ),
                  children: [
                    TextSpan(
                      text: 'terms & conditions',
                      recognizer: _termsRecognizer,
                      style: const TextStyle(
                        color: AppColors.logoBlue,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.logoBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}