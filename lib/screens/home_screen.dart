import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../services/sos_service.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final LocationService _locationService = LocationService();
  final SosService _sosService = SosService();
  final AuthService _authService = AuthService();
  final MapController _mapController = MapController();

  LatLng? _currentLatLng;
  bool _trackingActive = false;
  bool _sosSending = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _initTracking();
  }

  Future<void> _initTracking() async {
    final granted = await _locationService.requestPermission();
    if (!granted) {
      setState(() {
        _statusMessage =
            'Location permission is required for live tracking and SOS. '
            'Please enable it in device settings.';
      });
      return;
    }

    try {
      final position = await _locationService.getCurrentPosition();
      setState(() {
        _currentLatLng = LatLng(position.latitude, position.longitude);
      });
    } catch (_) {
      // Fall back silently; the stream below will update it shortly.
    }

    _locationService.startTracking(onUpdate: (Position position) {
      final latLng = LatLng(position.latitude, position.longitude);
      if (!mounted) return;
      setState(() {
        _currentLatLng = latLng;
        _trackingActive = true;
      });
      _mapController.move(latLng, _mapController.camera.zoom);
    });
  }

  Future<void> _handleSos() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm SOS'),
        content: const Text(
          'This will immediately alert authorities, your emergency contacts, '
          'and emergency services with your current location. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Send SOS'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _sosSending = true;
      _statusMessage = null;
    });

    try {
      final position = await _locationService.getCurrentPosition();
      await _sosService.triggerSos(position: position);
      setState(() {
        _statusMessage =
            '✅ SOS sent. Authorities and your emergency contacts have been notified.';
      });
    } catch (e) {
      setState(() {
        _statusMessage = '❌ $e';
      });
    } finally {
      if (mounted) setState(() => _sosSending = false);
    }
  }

  Future<void> _handleLogout() async {
    _locationService.stopTracking();
    await _authService.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  void dispose() {
    _locationService.stopTracking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Safety Tracking'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Log out',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_statusMessage != null)
            Container(
              width: double.infinity,
              color: Colors.amber.shade100,
              padding: const EdgeInsets.all(12),
              child: Text(_statusMessage!),
            ),
          Expanded(
            child: _currentLatLng == null
                ? const Center(child: CircularProgressIndicator())
                : FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _currentLatLng!,
                      initialZoom: 16,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.tourist_safety_app',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _currentLatLng!,
                            width: 48,
                            height: 48,
                            child: const Icon(
                              Icons.person_pin_circle,
                              color: Colors.indigo,
                              size: 48,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 12,
                  color: _trackingActive ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(_trackingActive ? 'Live tracking active' : 'Acquiring location...'),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _sosSending ? null : _handleSos,
        backgroundColor: Colors.red,
        icon: _sosSending
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.sos, color: Colors.white),
        label: Text(
          _sosSending ? 'Sending...' : 'SOS',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
