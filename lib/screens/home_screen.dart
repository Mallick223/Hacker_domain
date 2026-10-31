import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../services/location_service.dart';
import '../theme/guardian_theme.dart';
import '../widgets/guardian_widgets.dart';
import 'dashboard.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final LocationService _locationService = LocationService();
  final MapController _mapController = MapController();

  LatLng? _currentLatLng;
  bool _trackingActive = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _initTracking();
  }

  Future<void> _initTracking() async {
    final granted = await _locationService.requestPermission();
    if (!granted) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Location permission is required for live tracking. '
            'Please enable it in device settings.';
      });
      return;
    }

    try {
      final position = await _locationService.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _currentLatLng = LatLng(position.latitude, position.longitude);
      });
      unawaited(_locationService.sendLocationToServer(position));
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

  @override
  void dispose() {
    _locationService.stopTracking();
    super.dispose();
  }

  void _recenter() {
    final point = _currentLatLng;
    if (point != null) _mapController.move(point, 16);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GuardianColors.bg,
      body: Stack(
        children: [
          Positioned.fill(child: _buildMap()),
          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      _RoundIconButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Back',
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: GuardianColors.bgCard.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: GuardianColors.border),
                          ),
                          child: const Text(
                            'Live tracking',
                            style: TextStyle(
                              color: GuardianColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _RoundIconButton(
                        icon: Icons.person_outline_rounded,
                        tooltip: 'My profile',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const DashboardScreen()),
                        ),
                      ),
                    ],
                  ),
                  if (_statusMessage != null) ...[
                    const SizedBox(height: 12),
                    GuardianBanner(
                      message: _statusMessage!,
                      color: GuardianColors.warning,
                      icon: Icons.location_off_outlined,
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Bottom status card
          Positioned(
            left: 16,
            right: 16,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _RoundIconButton(
                      icon: Icons.my_location_rounded,
                      tooltip: 'Centre on me',
                      onTap: _recenter,
                    ),
                    const SizedBox(height: 12),
                    _buildStatusCard(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    final point = _currentLatLng;
    if (point == null) {
      return const GuardianBackground(
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(initialCenter: point, initialZoom: 16),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.tourist_safety_app',
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: point,
              width: 56,
              height: 56,
              child: const _LocationDot(),
            ),
          ],
        ),
        const SimpleAttributionWidget(
          source: Text('© OpenStreetMap contributors'),
          backgroundColor: Color(0xCC0A0E27),
        ),
      ],
    );
  }

  Widget _buildStatusCard() {
    final active = _trackingActive;
    final color = active ? GuardianColors.safeGreen : GuardianColors.warning;
    final point = _currentLatLng;
    return GuardianCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              active ? Icons.gps_fixed_rounded : Icons.gps_not_fixed_rounded,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  active ? 'Live tracking active' : 'Acquiring location…',
                  style: const TextStyle(
                    color: GuardianColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  point == null
                      ? 'Waiting for GPS signal'
                      : '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
                  style: const TextStyle(
                      color: GuardianColors.textSecondary, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: GuardianColors.bgCard.withValues(alpha: 0.92),
      shape: const CircleBorder(side: BorderSide(color: GuardianColors.border)),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon, color: GuardianColors.textPrimary, size: 22),
      ),
    );
  }
}

class _LocationDot extends StatelessWidget {
  const _LocationDot();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: GuardianColors.accentBlue,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: GuardianColors.accentBlue.withValues(alpha: 0.6),
              blurRadius: 18,
              spreadRadius: 6,
            ),
          ],
        ),
      ),
    );
  }
}