import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fotofocus/screens/learn_screen.dart';

// We need a placeholder for our "Challenges" tab
class ChallengeScreen extends StatelessWidget {
  const ChallengeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Challenge Gallery will be here!'));
  }
}

// ---

// Convert HomeScreen to a StatefulWidget to manage the tabs
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0; // Tracks which tab is currently selected

  // The list of screens to show
  static const List<Widget> _widgetOptions = <Widget>[
    ChallengeScreen(), // Tab 0
    LearnScreen(), // Tab 1
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FotoFocus'),
        actions: [
          // Logout Button
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      // Show the currently selected screen
      body: _widgetOptions.elementAt(_selectedIndex),

      // --- Add the Bottom Navigation Bar ---
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.camera),
            label: 'Challenges',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Learn'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
