import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wingbase/Screens/HomeScreen.dart';
import 'package:wingbase/Screens/RegisterScreen.dart';
import 'package:wingbase/providers/auth_provider.dart';
import 'package:wingbase/utils/colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identityController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  final bool _isLoggingIn = false;

  @override
  void dispose() {
    // TODO: implement dispose
    _identityController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_isLoggingIn) return;

    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    final auth = context.read<AuthProvider>();
    final success = await auth.login(
      emailOrPhone: _identityController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Auto redirect if already logged In
    if (auth.isAuthenticated) {
      Future.microtask(() {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      });
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: WingBaseColors.primary,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: WingBaseColors.primary.withOpacity(0.35),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.bolt,
                            color: Colors.white,
                            size: 42,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Welcome back",
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? WingBaseColors.darkTextPrimary
                                : WingBaseColors.lightTextPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: auth.error != null
                        ? _buildErrorBanner(auth.error!)
                        : const SizedBox.shrink(),
                  ),
                  // -----------------------------------
                  // EMAIL / PHONE FIELD
                  // -----------------------------------
                  _buildLabel('Email or Phone'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _identityController,
                    keyboardType: _adaptiveKeyboard(),
                    textInputAction: TextInputAction.next,
                    autofillHints: const [
                      AutofillHints.email,
                      AutofillHints.telephoneNumber,
                    ],
                    decoration: _inputDecoration(
                      hint: 'Enter email or phone number',
                      icon: Icons.person_outline,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Please enter your email or phone';
                      }
                      return null;
                    },
                    onChanged: (_) => context.read<AuthProvider>().clearError(),
                  ),
                  const SizedBox(height: 20),
                  // -----------------------------------
                  // PASSWORD FIELD
                  // -----------------------------------
                  _buildLabel('Password'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onFieldSubmitted: (_) => _login(),
                    decoration: _inputDecoration(
                      hint: 'Enter your password',
                      icon: Icons.lock_outline,
                      suffix: IconButton(
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                          color: isDark
                              ? WingBaseColors.darkTextPrimary
                              : WingBaseColors.lightTextPrimary,
                        ),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (v.length < 8) {
                        return 'Password must be at least 8 characters';
                      }
                      return null;
                    },
                    onChanged: (_) => context.read<AuthProvider>().clearError(),
                  ),
                  const SizedBox(height: 32),
                  // -----------------------------------
                  // LOGIN BUTTON
                  // -----------------------------------
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: auth.loading || _isLoggingIn ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: WingBaseColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: WingBaseColors.primary
                            .withOpacity(0.6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: auth.loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Sign In',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // -----------------------------------
                  // REGISTER LINK
                  // -----------------------------------
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: TextStyle(
                            color: isDark
                                ? WingBaseColors.darkTextSecondary
                                : WingBaseColors.lightTextSecondary,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (_, _, _) => const RegisterScreen(),
                              transitionsBuilder: (_, anim, _, child) =>
                                  FadeTransition(opacity: anim, child: child),
                              transitionDuration: const Duration(
                                milliseconds: 250,
                              ),
                            ),
                          ),
                          child: Text(
                            'Sign Up',
                            style: TextStyle(
                              color: WingBaseColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==============================================================
  // HELPER WIDGETS
  // ==============================================================

  TextInputType _adaptiveKeyboard() {
    final text = _identityController.text;
    return text.contains(RegExp(r'[a-zA-Z]'))
        ? TextInputType.emailAddress
        : TextInputType.phone;
  }

  Widget _buildLabel(String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: isDark
            ? WingBaseColors.darkTextSecondary
            : WingBaseColors.lightTextSecondary,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      key: ValueKey(message),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: isDark
            ? WingBaseColors.darkTextHint
            : WingBaseColors.lightTextHint,
        fontSize: 14,
      ),
      prefixIcon: Icon(
        icon,
        size: 20,
        color: isDark
            ? WingBaseColors.darkTextSecondary
            : WingBaseColors.lightTextSecondary,
      ),
      suffixIcon: suffix,
      filled: true,
      fillColor: isDark
          ? WingBaseColors.darkCardBg
          : WingBaseColors.lightCardBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark
              ? WingBaseColors.darkDivider
              : WingBaseColors.lightDivider,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark
              ? WingBaseColors.darkDivider
              : WingBaseColors.lightDivider,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: WingBaseColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
