import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../providers/auth_provider.dart';
import 'auth/login_screen.dart';
import 'home/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final auth = context.read<AuthProvider>();

    // ✅ validate token properly by calling /me inside init()
    await auth.init();

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            auth.user != null ? const HomeScreen() : const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF7F5FF), Color(0xFFFFFFFF)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Container(
              width: 340,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              decoration: AppTheme.cardDecoration(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: Colors.white,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.radio_button_checked,
                        color: AppTheme.purple1,
                        size: 44,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  RichText(
                    text: const TextSpan(
                      style:
                          TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                      children: [
                        TextSpan(
                            text: "Foto",
                            style: TextStyle(color: AppTheme.purple1)),
                        TextSpan(
                            text: "Focus",
                            style: TextStyle(color: AppTheme.textDark)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Loading your session...",
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
