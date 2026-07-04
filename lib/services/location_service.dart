import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'auth_service.dart';

/// Handles GPS permission requests, live position streaming,
/// and periodic upload of location to the backend.
class LocationService {
  final AuthService _auth = AuthService();
  StreamSubscription<Position>? _positionSub;

  /// Requests location permission. Returns true if granted.
  Future<bool> requestPermission() async {
    if (!kIsWeb) {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return false; // Ask the user to enable GPS in device settings.
      }
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false; // User must enable it manually from app settings.
    }

    return true;
  }

  /// Gets a single current position (e.g. for SOS or initial map center).
  Future<Position> getCurrentPosition() {
    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  /// Starts streaming live location updates.
  /// [onUpdate] fires on every new position (for updating the map UI).
  /// Also pushes each update to the backend so the admin dashboard
  /// and family members can see live tourist location.
  void startTracking({required void Function(Position) onUpdate}) {
    final settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: AppConfig.locationDistanceFilter.toInt(),
    );

    _positionSub = Geolocator.getPositionStream(locationSettings: settings)
        .listen((position) {
      onUpdate(position);
      _pushLocationToServer(position);
    });
  }

  void stopTracking() {
    _positionSub?.cancel();
    _positionSub = null;
  }

  Future<void> _pushLocationToServer(Position position) async {
    final token = await _auth.getToken();
    if (token == null) return;

    try {
      await http.post(
        Uri.parse(AppConfig.locationUpdateEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'lat': position.latitude,
          'lng': position.longitude,
          'speed': position.speed,
          'heading': position.heading,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
    } catch (_) {
      // Silently ignore network failures here; consider queuing
      // updates locally and retrying if you need offline resilience.
    }
  }
}
