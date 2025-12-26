import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../challenges/challenges_screen.dart';
import '../feed/feed_screen.dart';
import '../learn/learn_screen.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Load "me" once so we can show the real avatar in the AppBar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileProvider>().loadProfile(userId: null);
    });
  }

  String _resolveImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    return '${AppConstants.baseUrl}$url';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text("FotoFocus"),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ProfileScreen(userId: null),
                  ),
                );
              },
              child: Consumer2<AuthProvider, ProfileProvider>(
                builder: (_, auth, profile, __) {
                  // Prefer ProfileProvider (fresh avatar), fallback to AuthProvider
                  final avatarUrl = _resolveImageUrl(
                    profile.user?.avatarUrl ?? auth.user?.avatarUrl,
                  );

                  final label = (profile.user?.name?.trim().isNotEmpty == true)
                      ? profile.user!.name!.trim()
                      : (auth.user?.name?.trim().isNotEmpty == true)
                          ? auth.user!.name!.trim()
                          : (auth.user?.email ?? "U");

                  return CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.black12,
                    backgroundImage:
                        avatarUrl.isEmpty ? null : NetworkImage(avatarUrl),
                    child: avatarUrl.isEmpty
                        ? Text(label.isEmpty ? "U" : label[0].toUpperCase())
                        : null,
                  );
                },
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: const [
          ChallengesScreen(),
          FeedScreen(),
          LearnScreen(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: BottomNavigationBar(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_rounded),
              label: "Challenges",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: "Home",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.school_rounded),
              label: "Learn",
            ),
          ],
        ),
      ),
    );
  }
}
