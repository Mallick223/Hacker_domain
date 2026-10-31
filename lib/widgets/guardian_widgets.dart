import 'package:flutter/material.dart';
import '../theme/guardian_theme.dart';

/// Turns "Exception: something" into "something" for display.
String cleanError(Object e) => e.toString().replaceFirst('Exception: ', '');

/// Navy background with two soft glows. Wrap a screen body with this.
class GuardianBackground extends StatelessWidget {
  final Widget child;
  const GuardianBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: GuardianColors.bg,
      child: Stack(
        children: [
          const Positioned(
            top: -120,
            right: -90,
            child: _Glow(color: GuardianColors.accentPurple, size: 300),
          ),
          const Positioned(
            bottom: -150,
            left: -110,
            child: _Glow(color: GuardianColors.accentBlue, size: 340),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  final Color color;
  final double size;
  const _Glow({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [
            color.withValues(alpha: 0.22),
            color.withValues(alpha: 0),
          ]),
        ),
      ),
    );
  }
}

/// Brand logo mark used on auth screens.
class GuardianLogo extends StatelessWidget {
  final double size;
  const GuardianLogo({super.key, this.size = 72});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: GuardianColors.brandGradient,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(76, 111, 255, 0.45),
            blurRadius: 28,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: const Icon(Icons.shield_rounded, color: Colors.white, size: 36),
    );
  }
}

class GuardianCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const GuardianCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: GuardianColors.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: GuardianColors.border),
      ),
      child: child,
    );
  }
}

class GuardianTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool isPassword;
  final bool readOnly;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;

  const GuardianTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.validator,
    this.isPassword = false,
    this.readOnly = false,
    this.textInputAction,
    this.onFieldSubmitted,
  });

  @override
  State<GuardianTextField> createState() => _GuardianTextFieldState();
}

class _GuardianTextFieldState extends State<GuardianTextField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      obscureText: widget.isPassword && _obscure,
      readOnly: widget.readOnly,
      validator: widget.validator,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onFieldSubmitted,
      style: TextStyle(
        color: widget.readOnly
            ? GuardianColors.textSecondary
            : GuardianColors.textPrimary,
      ),
      cursorColor: GuardianColors.accentBlue,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: Icon(widget.icon, size: 20),
        suffixIcon: widget.isPassword
            ? IconButton(
                tooltip: _obscure ? 'Show password' : 'Hide password',
                icon: Icon(
                  _obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              )
            : null,
      ),
    );
  }
}

/// Primary gradient button with a built-in loading state.
class GuardianButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final Gradient gradient;

  const GuardianButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.gradient = GuardianColors.brandGradient,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final glow = gradient.colors.first;
    return Opacity(
      opacity: onPressed == null && !loading ? 0.5 : 1,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: glow.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: enabled ? onPressed : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (icon != null) ...[
                            Icon(icon, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GuardianOutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  const GuardianOutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon ?? Icons.arrow_forward_rounded, size: 20),
      label: Text(label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      style: OutlinedButton.styleFrom(
        foregroundColor: GuardianColors.textPrimary,
        side: const BorderSide(color: GuardianColors.border),
        backgroundColor: GuardianColors.bgCard,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

/// Inline message for errors, warnings and info.
class GuardianBanner extends StatelessWidget {
  final String message;
  final Color color;
  final IconData icon;

  const GuardianBanner({
    super.key,
    required this.message,
    this.color = GuardianColors.dangerRed,
    this.icon = Icons.error_outline_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: GuardianColors.textPrimary,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}