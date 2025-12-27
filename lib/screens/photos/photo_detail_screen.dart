import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../data/models/photo.dart';
import '../../providers/auth_provider.dart';
import '../../providers/photo_provider.dart';
import 'photo_comments_screen.dart';
import 'package:photo_view/photo_view.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:saver_gallery/saver_gallery.dart';

String resolveImageUrl(String url) {
  final u = url.trim();
  if (u.isEmpty) return "";

  if (u.startsWith("http://") || u.startsWith("https://")) return u;

  final path = u.startsWith("/") ? u : "/$u";
  return "${AppConstants.baseUrl}$path";
}

class PhotoDetailScreen extends StatefulWidget {
  const PhotoDetailScreen({
    super.key,
    required this.photo,
  });

  final Photo photo;

  @override
  State<PhotoDetailScreen> createState() => _PhotoDetailScreenState();
}

Future<void> downloadToGallery(BuildContext context, String url) async {
  try {
    // iOS permission
    if (Platform.isIOS) {
      final p = await Permission.photosAddOnly.request();
      if (!p.isGranted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photos permission denied')),
          );
        }
        return;
      }
    }

    // download bytes
    final resp = await Dio().get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = Uint8List.fromList(resp.data!);

    // try save
    Future<bool> _saveOnce() async {
      final result = await SaverGallery.saveImage(
        bytes,
        name: 'fotofocus_${DateTime.now().millisecondsSinceEpoch}',
        androidRelativePath: "Pictures/FotoFocus",
        androidExistNotSave: false,
      );
      return result.isSuccess;
    }

    bool ok = await _saveOnce();

    // If it failed on Android request legacy storage permission and retry
    if (!ok && Platform.isAndroid) {
      final storage = await Permission.storage.request();
      if (!storage.isGranted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permission denied')),
          );
        }
        return;
      }
      ok = await _saveOnce();
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Saved to gallery' : 'Save failed')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }
}

class _PhotoDetailScreenState extends State<PhotoDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final p = context.read<PhotoProvider>();
      await p.fetchPhotoDetail(widget.photo.id);
      await p.refreshMyRating(widget.photo.id);
    });
  }

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  Future<void> _handleMenu(String value) async {
    final p = context.read<PhotoProvider>();

    if (value == "delete") {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Delete photo?"),
          content: const Text("This action cannot be undone."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Delete"),
            ),
          ],
        ),
      );

      if (ok != true) return;

      await p.deletePhoto(widget.photo.id);
      if (!mounted) return;

      Navigator.pop(context, true);
      return;
    }

    if (value == "report") {
      final ctrl = TextEditingController();

      final reason = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Report photo"),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(hintText: "Reason."),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text("Send"),
            ),
          ],
        ),
      );

      if (reason == null || reason.isEmpty) return;

      await p.reportPhoto(widget.photo.id, reason);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Reported.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PhotoProvider>();
    final auth = context.watch<AuthProvider>();

    final photo = p.photo ?? widget.photo;

    final myUserId = _asInt(auth.user?.id);
    final bool isOwner = myUserId != null && myUserId == photo.userId;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Photo"),
        actions: [
          PopupMenuButton<String>(
            onSelected: _handleMenu,
            itemBuilder: (_) => [
              if (isOwner)
                const PopupMenuItem(
                  value: "delete",
                  child: Text("Delete"),
                ),
              const PopupMenuItem(
                value: "report",
                child: Text("Report"),
              ),
            ],
          ),
        ],
      ),
      body: p.loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: GestureDetector(
                    onTap: () {
                      final url = resolveImageUrl(photo.imageUrl);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          fullscreenDialog: true,
                          builder: (_) => FullScreenPhotoViewer(
                            imageUrl: url,
                            heroTag: 'photo-${photo.id}',
                          ),
                        ),
                      );
                    },
                    child: Hero(
                      tag: 'photo-${photo.id}',
                      child: Image.network(
                        resolveImageUrl(photo.imageUrl),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.white,
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image,
                              color: Colors.black26),
                        ),
                      ),
                    ),
                  ),
                ),

// uploader row (clickable)
                InkWell(
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/profile',
                      arguments: photo.userId,
                    );
                  },
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        const CircleAvatar(child: Icon(Icons.person)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            photo.userEmail,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // rating + comment button row
                Container(
                  color: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.amber),
                      const SizedBox(width: 6),
                      Text(
                        "${photo.avgRating.toStringAsFixed(1)} (${photo.ratingCount})",
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const Spacer(),

                      //  rating
                      _StarBar(
                        value: p.myRating,
                        onRate: (v) => context
                            .read<PhotoProvider>()
                            .ratePhoto(photo.id, v),
                      ),

                      const SizedBox(width: 8),

                      //  comments button
                      IconButton(
                        icon: const Icon(Icons.comment_outlined),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  PhotoCommentsScreen(photoId: photo.id),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _StarBar extends StatelessWidget {
  const _StarBar({
    required this.value,
    required this.onRate,
  });

  final int? value;
  final ValueChanged<int> onRate;

  @override
  Widget build(BuildContext context) {
    final current = value ?? 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final starValue = i + 1;
        final filled = starValue <= current;

        return IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Icon(
            filled ? Icons.star_rounded : Icons.star_border_rounded,
            color: filled ? Colors.amber : Colors.black26,
          ),
          onPressed: () => onRate(starValue),
        );
      }),
    );
  }
}

class FullScreenPhotoViewer extends StatelessWidget {
  const FullScreenPhotoViewer({
    super.key,
    required this.imageUrl,
    required this.heroTag,
  });

  final String imageUrl;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded, color: Colors.white),
            tooltip: 'Save',
            onPressed: () => downloadToGallery(context, imageUrl),
          ),
        ],
      ),
      body: Hero(
        tag: heroTag,
        child: PhotoView(
          imageProvider: NetworkImage(imageUrl),
          backgroundDecoration: const BoxDecoration(color: Colors.black),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 3.0,
        ),
      ),
    );
  }
}
