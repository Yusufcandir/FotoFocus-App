import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ChallengeScreen extends StatefulWidget {
  const ChallengeScreen({super.key});

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen> {
  // --- The Upload Function ---
  Future<void> _uploadPhoto() async {
    final picker = ImagePicker();
    // 1. Let the user pick an image from their gallery
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) {
      // User canceled the picker
      return;
    }

    // Show a loading dialog while uploading
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 2. Create a unique file path for the image
      final String fileName =
          '${FirebaseAuth.instance.currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final File imageFile = File(image.path);

      // 3. Upload the file to Firebase Storage
      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('submissions')
          .child(fileName);
      await storageRef.putFile(imageFile);

      // 4. Get the public Download URL for the image
      final String downloadURL = await storageRef.getDownloadURL();

      // 5. Save the image information to Firestore
      await FirebaseFirestore.instance.collection('submissions').add({
        'imageURL': downloadURL,
        'userID': FirebaseAuth.instance.currentUser!.uid,
        'timestamp': FieldValue.serverTimestamp(), // For ordering
      });

      // 6. Dismiss the loading dialog
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      // 6. Dismiss the loading dialog and show an error message
      if (mounted) Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to upload photo: $e')));
    }
  }

  // --- The UI ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Challenges'),
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Listen to the new 'submissions' collection
        stream: FirebaseFirestore.instance
            .collection('submissions')
            .orderBy('timestamp', descending: true) // Show newest photos first
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No submissions yet. Be the first!'),
            );
          }

          final documents = snapshot.data!.docs;

          // Use a GridView to show photos in a grid
          return GridView.builder(
            padding: const EdgeInsets.all(4),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, // 2 photos per row
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: documents.length,
            itemBuilder: (context, index) {
              final data = documents[index].data() as Map<String, dynamic>;
              final imageURL = data['imageURL'];

              return Image.network(
                imageURL,
                fit: BoxFit.cover, // Make the image fill the grid square
                // Show a loading spinner while each image downloads
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                // Show an error icon if an image fails to load
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.error);
                },
              );
            },
          );
        },
      ),
      // Add a Floating Action Button to let users upload photos
      floatingActionButton: FloatingActionButton(
        onPressed: _uploadPhoto,
        tooltip: 'Add Photo',
        child: const Icon(Icons.add_a_photo),
      ),
    );
  }
}
