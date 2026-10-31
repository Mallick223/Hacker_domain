import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';
import '../services/sos_service.dart';
import '../theme/guardian_theme.dart';
import '../widgets/guardian_widgets.dart';
import 'home_screen.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

enum _SosStage { ready, checking, deciding, sending, sent, issue }

class _SosStep {
  final String title;
  final String detail;
  final IconData icon;
  final bool complete;
  final bool active;

  const _SosStep({
    required this.title,
    required this.detail,
    required this.icon,
    this.complete = false,
    this.active = false,
  });
}

class _SosScreenState extends State<SosScreen> {
  final LocationService _locationService = LocationService();
  final SosService _sosService = SosService();

  _SosStage _stage = _SosStage.ready;
  String? _issue;
  Position? _position;

  Future<void> _startSos() async {
    setState(() {
      _stage = _SosStage.checking;
      _issue = null;
    });

    try {
      final permissionGranted = await _locationService.requestPermission();
      if (!permissionGranted) {
        throw Exception('Location permission or GPS service is unavailable.');
      }
      _position = await _locationService.getCurrentPosition();
      if (!mounted) return;
      setState(() => _stage = _SosStage.deciding);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _stage = _SosStage.issue;
        _issue = cleanError(error);
      });
    }
  }

  Future<void> _confirmDanger() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GuardianColors.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: GuardianColors.border),
        ),
        title: const Text('Confirm emergency',
            style: TextStyle(
                color: GuardianColors.textPrimary, fontWeight: FontWeight.w800)),
        content: const Text(
          'Are you in immediate danger? Guardian Go will send your location to the configured alert channels.',
          style: TextStyle(color: GuardianColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: GuardianColors.textSecondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: GuardianColors.dangerRed),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('I am in danger'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted || _position == null) return;
    await _sendSos(_position!);
  }

  Future<void> _sendSos(Position position) async {
    setState(() => _stage = _SosStage.sending);
    try {
      await _sosService.triggerSos(
        position: position,
        message: 'Emergency SOS confirmed by user',
      );
      if (!mounted) return;
      setState(() => _stage = _SosStage.sent);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _stage = _SosStage.issue;
        _issue = cleanError(error);
      });
    }
  }

  List<_SosStep> get _steps {
    final locationDone = _stage.index >= _SosStage.deciding.index &&
        _stage != _SosStage.issue;
    final decisionDone = _stage.index >= _SosStage.sending.index &&
        _stage != _SosStage.issue;
    final alertSent = _stage == _SosStage.sent;
    return [
      _SosStep(
        title: 'Location captured',
        detail: locationDone ? 'GPS coordinates ready' : 'Waiting for GPS permission',
        icon: Icons.location_on_outlined,
        complete: locationDone,
        active: _stage == _SosStage.checking,
      ),
      _SosStep(
        title: 'Danger decision',
        detail: decisionDone
            ? 'Emergency confirmed'
            : 'Confirm only if you need immediate help',
        icon: Icons.psychology_outlined,
        complete: decisionDone,
        active: _stage == _SosStage.deciding,
      ),
      _SosStep(
        title: 'Signal and alert delivery',
        detail: alertSent
            ? 'Backend accepted the SOS alert'
            : 'Network checked when alert is sent',
        icon: Icons.wifi_tethering,
        complete: alertSent,
        active: _stage == _SosStage.sending,
      ),
      _SosStep(
        title: 'Contact channels',
        detail: alertSent
            ? 'Authority, family, and emergency-service dispatch queued'
            : 'Channels wait for a confirmed alert',
        icon: Icons.groups_outlined,
        complete: alertSent,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _stage == _SosStage.checking || _stage == _SosStage.sending;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Emergency SOS')),
      body: GuardianBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStatusHeader(),
                const SizedBox(height: 20),
                ..._steps.map(_buildStep),
                if (_issue != null) ...[
                  const SizedBox(height: 4),
                  GuardianBanner(
                    message:
                        '$_issue\nCall local emergency services directly if this persists.',
                    color: GuardianColors.warning,
                  ),
                ],
                const SizedBox(height: 24),
                _buildAction(),
                if (isBusy)
                  const Padding(
                    padding: EdgeInsets.only(top: 14),
                    child: Text(
                      'Please keep this page open while the alert is being processed.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: GuardianColors.textSecondary, fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAction() {
    switch (_stage) {
      case _SosStage.ready:
      case _SosStage.issue:
        return GuardianButton(
          label: _stage == _SosStage.issue ? 'Try again' : 'Start SOS check',
          icon: Icons.sos_rounded,
          gradient: GuardianColors.dangerGradient,
          onPressed: _startSos,
        );
      case _SosStage.deciding:
        return GuardianButton(
          label: 'I am in danger',
          icon: Icons.warning_amber_rounded,
          gradient: GuardianColors.dangerGradient,
          onPressed: _confirmDanger,
        );
      case _SosStage.sent:
        return GuardianOutlineButton(
          label: 'Open live tracking',
          icon: Icons.map_outlined,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          ),
        );
      case _SosStage.checking:
      case _SosStage.sending:
        return const Center(child: CircularProgressIndicator());
    }
  }

  Widget _buildStatusHeader() {
    final sent = _stage == _SosStage.sent;
    final issue = _stage == _SosStage.issue;
    final color = sent
        ? GuardianColors.safeGreen
        : issue
            ? GuardianColors.warning
            : GuardianColors.dangerRed;
    final title = sent
        ? 'SOS alert accepted'
        : issue
            ? 'SOS could not be completed'
            : 'Emergency response readiness';
    final subtitle = sent
        ? 'Help has been notified. Stay where it is safe.'
        : issue
            ? 'Fix the issue below and try again.'
            : 'We check your location first, then ask you to confirm.';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.18), blurRadius: 24),
        ],
      ),
      child: Row(
        children: [
          Icon(
            sent
                ? Icons.check_circle_rounded
                : issue
                    ? Icons.error_outline_rounded
                    : Icons.shield_rounded,
            color: color,
            size: 40,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: color)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(
                        color: GuardianColors.textSecondary,
                        fontSize: 12.5,
                        height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(_SosStep step) {
    final color = step.complete
        ? GuardianColors.safeGreen
        : step.active
            ? GuardianColors.accentBlue
            : GuardianColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: GuardianColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: step.active || step.complete
                ? color.withValues(alpha: 0.45)
                : GuardianColors.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(step.complete ? Icons.check_rounded : step.icon,
                  color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(step.title,
                      style: const TextStyle(
                          color: GuardianColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5)),
                  const SizedBox(height: 2),
                  Text(step.detail,
                      style: const TextStyle(
                          color: GuardianColors.textSecondary, fontSize: 12.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}