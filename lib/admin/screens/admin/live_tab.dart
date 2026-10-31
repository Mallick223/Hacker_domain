import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../config.dart';
import '../../models/location_ping_model.dart';
import '../../models/sos_alert_model.dart';
import '../../services/admin_service.dart';
import '../../theme/admin_theme.dart';

class LiveTab extends StatefulWidget {
  const LiveTab({super.key});

  @override
  State<LiveTab> createState() => _LiveTabState();
}

class _LiveTabState extends State<LiveTab> {
  final AdminService _adminService = AdminService();
  List<LocationPingModel> _locations = [];
  List<SosAlertModel> _alerts = [];
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(
      AppConfig.adminRefreshInterval,
      (_) => _load(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final locations = await _adminService.fetchLiveLocations();
      final alerts = await _adminService.fetchAllSosAlerts();
      if (!mounted) return;
      setState(() {
        _locations = locations;
        _alerts = alerts;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not reach the backend. Pull down to retry.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final openAlerts = _alerts.where((a) => a.status != 'resolved').toList();
    final center = _locations.isNotEmpty
        ? LatLng(_locations.first.lat, _locations.first.lng)
        : const LatLng(15.40, 73.95);

    return RefreshIndicator(
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_error != null)
                  Container(
                    width: double.infinity,
                    color: AdminColors.dangerBg,
                    padding: const EdgeInsets.all(10),
                    child: Text(_error!, style: const TextStyle(color: Color(0xFFE7938C), fontSize: 12)),
                  ),
                Expanded(
                  child: FlutterMap(
                    options: MapOptions(initialCenter: center, initialZoom: 11),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.tourist_safety_app',
                      ),
                      MarkerLayer(
                        markers: [
                          ..._locations.map((loc) => Marker(
                                point: LatLng(loc.lat, loc.lng),
                                width: 20,
                                height: 20,
                                child: const Icon(Icons.circle, color: AdminColors.safe, size: 14),
                              )),
                          ...openAlerts.map((a) => Marker(
                                point: LatLng(a.lat, a.lng),
                                width: 28,
                                height: 28,
                                child: const Icon(Icons.sos, color: AdminColors.danger, size: 22),
                              )),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  color: AdminColors.panel,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  child: Row(
                    children: [
                      _statChip('${_locations.length}', 'Tracked now', AdminColors.brass),
                      const SizedBox(width: 10),
                      _statChip('${openAlerts.length}', 'Open SOS', AdminColors.danger),
                      const Spacer(),
                      Text(
                        'Auto-refreshes every ${AppConfig.adminRefreshInterval.inSeconds}s',
                        style: const TextStyle(color: AdminColors.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _statChip(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: AdminColors.hairline),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
          Text(label, style: const TextStyle(color: AdminColors.textMuted, fontSize: 10)),
        ],
      ),
    );
  }
}
