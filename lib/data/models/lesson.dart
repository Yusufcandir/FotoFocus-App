class Lesson {
  final int id;
  final String title;

  final String body;

  final String imageUrl;

  final int order;

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
