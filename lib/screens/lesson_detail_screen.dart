import 'package:flutter/material.dart';

class LessonDetailScreen extends StatelessWidget {
  final String title;
  final String body;

  // The constructor requires a title and body
  const LessonDetailScreen({
    super.key,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title), // Show the lesson title in the app bar
      ),
      body: SingleChildScrollView(
        // Makes the content scrollable
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            body,
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
            ), // Make it readable
          ),
        ),
      ),
    );
  }
}
