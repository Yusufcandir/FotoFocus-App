import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  // StatefulWidget can hold state (data that changes)
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Create "controllers" to read the text from the fields
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // A global key for our form
  final _formKey = GlobalKey<FormState>();

  // --- Our Login & Register Functions ---

  Future<void> _signIn() async {
    // first, validate the form
    if (!_formKey.currentState!.validate()) {
      return; // If form is not valid, stop.
    }

    try {
      // Show a loading circle
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Try to sign in with Firebase
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // If we get here, sign-in was successful.
      // The AuthWrapper will automatically see the change and show the HomeScreen.
      // We just need to pop the loading circle.
      if (mounted) Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      // Handle errors
      if (mounted) Navigator.of(context).pop(); // Pop loading circle
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to sign in: ${e.message}')),
      );
    }
  }

  Future<void> _register() async {
    // first, validate the form
    if (!_formKey.currentState!.validate()) {
      return; // If form is not valid, stop.
    }

    try {
      // Show a loading circle
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Try to create a new user with Firebase
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // If successful, pop the loading circle.
      // The AuthWrapper will automatically see the new user and log them in.
      if (mounted) Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      // Handle errors
      if (mounted) Navigator.of(context).pop(); // Pop loading circle
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to register: ${e.message}')),
      );
    }
  }

  // --- Build the UI ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login / Register')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey, // Attach our form key
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // --- Email Field ---
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty || !value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),

              // --- Password Field ---
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true, // Hides the password
                validator: (value) {
                  if (value == null || value.isEmpty || value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // --- Buttons ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // --- Login Button ---
                  ElevatedButton(
                    onPressed: _signIn,
                    child: const Text('Login'),
                  ),
                  // --- Register Button ---
                  ElevatedButton(
                    onPressed: _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Register'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
