import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_client.dart';

import '../config/api_config.dart';
import '../models/api_response.dart';
import '../models/patient_profile.dart';
import '../models/saved_address.dart';

/// All PATIENT table calls to the PHP API.
///
/// The screens never build URLs or parse JSON themselves - they call a method
/// here and get back an [ApiResponse] they can show.
class PatientService {
  // Only static helpers, never instantiated.
  PatientService._();
  /// Screen 3 - creates the account by inserting a row into PATIENT.
  ///
  /// Sends to `api/register_patient.php`. The password is sent as typed and
  /// hashed by PHP with password_hash() before it is stored.
  static Future<ApiResponse> register({
    required String fullName,
    required String phone,
    required String password,
    required String confirmPassword,
    required bool agreedToTerms,
  }) async {
    try {
      final response = await ApiClient
          .post(
            ApiConfig.endpoint('register_patient.php'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'full_name': fullName,
              'phone': phone,
              'password': password,
              'confirm_password': confirmPassword,
              'agreed_to_terms': agreedToTerms,
            }),
          )
          .timeout(ApiConfig.timeout);

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        return const ApiResponse.failure(
          'The server sent back something unexpected. Check the PHP error log.',
        );
      }

      return ApiResponse.fromJson(decoded);
    } on SocketException {
      // No route to the PC at all: XAMPP is off, or the phone is on a
      // different network than the PC.
      return ApiResponse.failure(
        'Cannot reach the server at ${ApiConfig.baseUrl}.\n'
        'Check that Apache and MySQL are running in XAMPP.',
      );
    } on TimeoutException {
      return const ApiResponse.failure(
        'The server took too long to answer. Please try again.',
      );
    } on FormatException {
      // Valid HTTP reply, but not JSON - usually a PHP warning or fatal error
      // printed before the real response.
      return const ApiResponse.failure(
        'The server did not send valid JSON. Open the endpoint in a browser '
        'to see the PHP error.',
      );
    }
  }

  /// The Basic Info screen's starting values.
  ///
  /// Reads the account fresh rather than using the signed in copy, because
  /// sign in only ever held the name and the phone - the date of birth, gender,
  /// blood group, photo and address were never part of it.
  static Future<ProfileResult> fetchProfile(int patientId) async {
    try {
      final uri = ApiConfig.endpoint('patient_profile.php').replace(
        queryParameters: {'patient_id': '$patientId'},
      );

      final response = await ApiClient.get(uri).timeout(ApiConfig.timeout);

      return _readProfile(response.body);
    } on SocketException {
      return ProfileResult.failure(
        'Cannot reach the server at ${ApiConfig.baseUrl}.\n'
        'Check that Apache and MySQL are running in XAMPP.',
      );
    } on TimeoutException {
      return const ProfileResult.failure(
        'The server took too long to answer. Please try again.',
      );
    } on FormatException {
      return const ProfileResult.failure(
        'The server did not send valid JSON. Open the endpoint in a browser '
        'to see the PHP error.',
      );
    }
  }

  /// Save changes on the Basic Info screen.
  ///
  /// Only the name and the phone are required. Everything else is sent as
  /// typed, and an empty one is stored as NULL by PHP rather than as a blank.
  ///
  /// The photo is not part of this on purpose - it goes up on its own through
  /// [uploadProfileImage], so saving the form can never wipe a picture.
  static Future<ApiResponse> updateProfile({
    required int patientId,
    required String fullName,
    required String phone,
    String? dateOfBirth,
    String? gender,
    String? bloodGroup,
    String? presentAddress,
  }) async {
    try {
      final response = await ApiClient
          .post(
            ApiConfig.endpoint('update_patient_profile.php'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'patient_id': patientId,
              'full_name': fullName,
              'phone': phone,
              'date_of_birth': dateOfBirth ?? '',
              'gender': gender ?? '',
              'blood_group': bloodGroup ?? '',
              'present_address': presentAddress ?? '',
            }),
          )
          .timeout(ApiConfig.timeout);

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        return const ApiResponse.failure(
          'The server sent back something unexpected. Check the PHP error log.',
        );
      }

      return ApiResponse.fromJson(decoded);
    } on SocketException {
      return ApiResponse.failure(
        'Cannot reach the server at ${ApiConfig.baseUrl}.\n'
        'Check that Apache and MySQL are running in XAMPP.',
      );
    } on TimeoutException {
      return const ApiResponse.failure(
        'The server took too long to answer. Please try again.',
      );
    } on FormatException {
      return const ApiResponse.failure(
        'The server did not send valid JSON. Open the endpoint in a browser '
        'to see the PHP error.',
      );
    }
  }

  /// Sends the picked photo up as a multipart upload.
  ///
  /// A file cannot go in a JSON body, so this is the one call in the app that
  /// is not [jsonEncode]d. PHP checks the bytes really are a picture, renames
  /// it after the patient, and answers with the whole profile - so the reply is
  /// read the same way [fetchProfile] reads its own.
  static Future<ProfileResult> uploadProfileImage({
    required int patientId,
    required String filePath,
  }) async {
    try {
      final request = ApiClient.multipart(
        'POST',
        ApiConfig.endpoint('upload_profile_image.php'),
      );

      request.fields['patient_id'] = '$patientId';
      request.files.add(await http.MultipartFile.fromPath('image', filePath));

      final streamed = await request.send().timeout(ApiConfig.timeout);
      final body = await streamed.stream.bytesToString();

      return _readProfile(body);
    } on SocketException {
      return ProfileResult.failure(
        'Cannot reach the server at ${ApiConfig.baseUrl}.\n'
        'Check that Apache and MySQL are running in XAMPP.',
      );
    } on TimeoutException {
      return const ProfileResult.failure(
        'The upload took too long. Please try a smaller picture.',
      );
    } on FormatException {
      return const ProfileResult.failure(
        'The server did not send valid JSON. Open the endpoint in a browser '
        'to see the PHP error.',
      );
    }
  }

  /// Every address this patient has saved, for the Saved Address screen.
  static Future<AddressListResult> fetchAddresses(int patientId) async {
    try {
      final uri = ApiConfig.endpoint('patient_addresses.php').replace(
        queryParameters: {'patient_id': '$patientId'},
      );

      final response = await ApiClient.get(uri).timeout(ApiConfig.timeout);

      return _readAddresses(response.body);
    } on SocketException {
      return AddressListResult.failure(
        'Cannot reach the server at ${ApiConfig.baseUrl}.\n'
        'Check that Apache and MySQL are running in XAMPP.',
      );
    } on TimeoutException {
      return const AddressListResult.failure(
        'The server took too long to answer. Please try again.',
      );
    } on FormatException {
      return const AddressListResult.failure(
        'The server did not send valid JSON. Open the endpoint in a browser '
        'to see the PHP error.',
      );
    }
  }

  /// Adds one address from the "+ Add new Address" box.
  ///
  /// Answers with the whole list back, so the screen redraws from what was
  /// really saved rather than from what it hoped was saved - which also picks
  /// up the flag PHP puts on a patient's very first address.
  static Future<AddressListResult> addAddress({
    required int patientId,
    required String address,
  }) => _postAddress('add_address.php', {
    'patient_id': patientId,
    'present_address': address,
  });

  /// Confirms one saved address as the patient's present address.
  ///
  /// This is what the radio button and Confirm do together. From here on the
  /// Basic Info screen shows this address, because both read the same flag.
  static Future<AddressListResult> selectAddress({
    required int patientId,
    required int addressId,
  }) => _postAddress('select_address.php', {
    'patient_id': patientId,
    'address_id': addressId,
  });

  /// Adding and confirming send different fields but come back with the same
  /// list, so they share one call.
  static Future<AddressListResult> _postAddress(
    String endpoint,
    Map<String, Object?> body,
  ) async {
    try {
      final response = await ApiClient
          .post(
            ApiConfig.endpoint(endpoint),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(ApiConfig.timeout);

      return _readAddresses(response.body);
    } on SocketException {
      return AddressListResult.failure(
        'Cannot reach the server at ${ApiConfig.baseUrl}.\n'
        'Check that Apache and MySQL are running in XAMPP.',
      );
    } on TimeoutException {
      return const AddressListResult.failure(
        'The server took too long to answer. Please try again.',
      );
    } on FormatException {
      return const AddressListResult.failure(
        'The server did not send valid JSON. Open the endpoint in a browser '
        'to see the PHP error.',
      );
    }
  }

  /// All three address calls answer with the same shape, so they share the one
  /// reader.
  static AddressListResult _readAddresses(String body) {
    final decoded = jsonDecode(body);

    if (decoded is! Map<String, dynamic>) {
      return const AddressListResult.failure(
        'The server sent back something unexpected. Check the PHP error log.',
      );
    }

    final parsed = ApiResponse.fromJson(decoded);

    if (!parsed.success) {
      return AddressListResult.failure(parsed.message);
    }

    final rows = decoded['data'];

    // A patient with no addresses answers with an empty list, not an error -
    // it is what the screen draws as "No addresses added currently".
    return AddressListResult.success(
      rows is List
          ? rows
                .whereType<Map<String, dynamic>>()
                .map(SavedAddress.fromJson)
                .toList()
          : const [],
      parsed.message,
    );
  }

  /// Both the profile read and the photo upload answer with the same shape, so
  /// they share the one reader.
  static ProfileResult _readProfile(String body) {
    final decoded = jsonDecode(body);

    if (decoded is! Map<String, dynamic>) {
      return const ProfileResult.failure(
        'The server sent back something unexpected. Check the PHP error log.',
      );
    }

    final parsed = ApiResponse.fromJson(decoded);
    final data = decoded['data'];

    if (!parsed.success || data is! Map<String, dynamic>) {
      return ProfileResult.failure(parsed.message);
    }

    return ProfileResult.success(
      PatientProfile.fromJson(data),
      parsed.message,
    );
  }
}

/// Either the patient's profile, or why it could not be loaded or saved.
class ProfileResult {
  const ProfileResult._(this.profile, this.message, this.error);

  const ProfileResult.success(PatientProfile profile, String message)
    : this._(profile, message, null);

  const ProfileResult.failure(String error) : this._(null, error, error);

  final PatientProfile? profile;

  /// What the server said, e.g. "Update successful." Worth showing on the way
  /// through, since it is the message the wireframe's popup asks for.
  final String message;

  final String? error;

  bool get isSuccess => profile != null;
}

/// Either the patient's saved addresses, or why they could not be loaded.
class AddressListResult {
  const AddressListResult._(this.addresses, this.message, this.error);

  const AddressListResult.success(List<SavedAddress> addresses, String message)
    : this._(addresses, message, null);

  const AddressListResult.failure(String error)
    : this._(const [], error, error);

  final List<SavedAddress> addresses;

  /// What the server said, e.g. "Address added." Worth showing, since it is
  /// what confirms the tap did something.
  final String message;

  final String? error;

  bool get isSuccess => error == null;

  /// The address the patient is currently using, or null when they have not
  /// chosen one.
  SavedAddress? get present {
    for (final address in addresses) {
      if (address.isPresent) return address;
    }
    return null;
  }
}
