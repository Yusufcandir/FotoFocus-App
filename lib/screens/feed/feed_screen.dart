import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/feed_provider.dart';
import '../../data/models/post.dart';
import '../../data/services/feed_service.dart';
import 'post_detail_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _scroll = ScrollController();
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FeedProvider>().refresh();
    });

    _scroll.addListener(() {
      final p = context.read<FeedProvider>();
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
        p.loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _openComposer() async {
    final contentCtrl = TextEditingController();
    File? picked;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 14,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (ctx, setModal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  Row(
                    children: [
                      const Text(
                        "New Post",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          final text = contentCtrl.text.trim();
                          if (text.isEmpty && picked == null) return;

                          Navigator.pop(ctx);
                          await context
                              .read<FeedProvider>()
                              .createPost(content: text, image: picked);
                        },
                        child: const Text("Post"),
                      ),
                    ],
                  ),
                  TextField(
                    controller: contentCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: "Share something…",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.image_outlined),
                        label: Text(picked == null ? "Add image" : "Change"),
                        onPressed: () async {
                          final x = await _picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 90,
                          );
                          if (x == null) return;
                          setModal(() => picked = File(x.path));
                        },
                      ),
                      const SizedBox(width: 10),
                      if (picked != null)
                        Expanded(
                          child: Text(
                            picked!.path.split(Platform.pathSeparator).last,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<FeedProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _openComposer,
            tooltip: "New post",
          ),
        ],
      ),
      body: feed.error != null
          ? Center(child: Text(feed.error!))
          : RefreshIndicator(
              onRefresh: feed.refresh,
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(12),
                itemCount: feed.posts.length + 1,
                itemBuilder: (_, i) {
                  if (i == feed.posts.length) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Center(
                        child: feed.loading
                            ? const CircularProgressIndicator()
                            : (!feed.hasMore
                                ? const Text("No more posts")
                                : const SizedBox.shrink()),
                      ),
                    );
                  }

                  final p = feed.posts[i];
                  final isOwner =
                      auth.userId != null && auth.userId == p.user.id;

                  final avatarUrl =
                      AppConstants.resolveImageUrl(p.user.avatarUrl);
                  final imgUrl = AppConstants.resolveImageUrl(p.imageUrl);

                  return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => PostDetailScreen(post: p)),
                        );
                      },
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side:
                              BorderSide(color: Colors.black.withOpacity(0.06)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: GestureDetector(
                                  onTap: () => Navigator.pushNamed(
                                    context,
                                    '/profile',
                                    arguments: p.user.id,
                                  ),
                                  child: CircleAvatar(
                                    backgroundImage: avatarUrl == null
                                        ? null
                                        : NetworkImage(avatarUrl),
                                    child: avatarUrl == null
                                        ? const Icon(Icons.person)
                                        : null,
                                  ),
                                ),
                                title: Text(
                                  p.user.displayName,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800),
                                ),
                                subtitle: Text(p.user.email,
                                    overflow: TextOverflow.ellipsis),
                                trailing: isOwner
                                    ? PopupMenuButton<String>(
                                        onSelected: (v) async {
                                          if (v == 'delete') {
                                            await context
                                                .read<FeedProvider>()
                                                .deletePost(p.id);
                                          }
                                        },
                                        itemBuilder: (_) => const [
                                          PopupMenuItem(
                                            value: 'delete',
                                            child: Text('Delete'),
                                          ),
                                        ],
                                      )
                                    : null,
                              ),
                              if (p.content.trim().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Text(p.content),
                                ),
                              if (imgUrl != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: GestureDetector(
                                    onTap: () {
                                      // You can reuse your FullScreenPhotoViewer here if you want
                                      showDialog(
                                        context: context,
                                        builder: (_) => Dialog(
                                          insetPadding:
                                              const EdgeInsets.all(12),
                                          child: InteractiveViewer(
                                            child: Image.network(imgUrl,
                                                fit: BoxFit.contain),
                                          ),
                                        ),
                                      );
                                    },
                                    child: Image.network(
                                      imgUrl,
                                      fit: BoxFit.cover,
                                      height: 220,
                                      width: double.infinity,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: () => context
                                        .read<FeedProvider>()
                                        .toggleLike(p),
                                    icon: Icon(
                                      p.isLiked
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                    ),
                                  ),
                                  Text("${p.likeCount}"),
                                  const SizedBox(width: 12),
                                  IconButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                PostDetailScreen(post: p)),
                                      );
                                    },
                                    icon: const Icon(Icons.chat_bubble_outline),
                                  ),
                                  Text("${p.commentCount}"),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ));
                },
              ),
            ),
    );
  }
}
