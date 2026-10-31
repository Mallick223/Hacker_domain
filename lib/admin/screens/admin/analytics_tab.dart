import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import '../../models/location_ping_model.dart';
import '../../models/sos_alert_model.dart';
import '../../theme/admin_theme.dart';

class AnalyticsTab extends StatefulWidget {
  const AnalyticsTab({super.key});

  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<AnalyticsTab> {
  final AdminService _adminService = AdminService();
  List<LocationPingModel> _locations = [];
  List<SosAlertModel> _alerts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
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
    if (_loading) return const Center(child: CircularProgressIndicator());

    final open = _alerts.where((a) => a.status == 'open').length;
    final ack = _alerts.where((a) => a.status == 'acknowledged').length;
    final resolved = _alerts.where((a) => a.status == 'resolved').length;
    final maxCount = [open, ack, resolved].reduce((a, b) => a > b ? a : b).clamp(1, 999);

    final avgLat = _locations.isEmpty
        ? null
        : _locations.map((l) => l.lat).reduce((a, b) => a + b) / _locations.length;
    final avgLng = _locations.isEmpty
        ? null
        : _locations.map((l) => l.lng).reduce((a, b) => a + b) / _locations.length;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null)
            Container(
              width: double.infinity,
              color: AdminColors.dangerBg,
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, style: const TextStyle(color: Color(0xFFE7938C), fontSize: 12)),
            ),
          Row(
            children: [
              Expanded(child: _statCard('${_locations.length}', 'Tracked now')),
              const SizedBox(width: 10),
              Expanded(child: _statCard('${_alerts.length}', 'Total incidents')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _statCard('$open', 'Open', color: AdminColors.danger)),
              const SizedBox(width: 10),
              Expanded(child: _statCard('$resolved', 'Resolved', color: AdminColors.safe)),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Incidents by status', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _bar('Open', open, maxCount, AdminColors.danger),
          _bar('Acknowledged', ack, maxCount, AdminColors.caution),
          _bar('Resolved', resolved, maxCount, AdminColors.safe),
          const SizedBox(height: 20),
          if (avgLat != null && avgLng != null) ...[
            const Text('Cluster center of tracked tourists', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              '${avgLat.toStringAsFixed(4)}, ${avgLng.toStringAsFixed(4)}',
              style: const TextStyle(color: AdminColors.brass, fontFamily: 'monospace', fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statCard(String value, String label, {Color color = AdminColors.brass}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminColors.panel,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AdminColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AdminColors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _bar(String label, int value, int max, Color color) {
    final fraction = value / max;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 12, color: AdminColors.textMuted))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: fraction.clamp(0, 1).toDouble(),
                minHeight: 10,
                backgroundColor: AdminColors.panel2,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 24, child: Text('$value', style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}
