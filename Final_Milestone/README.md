# Health Care

A doctor appointment, electronic medical record and patient health management app for Android.

Built for **CSE 489 – Mobile Application Development**. The app is written in Flutter and talks to a PHP REST API of its own over HTTP; the API is the only thing that touches MySQL.

| | |
|---|---|
| **Front end** | Flutter (Dart SDK `^3.13.0`), Material 3, Android only |
| **Back end** | Plain PHP REST API on XAMPP (Apache + PHP) |
| **Database** | MySQL / MariaDB — `healthcare_db`, 23 tables, mysqli + utf8mb4 |
| **Auth** | HMAC-SHA256 signed tokens, checked centrally on every request |
| **Size** | ~28,400 lines of Dart across 102 files · ~15,000 lines of PHP across 94 files |

---

## Contents

- [What it does](#what-it-does)
- [Architecture](#architecture)
- [Repository layout](#repository-layout)
- [Getting started](#getting-started)
- [Configuration](#configuration)
- [The API](#the-api)
- [The database](#the-database)
- [Design decisions worth knowing](#design-decisions-worth-knowing)
- [Packages used](#packages-used)
- [Testing notes](#testing-notes)
- [Known issues](#known-issues)
- [Troubleshooting](#troubleshooting)
- [Project information](#project-information)

---

## What it does

One sign-in screen serves two kinds of account. The account type returned by the API decides which dashboard opens, and the drawer, the bottom bar and the available screens follow from there.

### For a patient

| Feature | What it does |
|---|---|
| **Doctor search & filtering** | One typed line — "gastric doctor in Dhanmondi" — is read by the server, which works out whether it meant a speciality, a hospital, an area, an experience level or an availability, and hands back what it understood so the patient can narrow it with chips. |
| **Browse by area / hospital / department** | Pick an area, see its hospitals, see each hospital's departments, then the doctors who sit in that department. |
| **Appointment booking** | A doctor's sitting is cut into fifteen-minute serials. The form previews the exact time the patient would get, and refuses a slot that is already full or past the sitting's closing time. |
| **Manage appointments** | Reschedule or cancel. Every action is kept as a history row, colour-coded as booked / rescheduled / cancelled, and the doctor sees the change too. |
| **Health dashboard** | Blood pressure, blood sugar, heart rate, weight, height and BMI, each drawn on a bar of reference bands with a marker on it rather than as a bare number. |
| **Health records** | The patient's own filing cabinet — prescriptions, lab reports, X-rays, scans, discharge summaries and other documents, uploaded from the phone's file browser and filed by type. |
| **Prescriptions & medication** | Digital prescriptions from every visit; each medicine shows who prescribed it, how to take it and how much is left, and can be marked completed or reordered. |
| **Order medicine** | Brand search over the MedEx catalogue, price lookup, delivery address, order placement, and an order history that shows what was actually charged at the time. |
| **Lab tests** | The tests on offer with their prices, booked against the patient's account. |
| **Call a hospital** | Opens the phone's dialler with the number filled in. The app never places the call itself. |
| **Notifications** | Appointment changes, medicine orders and lab bookings merged into one list behind the bell. Opening the list clears the dot. |
| **Health tips** | An in-app article list and reader. |
| **Profile & addresses** | Edit details, set a profile photo from gallery or camera, and keep several addresses with exactly one marked as the present one. |

### For a doctor

| Feature | What it does |
|---|---|
| **Add schedule** | Hospital, weekday, time slot, off day, chamber number and floor. The patient's booking form reads these very same rows. |
| **Add degrees** | Qualifications shown on the doctor's public listing. |
| **Check appointments** | New bookings plus anything a patient rescheduled or cancelled, newest-acted-on first. Opening the list confirms pending bookings and clears the bell. The doctor can also call a visit off from here. |
| **EMR** | Pick a patient from the roster of everyone who has booked them, then read that patient's visit history, diagnoses, prescriptions and treatment records. |
| **Write up a visit** | Record a diagnosis and prescribe medicines, with brand search as they type. |
| **Chamber info** | Room, floor and lift for every hospital they sit at, with the days and hours of each sitting. |

---

## Architecture

```
┌──────────────────────────┐
│  Flutter app (Android)   │
│                          │
│  screens/  ──▶ services/ │   38 screens, 18 services
│  widgets/      models/   │   25 models,  16 shared widgets
│  config/ApiClient        │   one door for every request
└───────────┬──────────────┘
            │  HTTP  ·  JSON  ·  Bearer token
            ▼
┌──────────────────────────┐
│  healthcare_api  (PHP)   │
│                          │
│  api/        49 endpoints│   thin: parse, delegate, echo JSON
│    ▼                     │
│  controllers/  17        │   the rules live here
│    ▼                     │
│  models/       18        │   the only place SQL is written
│  config/       10        │   headers.php = the gate
└───────────┬──────────────┘
            │  mysqli
            ▼
┌──────────────────────────┐
│  MySQL · healthcare_db   │   23 tables
└──────────────────────────┘
```

Two rules hold the whole thing together:

1. **Flutter never touches MySQL** and never holds a database credential. Every database operation goes through the API.
2. **Every request passes through `config/headers.php`.** It is the single gate, which is what makes it the right place to ask who is calling — see [Authentication](#authentication).

---

## Repository layout

This is **two separate projects** that must stay separate:

```
E:\AndriodProjects\healthcare_app     ← this repository (Flutter app)
E:\xampp\htdocs\healthcare_api        ← the PHP API, served by XAMPP
```

### The Flutter app

```
lib/
├── main.dart                 App entry, theme, opens SignInScreen
├── config/                   3 files
│   ├── api_config.dart       ★ the ONE place the API address is decided
│   ├── api_client.dart       Every HTTP call, with the auth token attached
│   └── medex_config.dart     The external medicine index, as a link out
├── models/                   25 — one Dart class per API payload shape
├── services/                 18 — one per feature area; the only callers of ApiClient
├── screens/                  38 — one per wireframe screen
├── widgets/                  16 — shared building blocks (cards, fields, drawer, nav)
└── theme/
    └── app_colors.dart       The whole palette, with the accessibility rules written down

assets/
├── images/logo.jpg           Used in the drawer and the app-name header
└── launcher/                 Sources for the launcher icon and splash (build-time only)

android/
├── app/build.gradle.kts      Kotlin JVM target 17
├── gradle.properties         kotlin.incremental=false  ← see Troubleshooting
└── app/src/main/AndroidManifest.xml
                              INTERNET, usesCleartextTraffic, and the <queries> DIAL entry

Ai_Usage.txt                  Declaration of how AI tools were used on this project
```

The layering is strict: a **screen** never builds a URL and never calls `http` directly. It calls a **service**, the service calls `ApiClient`, and `ApiClient` is the only thing that knows about tokens.

### The PHP API

```
healthcare_api/
├── api/          49 endpoint files. Thin — each one requires headers.php first,
│                 parses input, calls a controller, prints JSON.
├── controllers/  17 files. All the rules: validation, permissions, merging.
├── models/       18 files. The only place SQL statements are written.
├── config/       10 files:
│   ├── headers.php            ★ the gate — auth + CORS + JSON headers
│   ├── auth.php               Token issuing and verification (HMAC-SHA256)
│   ├── database.php           The single mysqli connection
│   ├── medex.php              Reads the external medicine catalogue
│   ├── slots.php              Turns a sitting string into bookable serials
│   ├── metric_references.php  Reference bands for every health metric
│   ├── conditions.php         Symptom keywords → department, for search
│   ├── experiences.php        Experience level codes, for search
│   ├── degrees.php            The degree list offered to doctors
│   └── record_types.php       Health record categories
└── uploads/      Profile photos, and records/ for uploaded documents
```

---

## Getting started

### Prerequisites

- **Flutter SDK** with Dart `^3.13.0` (`flutter doctor` should be clean for Android)
- **XAMPP** with Apache and MySQL
- **Android SDK** with an emulator, or a physical Android device with USB debugging

### 1. Set up the database

Start **MySQL** from the XAMPP control panel, then create the schema and import it:

```bash
# From the XAMPP MySQL bin directory
mysql.exe -u root -e "CREATE DATABASE IF NOT EXISTS healthcare_db CHARACTER SET utf8mb4;"
mysql.exe -u root healthcare_db < path\to\healthcare_db.sql
```

Or do the same through **phpMyAdmin** at `http://localhost/phpmyadmin`.

The default connection is `localhost`, user `root`, empty password. If yours differs, change it in one place — `healthcare_api/config/database.php`.

### 2. Put the API in place

Copy the `healthcare_api` folder into XAMPP's document root so it sits at:

```
<xampp>/htdocs/healthcare_api
```

Start **Apache**, then check it answers:

```
http://localhost/healthcare_api/index.php
   → PHP is working!
     Database connection successful!
```

The first sign-in also writes `healthcare_api/config/.auth_secret` — 32 random bytes, generated the first time a token has to be signed, so no secret is ever committed to the repository. Deleting or rotating that file invalidates every token already issued, which is the blunt version of "sign everybody out".

### 3. Point the app at the right host

This is the step that catches people out. The emulator and a real phone reach your PC at **different addresses**, so open `lib/config/api_config.dart` and set the one constant:

```dart
static const ApiTarget target = ApiTarget.emulator;   // ← change this line
static const String pcLanIp   = '192.168.0.162';      // ← and this, for phone mode
```

| `target` | Resolves to | Use when |
|---|---|---|
| `ApiTarget.emulator` | `http://10.0.2.2/healthcare_api` | Running on an Android emulator. `10.0.2.2` is how the emulator reaches the host machine. |
| `ApiTarget.phone` | `http://127.0.0.1:8080/healthcare_api` | Running on a physical phone over USB, with a reverse port forward (below). Swap in `pcLanIp` if you would rather go over Wi-Fi. |
| `ApiTarget.desktop` | `http://localhost/healthcare_api` | Running on Windows desktop or Chrome. |

For a **USB phone**, or to run on the emulator while `target` is left on `phone`, forward the port with ADB:

```bash
adb reverse tcp:8080 tcp:80          # the device's 127.0.0.1:8080 → XAMPP's port 80
adb reverse --remove tcp:8080        # undo it afterwards
```

Over **Wi-Fi**, the phone and the PC must be on the same network, `pcLanIp` must be the PC's current IPv4 (it changes when the router reassigns), and Windows Firewall must allow inbound port 80.

### 4. Run the app

```bash
flutter pub get
flutter run
```

To regenerate the launcher icon or the splash screen after changing the logo:

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

---

## Configuration

Everything device- or environment-specific lives in one of four files:

| File | Holds |
|---|---|
| `lib/config/api_config.dart` | The API target, the LAN IP, the project folder name, and the 15-second request timeout. Also builds upload URLs from a stored file name. |
| `healthcare_api/config/database.php` | Host, user, password, schema name. |
| `healthcare_api/config/.auth_secret` | The token signing key. Generated at random on first use; never commit it. |
| `android/app/src/main/AndroidManifest.xml` | `INTERNET`, `usesCleartextTraffic="true"` (the local API is plain HTTP), and the `<queries>` entry for `DIAL` that `url_launcher` needs on Android 11+. |

---

## The API

### Conventions

Every endpoint answers with the same envelope:

```jsonc
{ "success": true,  "message": "...", "data": { } }
{ "success": false, "message": "...", "errors": { "phone": "why" } }
```

| Status | Means |
|---|---|
| `200` | Handled. An empty `data` list is a normal 200, not an error. |
| `401` | No token, a bad token, or an expired one. |
| `403` | Valid token, but this caller may not do this — wrong role, or an id that is not their own. |
| `422` | The input did not validate; `errors` names the fields. |

### Authentication

```
POST login.php  ──▶  { data: { account_type, ...ids..., token } }
                          │
                          ▼
              ApiClient.signIn(token)         (memory only, this run of the app)
                          │
   every later request ───┴──▶  Authorization: Bearer <token>
                                     │
                                     ▼
                            config/headers.php
                              1. Is a token needed at all?   ($PUBLIC list)
                              2. Is it valid and unexpired?  → 401
                              3. Is this caller allowed here, as themselves?
                                   · right role for this endpoint ($DOCTOR_ONLY)
                                   · the id in the request is their own  → 403
```

The token is `base64url(payload) . base64url(hmac_sha256(payload, secret))`, where the payload carries only an account type, an id and an expiry — never a name or a phone number, because it is signed, not encrypted. It lasts **7 days**.

Three things follow from where the check lives:

- **The id the server acts on comes out of the token**, not out of the query string. Before this, `patient_id=6` simply *was* patient 6, and the only thing between a stranger and a medical record was not knowing the number.
- **An endpoint nobody has classified is protected and patient-only.** A new file has to be deliberately named in `$PUBLIC` or `$DOCTOR_ONLY` before it will answer a stranger or a doctor, so forgetting to think about a new endpoint fails closed.
- **Identity is not permission.** The gate proves the caller *is* that doctor; whether that doctor may open one particular patient's record is a question about a relationship, and `EmrController` answers it separately by refusing a patient who has never booked them.

The token lives in memory only, so **closing the app signs you out**. For a health record that is the right default — there is no stored credential on the device to lose.

### Endpoints

**Public** (no token) — 18 of them, marked `○`. **Doctor only** — marked `◆`. Everything else needs a patient token for their own id.

<details>
<summary><b>Accounts &amp; profile</b> (6)</summary>

| Endpoint | |
|---|---|
| `login.php` | ○ Phone + password. Checks PATIENT first, then DOCTOR, and says which matched. Returns the token. |
| `register_patient.php` | ○ |
| `register_doctor.php` | ○ |
| `patient_profile.php` | Read the signed-in patient's own details |
| `update_patient_profile.php` | |
| `upload_profile_image.php` | Multipart. Separate from the form save, so saving the form can never wipe a photo. |
</details>

<details>
<summary><b>Reference data</b> (8)</summary>

| Endpoint | |
|---|---|
| `areas.php` · `hospitals.php` · `hospital_departments.php` · `departments.php` | ○ The place directory |
| `degrees.php` · `lab_tests.php` | ○ Catalogues |
| `articles.php` · `article.php` | ○ Health tips |
</details>

<details>
<summary><b>Doctors &amp; search</b> (7)</summary>

| Endpoint | |
|---|---|
| `doctors.php` | ○ Doctors in a department |
| `search_doctors.php` | ○ The one call behind the whole search feature — speciality, hospital, area, experience and weekday, all optional and all ANDed |
| `search_filters.php` | ○ The chips the results screen offers |
| `doctor_schedules.php` · `slot_availability.php` | ○ Sittings, and how many seats are left |
| `save_schedule.php` · `save_degrees.php` | ◆ |
</details>

<details>
<summary><b>Appointments</b> (8)</summary>

| Endpoint | |
|---|---|
| `book_appointment.php` | Checks the slot is real and not full before it writes |
| `patient_appointments.php` · `cancel_appointment.php` | |
| `reschedule_options.php` · `reschedule_appointment.php` | |
| `doctor_appointments.php` | ◆ Opening the list confirms pending bookings |
| `doctor_cancel_appointment.php` · `appointment_count.php` | ◆ |
</details>

<details>
<summary><b>Clinical records</b> (6)</summary>

| Endpoint | |
|---|---|
| `emr_patients.php` | ◆ The roster of patients who have booked this doctor. A search narrows it and can never widen it. |
| `emr_details.php` | ◆ 403 if the patient has never booked this doctor |
| `save_medical_record.php` | ◆ Diagnosis + prescription for one visit |
| `prescriptions.php` | The patient's own copy |
| `health_records.php` · `upload_health_record.php` | The patient's uploaded documents |
</details>

<details>
<summary><b>Health metrics, pharmacy, lab &amp; notifications</b> (14)</summary>

| Endpoint | |
|---|---|
| `health_metrics.php` · `save_health_metrics.php` | Readings, judged against `metric_references.php` on the server |
| `medicine_search.php` · `medicine_price.php` | ○ Brand lookup, backed by MedEx |
| `place_order.php` · `order_history.php` | |
| `medication.php` · `complete_medication.php` | |
| `patient_addresses.php` · `add_address.php` · `select_address.php` | |
| `book_lab_test.php` | |
| `notifications.php` · `patient_notification_count.php` | The bell, and the number on it |
</details>

---

## The database

`healthcare_db`, 23 tables, utf8mb4.

| Group | Tables |
|---|---|
| **People & places** | `patient`, `address`, `doctor`, `doctor_degree`, `department`, `hospital` |
| **Scheduling** | `doctor_schedule`, `appointment`, `appointment_history` |
| **Clinical** | `medical_record`, `prescription`, `prescription_item`, `health_record`, `health_metric` |
| **Pharmacy** | `medicine`, `cart`, `cart_item`, `order_header`, `order_item` |
| **Diagnostics** | `lab_test`, `lab_test_order`, `lab_test_order_item` |
| **Content** | `article` |

A few conventions that are easy to trip over:

- **Uploaded files are stored by name only** — `patient_6_1787235521.jpg`, never a URL. The same row therefore resolves correctly on the emulator and on a phone, which reach the server at different hosts; `ApiConfig.uploadUrl()` builds the address at the one place that knows which is in use.
- **Age is never stored.** It is computed with `TIMESTAMPDIFF` on read, mirrored by `ageFrom()` in Dart, so it cannot go stale.
- **`order_item` keeps the price that was charged**, not a reference to the current price. Medicine prices move; a receipt that changes afterwards is not a receipt.
- **`medicine` is a registry, not a menu** — it records brands that have actually been prescribed, rather than limiting what a doctor may prescribe. See below.

---

## Design decisions worth knowing

These are the choices that are non-obvious from reading the code, each of which is also explained in a comment at the top of the file that implements it.

**A signed token instead of a sessions table.** The schema was fixed, and a stateless token needs no storage, so nothing has to be cleaned up. The price is that a token cannot be revoked individually before it expires — rotating `.auth_secret` invalidates all of them at once, which is the right lever if one is thought to have leaked. A deployment holding real patients should keep a token table.

**One sitting, cut into serials.** `doctor_schedule.time_slot` holds a whole sitting as one string, e.g. `"4:00 PM - 10:00 PM"`. `config/slots.php` cuts it into fifteen-minute slots — serial 1 is 4:15 PM, serial 2 is 4:30 PM — which also puts a hard end on the day: once the closing time is reached there is no slot left to hand out and booking is refused, rather than quietly sending somebody to a chamber that has shut. It is pure arithmetic on a string, touching no database, so booking, rescheduling and the patient's time preview all get the same answer.

**The medicine catalogue is external.** A local table can only ever offer what somebody put into it, which would quietly limit what a doctor is allowed to prescribe. `config/medex.php` therefore reads brands from **medex.com.bd** as the doctor types, using the same request that site's own search box makes. It is HTML written for a browser, not a contract, so everything fails soft: a parse that finds nothing returns an empty list and the caller falls back to brands already prescribed, rather than breaking the write-up form.

**Three sources, one bell.** Appointment changes, medicine orders and lab bookings all light the patient's bell, but the rows share almost nothing beyond a timestamp. A SQL `UNION` would flatten them into whichever column set is widest and pad the rest with NULLs, which the app would only have to unpick again — so `NotificationController` merges them in PHP, each row keeping its own shape and a type tag.

**Nothing is judged in the app.** The health dashboard's statuses, wording and reference bands all come from `config/metric_references.php`, so a corrected range takes effect everywhere at once. The screen shows a reading next to the range it should be in and stops there — "see a doctor" is not its to say.

**A status is never colour alone.** Two of the four clinical status colours fall below a 3:1 contrast ratio against the white metric cards, so each one is always drawn with an icon and the server's own wording beside it. Those four colours are reserved: they are never reused as ordinary decoration, because a colour that sometimes means "your blood sugar is fine" and sometimes means "this row is selected" means nothing at all.

---

## Packages used

Runtime dependencies are deliberately minimal. There is **no third-party UI kit, no state-management package and no backend service** — every screen, widget, model, service and endpoint was written for this project.

| Package | Used for |
|---|---|
| `http` `^1.2.2` | Every call to the API |
| `image_picker` `^1.1.2` | Profile photo from gallery or camera. It only *picks* the file; the upload is a plain `MultipartRequest`. |
| `file_picker` `^12.0.0` | A document for Health Records, from the system file browser — `image_picker` can only reach the gallery and camera |
| `url_launcher` `^6.3.1` | Opens the dialler for Call a Hospital, and MedEx in the browser |
| `cupertino_icons` `^1.0.8` | Extra icons |

Development only, taking no part in the running app:

| Package | Used for |
|---|---|
| `flutter_lints` `^6.0.0` | The lint rules in `analysis_options.yaml` |
| `flutter_launcher_icons` `^0.14.0` | Generates the launcher icon |
| `flutter_native_splash` `^2.4.0` | Generates the splash screen |

---

## Testing notes

- **`flutter analyze` passing is not the same as working.** The dropdown crash under [Known issues](#known-issues) analysed clean and only appeared at runtime, after a successful save. Exercise the screen you changed.
- **Test writes on throwaway accounts.** Endpoints that mutate data should be tried against a patient registered for the purpose and deleted afterwards, not against a real account's rows.
- Passwords are bcrypt-hashed and cannot be read back, so a test account has to be registered through `register_patient.php` rather than inserted by hand.

---

## Known issues

**A harmless assertion on every cold start (debug builds only).** `sign_in_screen.dart` throws

```
BoxConstraints has a negative minimum height.
BoxConstraints(0.0<=w<=Infinity, -32.0<=h<=Infinity; NOT NORMALIZED)
```

The `LayoutBuilder` feeds a `ConstrainedBox` a `minHeight` computed by subtracting fixed padding from the incoming height, and on the very first frame Flutter reports a height of 0, so the subtraction goes negative. The screen renders correctly once real constraints arrive. It is noise in the console, not a crash. Fix by clamping the computed value to `0.0` when that screen is next touched.

**Dropdowns must hold a code, not an object.** None of the model classes override `==`, so a `DropdownButton` whose `value` is an object taken from a list that later reloads will match nothing in the new list and throw a red-screen assertion — *after* a successful write, which is exactly when nobody is looking. Hold the id or code and resolve it against the current list in a getter. Every dropdown in the app already does this; keep it that way when adding one.

---

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| Every screen spins, then times out after 15 s | XAMPP Apache is not running, or `ApiConfig.target` is set for the wrong device. Check `http://localhost/healthcare_api/index.php` in a browser first. |
| Works on the emulator, dead on the phone | `10.0.2.2` only means anything to the emulator. Switch `target` to `phone`, and either run `adb reverse tcp:8080 tcp:80` or set `pcLanIp` to the PC's current IPv4 and open port 80 in the firewall. |
| `401` on every call after signing in | The app was restarted. The token is held in memory only, so a restart is a sign-out — sign in again. |
| `403` with a valid login | The id in the request is not the signed-in account's, or a patient hit a `$DOCTOR_ONLY` endpoint. |
| Android build fails with `Could not close incremental caches ... class-fq-name-to-source.tab` | A Kotlin incremental-compilation clash from a plugin. `flutter clean` will **not** fix it — the caches are rebuilt and re-locked each run. The fix is `kotlin.incremental=false` in `android/gradle.properties`, which is already committed there. |
| `url_launcher` silently does nothing on Android 11+ | The `<queries>` entry for `android.intent.action.DIAL` is missing from the manifest. It does not error — it just returns. |
| A profile photo 404s | The database stores only the file name; check the file actually exists in `healthcare_api/uploads/` and that the API host is reachable from the device. |
| MedEx brand search returns nothing | Expected behaviour when the site is unreachable or its markup has changed — the search falls back to brands already prescribed. Not a crash. |

---

## Project information

| | |
|---|---|
| **Course** | CSE 489 — Android App Development |
| **Student** | Ahnaf Muhtasim |
| **ID** | 23101088 |

AI tools were used as an assistance and learning resource during development. How they were used, on which parts, and with what verification, is declared in [`Ai_Usage.txt`](Ai_Usage.txt).
