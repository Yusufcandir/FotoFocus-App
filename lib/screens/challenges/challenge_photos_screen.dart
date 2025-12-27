import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../data/models/photo.dart';
import '../../providers/auth_provider.dart';
import '../../providers/photo_provider.dart';
import '../photos/photo_detail_screen.dart';

String resolveImageUrl(String url) {
  if (url.isEmpty) return url;
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  final base = AppConstants.baseUrl;
  if (url.startsWith('/')) return '$base$url';
  return '$base/$url';
}

int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

class ChallengePhotosScreen extends StatefulWidget {
  final int challengeId;
  final String challengeTitle;

  const ChallengePhotosScreen({
    super.key,
    required this.challengeId,
    required this.challengeTitle,
  });

  @override
  State<ChallengePhotosScreen> createState() => _ChallengePhotosScreenState();
}

class _ChallengePhotosScreenState extends State<ChallengePhotosScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<PhotoProvider>().loadChallengePhotos(widget.challengeId);
    });
  }

  Future<void> _pickAndUpload() async {
    await context.read<PhotoProvider>().pickAndUploadPhoto(widget.challengeId);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final photosProvider = context.watch<PhotoProvider>();

    final int? myUserId = _asInt(auth.user?.id);
    final List<Photo> photos = photosProvider.photos;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          widget.challengeTitle,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.purple1,
        onPressed: photosProvider.uploading ? null : _pickAndUpload,
        child: photosProvider.uploading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.camera_alt),
      ),
      body: photosProvider.loading
          ? const Center(child: CircularProgressIndicator())
          : photosProvider.error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      photosProvider.error!,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : photos.isEmpty
                  ? const Center(
                      child: Text("No submissions yet. Be the first!"))
                  : Padding(
                      padding: const EdgeInsets.all(14),
                      child: GridView.builder(
                        itemCount: photos.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 0.95,
                        ),
                        itemBuilder: (context, index) {
                          final photo = photos[index];
                          final bool isOwner =
                              myUserId != null && myUserId == photo.userId;

                          return _PhotoCard(
                            photo: photo,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      PhotoDetailScreen(photo: photo),
                                ),
                              );
                            },
                            onDelete: isOwner
                                ? () async {
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: const Text("Delete photo?"),
                                        content: const Text(
                                            "This will remove the photo permanently."),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text("Cancel"),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text("Delete"),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (ok == true) {
                                      await context
                                          .read<PhotoProvider>()
                                          .deletePhoto(photo.id);
                                    }
                                  }
                                : null,
                          );
                        },
                      ),
                    ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  final Photo photo;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _PhotoCard({
    required this.photo,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 22,
              offset: const Offset(0, 12),
            )
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.network(
                resolveImageUrl(photo.imageUrl),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.white,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image, color: Colors.black26),
                ),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Row(
                children: [
                  const Icon(Icons.star_rounded, size: 18, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    "${photo.avgRating.toStringAsFixed(1)} (${photo.ratingCount})",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),

            /// delete button (owner only)
            if (onDelete != null)
              Positioned(
                top: 6,
                right: 6,
                child: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.white),
                  onPressed: onDelete,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
