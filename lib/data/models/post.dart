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
  final String text;
  final String? imageUrl;
  final DateTime createdAt;
  final PublicUserLite user;

  int likeCount;
  int commentCount;
  bool isLiked;

  FeedPost({
    required this.id,
    required this.text,
    required this.imageUrl,
    required this.createdAt,
    required this.user,
    required this.likeCount,
    required this.commentCount,
    required this.isLiked,
  });

  factory FeedPost.fromJson(Map<String, dynamic> j) {
    String readBody(dynamic v) {
      if (v == null) return '';
      final s = v.toString().trim();
      if (s.isEmpty || s.toLowerCase() == 'null') return '';
      return s;
    }

    // ✅ accept multiple possible keys
    final body = [
      j['text'],
      j['content'],
      j['caption'],
      j['body'],
      j['message'],
      j['description'],
    ].map(readBody).firstWhere((s) => s.isNotEmpty, orElse: () => '');

    return FeedPost(
      id: (j['id'] as num).toInt(),
      text: body,
      imageUrl: j['imageUrl']?.toString(),
      createdAt: DateTime.parse(j['createdAt'].toString()),
      user: PublicUserLite.fromJson(j['user'] as Map<String, dynamic>),
      likeCount: (j['likeCount'] ?? 0) as int,
      commentCount: (j['commentCount'] ?? 0) as int,
      isLiked: (j['isLiked'] ?? false) as bool,
    );
  }
}

class FeedComment {
  final int id;
  final DateTime createdAt;
  final PublicUserLite user;
  final String text;

  FeedComment({
    required this.id,
    required this.createdAt,
    required this.user,
    required this.text,
  });

  factory FeedComment.fromJson(Map<String, dynamic> j) {
    return FeedComment(
      id: (j['id'] as num).toInt(),
      text: (j['text'] ?? j['content']).toString(),
      createdAt:
          DateTime.tryParse(j['createdAt']?.toString() ?? '') ?? DateTime.now(),
      user: PublicUserLite.fromJson((j['user'] as Map).cast<String, dynamic>()),
    );
  }
}
