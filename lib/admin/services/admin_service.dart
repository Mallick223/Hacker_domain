import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config.dart';
import '../models/location_ping_model.dart';
import '../models/sos_alert_model.dart';
import '../../models/user_model.dart';

/// Talks to the admin-support endpoints on the FastAPI backend:
/// GET /api/location/live, GET /api/sos/all, PATCH /api/sos/{id}/status,
/// GET /api/auth/users. These are intentionally left open (no admin auth
/// check) in the starter backend — see the backend README before shipping.
class AdminService {
  Future<List<LocationPingModel>> fetchLiveLocations() async {
    final response = await http.get(Uri.parse(AppConfig.locationLiveEndpoint));
    if (response.statusCode != 200) {
      throw Exception('Failed to load live locations (${response.statusCode})');
    }
    final data = jsonDecode(response.body) as List;
    return data.map((e) => LocationPingModel.fromJson(e)).toList();
  }

  Future<List<SosAlertModel>> fetchAllSosAlerts() async {
    final response = await http.get(Uri.parse(AppConfig.sosAllEndpoint));
    if (response.statusCode != 200) {
      throw Exception('Failed to load SOS alerts (${response.statusCode})');
    }
    final data = jsonDecode(response.body) as List;
    return data.map((e) => SosAlertModel.fromJson(e)).toList();
  }

  Future<void> updateSosStatus(int alertId, String status) async {
    final response = await http.patch(
      Uri.parse('${AppConfig.sosBaseEndpoint}/$alertId/status'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'status': status}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update alert status (${response.statusCode})');
    }
  }

  Future<List<UserModel>> fetchAllUsers() async {
    final response = await http.get(Uri.parse(AppConfig.usersEndpoint));
    if (response.statusCode != 200) {
      throw Exception('Failed to load users (${response.statusCode})');
    }
    final data = jsonDecode(response.body) as List;
    return data.map((e) => UserModel.fromJson(e)).toList();
  }
}
