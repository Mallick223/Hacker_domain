import 'config_platform.dart'
    if (dart.library.html) 'config_platform_web.dart';

/// Central place for app configuration.
/// Point this at your Django/FastAPI backend.
class AppConfig {
  /// Local backend defaults:
  /// - Web / desktop: http://localhost:8000/api
  /// - Android emulator: http://10.0.2.2:8000/api
  /// - iOS simulator: http://localhost:8000/api
  /// Override at build time with:
  ///   flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8000/api
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: platformBaseUrl,
  );

  static const String registerEndpoint = "$baseUrl/auth/register";
  static const String loginEndpoint = "$baseUrl/auth/login";
  static const String locationUpdateEndpoint = "$baseUrl/location/update";
  static const String sosEndpoint = "$baseUrl/sos";

  // How often to push live location updates to the backend.
  static const Duration locationUpdateInterval = Duration(seconds: 15);

  // Minimum distance (meters) the device must move before a location
  // update is considered "new" (saves battery/data).
  static const double locationDistanceFilter = 10;
}
