import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/screen_header.dart';

/// Who is reading the terms. A patient and a doctor agree to different things,
/// so each registration screen opens its own version.
enum TermsAudience { patient, doctor }

/// The page behind the underlined "terms & conditions" link on the details
/// screens.
/// Plain text only - nothing here is saved to the database. The user's answer
/// to the checkbox lives on the details screen and is sent with the form.
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key, required this.audience});

  final TermsAudience audience;

  /// What a patient agrees to: how their account and records are handled.
  static const List<_TermsSection> _patientSections = [
    _TermsSection(
      title: '1. Using this app',
      body:
          'Health Care lets you register as a patient, book appointments with '
          'doctors, keep your health records, order medicine and request lab '
          'tests. You must be at least 18 years old, or use the app with the '
          'help of a parent or guardian.',
    ),
    _TermsSection(
      title: '2. Your account',
      body:
          'You register with your phone number and a password. Keep your '
          'password to yourself - anything done from your account is treated '
          'as done by you. Please give correct information when you register, '
          'because doctors rely on it when they treat you.',
    ),
    _TermsSection(
      title: '3. Medical advice',
      body:
          'This app helps you reach doctors and keep your records in one '
          'place. It does not give medical advice by itself. In an emergency, '
          'contact a hospital directly instead of using the app.',
    ),
    _TermsSection(
      title: '4. Your information',
      body:
          'Your name, phone number and health records are stored so the app '
          'can work. Your password is never stored as you typed it - it is '
          'converted into a hash that cannot be read back. Your records are '
          'shared only with the doctors you book an appointment with.',
    ),
    _TermsSection(
      title: '5. Payments and orders',
      body:
          'Prices for medicine and lab tests are shown before you confirm an '
          'order. Once an order is placed you can cancel it only while it is '
          'still pending.',
    ),
    _TermsSection(
      title: '6. Changes to these terms',
      body:
          'These terms may be updated as the app grows. Continuing to use the '
          'app after an update means you accept the updated terms.',
    ),
  ];

  /// What a doctor agrees to: proving the licence, treating patients, and
  /// handling patient data that is not their own.
  static const List<_TermsSection> _doctorSections = [
    _TermsSection(
      title: '1. Practising through this app',
      body:
          'Health Care lets you publish your schedule, accept appointments, '
          'write prescriptions and view the records of the patients who book '
          'you. You may use the app only for your own practice, and never on '
          'behalf of another person.',
    ),
    _TermsSection(
      title: '2. Your licence',
      body:
          'The licence number you register with must be your own, valid, and '
          'currently in force. Registering with a licence that is not yours, '
          'has expired, or has been suspended is a misuse of the app and the '
          'account will be removed. You agree to update your details if your '
          'registration status changes.',
    ),
    _TermsSection(
      title: '3. Your department and profile',
      body:
          'The department you choose decides where patients find you when they '
          'search for a doctor, so choose the one you actually practise in. '
          'Keep your specialization, experience and schedule accurate, because '
          'patients pick a doctor based on what your profile says.',
    ),
    _TermsSection(
      title: '4. Care you give',
      body:
          'You remain fully responsible for your own clinical decisions. The '
          'app records appointments and prescriptions but does not review, '
          'approve or correct them. Prescriptions you issue through the app '
          'carry the same weight as ones you write on paper.',
    ),
    _TermsSection(
      title: '5. Patient information',
      body:
          'Records you can see through the app belong to your patients, not to '
          'you. Open a record only when it belongs to a patient you are '
          'treating, use it only for that treatment, and never share it '
          'outside the app. Your password is stored only as a hash that cannot '
          'be read back.',
    ),
    _TermsSection(
      title: '6. Appointments you accept',
      body:
          'Once you accept an appointment, patients rely on you being there. '
          'Cancel as early as you can if something changes, so the slot can be '
          'given to another patient.',
    ),
    _TermsSection(
      title: '7. Changes to these terms',
      body:
          'These terms may be updated as the app grows. Continuing to use the '
          'app after an update means you accept the updated terms.',
    ),
  ];

  List<_TermsSection> get _sections {
    switch (audience) {
      case TermsAudience.patient:
        return _patientSections;
      case TermsAudience.doctor:
        return _doctorSections;
    }
  }

  String get _intro {
    switch (audience) {
      case TermsAudience.patient:
        return 'Please read these terms before creating your Health Care '
            'account.';
      case TermsAudience.doctor:
        return 'Please read these terms before registering as a doctor on '
            'Health Care.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ScreenHeader(title: 'Terms & Conditions'),
              const SizedBox(height: 20),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _intro,
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.textMuted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),

                      for (final section in _sections) ...[
                        Text(
                          section.title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          section.body,
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.textDark,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],
                    ],
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
/// One numbered block of the terms text.
class _TermsSection {
  const _TermsSection({required this.title, required this.body});

  final String title;
  final String body;
}