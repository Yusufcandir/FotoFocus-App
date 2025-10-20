import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fotofocus/screens/home_screen.dart';
import 'package:fotofocus/screens/login_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // StreamBuilder listens for auth changes
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. If the connection is loading, show a progress circle
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 2. If the user IS logged in, show the HomeScreen
        if (snapshot.hasData) {
          // We'll build this screen next
          return HomeScreen();
        }

        // 3. If the user IS NOT logged in, show the LoginScreen
        // We'll build this screen next
        return LoginScreen();
      },
    );
  }
}
