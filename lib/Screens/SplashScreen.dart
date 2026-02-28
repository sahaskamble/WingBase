import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wingbase/Screens/HomeScreen.dart';
import 'package:wingbase/Screens/LoginScreen.dart';
import 'package:wingbase/providers/auth_provider.dart';
import 'package:wingbase/utils/colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  // to prevent double navigation
  bool _navigated = false;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeIn));

    _scaleAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );

    _animController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuth();
    });
  }

  Future<void> _checkAuth() async {
    final authProvider = context.read<AuthProvider>();

    await authProvider.tryAutoLogin();

    if (!mounted || _navigated) return;

    _navigated = true;

    final next = authProvider.isAuthenticated
        ? const HomeScreen()
        : const LoginScreen();

    _navigateTo(next);
  }

  void _navigateTo(Widget screen) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => screen,
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    // TODO: implement dispose
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark
          ? WingBaseColors.darkScaffoldBg
          : WingBaseColors.lightScaffoldBg,
      body: Center(
        child: AnimatedBuilder(
          animation: _animController,
          builder: (context, child) => Opacity(
            opacity: _fadeAnim.value,
            child: Transform.scale(scale: _scaleAnim.value, child: child),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: WingBaseColors.primary,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: WingBaseColors.primary.withOpacity(0.4),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(Icons.bolt, color: Colors.white, size: 52),
              ),
              const SizedBox(height: 20),
              Text(
                "WingBase",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? WingBaseColors.darkTextPrimary
                      : WingBaseColors.lightTextPrimary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: WingBaseColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
