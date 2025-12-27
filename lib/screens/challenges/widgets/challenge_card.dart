import 'package:flutter/material.dart';

import '../../../data/models/challenge.dart';
import 'package:provider/provider.dart';
import '../../../providers/photo_detail_provider.dart';

class ChallengeCard extends StatelessWidget {
  final Challenge challenge;

  const ChallengeCard({
    super.key,
    required this.challenge,
  });

  String _fullImageUrl(String path) {
    if (path.isEmpty) return "";
    if (path.startsWith("http")) return path;
    return "http://10.0.2.2:8080$path"; // emulator base
  }

  @override
  Widget build(BuildContext context) {
    final imagePath = (challenge.coverUrl?.isNotEmpty ?? false)
        ? _fullImageUrl(challenge.coverUrl!)
        : null;
    final desc = (challenge.description ?? "").trim();

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          "/challenge-detail",
          arguments: challenge,
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned.fill(
              child: imagePath != null
                  ? Image.network(
                      imagePath,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image),
                    )
                  : _placeholder(),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.center,
                    colors: [
                      Colors.black.withOpacity(0.55),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    challenge.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  if (desc.isNotEmpty) const SizedBox(height: 4),
                  if (desc.isNotEmpty)
                    Text(
                      desc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 12,
                        height: 1.2,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFFE9E9EF),
      child: const Center(
        child: Icon(Icons.photo, size: 28, color: Color(0xFF9A9AA6)),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete photo"),
        content: const Text("Are you sure you want to delete this photo?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "Delete",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await context.read<PhotoDetailProvider>().deletePhoto(challenge.id);

      if (!context.mounted) return;
      Navigator.pop(context); // go back after delete
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to delete photo")),
      );
    }
  }
}
