import '../../core/constants.dart';

class Challenge {
  final int id;
  final int creatorId;
  final String title;
  final String subtitle;
  final String description;
  final String difficulty;
  final String startsAt;
  final String endsAt;
  final ChallengeCreator? creator;

  final String coverUrl;

  final List<String> tips;
  final bool featured;

  Challenge({
    required this.id,
    required this.creatorId,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.difficulty,
    required this.startsAt,
    required this.endsAt,
    required this.coverUrl,
    required this.tips,
    required this.featured,
    required this.creator,
  });

  @Deprecated('Use coverUrl instead')
  String get coverImageUrl => coverUrl;

  static List<String> _parseTips(dynamic v) {
    if (v == null) return [];
    if (v is List) return v.map((e) => e.toString()).toList();
    final s = v.toString().trim();
    if (s.isEmpty) return [];
    return [s];
  }

  static String _normalizeCover(String raw) {
    final c = raw.trim();
    if (c.isEmpty) return "";

    // already absolute
    if (c.startsWith("http://") || c.startsWith("https://")) return c;

    // handle "/uploads/.."
    if (c.startsWith("/")) return "${AppConstants.baseUrl}$c";

    // handle "uploads/.."
    return "${AppConstants.baseUrl}/$c";
  }

  factory Challenge.fromJson(Map<String, dynamic> json) {
    final rawCover = (json["coverUrl"] ??
            json["coverImageUrl"] ??
            json["coverImage"] ??
            json["cover"] ??
            "")
        .toString();

    return Challenge(
      id: (json["id"] as num).toInt(),
      creatorId: (() {
        final v = json['creatorId'] ?? json['creator']?['id'];
        if (v == null) return 0; // or throw if you prefer strict
        if (v is int) return v;
        if (v is num) return v.toInt();
        return int.tryParse(v.toString()) ?? 0;
      })(),
      title: (json["title"] ?? "").toString(),
      subtitle: (json["subtitle"] ?? "").toString(),
      description: (json["description"] ?? "").toString(),
      difficulty: (json["difficulty"] ?? "").toString(),
      startsAt: (json["startsAt"] ?? "").toString(),
      endsAt: (json["endsAt"] ?? "").toString(),
      coverUrl: _normalizeCover(rawCover),
      tips: _parseTips(json["tips"]),
      featured: json["featured"] == true,
      creator: json['creator'] != null
          ? ChallengeCreator.fromJson(json['creator'])
          : null,
    );
  }
}

class ChallengeCreator {
  final int id;
  final String email;
  final String? name;
  final String? avatarUrl;

  ChallengeCreator({
    required this.id,
    required this.email,
    this.name,
    this.avatarUrl,
  });

  factory ChallengeCreator.fromJson(Map<String, dynamic> json) {
    return ChallengeCreator(
      id: (json['id'] as num).toInt(),
      email: (json['email'] ?? '').toString(),
      name: json['name']?.toString(),
      avatarUrl: json['avatarUrl']?.toString(),
    );
  }
}
