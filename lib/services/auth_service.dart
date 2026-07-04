import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../models/user_model.dart';

/// Handles registration, login, logout, and auth-token persistence.
class AuthService {
  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';

  /// Registers a new tourist account.
  /// Returns the created user on success, throws [AuthException] on failure.
  Future<UserModel> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    String? emergencyContact,
  }) async {
    final response = await http.post(
      Uri.parse(AppConfig.registerEndpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
        'emergency_contact': emergencyContact,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      await _saveSession(data['token'], data['user']);
      return UserModel.fromJson(data['user']);
    } else {
      throw AuthException(_extractError(response));
    }
  }

  /// Logs a user in with email/password.
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse(AppConfig.loginEndpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await _saveSession(data['token'], data['user']);
      return UserModel.fromJson(data['user']);
    } else {
      throw AuthException(_extractError(response));
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<UserModel?> getCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);
    if (userJson == null) return null;
    return UserModel.fromJson(jsonDecode(userJson));
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> _saveSession(String token, Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(user));
  }

  String _extractError(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      return body['message'] ?? body['detail'] ?? 'Something went wrong (${response.statusCode})';
    } catch (_) {
      return 'Something went wrong (${response.statusCode})';
    }
  }
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}
