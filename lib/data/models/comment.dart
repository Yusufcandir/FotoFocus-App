class CommentUser {
  final int id;
  final String email;
  final String? name;
  final String? avatarUrl;

  const CommentUser({
    required this.id,
    required this.email,
    this.name,
    this.avatarUrl,
  });

  factory CommentUser.fromJson(Map<String, dynamic> json) {
    return CommentUser(
      id: (json["id"] as num).toInt(),
      email: (json["email"] ?? "").toString(),
      name: json["name"]?.toString(),
      avatarUrl: json["avatarUrl"]?.toString(),
    );
  }
}

class CommentModel {
  final int id;
  final String text;
  final int photoId;
  final int userId;
  final DateTime createdAt;

  final int? parentId;
  final List<CommentModel> replies;

  final CommentUser user;

  const CommentModel({
    required this.id,
    required this.text,
    required this.photoId,
    required this.userId,
    required this.createdAt,
    required this.user,
    this.parentId,
    this.replies = const [],
  });

  String get userEmail => user.email;

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    final userJson = (json["user"] is Map<String, dynamic>)
        ? (json["user"] as Map<String, dynamic>)
        : <String, dynamic>{
            "id": json["userId"] ?? 0,
            "email": json["userEmail"] ?? "",
            "name": null,
            "avatarUrl": null,
          };

    final repliesRaw =
        (json["replies"] is List) ? (json["replies"] as List) : [];

    return CommentModel(
      id: (json["id"] as num).toInt(),
      text: (json["text"] ?? "").toString(),
      photoId: (json["photoId"] as num).toInt(),
      userId: (json["userId"] as num).toInt(),
      parentId:
          (json["parentId"] is num) ? (json["parentId"] as num).toInt() : null,
      createdAt: DateTime.tryParse((json["createdAt"] ?? "").toString()) ??
          DateTime.now(),
      user: CommentUser.fromJson(userJson),
      replies: repliesRaw
          .whereType<Map>()
          .map((e) => CommentModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}
