import 'dart:io';
import 'package:dio/dio.dart';
import '../models/post.dart';
import '/data/services/token_storage.dart';
import '../../core/constants.dart';

class FeedService {
  FeedService({Dio? dio, TokenStorage? tokenStorage})
      : _dio = dio ?? Dio(),
        _tokenStorage = tokenStorage ?? TokenStorage();

  final Dio _dio;
  final TokenStorage _tokenStorage;

  Future<Map<String, dynamic>> _headers({required bool auth}) async {
    final h = <String, dynamic>{
      'Accept': 'application/json',
    };
    if (auth) {
      final token = await _tokenStorage.getToken();
      if (token != null && token.isNotEmpty) {
        h['Authorization'] = 'Bearer $token';
      }
    }
    return h;
  }

  String _url(String path) => '${AppConstants.baseUrl}$path';

  Future<List<FeedPost>> fetchFeed({int? cursor, int limit = 20}) async {
    final res = await _dio.get(
      _url('/posts'),
      queryParameters: {
        if (cursor != null) 'cursor': cursor,
        'limit': limit,
      },
      options: Options(headers: await _headers(auth: true)),
    );

    final data = res.data;
    if (data is List) {
      return data
          .map((e) => FeedPost.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    }
    return const [];
  }

  Future<FeedPost> createPost({required String content, File? image}) async {
    final form = FormData.fromMap({
      'content': content,
      if (image != null)
        'image': await MultipartFile.fromFile(image.path,
            filename: image.path.split(Platform.pathSeparator).last),
    });

    final res = await _dio.post(
      _url('/posts'),
      data: form,
      options: Options(
        headers: await _headers(auth: true),
        contentType: 'multipart/form-data',
      ),
    );

    return FeedPost.fromJson((res.data as Map).cast<String, dynamic>());
  }

  Future<void> deletePost(int postId) async {
    await _dio.delete(
      _url('/posts/$postId'),
      options: Options(headers: await _headers(auth: true)),
    );
  }

  Future<bool> like(int postId) async {
    final res = await _dio.post(
      _url('/posts/$postId/like'),
      options: Options(headers: await _headers(auth: true)),
    );
    final data = res.data;
    return (data is Map) ? (data['liked'] == true) : true;
  }

  Future<bool> unlike(int postId) async {
    final res = await _dio.delete(
      _url('/posts/$postId/like'),
      options: Options(headers: await _headers(auth: true)),
    );
    final data = res.data;
    return (data is Map) ? (data['liked'] == true) : false;
  }

  Future<List<FeedComment>> fetchComments(int postId) async {
    final res = await _dio.get(
      _url('/posts/$postId/comments'),
      options: Options(headers: await _headers(auth: true)),
    );

    final data = res.data;

    final List list = (data is Map && data['comments'] is List)
        ? data['comments'] as List
        : (data is List ? data : const []);

    return list
        .map((e) => FeedComment.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<FeedComment> addComment(int postId, String text) async {
    final res = await _dio.post(
      _url('/posts/$postId/comments'),
      data: {'text': text},
      options: Options(headers: await _headers(auth: true)),
    );

    final data = res.data;
    final Map j =
        (data is Map && data['comment'] is Map) ? data['comment'] : data;
    return FeedComment.fromJson((j as Map).cast<String, dynamic>());
  }

  Future<void> deleteComment(int postId, int commentId) async {
    await _dio.delete(
      _url('/posts/$postId/comments/$commentId'),
      options: Options(headers: await _headers(auth: true)),
    );
  }
}
