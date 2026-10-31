import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/guardian_theme.dart';
import '../widgets/guardian_widgets.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  final _authService = AuthService();

  bool _loading = false;
  String? _error;
  String _selectedEmergencyRelation = 'Mother';
  final List<String> _emergencyRelations = ['Mother', 'Father', 'Sibling', 'Other'];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _emergencyContactController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final emergencyContact = _emergencyContactController.text.trim();
      await _authService.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        password: _passwordController.text,
        emergencyContact: emergencyContact.isEmpty
            ? null
            : '$_selectedEmergencyRelation: $emergencyContact',
      );
      await _authService.logout();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const LoginScreen(
            successMessage: 'Registration completed successfully.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _error = cleanError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _sectionTitle(String text, {String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text,
              style: const TextStyle(
                  color: GuardianColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(hint,
                style: const TextStyle(
                    color: GuardianColors.textSecondary, fontSize: 12.5)),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(),
      body: GuardianBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Create your account',
                        style: TextStyle(
                          color: GuardianColors.textPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'It takes a minute and helps us reach you in an emergency.',
                        style: TextStyle(
                            color: GuardianColors.textSecondary, fontSize: 14),
                      ),
                      const SizedBox(height: 28),
                      _sectionTitle('About you'),
                      GuardianTextField(
                        controller: _nameController,
                        label: 'Full name',
                        icon: Icons.person_outline_rounded,
                        textInputAction: TextInputAction.next,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Enter your name'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      GuardianTextField(
                        controller: _emailController,
                        label: 'Email',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: (v) => (v == null || !v.contains('@'))
                            ? 'Enter a valid email'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      GuardianTextField(
                        controller: _phoneController,
                        label: 'Phone number',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Enter your phone number'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      GuardianTextField(
                        controller: _passwordController,
                        label: 'Password',
                        icon: Icons.lock_outline_rounded,
                        isPassword: true,
                        textInputAction: TextInputAction.next,
                        validator: (v) => (v == null || v.length < 6)
                            ? 'Use at least 6 characters'
                            : null,
                      ),
                      const SizedBox(height: 28),
                      _sectionTitle('Emergency contact',
                          hint: 'Optional. We alert this person if you trigger an SOS.'),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedEmergencyRelation,
                        dropdownColor: GuardianColors.bgCardAlt,
                        style: const TextStyle(color: GuardianColors.textPrimary),
                        iconEnabledColor: GuardianColors.textSecondary,
                        decoration: const InputDecoration(
                          labelText: 'Relation',
                          prefixIcon: Icon(Icons.people_outline_rounded, size: 20),
                        ),
                        items: _emergencyRelations
                            .map((r) => DropdownMenuItem<String>(
                                value: r, child: Text(r)))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedEmergencyRelation = value);
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                      GuardianTextField(
                        controller: _emergencyContactController,
                        label: 'Contact number',
                        icon: Icons.contact_phone_outlined,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.done,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        GuardianBanner(message: _error!),
                      ],
                      const SizedBox(height: 28),
                      GuardianButton(
                        label: 'Create account',
                        loading: _loading,
                        onPressed: _handleRegister,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}