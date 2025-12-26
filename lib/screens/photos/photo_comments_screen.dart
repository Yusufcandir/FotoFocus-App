import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/comment.dart';
import '../../providers/photo_provider.dart';
import '../../providers/auth_provider.dart';
import '../photos/photo_detail_screen.dart';

class PhotoCommentsScreen extends StatefulWidget {
  final int photoId;
  const PhotoCommentsScreen({super.key, required this.photoId});

  @override
  State<PhotoCommentsScreen> createState() => _PhotoCommentsScreenState();
}

class _PhotoCommentsScreenState extends State<PhotoCommentsScreen> {
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PhotoProvider>().reloadComments(widget.photoId);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PhotoProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text("Comments")),
      backgroundColor: Colors.grey.shade100,

      // -----------------------------
      // INPUT BAR (reply aware)
      // -----------------------------
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (p.replyToCommentId != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Replying to ${p.replyToLabel}",
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: p.cancelReply,
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      decoration: const InputDecoration(
                        hintText: "Add a comment...",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      final text = _ctrl.text.trim();
                      if (text.isEmpty) return;

                      await p.postComment(widget.photoId, text);
                      _ctrl.clear();
                    },
                    child: const Text("Post"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),

      // -----------------------------
      // COMMENTS LIST (parents + children)
      // -----------------------------
      body: p.comments.isEmpty
          ? const Center(child: Text("No comments yet"))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
              itemCount: p.comments.length,
              itemBuilder: (_, i) {
                final parent = p.comments[i];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _commentTile(
                      comment: parent,
                      provider: p,
                      auth: auth,
                      isReply: false,
                    ),
                    for (final child in parent.replies)
                      Padding(
                        padding: const EdgeInsets.only(left: 40),
                        child: _commentTile(
                          comment: child,
                          provider: p,
                          auth: auth,
                          isReply: true,
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }

  // -----------------------------
  // SINGLE COMMENT TILE
  // -----------------------------
  Widget _commentTile({
    required CommentModel comment,
    required PhotoProvider provider,
    required AuthProvider auth,
    required bool isReply,
  }) {
    final label = comment.user.name ?? comment.user.email;
    final isOwner = auth.userId == comment.user.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isReply ? 0 : 1,
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: (comment.user.avatarUrl != null &&
                  comment.user.avatarUrl!.trim().isNotEmpty)
              ? NetworkImage(resolveImageUrl(comment.user.avatarUrl!))
              : null,
          child: (comment.user.avatarUrl == null ||
                  comment.user.avatarUrl!.trim().isEmpty)
              ? Text(label[0].toUpperCase())
              : null,
        ),
        title: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(comment.text),

        // -----------------------------
        // ACTIONS: Reply + Delete (owner only)
        // -----------------------------
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () {
                provider.startReply(
                  commentId: comment.id,
                  label: label,
                );
              },
              child: const Text("Reply"),
            ),
            if (isOwner)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text("Delete comment?"),
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

                  if (ok == true) {
                    await provider.deleteComment(
                      photoId: widget.photoId,
                      commentId: comment.id,
                    );
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}
