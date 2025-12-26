import 'dart:io';

import '../../core/constants.dart';
import '../models/challenge.dart';
import '../models/photo.dart';
import '../models/users.dart';
import '../models/post.dart';
import 'api_service.dart';

class ProfileService {
  ProfileService({ApiService? apiService}) : _api = apiService ?? ApiService();
  final ApiService _api;

  Future<dynamic> _getWithFallback(List<String> paths,
      {required bool auth}) async {
    Object? lastErr;
    for (final p in paths) {
      try {
        return await _api.get(p, auth: auth);
      } catch (e) {
        lastErr = e;
      }
    }
    throw lastErr ?? Exception("Request failed");
  }

  Future<User> fetchUser({int? userId}) async {
    final paths =
        (userId == null) ? <String>["/me"] : <String>["/users/$userId"];

    final res = await _getWithFallback(paths, auth: true);

    return User.fromJson((res as Map).cast<String, dynamic>());
  }

  Future<Map<String, dynamic>> fetchStats({int? userId}) async {
    final paths = (userId == null)
        ? <String>["/me/stats"]
        : <String>["/users/$userId/stats"];

    final res = await _getWithFallback(paths, auth: true);

    return (res as Map).cast<String, dynamic>();
  }

  Future<List<Photo>> fetchUserPhotos({int? userId}) async {
    final paths = (userId == null)
        ? <String>["/me/photos"]
        : <String>["/users/$userId/photos"];

    final res = await _getWithFallback(paths, auth: true);

    final List list =
        (res is Map && res["photos"] is List) ? res["photos"] : (res as List);
    return list
        .map((e) => Photo.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<Challenge>> fetchUserChallenges({int? userId}) async {
    final paths = (userId == null)
        ? <String>["/me/challenges"]
        : <String>["/users/$userId/mychallenges"];

    final res = await _getWithFallback(paths, auth: true);

    final List list = (res is Map && res["challenges"] is List)
        ? res["challenges"]
        : (res as List);
    return list
        .map((e) => Challenge.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<User> updateMyProfile({required String name}) async {
    final res = await _api.put(
      "/me",
      body: {"name": name},
      auth: true,
    );
    return User.fromJson((res as Map).cast<String, dynamic>());
  }

  Future<User> uploadAvatar(File file) async {
    // backend expects: POST /me/avatar, field "avatar"
    final res = await _api.multipartPost(
      "/me/avatar",
      file: file,
      fileField: "avatar",
      fields: const {},
      auth: true,
    );

    return User.fromJson((res as Map).cast<String, dynamic>());
  }

  Future<void> deletePhoto(int photoId) async {
    await _api.delete("${AppConstants.photos}/$photoId", auth: true);
  }

  // ---------- FOLLOW ----------
  Future<bool> isFollowing(int userId) async {
    final res = await _api.get("/users/$userId/isFollowing", auth: true);
    if (res is Map && res["isFollowing"] is bool)
      return res["isFollowing"] as bool;
    return false;
  }

  Future<void> follow(int userId) async {
    await _api.post("/users/$userId/follow", body: {}, auth: true);
  }

  Future<void> unfollow(int userId) async {
    await _api.delete("/users/$userId/follow", auth: true);
  }

  Future<List<User>> fetchFollowers(int userId) async {
    final res = await _api.get("/users/$userId/followers", auth: true);
    final List list = (res is Map && res["followers"] is List)
        ? res["followers"]
        : (res as List);
    return list
        .map((e) => User.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<User>> fetchFollowing(int userId) async {
    final res = await _api.get("/users/$userId/following", auth: true);
    final List list = (res is Map && res["following"] is List)
        ? res["following"]
        : (res as List);
    return list
        .map((e) => User.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<FeedPost>> fetchUserPosts({int? userId}) async {
    final paths = (userId == null)
        ? <String>["/me/posts"]
        : <String>["/users/$userId/posts"];

    final res = await _getWithFallback(paths, auth: true);
    final List list =
        (res is Map && res["posts"] is List) ? res["posts"] : (res as List);

    return list
        .map((e) => FeedPost.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<FeedPost>> fetchLikedPosts({int? userId}) async {
    final paths = (userId == null)
        ? <String>["/me/liked-posts"]
        : <String>["/users/$userId/liked-posts"];

    final res = await _getWithFallback(paths, auth: true);
    final List list =
        (res is Map && res["posts"] is List) ? res["posts"] : (res as List);

    return list
        .map((e) => FeedPost.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }
}
