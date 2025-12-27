import 'dart:io';
import 'package:flutter/foundation.dart';
import '../data/models/post.dart';
import '../data/services/feed_service.dart';

class FeedProvider extends ChangeNotifier {
  FeedProvider({FeedService? service}) : _service = service ?? FeedService();

  final FeedService _service;

  bool loading = false;
  String? error;

  final List<FeedPost> posts = [];
  bool hasMore = true;
  int? cursor;

  List<FeedComment> comments = [];
  bool commentsLoading = false;
  String? commentsError;
  int? _commentsPostId;

  Future<void> refresh() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final data = await _service.fetchFeed(cursor: null, limit: 20);
      posts
        ..clear()
        ..addAll(data);

      cursor = posts.isEmpty ? null : posts.last.id;
      hasMore = data.length == 20;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (loading || !hasMore) return;

    loading = true;
    notifyListeners();

    try {
      final data = await _service.fetchFeed(cursor: cursor, limit: 20);
      posts.addAll(data);

      cursor = posts.isEmpty ? null : posts.last.id;
      hasMore = data.length == 20;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> createPost({required String text, File? image}) async {
    final p = await _service.createPost(text: text, image: image);
    posts.insert(0, p);
    notifyListeners();
  }

  Future<void> deletePost(int postId) async {
    await _service.deletePost(postId);
    posts.removeWhere((p) => p.id == postId);
    notifyListeners();
  }

  Future<void> toggleLike(FeedPost p) async {
    final oldLiked = p.isLiked;
    final oldCount = p.likeCount;

    // optimistic
    p.isLiked = !oldLiked;
    p.likeCount = oldLiked ? (oldCount - 1) : (oldCount + 1);
    notifyListeners();

    try {
      if (!oldLiked) {
        await _service.like(p.id);
      } else {
        await _service.unlike(p.id);
      }
    } catch (_) {
      // rollback
      p.isLiked = oldLiked;
      p.likeCount = oldCount;
      notifyListeners();
    }
  }

  Future<void> loadComments(int postId) async {
    commentsLoading = true;
    commentsError = null;
    _commentsPostId = postId;
    notifyListeners();

    try {
      comments = await _service.fetchComments(postId);
    } catch (e) {
      commentsError = e.toString();
      comments = [];
    } finally {
      commentsLoading = false;
      notifyListeners();
    }
  }

  Future<void> addComment(int postId, String text) async {
    final t = text.trim();
    if (t.isEmpty) return;

    try {
      final newComment = await _service.addComment(postId, t);
      comments = [newComment, ...comments];
      // also update post commentCount locally if you keep a posts list
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteComment(int postId, int commentId) async {
    try {
      await _service.deleteComment(postId, commentId);
      comments = comments.where((c) => c.id != commentId).toList();
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> addCommentToPost(int postId, String text) async {
    final t = text.trim();
    if (t.isEmpty) return;

    final newComment = await _service.addComment(postId, t);

    // Only insert if we are viewing the same post’s comments
    if (_commentsPostId == postId) {
      comments = [newComment, ...comments];
      notifyListeners();
    }
  }

  Future<void> deleteCommentFromPost(int postId, int commentId) async {
    await _service.deleteComment(postId, commentId);

    if (_commentsPostId == postId) {
      comments = comments.where((c) => c.id != commentId).toList();
      notifyListeners();
    }
  }
}
