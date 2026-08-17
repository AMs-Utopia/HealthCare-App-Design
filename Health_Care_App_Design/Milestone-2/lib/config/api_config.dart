///Here PHP API lives.
///Every screen gets its URL from here, so switching between the emulator and
///a real phone is a one line change instead of a search through the code.
library;
///The machine the app is running on while testing.
enum ApiTarget {
  ///Android emulator. 10.0.2.2--IP
  emulator,
  /// A real Android phone on the same Wi-Fi as the PC. Uses [ApiConfig.pcLanIp]. ///changed to fixed LAN due to SQL
  phone,
  ///Windows desktop or Chrome, for emergency use :(
  desktop,
}

class ApiConfig {
  //Only holds configuration
  ApiConfig._();
  //================================================
  //CHANGE THESE TWO VALUES WHEN YOU SWITCH DEVICE**
  //================================================

  ///For pixel4XL
  static const ApiTarget target = ApiTarget.emulator;
  ///The PC's IPv4 address on the Wi-Fi network. Only used when [target] is
  ///[ApiTarget.phone].
  static const String pcLanIp = '192.168.0.162';

  // ==========================================================================
  ///The folder the API sits in under htdocs.
  static const String _projectFolder = 'healthcare_api';

  /// Root of the API, e.g. http://10.0.2.2/healthcare_api
  static String get baseUrl {
    switch (target) {
      case ApiTarget.emulator:
        return 'http://10.0.2.2/$_projectFolder';
      case ApiTarget.phone:
        return 'http://127.0.0.1:8080/$_projectFolder'; //Fixed for USB physical device
      case ApiTarget.desktop:
        return 'http://localhost/$_projectFolder';
    }
  }

  ///Builds the full address of one endpoint file inside /api.
  ///`ApiConfig.endpoint('register_patient.php')`
  ///  -> http://10.0.2.2/healthcare_api/api/register_patient.php
  static Uri endpoint(String fileName) => Uri.parse('$baseUrl/api/$fileName');

  ///How long to wait before giving up on a request. Without this the app
  ///would sit on the loading spinner forever when XAMPP is not running.
  static const Duration timeout = Duration(seconds: 15);
}
