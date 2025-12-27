import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/challenge_provider.dart';
import 'providers/lesson_provider.dart';
import 'providers/photo_detail_provider.dart';
import 'providers/photo_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/feed_provider.dart';

import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/reset_password_screen.dart';

import 'screens/home/home_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/settings/settings_screen.dart';

import 'data/models/challenge.dart';
import 'data/models/photo.dart';
import 'data/models/post.dart';
import 'screens/challenges/challenges_detail_screen.dart';
import 'screens/photos/photo_detail_screen.dart';
import 'screens/feed/post_detail_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/verify_email_screen.dart';
import 'screens/challenges/create_challenge_screen.dart';

void main() {
  runApp(const FotoFocusApp());
}

class FotoFocusApp extends StatelessWidget {
  const FotoFocusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LessonProvider()),
        ChangeNotifierProvider(create: (_) => ChallengeProvider()),
        ChangeNotifierProvider(create: (_) => PhotoProvider()),
        ChangeNotifierProvider(create: (_) => PhotoDetailProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => FeedProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: "FotoFocus",
        theme: AppTheme.light,
        initialRoute: "/",
        routes: {
          "/": (_) => const SplashScreen(),
          "/login": (_) => const LoginScreen(),
          "/register": (_) => const RegisterScreen(),
          "/forgot-password": (_) => const ForgotPasswordScreen(),
          "/reset-password": (_) => const ResetPasswordScreen(),
          "/challenge-create": (_) => const CreateChallengeScreen(),
          "/home": (_) => const HomeScreen(),
          "/profile": (_) => const ProfileScreen(),
          "/settings": (_) => const SettingsScreen(),
          "/post_detail": (context) {
            final post = ModalRoute.of(context)!.settings.arguments;
            return PostDetailScreen(post: post as FeedPost);
          },
          "/photo_detail": (context) {
            final photo = ModalRoute.of(context)!.settings.arguments as Photo;
            return PhotoDetailScreen(photo: photo);
          },
          "/challenge-detail": (context) {
            final args = ModalRoute.of(context)!.settings.arguments;

            if (args is Challenge) {
              return ChallengeDetailScreen(challengeId: args.id);
            }
            if (args is int) {
              return ChallengeDetailScreen(challengeId: args);
            }
            if (args is Map) {
              final rawId = args["id"];
              final id = rawId is int ? rawId : int.tryParse("$rawId");
              if (id != null) return ChallengeDetailScreen(challengeId: id);
            }

            return const Scaffold(
              body: Center(child: Text("Invalid challenge argument")),
            );
          },
          "/verify-email": (context) {
            final email = ModalRoute.of(context)!.settings.arguments as String;
            return VerifyEmailScreen(email: email);
          },
        },
      ),
    );
  }
}
