import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'lesson_detail_screen.dart';

import '../../core/theme.dart';
import '../../providers/lesson_provider.dart';

class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LessonProvider>().loadLessons();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<LessonProvider>();
    final bg = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0, //  prevents scroll color/elevation change
        surfaceTintColor: Colors.transparent, // prevents Material3 tint
        title: const Text(
          "Learn Hub",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: AppTheme.textDark,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (p.loading)
              const Expanded(child: Center(child: CircularProgressIndicator())),
            if (!p.loading && p.error != null)
              Expanded(
                child: Center(
                  child: Text(
                    p.error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            if (!p.loading && p.error == null)
              Expanded(
                child: ListView.separated(
                  itemCount: p.lessons.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, i) {
                    final lesson = p.lessons[i];

                    final subtitle = lesson.body.trim().isEmpty
                        ? "Tap to open the lesson"
                        : lesson.body.trim();

                    final hasImage = lesson.imageUrl.trim().isNotEmpty;
                    final imageUrl =
                        hasImage ? '${lesson.imageUrl}?v=${lesson.id}' : '';

                    return InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                LessonDetailScreen(lessonId: lesson.id),
                          ),
                        );
                      },
                      child: Container(
                        decoration: AppTheme.cardDecoration(radius: 22),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (hasImage)
                              SizedBox(
                                height: 140,
                                width: double.infinity,
                                child: Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    height: 140,
                                    color: Colors.black12,
                                    alignment: Alignment.center,
                                    child: const Icon(Icons.broken_image,
                                        color: Colors.black26),
                                  ),
                                ),
                              ),
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(14, 12, 14, 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    lesson.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      color: AppTheme.textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    subtitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.black.withOpacity(0.6),
                                      height: 1.25,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: const [
                                      Icon(Icons.menu_book_rounded, size: 16),
                                      SizedBox(width: 6),
                                      Text(
                                        "Lesson",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Spacer(),
                                      Icon(Icons.chevron_right_rounded),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
