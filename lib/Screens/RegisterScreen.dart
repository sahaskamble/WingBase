import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:wingbase/providers/auth_provider.dart';
import 'package:wingbase/Screens/HomeScreen.dart';
import 'package:wingbase/Screens/LoginScreen.dart';
import 'package:wingbase/utils/colors.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isRegistering = false;
  File? _avatarFile;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------
  // PICK AVATAR
  // ---------------------------------------------------------------
  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (picked != null) {
      setState(() => _avatarFile = File(picked.path));
    }
  }

  // ---------------------------------------------------------------
  // REGISTER
  // ---------------------------------------------------------------
  Future<void> _register() async {
    if (_isRegistering) return; // Prevent double taps
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _isRegistering = true);

    final auth = context.read<AuthProvider>();
    final success = await auth.register(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      password: _passwordController.text,
      avatar: _avatarFile,
    );

    if (!mounted) return;
    setState(() => _isRegistering = false);

    if (success) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ---------------------------------------------------------------
    // AUTO REDIRECT IF ALREADY LOGGED IN
    // ---------------------------------------------------------------
    if (auth.isAuthenticated) {
      Future.microtask(() {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      });
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => _navigateBack(context),
          icon: const Icon(Icons.arrow_back),
        ),
      ),

      // ---------------------------------------------------------------
      // BODY
      // ---------------------------------------------------------------
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  'Create account',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? WingBaseColors.darkTextPrimary
                        : WingBaseColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Fill in your details to get started',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? WingBaseColors.darkTextSecondary
                        : WingBaseColors.lightTextSecondary,
                  ),
                ),

                const SizedBox(height: 28),

                // Avatar picker
                Center(child: _buildAvatarPicker(isDark)),
                const SizedBox(height: 28),

                // Animated error banner
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: auth.error != null
                      ? _buildErrorBanner(auth.error!)
                      : const SizedBox.shrink(),
                ),

                // Full Name
                _buildLabel('Full Name'),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _nameController,
                  hint: 'Your full name',
                  icon: Icons.person_outline,
                  validator: (v) {
                    if (v!.trim().isEmpty) return 'Name is required';
                    if (v.length < 2) return 'Name is too short';
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Phone Number
                _buildLabel('Phone Number'),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _phoneController,
                  hint: '+91 9876543210',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (v) {
                    if (v!.trim().isEmpty) return 'Phone is required';
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Email
                _buildLabel('Email Address'),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _emailController,
                  hint: 'your@email.com',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v!.trim().isEmpty) return 'Email is required';
                    if (!RegExp(
                      r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$',
                    ).hasMatch(v)) {
                      return 'Invalid email';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Password
                _buildLabel('Password'),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _passwordController,
                  hint: 'Minimum 8 characters',
                  icon: Icons.lock_outline,
                  obscure: _obscurePassword,
                  suffix: _passwordToggle(isDark, isConfirm: false),
                  validator: (v) {
                    if (v!.isEmpty) return 'Password is required';
                    if (v.length < 8) return 'Password too short';
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Confirm Password
                _buildLabel('Confirm Password'),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _confirmPasswordController,
                  hint: 'Re-enter your password',
                  icon: Icons.lock_outline,
                  obscure: _obscureConfirm,
                  suffix: _passwordToggle(isDark, isConfirm: true),
                  validator: (v) {
                    if (v != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 32),

                // Register button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: auth.loading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: WingBaseColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: WingBaseColors.primary
                          .withOpacity(0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
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
                            'Create Account',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 24),

                // Login link
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: TextStyle(
                          color: isDark
                              ? WingBaseColors.darkTextSecondary
                              : WingBaseColors.lightTextSecondary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _navigateBack(context),
                        child: Text(
                          'Sign In',
                          style: TextStyle(
                            color: WingBaseColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // NAVIGATION (SMOOTH FADE)
  // ---------------------------------------------------------------
  void _navigateBack(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const LoginScreen(),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  // ---------------------------------------------------------------
  // REUSABLE WIDGETS
  // ---------------------------------------------------------------

  Widget _buildAvatarPicker(bool isDark) {
    return GestureDetector(
      onTap: _pickAvatar,
      child: Stack(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? WingBaseColors.darkCardBg
                  : WingBaseColors.lightCardBg,
              border: Border.all(
                color: WingBaseColors.primary.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: _avatarFile != null
                ? ClipOval(
                    child: Image.file(
                      _avatarFile!,
                      fit: BoxFit.cover,
                      width: 96,
                      height: 96,
                    ),
                  )
                : Icon(
                    Icons.person_outline,
                    size: 40,
                    color: isDark
                        ? WingBaseColors.darkTextSecondary
                        : WingBaseColors.lightTextSecondary,
                  ),
          ),
          // Camera badge
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: WingBaseColors.primary,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark
                      ? WingBaseColors.darkScaffoldBg
                      : WingBaseColors.lightScaffoldBg,
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.camera_alt,
                size: 15,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: (_) => context.read<AuthProvider>().clearError(),
      decoration: InputDecoration(
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _passwordToggle(bool isDark, {required bool isConfirm}) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      icon: Icon(
        isConfirm
            ? (_obscureConfirm
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined)
            : (_obscurePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined),
        size: 20,
        color: isDark
            ? WingBaseColors.darkTextSecondary
            : WingBaseColors.lightTextSecondary,
      ),
      onPressed: () {
        setState(() {
          if (isConfirm) {
            _obscureConfirm = !_obscureConfirm;
          } else {
            _obscurePassword = !_obscurePassword;
          }
        });
      },
    );
  }
}
