import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/guardian_theme.dart';
import '../widgets/guardian_widgets.dart';
import 'main_menu_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  final String? successMessage;

  const LoginScreen({super.key, this.successMessage});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.successMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.successMessage!)),
        );
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _authService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainMenuScreen()),
      );
    } catch (e) {
      if (mounted) setState(() => _error = cleanError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GuardianBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Image.asset(
                          'assets/splash_logo.png',
                          width: 180,
                          height: 180,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Welcome back',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: GuardianColors.textPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Sign in to keep your trip monitored.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: GuardianColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 32),
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
                      const SizedBox(height: 16),
                      GuardianTextField(
                        controller: _passwordController,
                        label: 'Password',
                        icon: Icons.lock_outline_rounded,
                        isPassword: true,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _handleLogin(),
                        validator: (v) => (v == null || v.length < 6)
                            ? 'Use at least 6 characters'
                            : null,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        GuardianBanner(message: _error!),
                      ],
                      const SizedBox(height: 24),
                      GuardianButton(
                        label: 'Log in',
                        loading: _loading,
                        onPressed: _handleLogin,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Don't have an account?",
                            style: TextStyle(
                                color: GuardianColors.textSecondary,
                                fontSize: 13),
                          ),
                          TextButton(
                            onPressed: _loading
                                ? null
                                : () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const RegisterScreen()),
                                    ),
                            child: const Text(
                              'Create account',
                              style: TextStyle(
                                color: GuardianColors.accentBlue,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
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