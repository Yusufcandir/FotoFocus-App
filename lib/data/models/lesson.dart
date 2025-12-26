class Lesson {
  final int id;
  final String title;

  /// Use one field in UI: show this in list + detail
  final String body;

  /// Optional image (can be empty)
  final String imageUrl;

  /// Optional ordering
  final int order;

  /// Optional slug (if you use it later)
  final String? slug;

  Lesson({
    required this.id,
    required this.title,
    required this.body,
    required this.imageUrl,
    this.order = 0,
    this.slug,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    // Support BOTH backends:
    // - old: { id, title, body, imageUrl }
    // - new: { id, slug, title, summary, content, coverUrl, order }
    final title = (json['title'] ?? '').toString();

    final body =
        (json['body'] ?? json['content'] ?? json['summary'] ?? '').toString();

    final imageUrl = (json['imageUrl'] ?? json['coverUrl'] ?? '').toString();

    final order = (json['order'] is num) ? (json['order'] as num).toInt() : 0;

    return Lesson(
      id: (json['id'] as num).toInt(),
      slug: json['slug']?.toString(),
      title: title,
      body: body,
      imageUrl: imageUrl,
      order: order,
    );
  }
}
