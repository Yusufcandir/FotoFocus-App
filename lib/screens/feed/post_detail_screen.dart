import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../data/models/post.dart';
import '../../providers/auth_provider.dart';
import '../../providers/feed_provider.dart';

class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({super.key, required this.post});
  final FeedPost post;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FeedProvider>().loadComments(widget.post.id);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    FocusScope.of(context).unfocus();
    _ctrl.clear();

    try {
      await context.read<FeedProvider>().addCommentToPost(widget.post.id, text);

      widget.post.commentCount += 1;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Comment failed: $e")),
      );
    }
  }

  Future<void> _delete(int commentId) async {
    try {
      await context
          .read<FeedProvider>()
          .deleteCommentFromPost(widget.post.id, commentId);

      if (widget.post.commentCount > 0) widget.post.commentCount -= 1;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Delete failed: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<FeedProvider>();
    final auth = context.watch<AuthProvider>();

    final loading = feed.commentsLoading;
    final err = feed.commentsError;
    final comments = feed.comments;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Post"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<FeedProvider>().loadComments(
                  widget.post.id,
                ),
          ),
        ],
      ),
      body: Column(
        children: [
          //  POST HEADER (like in feed)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: _PostHeaderCard(post: widget.post),
          ),

          const Divider(height: 1),

          //  COMMENTS LIST
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : (err != null)
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            err,
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : (comments.isEmpty)
                        ? const Center(child: Text("No comments yet"))
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: comments.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final c = comments[i];
                              final viewerId = auth.userId;
                              final isOwner =
                                  viewerId != null && viewerId == c.user.id;
                              final isPostOwner = viewerId != null &&
                                  viewerId == widget.post.user.id;

                              final avatar = AppConstants.resolveImageUrl(
                                  c.user.avatarUrl);

                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 8,
                                      offset: Offset(0, 3),
                                    )
                                  ],
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      backgroundImage: (avatar.isNotEmpty &&
                                              avatar.startsWith('http'))
                                          ? NetworkImage(avatar)
                                          : null,
                                      child: (avatar.isNotEmpty &&
                                              avatar.startsWith('http'))
                                          ? null
                                          : const Icon(Icons.person, size: 18),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            c.user.displayName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w800),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(c.text),
                                        ],
                                      ),
                                    ),
                                    if (isOwner || isPostOwner)
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline),
                                        onPressed: () => _delete(c.id),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),

          // COMMENT INPUT
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: "Write a comment…",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PostHeaderCard extends StatelessWidget {
  const _PostHeaderCard({required this.post});

  final FeedPost post;

  @override
  Widget build(BuildContext context) {
    final u = post.user;
    final avatar = AppConstants.resolveImageUrl(u.avatarUrl);
    final imageUrl = AppConstants.resolveImageUrl(post.imageUrl);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundImage:
                    (avatar.isNotEmpty && avatar.startsWith('http'))
                        ? NetworkImage(avatar)
                        : null,
                child: (avatar.isNotEmpty && avatar.startsWith('http'))
                    ? null
                    : const Icon(Icons.person, size: 18),
              ),
              title: Text(u.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle:
                  Text(u.email, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            if (imageUrl.isNotEmpty && imageUrl.startsWith('http')) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 220,
                ),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Icon(post.isLiked ? Icons.favorite : Icons.favorite_border),
                const SizedBox(width: 6),
                Text('${post.likeCount}'),
                const SizedBox(width: 18),
                const Icon(Icons.chat_bubble_outline),
                const SizedBox(width: 6),
                Text('${post.commentCount}'),
              ],
            ),
            if (post.text.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(post.text.trim()),
            ],
          ],
        ),
      ),
    );
  }
}
