import 'dart:io';

import 'package:flutter/foundation.dart';

import '../data/models/challenge.dart';
import '../data/models/photo.dart';
import '../data/models/users.dart';
import '../data/services/profile_service.dart';
import '../data/models/post.dart';

class ProfileProvider extends ChangeNotifier {
  ProfileProvider({ProfileService? service})
      : _service = service ?? ProfileService();
  final ProfileService _service;

  User? user;
  Map<String, dynamic>? stats;

  List<Photo> photos = [];
  List<Challenge> challenges = [];

  List<User> followers = [];
  List<User> following = [];

  bool loading = false;
  bool followersLoading = false;
  bool followingLoading = false;

  bool followBusy = false;
  bool? isFollowing;

  String? error;
  List<FeedPost> posts = [];
  List<FeedPost> likedPosts = [];
  bool postsLoading = false;
  bool likedLoading = false;

  int get photoCount => (stats?["photoCount"] as int?) ?? photos.length;
  int get challengeCount =>
      (stats?["challengeCount"] as int?) ?? challenges.length;
  int get followersCount => (stats?["followersCount"] as int?) ?? 0;
  int get followingCount => (stats?["followingCount"] as int?) ?? 0;

  double get avgRatingReceived =>
      ((stats?["avgRatingReceived"] as num?) ?? 0).toDouble();
  int get totalComments => (stats?["totalComments"] as int?) ?? 0;

  Future<void> loadProfile({int? userId}) async {
    loading = true;
    error = null;

    postsLoading = true;
    likedLoading = true;

    notifyListeners();

    try {
      // Load the main profile data first (if this fails, profile can't show)
      final u = await _service.fetchUser(userId: userId);
      final s = await _service.fetchStats(userId: userId);
      final p = await _service.fetchUserPhotos(userId: userId);
      final c = await _service.fetchUserChallenges(userId: userId);

      user = u;
      stats = s;
      photos = p;
      challenges = c;

      // Only compute relationship when viewing another user (not /me)
      if (userId != null) {
        isFollowing = await _service.isFollowing(userId);
      } else {
        isFollowing = null;
      }

      try {
        posts = await _service.fetchUserPosts(userId: userId);
      } catch (_) {
        posts = [];
      } finally {
        postsLoading = false;
      }

      try {
        likedPosts = await _service.fetchLikedPosts(userId: userId);
      } catch (_) {
        likedPosts = [];
      } finally {
        likedLoading = false;
      }
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;

      postsLoading = false;
      likedLoading = false;

      notifyListeners();
    }
  }

  Future<void> refresh({int? userId}) => loadProfile(userId: userId);

  Future<void> updateName(String name) async {
    try {
      final updated = await _service.updateMyProfile(name: name);
      user = updated;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> uploadAvatar(File file) async {
    try {
      final updated = await _service.uploadAvatar(file);
      user = updated;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deletePhoto(int photoId) async {
    try {
      await _service.deletePhoto(photoId);
      photos.removeWhere((p) => p.id == photoId);
      stats = {
        ...(stats ?? {}),
        "photoCount": photos.length,
      };
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deletePost(int postId) async {
    try {
      await _service.deletePost(postId);
      posts.removeWhere((p) => p.id == postId);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  // ---------- FOLLOW ----------
  Future<void> toggleFollow(int targetUserId) async {
    if (followBusy) return;
    followBusy = true;
    notifyListeners();

    try {
      final currently = isFollowing == true;
      if (currently) {
        await _service.unfollow(targetUserId);
        isFollowing = false;
        stats = {
          ...(stats ?? {}),
          "followersCount": (followersCount - 1).clamp(0, 1 << 30),
        };
      } else {
        await _service.follow(targetUserId);
        isFollowing = true;
        stats = {
          ...(stats ?? {}),
          "followersCount": followersCount + 1,
        };
      }
    } finally {
      followBusy = false;
      notifyListeners();
    }
  }

  Future<void> loadFollowers(int userId) async {
    followersLoading = true;
    notifyListeners();
    try {
      followers = await _service.fetchFollowers(userId);
    } finally {
      followersLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadFollowing(int userId) async {
    followingLoading = true;
    notifyListeners();
    try {
      following = await _service.fetchFollowing(userId);
    } finally {
      followingLoading = false;
      notifyListeners();
    }
  }
}
