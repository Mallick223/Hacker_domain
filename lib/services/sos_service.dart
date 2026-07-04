import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'auth_service.dart';

/// Fires the emergency SOS alert to the backend, which fans it out
/// to Authorities/Rescue, Family Members, and Emergency Services
/// (per the Decision & Alert Engine in the system design).
class SosService {
  final AuthService _auth = AuthService();

  Future<void> triggerSos({
    required Position position,
    String? message,
  }) async {
    final token = await _auth.getToken();
    if (token == null) {
      throw Exception('You must be logged in to send an SOS alert.');
    }

    final response = await http.post(
      Uri.parse(AppConfig.sosEndpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'lat': position.latitude,
        'lng': position.longitude,
        'timestamp': DateTime.now().toIso8601String(),
        'message': message ?? 'Emergency SOS triggered by user',
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to send SOS alert (${response.statusCode}). '
          'Please call local emergency services directly if this persists.');
    }
  }
}
