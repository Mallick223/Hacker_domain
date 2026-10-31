import 'package:flutter/foundation.dart';

/// Central place for app configuration.
/// Point this at your Django/FastAPI backend.
class AppConfig {
  /// Local backend defaults:
  /// - Web: http://127.0.0.1:8000/api
  /// - Android emulator: http://10.0.2.2:8000/api
  /// - iOS simulator / desktop: http://127.0.0.1:8000/api
  /// Override at build time with:
  ///   flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8000/api
  static String resolveBaseUrl({TargetPlatform? platform}) {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;

    if (kIsWeb) return 'http://127.0.0.1:8000/api';

    final target = platform ?? defaultTargetPlatform;
    switch (target) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:8000/api';
      case TargetPlatform.iOS:
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
        return 'http://127.0.0.1:8000/api';
      default:
        return 'http://localhost:8000/api';
    }
  }

  static String get baseUrl => resolveBaseUrl();
  static String get locationUpdateEndpoint => '$baseUrl/location/update';
  static String get sosEndpoint => '$baseUrl/sos';

  // Admin dashboard endpoints
  static String get locationLiveEndpoint => '$baseUrl/location/live';
  static String get sosAllEndpoint => '$baseUrl/sos/all';
  static String get sosBaseEndpoint => '$baseUrl/sos';
  static String get usersEndpoint => '$baseUrl/auth/users';
  static String get updateProfileEndpoint => '$baseUrl/auth/me';

  // How often the admin dashboard polls for new data.
  static const Duration adminRefreshInterval = Duration(seconds: 15);
  // How often to push live location updates to the backend.
  static const Duration locationUpdateInterval = Duration(seconds: 15);

  // Minimum distance (meters) the device must move before a location
  // update is considered "new" (saves battery/data).
  static const double locationDistanceFilter = 10;
}
