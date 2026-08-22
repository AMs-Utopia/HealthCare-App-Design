/// One reply from the PHP API, in the shape every endpoint returns:
/// ```json
/// { "success": true,  "message": "...", "data": { ... } }
/// { "success": false, "message": "...", "errors": { "phone": "..." } }
///```
class ApiResponse {
  const ApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.fieldErrors = const {},
  });
  ///Tells whether the API operation succeeded.
  final bool success;
  ///Server message to display to the user.
  final String message;
  ///Contains returned information, such as a newly created patient ID.
  final Map<String, dynamic>? data;
  ///Contains errors for specific fields, such as an already-registered phone number.
  final Map<String, String> fieldErrors;

  ///fromJson() takes the JSON response from PHP and converts it into an
  ///ApiResponse object that Flutter can easily work with.
  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    final rawErrors = json['errors'];

    return ApiResponse(
      success: json['success'] == true,
      message: (json['message'] as String?) ?? 'Something went wrong.',
      data: json['data'] is Map<String, dynamic>
          ? json['data'] as Map<String, dynamic>
          : null,
      fieldErrors: rawErrors is Map
          ? rawErrors.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            )
          : const {},
    );
  }
  ///When the request never reached a working API - no server, no Wi-Fi,
  ///or a PHP error page instead of JSON.
  const ApiResponse.failure(this.message)
      : success = false,
        data = null,
        fieldErrors = const {};
}