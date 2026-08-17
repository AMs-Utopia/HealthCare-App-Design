// Widget tests for screen 1 (sign in), screen 2 (create account) and the
// patient dashboard with its drawer.
//
// Nothing here touches the PHP API - the dashboard is given an account
// directly, the same way the sign in screen hands one over after login.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:healthcare_app/main.dart';
import 'package:healthcare_app/models/department.dart';
import 'package:healthcare_app/models/doctor_listing.dart';
import 'package:healthcare_app/models/appointment.dart';
import 'package:healthcare_app/models/hospital.dart';
import 'package:healthcare_app/models/signed_in_user.dart';
import 'package:healthcare_app/models/weekday.dart';
import 'package:healthcare_app/screens/add_degrees_screen.dart';
import 'package:healthcare_app/screens/add_schedule_screen.dart';
import 'package:healthcare_app/screens/appointments_list_screen.dart';
import 'package:healthcare_app/screens/book_slot_screen.dart';
import 'package:healthcare_app/screens/choose_area_screen.dart';
import 'package:healthcare_app/screens/choose_department_screen.dart';
import 'package:healthcare_app/screens/create_account_screen.dart';
import 'package:healthcare_app/screens/doctor_dashboard_screen.dart';
import 'package:healthcare_app/screens/doctors_list_screen.dart';
import 'package:healthcare_app/screens/hospitals_screen.dart';
import 'package:healthcare_app/screens/patient_dashboard_screen.dart';
import 'package:healthcare_app/screens/sign_in_screen.dart';
import 'package:healthcare_app/theme/app_colors.dart';
import 'package:healthcare_app/widgets/primary_button.dart';

/// The default test surface is 800x600, which is wider and much shorter than a
/// phone, so widgets near the bottom end up off-screen and cannot be tapped.
/// This sets a normal phone size (360x800 logical pixels) instead.
void usePhoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

/// Pumps frames until [finder] matches something, for screens that are waiting
/// on an API call. pumpAndSettle cannot be used while a spinner is on screen
/// because its animation never ends.
Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  int maxPumps = 30,
}) async {
  for (var i = 0; i < maxPumps; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Stand-ins for the accounts api/login.php returns, shared by every group.
const signedInPatient = SignedInUser(
  accountType: SignedInAccountType.patient,
  id: 1,
  fullName: 'Ahnaf Muhtasim',
  phone: '01765276162',
  patientUid: 'PAT00001',
);

const ibneSina = Hospital(
  id: 21,
  name: 'Ibne Sina Hospital',
  area: 'Badda',
  address: 'Badda, Dhaka',
);

const signedInDoctor = SignedInUser(
  accountType: SignedInAccountType.doctor,
  id: 1,
  fullName: 'Ashfaq',
  phone: '01533565762',
  licenseNo: 'BX-2855',
  departmentName: 'Gastroenterology',
);

void main() {
  group('Screen 1 - sign in', () {
    testWidgets('shows the app name, fields and register link', (
      WidgetTester tester,
    ) async {
      usePhoneScreen(tester);
      await tester.pumpWidget(const HealthCareApp());

      expect(find.text('Health Care'), findsOneWidget);
      expect(find.text('Phone :'), findsOneWidget);
      expect(find.text('Password :'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text("Don't have an account?"), findsOneWidget);
      expect(find.text('Register'), findsOneWidget);
    });

    testWidgets('shows validation errors when the fields are empty', (
      WidgetTester tester,
    ) async {
      usePhoneScreen(tester);
      await tester.pumpWidget(const HealthCareApp());

      await tester.tap(find.text('Sign in'));
      await tester.pump();

      expect(find.text('Please enter your phone number'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);
    });

    testWidgets('tapping Register opens the create account screen', (
      WidgetTester tester,
    ) async {
      usePhoneScreen(tester);
      await tester.pumpWidget(const HealthCareApp());

      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();

      expect(find.byType(CreateAccountScreen), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
    });
  });

  group('Screen 2 - create account', () {
    /// Pumps the app and navigates from sign in to the create account screen.
    Future<void> openCreateAccount(WidgetTester tester) async {
      usePhoneScreen(tester);
      await tester.pumpWidget(const HealthCareApp());
      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows both account type options and Continue', (
      WidgetTester tester,
    ) async {
      await openCreateAccount(tester);

      expect(find.text('User / Patient'), findsOneWidget);
      expect(find.text('Doctor'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('Continue is disabled until an option is selected', (
      WidgetTester tester,
    ) async {
      await openCreateAccount(tester);

      PrimaryButton button() =>
          tester.widget<PrimaryButton>(find.byType(PrimaryButton));

      // Nothing selected yet.
      expect(button().onPressed, isNull);
      expect(button().glow, isFalse);

      await tester.tap(find.text('User / Patient'));
      await tester.pumpAndSettle();

      // Selecting a card lights up the button and enables it.
      expect(button().onPressed, isNotNull);
      expect(button().glow, isTrue);
    });

    testWidgets('selecting doctor deselects patient', (
      WidgetTester tester,
    ) async {
      await openCreateAccount(tester);

      await tester.tap(find.text('User / Patient'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Doctor'));
      await tester.pumpAndSettle();

      // Only the doctor card should be highlighted in green.
      final patientLabel = tester.widget<Text>(find.text('User / Patient'));
      final doctorLabel = tester.widget<Text>(find.text('Doctor'));
      expect(patientLabel.style!.color, isNot(doctorLabel.style!.color));
    });

    testWidgets('back arrow returns to the sign in screen', (
      WidgetTester tester,
    ) async {
      await openCreateAccount(tester);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.byType(CreateAccountScreen), findsNothing);
      expect(find.text('Sign in'), findsOneWidget);
    });
  });

  group('Patient dashboard and drawer', () {
    Future<void> openDashboard(WidgetTester tester) async {
      usePhoneScreen(tester);
      await tester.pumpWidget(
        const MaterialApp(
          home: PatientDashboardScreen(user: signedInPatient),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> openDrawer(WidgetTester tester) async {
      await openDashboard(tester);
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
    }

    testWidgets('greets the signed in patient and shows the four boxes', (
      WidgetTester tester,
    ) async {
      await openDashboard(tester);

      expect(find.text('Welcome'), findsOneWidget);
      expect(find.text('Ahnaf Muhtasim'), findsOneWidget);
      expect(
        find.text('Search doctors, departments, hospitals'),
        findsOneWidget,
      );
      expect(find.text('Monitor Health'), findsOneWidget);
      expect(find.text('Doctor Lists'), findsOneWidget);
      expect(find.text('Investigation'), findsOneWidget);
      expect(find.text('Call a Hospital'), findsOneWidget);
    });

    testWidgets('the drawer lists all five destinations and the account', (
      WidgetTester tester,
    ) async {
      await openDrawer(tester);

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Appointment'), findsOneWidget);
      expect(find.text('Services'), findsOneWidget);
      expect(find.text('Health Records'), findsOneWidget);

      // The footer shows who is signed in.
      expect(find.text('Ahnaf Muhtasim'), findsWidgets);
      expect(find.text('PAT00001'), findsOneWidget);
      expect(find.byIcon(Icons.logout), findsOneWidget);
    });

    testWidgets('tapping a destination lights it up', (
      WidgetTester tester,
    ) async {
      await openDrawer(tester);

      Color? profileColour() =>
          tester.widget<Text>(find.text('Profile')).style?.color;

      expect(profileColour(), AppColors.textDark);

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      expect(profileColour(), AppColors.logoGreen);
    });

    testWidgets('Home just closes the drawer', (WidgetTester tester) async {
      await openDrawer(tester);

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      // Back on the dashboard with the drawer gone.
      expect(find.text('Profile'), findsNothing);
      expect(find.text('Monitor Health'), findsOneWidget);
    });

    testWidgets('logout returns to the sign in screen', (
      WidgetTester tester,
    ) async {
      await openDrawer(tester);

      await tester.tap(find.byIcon(Icons.logout));
      await tester.pumpAndSettle();

      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.byType(PatientDashboardScreen), findsNothing);
    });

    testWidgets('Doctor Lists opens the choose area screen', (
      WidgetTester tester,
    ) async {
      await openDashboard(tester);

      await tester.tap(find.text('Doctor Lists'));
      // Not pumpAndSettle: the screen shows a spinner while it loads, and a
      // spinner never settles.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(ChooseAreaScreen), findsOneWidget);
      expect(find.text('Choose Area'), findsOneWidget);

      // flutter_test blocks real network calls, so the areas cannot load and
      // the screen must offer a way to retry rather than sit on the spinner.
      await pumpUntil(tester, find.text('Try again'));
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('Doctor dashboard and drawer', () {
    Future<void> openDoctorDashboard(WidgetTester tester) async {
      usePhoneScreen(tester);
      await tester.pumpWidget(
        const MaterialApp(
          home: DoctorDashboardScreen(user: signedInDoctor),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('greets the doctor by title and shows the four boxes', (
      WidgetTester tester,
    ) async {
      await openDoctorDashboard(tester);

      expect(find.text('Welcome'), findsOneWidget);
      expect(find.text('Dr. Ashfaq'), findsOneWidget);

      expect(find.text('Add Schedule'), findsOneWidget);
      expect(find.text('Add Degrees'), findsOneWidget);
      expect(find.text('Check Appointments'), findsOneWidget);
      expect(find.text('EMR Details of Patients'), findsOneWidget);

      // The doctor dashboard has no search bar.
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('the drawer shows only Home and Chamber Info', (
      WidgetTester tester,
    ) async {
      await openDoctorDashboard(tester);
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Chamber Info'), findsOneWidget);

      // The patient only entries must not leak into the doctor's drawer.
      expect(find.text('Profile'), findsNothing);
      expect(find.text('Appointment'), findsNothing);
      expect(find.text('Services'), findsNothing);
      expect(find.text('Health Records'), findsNothing);

      // The footer shows the doctor's department rather than a patient UID.
      expect(find.text('Gastroenterology'), findsOneWidget);
      expect(find.byIcon(Icons.logout), findsOneWidget);
    });

    testWidgets('tapping a box lights it up', (WidgetTester tester) async {
      await openDoctorDashboard(tester);

      Color? scheduleColour() =>
          tester.widget<Text>(find.text('Add Schedule')).style?.color;

      expect(scheduleColour(), AppColors.textDark);

      await tester.tap(find.text('Add Schedule'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(scheduleColour(), AppColors.logoGreen);
    });

    testWidgets('logout returns the doctor to the sign in screen', (
      WidgetTester tester,
    ) async {
      await openDoctorDashboard(tester);
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.logout));
      await tester.pumpAndSettle();

      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.byType(DoctorDashboardScreen), findsNothing);
    });
  });

  group('Weekday codes', () {
    test('parses a stored csv back into days in week order', () {
      // Stored out of order on purpose.
      expect(
        Weekday.parseCsv('Wed,Sat,Mon'),
        [Weekday.sat, Weekday.mon, Weekday.wed],
      );
    });

    test('ignores empty and unknown codes', () {
      expect(Weekday.parseCsv(null), isEmpty);
      expect(Weekday.parseCsv(''), isEmpty);
      expect(Weekday.parseCsv('Funday,Sat'), [Weekday.sat]);
    });

    test('always writes days back in week order', () {
      expect(
        Weekday.toCsv([Weekday.fri, Weekday.sat, Weekday.tue]),
        'Sat,Tue,Fri',
      );
    });

    test('all seven days still fit in weekday varchar(30)', () {
      final csv = Weekday.toCsv(Weekday.values);

      expect(csv, 'Sat,Sun,Mon,Tue,Wed,Thu,Fri');
      // This is the constraint that forced short codes in the first place.
      expect(csv.length, lessThanOrEqualTo(30));
    });

    test('describes days with their full names', () {
      expect(
        Weekday.describe([Weekday.mon, Weekday.sat]),
        'Saturday, Monday',
      );
    });
  });

  group('Add schedule screen', () {
    testWidgets('shows the title and offers a retry when the API is down', (
      WidgetTester tester,
    ) async {
      usePhoneScreen(tester);
      await tester.pumpWidget(
        const MaterialApp(home: AddScheduleScreen(doctor: signedInDoctor)),
      );
      await tester.pump();

      expect(find.text('Add Schedule'), findsOneWidget);

      await pumpUntil(tester, find.text('Try again'));
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('Add degrees screen', () {
    testWidgets('shows the title and offers a retry when the API is down', (
      WidgetTester tester,
    ) async {
      usePhoneScreen(tester);
      await tester.pumpWidget(
        const MaterialApp(home: AddDegreesScreen(doctor: signedInDoctor)),
      );
      await tester.pump();

      expect(find.text('Add Degrees'), findsOneWidget);

      await pumpUntil(tester, find.text('Try again'));
      expect(find.text('Try again'), findsOneWidget);

      // With nothing loaded there is nothing to save, so Update must not be
      // offered at all.
      expect(find.text('Update'), findsNothing);
    });
  });

  group('Hospitals screen', () {
    testWidgets('shows the title and the area it is listing', (
      WidgetTester tester,
    ) async {
      usePhoneScreen(tester);
      await tester.pumpWidget(
        const MaterialApp(
          home: HospitalsScreen(area: 'Badda', patient: signedInPatient),
        ),
      );
      await tester.pump();

      expect(find.text('Hospitals'), findsOneWidget);
      expect(find.text('Badda'), findsOneWidget);

      // Same as the area screen: no network in tests, so it must offer a retry
      // instead of spinning forever.
      await pumpUntil(tester, find.text('Try again'));
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('Choose department screen', () {
    testWidgets('shows the title and the hospital it is listing for', (
      WidgetTester tester,
    ) async {
      usePhoneScreen(tester);
      await tester.pumpWidget(
        const MaterialApp(
          home: ChooseDepartmentScreen(
            hospital: ibneSina,
            patient: signedInPatient,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Choose Department'), findsOneWidget);
      expect(find.text('Ibne Sina Hospital'), findsOneWidget);

      await pumpUntil(tester, find.text('Try again'));
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('doctors list shows the department and hospital together', (
      WidgetTester tester,
    ) async {
      usePhoneScreen(tester);
      await tester.pumpWidget(
        const MaterialApp(
          home: DoctorsListScreen(
            hospital: ibneSina,
            department: Department(id: 12, name: 'Gastroenterology'),
            patient: signedInPatient,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Doctors List'), findsOneWidget);
      expect(
        find.text('Gastroenterology  ·  Ibne Sina Hospital'),
        findsOneWidget,
      );

      await pumpUntil(tester, find.text('Try again'));
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('Book a slot screen', () {
    final gastroDoctor = DoctorListing.fromJson(const {
      'doctor_id': 5,
      'schedule_id': 4,
      'full_name': 'Mahfuzur Rahman',
      'department_name': 'Gastroenterology',
      'weekday': 'Sun,Wed',
      'time_slot': '10:00 AM - 2:00 PM',
      'offday': 'Fri',
      'degrees': 'MBBS, MD (Gastroenterology), MRCP (UK)',
    });

    testWidgets('shows the doctor and prefills the form from the account', (
      WidgetTester tester,
    ) async {
      usePhoneScreen(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: BookSlotScreen(
            patient: signedInPatient,
            doctor: gastroDoctor,
            hospital: ibneSina,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Book a Slot'), findsOneWidget);
      expect(find.text('Application Form'), findsOneWidget);

      // Doctor name, qualifications and department, as in the wireframe.
      expect(find.text('Dr. Mahfuzur Rahman'), findsOneWidget);
      expect(
        find.text('MBBS, MD (Gastroenterology), MRCP (UK)'),
        findsOneWidget,
      );
      expect(find.text('Gastroenterology'), findsOneWidget);

      // Name and mobile start from the signed in account.
      expect(find.text('Ahnaf Muhtasim'), findsOneWidget);
      expect(find.text('01765276162'), findsOneWidget);
    });

    testWidgets('Submit stays dark until a date and a type are chosen', (
      WidgetTester tester,
    ) async {
      usePhoneScreen(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: BookSlotScreen(
            patient: signedInPatient,
            doctor: gastroDoctor,
            hospital: ibneSina,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final button = tester.widget<PrimaryButton>(
        find.byType(PrimaryButton),
      );
      expect(button.onPressed, isNull);
      expect(button.glow, isFalse);
    });
  });

  group('Doctor appointments', () {
    testWidgets('appointments list opens and offers a retry when API is down', (
      WidgetTester tester,
    ) async {
      usePhoneScreen(tester);
      await tester.pumpWidget(
        const MaterialApp(
          home: AppointmentsListScreen(doctor: signedInDoctor),
        ),
      );
      await tester.pump();

      expect(find.text('Appointments List'), findsOneWidget);

      await pumpUntil(tester, find.text('Try again'));
      expect(find.text('Try again'), findsOneWidget);
    });

    test('reads an appointment row the way the API sends it', () {
      final appointment = DoctorAppointment.fromJson(const {
        'appointment_id': 2,
        'serial_no': 2,
        'patient_name': 'Second Tester',
        'patient_uid': 'PAT00004',
        'age': null,
        'visit_type': 'Report Check',
        'status': 'Pending',
        'appointment_date': '2026-08-19',
        'appointment_time': '10:00 AM - 2:00 PM',
        'contact_mobile': '01999777444',
        'hospital_name': 'Ibne Sina Hospital',
      });

      expect(appointment.serialNo, 2);
      expect(appointment.patientUid, 'PAT00004');
      // No screen collects a date of birth yet, so age comes back null.
      expect(appointment.age, isNull);
      // Pending is what puts the dot on the doctor's bell.
      expect(appointment.isNew, isTrue);
    });

    test('formats an appointment date for display', () {
      expect(formatAppointmentDate('2026-08-19'), 'Wed, 19 Aug 2026');
      // A value that is not a date is shown as it came, not crashed on.
      expect(formatAppointmentDate('not a date'), 'not a date');
    });
  });

  group('Doctor listing model', () {
    test('reads a doctor row the way the API sends it', () {
      final doctor = DoctorListing.fromJson(const {
        'doctor_id': 5,
        'full_name': 'Mahfuzur Rahman',
        'department_name': 'Gastroenterology',
        'license_no': 'BMDC-A-40123',
        'weekday': 'Wed,Sun',
        'time_slot': '10:00 AM - 2:00 PM',
        'offday': 'Fri',
        'degrees': 'MBBS, MD (Gastroenterology), MRCP (UK)',
        'chamber_no': null,
        'floor_no': null,
      });

      expect(doctor.displayName, 'Dr. Mahfuzur Rahman');
      // Days come back in week order regardless of how they were stored.
      expect(doctor.weekdays, [Weekday.sun, Weekday.wed]);
      expect(doctor.offday, Weekday.fri);
      expect(doctor.degrees, 'MBBS, MD (Gastroenterology), MRCP (UK)');
      // Nothing to show until the chamber info screen exists.
      expect(doctor.chamberLine, isNull);
    });

    test('builds a chamber line once the doctor fills it in', () {
      final doctor = DoctorListing.fromJson(const {
        'doctor_id': 1,
        'full_name': 'Ashfaq',
        'department_name': 'Gastroenterology',
        'weekday': 'Sat',
        'time_slot': '4:00 PM - 10:00 PM',
        'chamber_no': '204',
        'floor_no': '2',
      });

      expect(doctor.chamberLine, 'Chamber 204, Floor 2');
    });
  });
}
