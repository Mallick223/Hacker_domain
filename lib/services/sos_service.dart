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

    final endpoint = AppConfig.sosEndpoint;

    try {
      final response = await http.post(
        Uri.parse(endpoint),
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
        throw Exception(
          'SOS backend rejected the request at $endpoint '
          '(HTTP ${response.statusCode}). '
          'Check that your FastAPI server is running and the API_BASE_URL matches your environment.',
        );
      }
    } on http.ClientException {
      throw Exception(
        'Could not reach the SOS backend at $endpoint. '
        'Start the API server or set API_BASE_URL to the correct host for this device.',
      );
    }
  }
}
