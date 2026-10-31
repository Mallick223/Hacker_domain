import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../models/user_model.dart';

/// Handles registration, login, logout, and auth-token persistence.
class AuthService {
  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Registers a new tourist account.
  /// Returns the created user on success, throws [AuthException] on failure.
  Future<UserModel> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    String? emergencyContact,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final firebaseUser = credential.user;
      if (firebaseUser == null) throw AuthException('Registration failed');

      await firebaseUser.updateDisplayName(name);
      final user = UserModel(
        id: firebaseUser.uid,
        name: name,
        email: email,
        phone: phone,
        emergencyContact: emergencyContact,
      );
      await _firestore.collection('users').doc(firebaseUser.uid).set({
        ...user.toJson(),
        'created_at': FieldValue.serverTimestamp(),
      });
      await _saveFirebaseSession(firebaseUser, user);
      return user;
    } on FirebaseAuthException catch (error) {
      throw AuthException(_firebaseError(error));
    }
  }

  /// Logs a user in with email/password.
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final firebaseUser = credential.user;
      if (firebaseUser == null) throw AuthException('Login failed');

      final snapshot = await _firestore.collection('users').doc(firebaseUser.uid).get();
      final user = snapshot.exists
          ? UserModel.fromJson(snapshot.data()!)
          : UserModel(
              id: firebaseUser.uid,
              name: firebaseUser.displayName ?? '',
              email: firebaseUser.email ?? email,
              phone: '',
            );
      await _saveFirebaseSession(firebaseUser, user);
      return user;
    } on FirebaseAuthException catch (error) {
      throw AuthException(_firebaseError(error));
    }
  }

  Future<void> logout() async {
    await _firebaseAuth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  Future<UserModel> updateProfile({
    required String name,
    required String phone,
    String? emergencyContact,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw AuthException('Not authenticated');
    }

    final body = jsonEncode({
      'name': name,
      'phone': phone,
      'emergency_contact': emergencyContact,
    });

    final response = await http.patch(
      Uri.parse(AppConfig.updateProfileEndpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final updatedUser = UserModel.fromJson(data);
      await _saveUser(updatedUser.toJson());
      return updatedUser;
    } else {
      throw AuthException(_extractError(response));
    }
  }

  Future<void> _saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user));
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

  Future<void> _saveFirebaseSession(User firebaseUser, UserModel user) async {
    final token = await firebaseUser.getIdToken();
    if (token == null || token.isEmpty) throw AuthException('Could not create an auth token');
    await _saveSession(token, user.toJson());
  }

  String _firebaseError(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'An account with this email already exists';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Invalid email or password';
      case 'weak-password':
        return 'Password is too weak';
      case 'invalid-email':
        return 'Enter a valid email address';
      default:
        return error.message ?? 'Authentication failed';
    }
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
