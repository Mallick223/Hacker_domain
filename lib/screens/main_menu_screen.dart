import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/auth_service.dart';
import '../theme/guardian_theme.dart';
import 'dashboard.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'sos_screen.dart';

/// ---------------------------------------------------------------------
/// Guardian Go — Main Menu / Dashboard
/// Redesigned in the SYBRAI style: deep navy background, glassy gradient
/// cards, blue-purple accent, soft glows, bottom nav.
/// Drop this in as lib/screens/main_menu_screen.dart
/// ---------------------------------------------------------------------

class MainMenuScreen extends StatefulWidget {
  final String userName;
  final int safetyScore; // 0-100
  final bool inSafeZone;

  const MainMenuScreen({
    super.key,
    this.userName = 'Traveler',
    this.safetyScore = 92,
    this.inSafeZone = true,
  });

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  final AuthService _authService = AuthService();
  int _navIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GuardianColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildSafeZoneCard(),
              const SizedBox(height: 20),
              _buildQuickAccessGrid(context),
              const SizedBox(height: 20),
              _buildRecentAlerts(),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildSosFab(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ---------------- Header ----------------
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello, ${widget.userName} 👋',
              style: const TextStyle(
                color: GuardianColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Stay Alert, Stay Safe',
              style: TextStyle(color: GuardianColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: GuardianColors.bgCard,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white10),
              ),
              child: const Icon(Icons.notifications_none_rounded,
                  color: GuardianColors.textPrimary, size: 22),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _handleLogout,
              tooltip: 'Log out',
              icon: const Icon(Icons.logout_rounded,
                  color: GuardianColors.textPrimary),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------- Safe zone / safety score card ----------------
  Widget _buildSafeZoneCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: widget.inSafeZone
            ? GuardianColors.safeZoneGradient
            : const LinearGradient(
                colors: [Color(0xFFB91C1C), Color(0xFFEF4444)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (widget.inSafeZone
                    ? GuardianColors.safeGreen
                    : GuardianColors.dangerRed)
                .withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You are in',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
              ),
              Text(
                widget.inSafeZone ? 'Safe Zone' : 'Risk Zone',
                style: const TextStyle(
                    color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              Text(
                'Safety Score',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${widget.safetyScore}',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                  const Text(' /100',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shield_rounded, color: Colors.white, size: 32),
          ),
        ],
      ),
    );
  }

  // ---------------- Quick access 2x2 tiles ----------------
  Widget _buildQuickAccessGrid(BuildContext context) {
    final tiles = [
      _TileData(
        'AI Risk Prediction',
        'Low Risk',
        'assets/images/ai_risk_prediction.svg',
        GuardianColors.accentBlue,
        () => _comingSoon(context, 'AI Risk Prediction'),
      ),
      _TileData(
        'Live Tracking',
        'Active',
        'assets/images/live_tracking.svg',
        GuardianColors.accentPurple,
        () => _openTracking(context),
      ),
      _TileData(
        'Emergency SOS',
        'Tap for Help',
        'assets/images/emergency_sos.svg',
        GuardianColors.dangerRed,
        () => _openSos(context),
      ),
      _TileData(
        'Geofencing',
        'Get Directions',
        'assets/images/geofencing.svg',
        GuardianColors.safeGreen,
        () => _comingSoon(context, 'Geofencing'),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tiles.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.35,
      ),
      itemBuilder: (context, i) => _QuickTile(data: tiles[i]),
    );
  }

  // ---------------- Recent alerts ----------------
  Widget _buildRecentAlerts() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: GuardianColors.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recent Alerts',
              style: TextStyle(
                  color: GuardianColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _alertRow('Low crowd density in your area', '2 min ago',
              GuardianColors.safeGreen),
        ],
      ),
    );
  }

  Widget _alertRow(String text, String time, Color dotColor) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: const TextStyle(color: GuardianColors.textSecondary, fontSize: 13)),
        ),
        Text(time,
            style: const TextStyle(color: GuardianColors.textSecondary, fontSize: 11)),
      ],
    );
  }

  // ---------------- SOS FAB ----------------
  Widget _buildSosFab(BuildContext context) {
    return GestureDetector(
      onTap: () => _openSos(context),
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
              colors: [Color(0xFFEF4444), Color(0xFFB91C1C)]),
          boxShadow: [
            BoxShadow(
              color: GuardianColors.dangerRed.withValues(alpha: 0.5),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Icon(Icons.sos_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  // ---------------- Bottom nav ----------------
  Widget _buildBottomNav() {
    final items = [
      _NavItem(Icons.home_rounded, 'Home'),
      _NavItem(Icons.notifications_none_rounded, 'Alerts'),
      _NavItem(Icons.qr_code_scanner_rounded, 'Scan'),
      _NavItem(Icons.person_outline_rounded, 'Profile'),
    ];

    return BottomAppBar(
      color: GuardianColors.bgCardAlt,
      shape: const CircularNotchedRectangle(),
      notchMargin: 10,
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (i) {
            final selected = i == _navIndex;
            return InkWell(
              onTap: () => _handleNavTap(context, i),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(items[i].icon,
                      color: selected
                          ? GuardianColors.accentBlue
                          : GuardianColors.textSecondary,
                      size: 22),
                  const SizedBox(height: 2),
                  Text(items[i].label,
                      style: TextStyle(
                          fontSize: 10,
                          color: selected
                              ? GuardianColors.accentBlue
                              : GuardianColors.textSecondary)),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  void _handleNavTap(BuildContext context, int index) {
    if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
      return;
    }

    setState(() => _navIndex = index);
  }

  void _openTracking(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  void _openSos(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const SosScreen()));
  }

  Future<void> _handleLogout() async {
    await _authService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _comingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature — coming soon'),
        backgroundColor: GuardianColors.bgCardAlt,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Small helper widgets
// ---------------------------------------------------------------------

class _TileData {
  final String title;
  final String subtitle;
  final String artwork;
  final Color color;
  final VoidCallback onTap;
  _TileData(this.title, this.subtitle, this.artwork, this.color, this.onTap);
}

class _QuickTile extends StatelessWidget {
  final _TileData data;
  const _QuickTile({required this.data});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: data.onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: GuardianColors.bgCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: SvgPicture.asset(
                  data.artwork,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              data.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: GuardianColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              data.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: data.color,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  _NavItem(this.icon, this.label);
}