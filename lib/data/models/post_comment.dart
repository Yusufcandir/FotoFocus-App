class PostComment {
  final int id;
  final String text;
  final DateTime createdAt;
  final Map<String, dynamic> user;

  PostComment({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.user,
  });

  factory PostComment.fromJson(Map<String, dynamic> j) => PostComment(
        id: j["id"],
        text: j["text"],
        createdAt: DateTime.parse(j["createdAt"]),
        user: (j["user"] as Map).cast<String, dynamic>(),
      );
}
