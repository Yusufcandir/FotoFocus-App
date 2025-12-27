import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fotofocus/data/models/challenge.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../data/models/users.dart';
import '../../core/theme.dart';
import '../../data/models/post.dart';
import '../feed/post_detail_screen.dart';
import '../../providers/feed_provider.dart';

class ProfileScreen extends StatefulWidget {
  final int? userId; // null => me
  final Challenge? challenge;

  const ProfileScreen({super.key, this.userId, this.challenge});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileProvider provider;

  @override
  void initState() {
    super.initState();
    provider = context.read<ProfileProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final meId = auth.user?.id;

      final int? resolvedUserId =
          (widget.userId == null || widget.userId == meId)
              ? null
              : widget.userId;

      provider.loadProfile(userId: resolvedUserId);
    });
  }

  String resolveImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    return '${AppConstants.baseUrl}$url';
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    try {
      await provider.uploadAvatar(File(picked.path));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Avatar updated")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload failed: $e")),
      );
    }
  }

  Future<void> _editNameDialog() async {
    final current = provider.user?.name ?? '';
    final ctrl = TextEditingController(text: current);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit name"),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: "Your name",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel")),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Save")),
        ],
      ),
    );

    if (saved != true) return;

    try {
      await provider.updateName(ctrl.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile updated")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Update failed: $e")),
      );
    }
  }

  Future<void> _showUsersSheet({
    required String title,
    required Future<void> Function() load,
    required bool loading,
    required List<User> users,
  }) async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.75,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(title,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w800)),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: FutureBuilder(
                      future: load(),
                      builder: (_, __) {
                        final p = context.watch<ProfileProvider>();
                        final isLoadingNow = title == "Followers"
                            ? p.followersLoading
                            : p.followingLoading;
                        final list =
                            title == "Followers" ? p.followers : p.following;

                        if (isLoadingNow && list.isEmpty) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (list.isEmpty) {
                          return const Center(child: Text("No users"));
                        }

                        return ListView.separated(
                          itemCount: list.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final u = list[i];
                            final avatarUrl = resolveImageUrl(u.avatarUrl);
                            final label = (u.name?.trim().isNotEmpty == true)
                                ? u.name!.trim()
                                : u.email;

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.black12,
                                backgroundImage: avatarUrl.isEmpty
                                    ? null
                                    : NetworkImage(avatarUrl),
                                child: avatarUrl.isEmpty
                                    ? Text(label.isEmpty
                                        ? "U"
                                        : label[0].toUpperCase())
                                    : null,
                              ),
                              title: Text(label,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(u.email,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.pop(ctx);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          ProfileScreen(userId: u.id)),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final meId = auth.user?.id;

    final p = context.watch<ProfileProvider>();
    final u = p.user;

    final bool isMe =
        widget.userId == null || (meId != null && widget.userId == meId);

    // If provider finished loading but we still don't have a user object,
    // avoid crashing with null-asserts and show a safe fallback.
    if (!p.loading && p.error == null && u == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text("Profile"),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(child: Text("Profile not available")),
      );
    }

    final avatarUrl = resolveImageUrl(u?.avatarUrl);
    final displayName = (u?.name?.trim().isNotEmpty == true)
        ? u!.name!.trim()
        : (u?.email ?? "User");

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text("Profile"),
          backgroundColor: Colors.white,
          elevation: 0,
          actions: [
            if (isMe)
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'settings') {
                    Navigator.pushNamed(context, '/settings');
                  }
                  if (v == "name") await _editNameDialog();
                  if (v == "avatar") await _pickAvatar();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: "name", child: Text("Edit name")),
                  PopupMenuItem(value: "avatar", child: Text("Change avatar")),
                  PopupMenuItem(value: "settings", child: Text("Settings")),
                ],
              ),
          ],
        ),
        body: p.loading
            ? const Center(child: CircularProgressIndicator())
            : p.error != null
                ? Center(
                    child: Text(
                      p.error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  )
                : NestedScrollView(
                    headerSliverBuilder: (_, __) => [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                          child: Column(
                            children: [
                              // Header card
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 10,
                                      offset: Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    InkWell(
                                      borderRadius: BorderRadius.circular(999),
                                      onTap: isMe ? _pickAvatar : null,
                                      child: CircleAvatar(
                                        radius: 26,
                                        backgroundColor: Colors.black12,
                                        backgroundImage: avatarUrl.isEmpty
                                            ? null
                                            : NetworkImage(avatarUrl),
                                        child: avatarUrl.isEmpty
                                            ? Text(displayName.isEmpty
                                                ? "U"
                                                : displayName[0].toUpperCase())
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            displayName,
                                            style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w900),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            u?.email ?? "",
                                            style: const TextStyle(
                                                color: Colors.black54),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!isMe && widget.userId != null)
                                      SizedBox(
                                        height: 38,
                                        child: FilledButton.tonal(
                                          onPressed: p.followBusy
                                              ? null
                                              : () => p
                                                  .toggleFollow(widget.userId!),
                                          child: Text(
                                            (p.isFollowing == true)
                                                ? "Following"
                                                : "Follow",
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 12),

                              // Stats row
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _StatCard(
                                      label: "Followers",
                                      value: "${p.followersCount}",
                                      onTap: () async {
                                        final uid = u?.id;
                                        if (uid == null) return;
                                        await p.loadFollowers(uid);
                                        await _showUsersSheet(
                                          title: "Followers",
                                          load: () => p.loadFollowers(uid),
                                          loading: p.followersLoading,
                                          users: p.followers,
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _StatCard(
                                      label: "Following",
                                      value: "${p.followingCount}",
                                      onTap: () async {
                                        final uid = u?.id;
                                        if (uid == null) return;
                                        await p.loadFollowing(uid);
                                        await _showUsersSheet(
                                          title: "Following",
                                          load: () => p.loadFollowing(uid),
                                          loading: p.followingLoading,
                                          users: p.following,
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _TabHeader(
                          child: Container(
                            color: AppTheme.background,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: const TabBar(
                              labelColor: Colors.black,
                              unselectedLabelColor: Colors.black54,
                              indicatorColor: Colors.black,
                              isScrollable: true,
                              tabs: [
                                Tab(text: "Posts"),
                                Tab(text: "Media"),
                                Tab(text: "Challenges"),
                                Tab(text: "Liked"),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                    body: TabBarView(
                      children: [
                        // Posts TAB
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                          child: p.postsLoading
                              ? const Center(child: CircularProgressIndicator())
                              : Builder(builder: (context) {
                                  bool hasImage(FeedPost post) {
                                    final s = (post.imageUrl ?? '').trim();
                                    return s.isNotEmpty &&
                                        s.toLowerCase() != 'null';
                                  }

                                  final imagePosts =
                                      p.posts.where(hasImage).toList();

                                  if (imagePosts.isEmpty) {
                                    return const Center(
                                        child: Text("No photo posts yet"));
                                  }

                                  return GridView.builder(
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3,
                                      crossAxisSpacing: 8,
                                      mainAxisSpacing: 8,
                                      childAspectRatio: 1,
                                    ),
                                    itemCount: imagePosts.length,
                                    itemBuilder: (context, index) {
                                      final post = imagePosts[index];
                                      final img =
                                          resolveImageUrl(post.imageUrl!);

                                      return GestureDetector(
                                        onTap: () {
                                          Navigator.pushNamed(
                                            context,
                                            '/post_detail',
                                            arguments: post,
                                          );
                                        },
                                        child: Stack(
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: Image.network(
                                                img,
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                                height: double.infinity,
                                                errorBuilder: (_, __, ___) =>
                                                    Container(
                                                  color: Colors.white,
                                                  alignment: Alignment.center,
                                                  child: const Icon(
                                                      Icons.broken_image,
                                                      color: Colors.black26),
                                                ),
                                              ),
                                            ),

                                            // Like/comment overlay
                                            Positioned(
                                              left: 8,
                                              bottom: 8,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: Colors.black
                                                      .withOpacity(0.45),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      post.isLiked
                                                          ? Icons.favorite
                                                          : Icons
                                                              .favorite_border,
                                                      size: 16,
                                                      color: Colors.white,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text('${post.likeCount}',
                                                        style: const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 12)),
                                                    const SizedBox(width: 10),
                                                    const Icon(
                                                        Icons
                                                            .chat_bubble_outline,
                                                        size: 16,
                                                        color: Colors.white),
                                                    const SizedBox(width: 4),
                                                    Text('${post.commentCount}',
                                                        style: const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 12)),
                                                  ],
                                                ),
                                              ),
                                            ),

                                            // Delete button (visible on any background)
                                            if (isMe)
                                              Positioned(
                                                top: 6,
                                                right: 6,
                                                child: InkWell(
                                                  onTap: () async {
                                                    try {
                                                      await p.deletePost(post
                                                          .id); // your method
                                                    } catch (e) {
                                                      if (!mounted) return;
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                        SnackBar(
                                                            content: Text(
                                                                "Delete failed: $e")),
                                                      );
                                                    }
                                                  },
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      color: Colors.black
                                                          .withOpacity(0.45),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    padding:
                                                        const EdgeInsets.all(6),
                                                    child: const Icon(
                                                        Icons.delete,
                                                        color: Colors.white,
                                                        size: 18),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                }),
                        ),

                        // Media TAB
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                          child: p.photos.isEmpty
                              ? const Center(child: Text("No photos yet"))
                              : GridView.builder(
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 8,
                                    childAspectRatio: 1,
                                  ),
                                  itemCount: p.photos.length,
                                  itemBuilder: (context, index) {
                                    final photo = p.photos[index];
                                    final img = resolveImageUrl(photo.imageUrl);

                                    return GestureDetector(
                                      onTap: () {
                                        Navigator.pushNamed(
                                            context, '/photo_detail',
                                            arguments: photo);
                                      },
                                      child: Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            child: Image.network(
                                              img,
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              height: double.infinity,
                                              errorBuilder: (_, __, ___) =>
                                                  Container(
                                                color: Colors.white,
                                                alignment: Alignment.center,
                                                child: const Icon(
                                                    Icons.broken_image,
                                                    color: Colors.black26),
                                              ),
                                            ),
                                          ),
                                          if (isMe)
                                            Positioned(
                                              top: 6,
                                              right: 6,
                                              child: IconButton(
                                                icon: const Icon(Icons.delete,
                                                    color: Colors.white),
                                                onPressed: () async {
                                                  try {
                                                    await p
                                                        .deletePhoto(photo.id);
                                                  } catch (e) {
                                                    if (!mounted) return;
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                          content: Text(
                                                              "Delete failed: $e")),
                                                    );
                                                  }
                                                },
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),

                        // CHALLENGES TAB
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                          child: p.challenges.isEmpty
                              ? const Center(child: Text("No challenges yet"))
                              : ListView.separated(
                                  itemCount: p.challenges.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (_, i) {
                                    final c = p.challenges[i];
                                    final cover = resolveImageUrl(c.coverUrl);

                                    return InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: () => Navigator.pushNamed(
                                        context,
                                        "/challenge-detail",
                                        arguments: c, // Challenge
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Colors.black12,
                                              blurRadius: 10,
                                              offset: Offset(0, 6),
                                            )
                                          ],
                                        ),
                                        child: Row(
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: Container(
                                                width: 64,
                                                height: 64,
                                                color: Colors.black12,
                                                child: cover.isEmpty
                                                    ? const Icon(Icons.image,
                                                        color: Colors.black26)
                                                    : Image.network(
                                                        cover,
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (_, __,
                                                                ___) =>
                                                            const Icon(Icons
                                                                .broken_image),
                                                      ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    c.title,
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w900),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    (c.description ?? "")
                                                            .isEmpty
                                                        ? "No description"
                                                        : c.description!,
                                                    style: const TextStyle(
                                                        color: Colors.black54),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Icon(Icons.chevron_right),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),

                        // LIKED TAB
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                          child: p.likedLoading
                              ? const Center(child: CircularProgressIndicator())
                              : p.likedPosts.isEmpty
                                  ? const Center(child: Text("No liked posts"))
                                  : ListView.separated(
                                      itemCount: p.likedPosts.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(height: 10),
                                      itemBuilder: (_, i) =>
                                          FeedPostCard(post: p.likedPosts[i]),
                                    ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12, blurRadius: 10, offset: Offset(0, 6)),
          ],
        ),
        child: Column(
          children: [
            Text(value,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    color: Colors.black54, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _TabHeader extends SliverPersistentHeaderDelegate {
  _TabHeader({required this.child, this.extent = kTextTabBarHeight});
  final Widget child;
  final double extent;

  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      SizedBox(height: extent, child: child);

  @override
  double get maxExtent => extent;

  @override
  double get minExtent => extent;

  @override
  bool shouldRebuild(covariant _TabHeader oldDelegate) => false;
}

class FeedPostCard extends StatelessWidget {
  const FeedPostCard({super.key, required this.post});

  final FeedPost post;

  String _resolveImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    return '${AppConstants.baseUrl}$url';
  }

  @override
  Widget build(BuildContext context) {
    // adjust these field names ONLY if your model uses different names
    final u = post.user; // PublicUserLite
    final name = (u.name?.trim().isNotEmpty == true) ? u.name!.trim() : u.email;
    final avatarUrl = _resolveImageUrl(u.avatarUrl);
    final imageUrl = _resolveImageUrl(post.imageUrl);

    final likeCount = post.likeCount;
    final commentCount = post.commentCount;
    final isLiked = post.isLiked == true;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PostDetailScreen(post: post),
          ),
        );
      },
      child: Card(
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
                  backgroundColor: Colors.black12,
                  backgroundImage:
                      avatarUrl.isEmpty ? null : NetworkImage(avatarUrl),
                  child: avatarUrl.isEmpty
                      ? Text(name.isEmpty ? "U" : name[0].toUpperCase())
                      : null,
                ),
                title: Text(name,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle:
                    Text(u.email, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              if (imageUrl.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 220,
                    errorBuilder: (_, __, ___) => Container(
                      height: 220,
                      color: Colors.black12,
                      alignment: Alignment.center,
                      child:
                          const Icon(Icons.broken_image, color: Colors.black26),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 10),
              Consumer<FeedProvider>(
                builder: (context, feed, _) {
                  return Row(
                    children: [
                      IconButton(
                        onPressed: () => feed.toggleLike(post),
                        icon: Icon(
                          post.isLiked ? Icons.favorite : Icons.favorite_border,
                        ),
                      ),
                      Text("${post.likeCount}"),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => PostDetailScreen(post: post)),
                          );
                        },
                        icon: const Icon(Icons.chat_bubble_outline),
                      ),
                      Text("${post.commentCount}"),
                    ],
                  );
                },
              ),
              if (post.text.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(post.text.trim()),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Helper widget
Widget _TextTile(String body) {
  return Container(
    color: Colors.white,
    padding: const EdgeInsets.all(8),
    child: Align(
        alignment: Alignment.topLeft,
        child: Text(
          body.isEmpty ? "Text post" : body,
          maxLines: 6,
          overflow: TextOverflow.ellipsis,
        )),
  );
}
