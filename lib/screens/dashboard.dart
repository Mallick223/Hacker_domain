import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../screens/home_screen.dart';
import '../services/auth_service.dart';
import '../theme/guardian_theme.dart';
import '../widgets/guardian_widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emergencyController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _loading = false;
  String? _error;
  UserModel? _user;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _emergencyController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final currentUser = await _authService.getCachedUser();
    if (!mounted) return;
    if (currentUser != null) {
      _nameController.text = currentUser.name;
      _emailController.text = currentUser.email;
      _phoneController.text = currentUser.phone;
      _emergencyController.text = currentUser.emergencyContact ?? '';
    }
    setState(() => _user = currentUser);
  }

  double get _profilePercent {
    final user = _user;
    if (user == null) return 0.0;
    var score = 0;
    if (user.name.isNotEmpty) score += 1;
    if (user.phone.isNotEmpty) score += 1;
    if ((user.emergencyContact ?? '').isNotEmpty) score += 1;
    return score / 3;
  }

  String get _initials {
    final parts = (_user?.name ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s[0].toUpperCase());
    final text = parts.join();
    return text.isEmpty ? 'U' : text;
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final updatedUser = await _authService.updateProfile(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        emergencyContact: _emergencyController.text.trim().isEmpty
            ? null
            : _emergencyController.text.trim(),
      );

      if (!mounted) return;
      setState(() {
        _user = updatedUser;
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = cleanError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('My profile')),
      body: GuardianBackground(
        child: SafeArea(
          child: _user == null
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeaderCard(),
                      const SizedBox(height: 16),
                      _buildCompletenessCard(),
                      const SizedBox(height: 16),
                      _buildFormCard(),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _StatusTile(
                            icon: Icons.phone_outlined,
                            label: _phoneController.text.trim().isNotEmpty
                                ? 'Phone added'
                                : 'Add phone',
                            ok: _phoneController.text.trim().isNotEmpty,
                          ),
                          const SizedBox(width: 12),
                          _StatusTile(
                            icon: Icons.phone_in_talk_outlined,
                            label: _user!.emergencyContact?.isNotEmpty == true
                                ? 'Emergency contact set'
                                : 'Add emergency contact',
                            ok: _user!.emergencyContact?.isNotEmpty == true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      GuardianOutlineButton(
                        label: 'Open live tracking',
                        icon: Icons.map_outlined,
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const HomeScreen()),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: GuardianColors.brandGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: GuardianColors.accentBlue.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.white,
            child: Text(
              _initials,
              style: const TextStyle(
                color: GuardianColors.bg,
                fontWeight: FontWeight.w800,
                fontSize: 22,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome back,',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13)),
                const SizedBox(height: 2),
                Text(
                  _user!.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Keep your details current so help can reach you faster.',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12.5,
                      height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletenessCard() {
    final complete = _profilePercent == 1.0;
    return GuardianCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Profile completeness',
                  style: TextStyle(
                      color: GuardianColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              Text(
                '${(_profilePercent * 100).round()}%',
                style: TextStyle(
                  color: complete
                      ? GuardianColors.safeGreen
                      : GuardianColors.warning,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _profilePercent,
              minHeight: 8,
              color: complete
                  ? GuardianColors.safeGreen
                  : GuardianColors.accentBlue,
              backgroundColor: GuardianColors.bgCardAlt,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            complete
                ? 'All set. Your profile is complete.'
                : 'Add the missing details below.',
            style: const TextStyle(
                color: GuardianColors.textSecondary, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return GuardianCard(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Personal info',
                style: TextStyle(
                    color: GuardianColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            GuardianTextField(
              controller: _nameController,
              label: 'Full name',
              icon: Icons.person_outline_rounded,
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Enter your name' : null,
            ),
            const SizedBox(height: 14),
            GuardianTextField(
              controller: _emailController,
              label: 'Email',
              icon: Icons.email_outlined,
              readOnly: true,
            ),
            const SizedBox(height: 14),
            GuardianTextField(
              controller: _phoneController,
              label: 'Phone number',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Enter your phone number' : null,
            ),
            const SizedBox(height: 14),
            GuardianTextField(
              controller: _emergencyController,
              label: 'Emergency contact',
              icon: Icons.contact_phone_outlined,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              GuardianBanner(message: _error!),
            ],
            const SizedBox(height: 20),
            GuardianButton(
              label: 'Save changes',
              loading: _loading,
              onPressed: _handleSave,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool ok;

  const _StatusTile({
    required this.icon,
    required this.label,
    required this.ok,
  });

  @override
  Widget build(BuildContext context) {
    final color = ok ? GuardianColors.safeGreen : GuardianColors.warning;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: GuardianColors.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}