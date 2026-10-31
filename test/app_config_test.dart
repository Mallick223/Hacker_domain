import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:tourist_safety_app/config.dart';

void main() {
  test('Android targets use the emulator host for local backend', () {
    expect(
      AppConfig.resolveBaseUrl(platform: TargetPlatform.android),
      'http://10.0.2.2:8000/api',
    );
  });

  test('Desktop targets use the local loopback host', () {
    expect(
      AppConfig.resolveBaseUrl(platform: TargetPlatform.windows),
      'http://127.0.0.1:8000/api',
    );
  });
}
