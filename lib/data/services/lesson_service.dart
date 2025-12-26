import '../../core/constants.dart';
import '../models/lesson.dart';
import 'api_service.dart';

class LessonService {
  LessonService({ApiService? apiService}) : _api = apiService ?? ApiService();

  final ApiService _api;

  Future<List<Lesson>> fetchLessons() async {
    final data = await _api.get(AppConstants.lessons, auth: true);

    // Backend might return:
    // 1) List مباشرة:  [ {...}, {...} ]
    // 2) Map wrapper: { lessons: [ {...}, {...} ] }
    final List rawList = (data is List)
        ? data
        : ((data is Map && data['lessons'] is List)
            ? data['lessons'] as List
            : const []);

    return rawList
        .map((e) => Lesson.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<Lesson> fetchLessonDetail(int id) async {
    final data = await _api.get("${AppConstants.lessons}/$id", auth: true);

    // Backend might return:
    // 1) Map directly: { ...lesson fields... }
    // 2) Wrapper: { lesson: { ... } }
    final Map lessonJson = (data is Map && data['lesson'] is Map)
        ? (data['lesson'] as Map)
        : (data as Map);

    return Lesson.fromJson(lessonJson.cast<String, dynamic>());
  }
}
