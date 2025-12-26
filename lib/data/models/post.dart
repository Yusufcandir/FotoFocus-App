class PublicUserLite {
  final int id;
  final String email;
  final String? name;
  final String? avatarUrl;

  const PublicUserLite({
    required this.id,
    required this.email,
    this.name,
    this.avatarUrl,
  });

  factory PublicUserLite.fromJson(Map<String, dynamic> j) {
    return PublicUserLite(
      id: (j['id'] as num).toInt(),
      email: (j['email'] ?? '').toString(),
      name: j['name']?.toString(),
      avatarUrl: j['avatarUrl']?.toString(),
    );
  }

  String get displayName =>
      (name != null && name!.trim().isNotEmpty) ? name!.trim() : email;
}

class FeedPost {
  final int id;
  final String content;
  final String? imageUrl;
  final DateTime createdAt;
  final PublicUserLite user;

  int likeCount;
  int commentCount;
  bool isLiked;

  FeedPost({
    required this.id,
    required this.content,
    required this.imageUrl,
    required this.createdAt,
    required this.user,
    required this.likeCount,
    required this.commentCount,
    required this.isLiked,
  });

  factory FeedPost.fromJson(Map<String, dynamic> j) {
    return FeedPost(
      id: (j['id'] as num).toInt(),
      content: (j['content'] ?? '').toString(),
      imageUrl: j['imageUrl']?.toString(),
      createdAt:
          DateTime.tryParse(j['createdAt']?.toString() ?? '') ?? DateTime.now(),
      user: PublicUserLite.fromJson((j['user'] as Map).cast<String, dynamic>()),
      likeCount: (j['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (j['commentCount'] as num?)?.toInt() ?? 0,
      isLiked: (j['isLiked'] as bool?) ?? false,
    );
  }
}

class FeedComment {
  final int id;
  final String text;
  final DateTime createdAt;
  final PublicUserLite user;

  FeedComment({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.user,
  });

  factory FeedComment.fromJson(Map<String, dynamic> j) {
    return FeedComment(
      id: (j['id'] as num).toInt(),
      text: (j['text'] ?? '').toString(),
      createdAt:
          DateTime.tryParse(j['createdAt']?.toString() ?? '') ?? DateTime.now(),
      user: PublicUserLite.fromJson((j['user'] as Map).cast<String, dynamic>()),
    );
  }
}
