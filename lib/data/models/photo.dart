import '../../core/constants.dart';

class Photo {
  /// Unique photo id
  final int id;

  /// Challenge this photo belongs to
  final int challengeId;

  /// Full or relative image URL
  final String imageUrl;

  /// Optional caption
  final String caption;

  /// Email of uploader (for display)
  final String userEmail;

  /// ISO date string from backend
  final String createdAt;

  /// Average rating (0.0 if none)
  final double avgRating;

  /// Number of ratings
  final int ratingCount;

  /// User id of uploader (IMPORTANT for delete permission)
  final int userId;

  const Photo({
    required this.id,
    required this.challengeId,
    required this.imageUrl,
    required this.caption,
    required this.userEmail,
    required this.createdAt,
    required this.avgRating,
    required this.ratingCount,
    required this.userId,
  });

  /// Parse Photo from backend JSON
  factory Photo.fromJson(Map<String, dynamic> json) {
    final rawUrl =
        (json["imageUrl"] ?? json["url"] ?? json["path"] ?? "").toString();

    return Photo(
      id: (json["id"] as num).toInt(),
      challengeId: (json["challengeId"] as num).toInt(),
      userId: (json["userId"] as num).toInt(),
      caption: (json["caption"] ?? "").toString(),

      // ✅ normalize once here → UI always gets a usable URL
      imageUrl: AppConstants.resolveImageUrl(rawUrl),

      avgRating: ((json["avgRating"] ?? 0) as num).toDouble(),
      ratingCount: ((json["ratingCount"] ?? 0) as num).toInt(),
      userEmail: (json["userEmail"] ?? "").toString(),
      createdAt: (json["createdAt"] ?? "").toString(),
    );
  }

  Photo copyWith({
    int? id,
    int? challengeId,
    int? userId,
    String? caption,
    String? imageUrl,
    double? avgRating,
    int? ratingCount,
    String? userEmail,
    String? createdAt,
  }) {
    return Photo(
      id: id ?? this.id,
      challengeId: challengeId ?? this.challengeId,
      userId: userId ?? this.userId,
      caption: caption ?? this.caption,
      imageUrl: imageUrl ?? this.imageUrl,
      avgRating: avgRating ?? this.avgRating,
      ratingCount: ratingCount ?? this.ratingCount,
      userEmail: userEmail ?? this.userEmail,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Convert to JSON (useful later for caching / optimistic UI)
  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "challengeId": challengeId,
      "imageUrl": imageUrl,
      "caption": caption,
      "userEmail": userEmail,
      "createdAt": createdAt,
      "avgRating": avgRating,
      "ratingCount": ratingCount,
      "userId": userId,
    };
  }

  /// Helper: check if this photo belongs to current user
  bool isOwnedBy(int currentUserId) {
    return userId == currentUserId;
  }

  /// Helper: parsed DateTime (safe)
  DateTime? get createdDate {
    try {
      return DateTime.parse(createdAt);
    } catch (_) {
      return null;
    }
  }

  /// Helper: display-friendly date
  String get formattedDate {
    final date = createdDate;
    if (date == null) return "";
    return "${date.day}/${date.month}/${date.year}";
  }

  // ─────────────────────────────────────────────
  // Private safe parsers
  // ─────────────────────────────────────────────

  static int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return 0;
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return 0.0;
  }
}
