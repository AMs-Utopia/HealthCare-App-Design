import 'package:flutter/material.dart';

import '../models/account_type.dart';
import '../theme/app_colors.dart';
import '../widgets/account_type_card.dart';
import '../widgets/primary_button.dart';
import 'doctor_details_screen.dart';
import 'patient_details_screen.dart';

/// Screen 2 - Create account.
/// The user picks whether they are registering as a patient or as a doctor.
/// Nothing is saved here; the choice is only passed on to the registration
/// form screen, which decides whether to insert into PATIENT or DOCTOR.
class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  /// Null until the user taps one of the two cards.
  AccountType? _selectedType;
  void _selectType(AccountType type) {
    setState(() {
      _selectedType = type;
    });
  }

  void _onContinuePressed() {
    final selected = _selectedType;
    if (selected == null) {
      return; // The button is disabled in this case anyway.
    }

    switch (selected) {
      case AccountType.patient:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PatientDetailsScreen()),
        );
      case AccountType.doctor:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const DoctorDetailsScreen()),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = _selectedType != null;

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
                      // Back arrow, as drawn in the top left of the wireframe.
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back),
                          color: AppColors.textDark,
                          iconSize: 28,
                          tooltip: 'Back',
                        ),
                      ),

                      Image.asset(
                        'assets/images/logo.jpg',
                        height: 150,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 20),

                      const Text(
                        'Create Account',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 36),

                      // IntrinsicHeight keeps both cards the same height even
                      // though "User / Patient" wraps onto two lines.
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: AccountTypeCard(
                                icon: Icons.person,
                                label: AccountType.patient.label,
                                selected:
                                    _selectedType == AccountType.patient,
                                onTap: () => _selectType(AccountType.patient),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: AccountTypeCard(
                                // Flutter has no built-in stethoscope icon,
                                // so the medical bag is used instead.
                                icon: Icons.medical_services,
                                label: AccountType.doctor.label,
                                selected: _selectedType == AccountType.doctor,
                                onTap: () => _selectType(AccountType.doctor),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),

                      Center(
                        child: PrimaryButton(
                          label: 'Continue',
                          trailingIcon: Icons.arrow_forward,
                          // Disabled and dull until a card is selected.
                          onPressed:
                              hasSelection ? _onContinuePressed : null,
                          glow: hasSelection,
                          width: 210,
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
}