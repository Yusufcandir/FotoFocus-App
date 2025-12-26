import 'package:flutter/foundation.dart';
import '../data/models/lesson.dart';
import '../data/services/lesson_service.dart';

class LessonProvider extends ChangeNotifier {
  LessonProvider({LessonService? service})
      : _service = service ?? LessonService();

  final LessonService _service;

  bool _loading = false;
  String? _error;
  List<Lesson> _lessons = [];

  bool get loading => _loading;
  String? get error => _error;
  List<Lesson> get lessons => _lessons;

  Future<void> loadLessons() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _lessons = await _service.fetchLessons();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
