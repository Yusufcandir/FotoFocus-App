import 'dart:io';
import '../../core/constants.dart';
import '../models/challenge.dart';
import 'api_service.dart';

class ChallengeService {
  ChallengeService({ApiService? apiService})
      : _api = apiService ?? ApiService();
  final ApiService _api;

  Future<List<Challenge>> fetchChallenges() async {
    final data = await _api.get(AppConstants.challenges, auth: true);

    // supports: { challenges: [...] } OR just [...]
    final List list;
    if (data is Map<String, dynamic> && data['challenges'] is List) {
      list = data['challenges'] as List;
    } else if (data is List) {
      list = data;
    } else {
      throw Exception('Unexpected response for challenges');
    }

    return list
        .map((e) => Challenge.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Challenge> fetchChallengeDetail(int challengeId) async {
    final data =
        await _api.get("${AppConstants.challenges}/$challengeId", auth: true);

    // supports: { challenge: {...} } OR just {...}
    final raw = (data is Map<String, dynamic> && data["challenge"] is Map)
        ? data["challenge"]
        : data;

    return Challenge.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<Challenge> createChallenge({
    required String title,
    String? description,
    File? coverFile,
  }) async {
    dynamic data;

    if (coverFile != null) {
      data = await _api.multipartPost(
        AppConstants.challenges,
        file: coverFile,
        fileField: "cover",
        fields: {
          "title": title,
          if ((description ?? "").trim().isNotEmpty)
            "description": description!,
        },
        auth: true,
      );
    } else {
      data = await _api.post(
        AppConstants.challenges,
        body: {
          "title": title,
          if ((description ?? "").trim().isNotEmpty) "description": description,
        },
        auth: true,
      );
    }

    final raw =
        (data is Map && data["challenge"] is Map) ? data["challenge"] : data;
    return Challenge.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<Challenge> updateChallenge(
    int id, {
    required String title,
    String? description,
    File? coverImage,
  }) async {
    final body = <String, dynamic>{
      'title': title,
      'description': description ?? '',
    };

    final res = await _api.put(
      '/challenges/$id',
      body: body,
      auth: true,
    );

    return Challenge.fromJson(res as Map<String, dynamic>);
  }

  Future<void> deleteChallenge(int id) async {
    await _api.delete('/challenges/$id', auth: true);
  }
}
