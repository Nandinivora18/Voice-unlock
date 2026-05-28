// constants.dart
// Central place for app-wide configuration values.

class AppConstants {
  AppConstants._(); // prevent instantiation

  // ----- Server -------------------------------------------------------
  // Android EMULATOR: 10.0.2.2 maps to the host machine's localhost.
  // Android PHYSICAL DEVICE: run  `adb reverse tcp:8765 tcp:8765`
  //   then change this to 'http://localhost:8765'
  static const String serverUrl = 'http://127.0.0.1:8765';

  // ----- Voice / Auth -------------------------------------------------
  /// Recording duration in seconds (auto-stop after this).
  static const int recordingDuration = 4;

  /// SharedPreferences key that tracks whether enrollment is complete.
  static const String prefEnrolled = 'is_enrolled';

  /// HTTP header name for the session token.
  static const String sessionHeader = 'X-Session-Token';
}
