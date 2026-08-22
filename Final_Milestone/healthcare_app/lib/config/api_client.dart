import 'package:http/http.dart' as http;

/// Every call to the API, with proof of who is making it.
///
/// The server used to believe whatever id it was handed: a request saying
/// `patient_id=6` WAS patient 6, and the only thing between a stranger and
/// somebody's medical record was not knowing the number. It does not believe
/// that any more - `api/login.php` hands back a signed token, and every request
/// after it has to carry that token or be refused.
///
/// So no service may call `http.get` or `http.post` directly. They go through
/// here, which attaches the token, because a call that forgets it does not fail
/// loudly at compile time - it fails at run time as a 401 on one screen that
/// somebody has to notice. One door is easier to keep shut than fourteen.
///
/// The token lives in memory only, for the life of one run of the app. Nothing
/// is written to the phone, so a closed app is a signed out app - which for a
/// health record is the right default, and means there is no stored credential
/// on the device to lose. If "stay signed in" is ever wanted, this is the class
/// that would keep it, and it should be `flutter_secure_storage` rather than
/// shared preferences.
class ApiClient {
  // Only static members, never instantiated.
  ApiClient._();

  static String? _token;

  /// Remembers the token that `login.php` returned. Called once, by
  /// AuthService.login, the moment a password has been accepted.
  static void signIn(String token) => _token = token;

  /// Forgets it. Called when the patient signs out, so the next screen cannot
  /// keep using the last account's token.
  static void signOut() => _token = null;

  static bool get isSignedIn => _token != null && _token!.isNotEmpty;

  /// The token as the server wants to read it, merged with whatever else the
  /// caller is sending.
  ///
  /// When there is no token the header is simply left off rather than sent
  /// empty - the public endpoints (hospitals, departments, the doctor search)
  /// take no notice either way, and an empty Bearer would only look like a
  /// malformed one.
  static Map<String, String> authHeaders([Map<String, String>? extra]) {
    return {
      if (isSignedIn) 'Authorization': 'Bearer $_token',
      ...?extra,
    };
  }

  static Future<http.Response> get(Uri url) {
    return http.get(url, headers: authHeaders());
  }

  static Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return http.post(url, headers: authHeaders(headers), body: body);
  }

  /// A file upload. The request is returned rather than sent, because the
  /// caller still has to add its fields and its file - but the token is already
  /// on it, so it cannot be forgotten between here and `send()`.
  static http.MultipartRequest multipart(String method, Uri url) {
    return http.MultipartRequest(method, url)..headers.addAll(authHeaders());
  }
}
