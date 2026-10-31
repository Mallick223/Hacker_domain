import 'package:flutter/material.dart';
import '../../models/sos_alert_model.dart';
import '../../services/admin_service.dart';
import '../../theme/admin_theme.dart';

class IncidentsTab extends StatefulWidget {
  const IncidentsTab({super.key});

  @override
  State<IncidentsTab> createState() => _IncidentsTabState();
}

class _IncidentsTabState extends State<IncidentsTab> {
  final AdminService _adminService = AdminService();
  List<SosAlertModel> _alerts = [];
  String _filter = 'all';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final alerts = await _adminService.fetchAllSosAlerts();
      alerts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      if (!mounted) return;
      setState(() {
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

  Future<void> _updateStatus(SosAlertModel alert, String status) async {
    try {
      await _adminService.updateSosStatus(alert.id, status);
      setState(() {
        _alerts = _alerts
            .map((a) => a.id == alert.id ? a.copyWith(status: status) : a)
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    }
  }

  String _timeAgo(DateTime t) {
    final mins = DateTime.now().difference(t).inMinutes;
    if (mins < 60) return '${mins}m ago';
    return '${(mins / 60).floor()}h ago';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filter == 'all'
        ? _alerts
        : _alerts.where((a) => a.status == _filter).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _filterChip('all', 'All'),
                const SizedBox(width: 6),
                _filterChip('open', 'Open'),
                const SizedBox(width: 6),
                _filterChip('acknowledged', 'Ack'),
                const SizedBox(width: 6),
                _filterChip('resolved', 'Resolved'),
              ],
            ),
          ),
          if (_error != null)
            Container(
              width: double.infinity,
              color: AdminColors.dangerBg,
              padding: const EdgeInsets.all(10),
              child: Text(_error!, style: const TextStyle(color: Color(0xFFE7938C), fontSize: 12)),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? const Center(
                        child: Text('No incidents match this filter.',
                            style: TextStyle(color: AdminColors.textMuted)),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) => _incidentCard(filtered[index]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String value, String label) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: selected ? AdminColors.chrome : AdminColors.textMuted)),
      selected: selected,
      selectedColor: AdminColors.brass,
      backgroundColor: AdminColors.panel2,
      onSelected: (_) => setState(() => _filter = value),
    );
  }

  Widget _incidentCard(SosAlertModel alert) {
    final color = AdminColors.statusColor(alert.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AdminColors.panel,
        border: Border.all(color: AdminColors.hairline),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: double.infinity, height: 3, color: color),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Tourist #${alert.userId}',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: AdminColors.textPrimary)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AdminColors.statusBg(alert.status),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(alert.status.toUpperCase(),
                          style: TextStyle(fontSize: 10, color: color, letterSpacing: 0.5)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${alert.lat.toStringAsFixed(4)}, ${alert.lng.toStringAsFixed(4)} · ${_timeAgo(alert.timestamp)}',
                  style: const TextStyle(color: AdminColors.textMuted, fontSize: 11, fontFamily: 'monospace'),
                ),
                const SizedBox(height: 8),
                Text(alert.message ?? '', style: const TextStyle(color: AdminColors.textPrimary, fontSize: 13)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (alert.status == 'open')
                      TextButton(
                        onPressed: () => _updateStatus(alert, 'acknowledged'),
                        child: const Text('Acknowledge', style: TextStyle(color: AdminColors.caution, fontSize: 12)),
                      ),
                    if (alert.status != 'resolved')
                      TextButton(
                        onPressed: () => _updateStatus(alert, 'resolved'),
                        child: const Text('Resolve', style: TextStyle(color: AdminColors.safe, fontSize: 12)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
