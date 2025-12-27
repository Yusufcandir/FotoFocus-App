import 'dart:io';
import '../../core/constants.dart';
import '../models/photo.dart';
import '../models/comment.dart';
import 'api_service.dart';

class PhotoService {
  PhotoService({ApiService? apiService}) : _api = apiService ?? ApiService();
  final ApiService _api;

  List<dynamic> _extractList(dynamic data, String key) {
    if (data is Map<String, dynamic> && data[key] is List) {
      return data[key] as List;
    }
    if (data is List) return data;
    return <dynamic>[];
  }

  Map<String, dynamic> _extractMap(dynamic data, String key) {
    if (data is Map<String, dynamic> && data[key] is Map) {
      return Map<String, dynamic>.from(data[key] as Map);
    }
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  Future<List<Photo>> fetchChallengePhotos(int challengeId) async {
    final data = await _api.get(
      "${AppConstants.challenges}/$challengeId/photos",
      auth: true,
    );

    final list = _extractList(data, "photos");
    return list
        .whereType<Map>()
        .map((e) => Photo.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Photo> fetchPhotoDetail(int photoId) async {
    final data = await _api.get("${AppConstants.photos}/$photoId", auth: true);
    final json = _extractMap(data, "photo");
    return Photo.fromJson(json);
  }

  Future<List<CommentModel>> fetchComments(int photoId) async {
    final data =
        await _api.get("${AppConstants.photos}/$photoId/comments", auth: true);

    final list = _extractList(data, "comments");
    return list
        .whereType<Map>()
        .map((e) => CommentModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<CommentModel> postComment(
    int photoId,
    String text, {
    int? parentId,
  }) async {
    final body = <String, dynamic>{"text": text};
    if (parentId != null) body["parentId"] = parentId;

    final data = await _api.post(
      "${AppConstants.photos}/$photoId/comments",
      body: body,
      auth: true,
    );

    final json = _extractMap(data, "comment");
    return CommentModel.fromJson(
        json.isEmpty && data is Map<String, dynamic> ? data : json);
  }

  Future<void> deleteComment(int commentId) async {
    await _api.delete(
      "/comments/$commentId",
      auth: true,
    );
  }

  Future<Map<String, dynamic>> ratePhoto(int photoId, int rating) async {
    final data = await _api.post(
      "${AppConstants.photos}/$photoId/ratings",
      body: {'value': rating},
      auth: true,
    );

    return (data as Map<String, dynamic>)["photo"];
  }

  Future<int?> fetchMyRating(int photoId) async {
    final data =
        await _api.get("${AppConstants.photos}/$photoId/my-rating", auth: true);

    if (data is Map<String, dynamic> && data["ratings"] != null) {
      return (data["ratings"] as num).toInt();
    }
    return null;
  }

  Future<Photo> uploadPhoto({
    required int challengeId,
    required File photoFile,
  }) async {
    final data = await _api.multipartPost(
      "${AppConstants.challenges}/$challengeId/photos",
      file: photoFile,
      fileField: "photo",
      auth: true,
    );

    final raw = (data is Map && data["photo"] is Map) ? data["photo"] : data;
    return Photo.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<void> deletePhoto(int photoId) async {
    await _api.delete(
      "${AppConstants.photos}/$photoId",
      auth: true,
    );
  }

  Future<Photo> updateCaption(int photoId, String caption) async {
    final data = await _api.put(
      "${AppConstants.photos}/$photoId",
      body: {"caption": caption},
      auth: true,
    );

    final json = _extractMap(data, "photo");
    return Photo.fromJson(json);
  }

  Future<void> reportPhoto(int photoId, String reason) async {
    await _api.post(
      "${AppConstants.photos}/$photoId/report",
      body: {"reason": reason},
      auth: true,
    );
  }

  Future<List<Photo>> fetchMyPhotos() async {
    final data = await _api.get("/me/photos", auth: true);
    final list = _extractList(data, "photos");
    return list
        .whereType<Map>()
        .map((e) => Photo.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<String> fetchMyEmail() async {
    final data = await _api.get("/me", auth: true);
    if (data is Map<String, dynamic> && data["user"] is Map) {
      return ((data["user"] as Map)["email"] ?? "").toString();
    }
    return "";
  }
}
