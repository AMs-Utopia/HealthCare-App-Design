import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_name_header.dart';
import 'create_account_screen.dart';
import 'doctor_dashboard_screen.dart';
import '../widgets/labeled_text_field.dart';
import '../widgets/primary_button.dart';
import 'patient_dashboard_screen.dart';

/// Screen 1 - Sign in.
///
/// The form is laid out exactly as in the wireframe. The phone and password
/// are checked by `api/login.php`, which looks in PATIENT first and then in
/// DOCTOR, so both kinds of account sign in here.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  /// True while the API call is running, so the form cannot be sent twice.
  bool _isSigningIn = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onSignInPressed() async {
    // Check the fields first so an empty form never reaches the server.
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSigningIn = true);

    final result = await AuthService.login(
      phone: _phoneController.text.trim(),
      password: _passwordController.text,
    );

    // The screen can be gone by the time the reply arrives.
    if (!mounted) return;

    setState(() => _isSigningIn = false);

    final user = result.user;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error?.message ?? 'Could not sign in.'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }
    // Replace rather than push, so the back button does not walk back into
    // the sign in form of an account that is already signed in. Which
    // dashboard opens depends on the table the account came from.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => user.isPatient
            ? PatientDashboardScreen(user: user)
            : DoctorDashboardScreen(user: user),
      ),
    );
  }

  void _onRegisterPressed() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateAccountScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        // LayoutBuilder + IntrinsicHeight lets the bottom register text sit at
        // the bottom of the screen while the page can still scroll when the
        // keyboard covers the fields.
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AppNameHeader(title: 'Health Care'),
                      const SizedBox(height: 28),

                      Image.asset(
                        'assets/images/logo.jpg',
                        height: 170,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 32),

                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            LabeledTextField(
                              label: 'Phone',
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              enabled: !_isSigningIn,
                              textInputAction: TextInputAction.next,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your phone number';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 18),
                            LabeledTextField(
                              label: 'Password',
                              controller: _passwordController,
                              obscureText: true,
                              enabled: !_isSigningIn,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) {
                                if (!_isSigningIn) _onSignInPressed();
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your password';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),

                      Center(
                        child: PrimaryButton(
                          label: _isSigningIn ? 'Signing in...' : 'Sign in',
                          onPressed: _isSigningIn ? null : _onSignInPressed,
                        ),
                      ),

                      // Pushes the register message towards the bottom.
                      const Expanded(child: SizedBox(height: 30)),

                      const Text(
                        "Don't have an account?",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Center(
                        child: GestureDetector(
                          onTap: _onRegisterPressed,
                          child: const Text(
                            'Register',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: AppColors.logoBlue,
                              decoration: TextDecoration.underline,
                              decorationColor: AppColors.logoBlue,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
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
}