import 'package:shared_preferences/shared_preferences.dart';
import '../models/course_lesson.dart';
import '../models/home_progress.dart';

class ProgressService {
  static const String _completedLessonsKey = 'completed_lessons';

  Future<Set<String>> getCompletedLessons() async {
    final prefs = await SharedPreferences.getInstance();

    final completed =
        prefs.getStringList(_completedLessonsKey) ?? [];

    return completed.toSet();
  }

  Future<bool> isLessonCompleted(String lessonId) async {
    final completed = await getCompletedLessons();

    return completed.contains(lessonId);
  }

  Future<void> completeLesson(String lessonId) async {
    final prefs = await SharedPreferences.getInstance();

    final completed = await getCompletedLessons();

    completed.add(lessonId);

    await prefs.setStringList(
      _completedLessonsKey,
      completed.toList(),
    );
  }
  Future<HomeProgress> calculateProgress(
    List<CourseLesson> allLessons,
  ) async {
    final completed = await getCompletedLessons();

    final completedCount = allLessons
        .where(
          (item) => completed.contains(
            item.lesson.id,
          ),
        )
        .length;

    CourseLesson? nextLesson;

    for (final item in allLessons) {
      if (!completed.contains(item.lesson.id)) {
        nextLesson = item;
        break;
      }
    }

    return HomeProgress(
      totalLessons: allLessons.length,
      completedLessons: completedCount,
      nextLesson: nextLesson,
    );
  }
}