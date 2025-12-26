import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../data/models/challenge.dart';
import '../../data/services/challenge_service.dart';
import '../../providers/auth_provider.dart';
import '../profile/profile_screen.dart';
import 'challenge_photos_screen.dart';

class ChallengeDetailScreen extends StatefulWidget {
  const ChallengeDetailScreen({super.key, required this.challengeId});

  final int challengeId;

  @override
  State<ChallengeDetailScreen> createState() => _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends State<ChallengeDetailScreen> {
  final ChallengeService _service = ChallengeService();
  String? _resolveImageUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    if (raw.startsWith('http')) return raw;
    return '${AppConstants.baseUrl}$raw'; // /uploads/...
  }

  bool _loading = true;
  String? _error;
  Challenge? _challenge;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final ch = await _service.fetchChallengeDetail(widget.challengeId);
      if (!mounted) return;
      setState(() => _challenge = ch);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  // ---------- Owner-only actions ----------
  Future<void> _editChallenge(Challenge challenge) async {
    final titleCtrl = TextEditingController(text: challenge.title);
    final subtitleCtrl = TextEditingController(text: challenge.subtitle);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit challenge'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Title'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: subtitleCtrl,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final title = titleCtrl.text.trim();
    final subtitle = subtitleCtrl.text.trim();
    if (title.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title cannot be empty')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await _updateChallengeOnServer(
        challenge.id,
        {
          'title': title,
          // your backend might use one of these keys
          'subtitle': subtitle,
          'description': subtitle,
        },
      );

      if (!mounted) return;
      await _load();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Challenge updated')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _confirmAndDelete(Challenge challenge) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete challenge?'),
        content: const Text('This will permanently delete the challenge.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _loading = true);

    try {
      await _deleteChallengeOnServer(challenge.id);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  /// Tries multiple common `ChallengeService` update signatures so you don't
  /// need to change other files.
  Future<void> _updateChallengeOnServer(
      int id, Map<String, dynamic> data) async {
    final svc = _service as dynamic;

    // 1) updateChallenge(id, data)
    try {
      await svc.updateChallenge(id, data);
      return;
    } catch (_) {}

    // 2) updateChallenge(challengeId: id, data: data)
    try {
      await svc.updateChallenge(challengeId: id, data: data);
      return;
    } catch (_) {}

    // 3) updateChallenge(challengeId: id, title: ..., subtitle: ..., description: ...)
    try {
      await svc.updateChallenge(
        challengeId: id,
        title: data['title'],
        subtitle: data['subtitle'],
        description: data['description'],
      );
      return;
    } catch (_) {}

    await _service.updateChallenge(
      id,
      title: data['title'],
      description: data['description'],
      coverImage: data['coverImage'], // if you have it
    );
  }

  /// Tries multiple common `ChallengeService` delete signatures.
  Future<void> _deleteChallengeOnServer(int id) async {
    await _service.deleteChallenge(id);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final currentUserId = auth.user?.id?.toString();
    final creatorId = _challenge?.creatorId?.toString();

    final isOwner = !_loading &&
        _challenge != null &&
        currentUserId != null &&
        creatorId != null &&
        currentUserId == creatorId;

    // ---- AppBar creator (works with either creator object OR creatorId) ----
    final creatorObj = _challenge?.creator;
    int? creatorUserId;
    String creatorName = 'User';
    String? creatorAvatarRaw;

    final c = _challenge?.creator;

    creatorUserId = c?.id ?? _challenge?.creatorId;
    creatorName = (c?.name ?? c?.email ?? 'User').toString();

    creatorUserId ??= int.tryParse('${_challenge?.creatorId ?? ''}');
    final creatorAvatarUrl = _resolveImageUrl(creatorAvatarRaw);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        title: const Text('Challenge'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (isOwner)
            PopupMenuButton<String>(
              onSelected: (v) {
                final c = _challenge;
                if (c == null) return;
                if (v == 'edit') _editChallenge(c);
                if (v == 'delete') _confirmAndDelete(c);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _challenge == null
                  ? const Center(child: Text('Challenge not found'))
                  : _Body(challenge: _challenge!),
    );
  }
}

// ---------- UI Widgets ----------
class _Body extends StatelessWidget {
  const _Body({required this.challenge});

  final Challenge challenge;

  String? _resolveImageUrl(String? v) {
    if (v == null) return null;
    final s = v.trim();
    if (s.isEmpty) return null;
    // if already absolute
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    // otherwise assume backend serves it
    return AppConstants.baseUrl + s;
  }

  @override
  Widget build(BuildContext context) {
    final coverUrl = _resolveImageUrl(challenge.coverImageUrl);

    // creator (backend might return object or id)
    final creator = challenge.creator;
    final c = challenge.creator;

    final creatorId = c?.id ?? challenge.creatorId;
    final creatorEmail = (c?.email ?? '').toString();
    final creatorName = (c?.name ?? '').toString();

    final display =
        (creatorName.isNotEmpty ? creatorName : creatorEmail).trim();

    final String? creatorAvatarRaw = null;

    final creatorAvatarUrl = _resolveImageUrl(creatorAvatarRaw);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (coverUrl != null) _Cover(url: coverUrl),
              const SizedBox(height: 16),
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      challenge.title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (challenge.subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        challenge.subtitle,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (display.isNotEmpty)
                      _CreatorRow(
                        label: 'Created by',
                        value: display,
                        avatarUrl: creatorAvatarUrl,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProfileScreen(
                                userId: creatorId is int ? creatorId : null,
                              ),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChallengePhotosScreen(
                                challengeId: challenge.id,
                                challengeTitle: challenge.title,
                              ),
                            ),
                          );
                        },
                        child: const Text(
                          'View Photos',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: Colors.black12,
            alignment: Alignment.center,
            child: const Icon(Icons.broken_image_outlined, size: 40),
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
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
      child: child,
    );
  }
}

class _CreatorRow extends StatelessWidget {
  const _CreatorRow({
    required this.label,
    required this.value,
    this.avatarUrl,
    this.onTap,
  });

  final String label;
  final String value;
  final String? avatarUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: Colors.black12,
              backgroundImage: (avatarUrl != null && avatarUrl!.isNotEmpty)
                  ? NetworkImage(avatarUrl!)
                  : null,
              child: (avatarUrl == null || avatarUrl!.isEmpty)
                  ? Text(
                      value.isNotEmpty ? value[0].toUpperCase() : '?',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black45,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black38),
          ],
        ),
      ),
    );
  }
}
