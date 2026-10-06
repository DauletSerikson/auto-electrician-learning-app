import 'package:shared_preferences/shared_preferences.dart';

import '../domain/course_progress.dart';
import '../models/course_lesson.dart';
import '../models/home_progress.dart';

class ProgressService {
  static const String _completedLessonsKey = 'completed_lessons';

  Future<Set<String>> getCompletedLessons() async {
    final prefs = await SharedPreferences.getInstance();

    // A setter updates the plugin cache before the platform confirms the write.
    // Read persisted values so a failed write cannot appear as completion.
    await prefs.reload();

    final completed = prefs.getStringList(_completedLessonsKey) ?? [];

    return completed.toSet();
  }

  Future<bool> isLessonCompleted(String lessonId) async {
    final completed = await getCompletedLessons();

    return completed.contains(lessonId);
  }

  /// Completes after a confirmed write; false results and storage errors throw.
  Future<void> completeLesson(String lessonId) async {
    final prefs = await SharedPreferences.getInstance();

    final completed = await getCompletedLessons();

    completed.add(lessonId);

    final saved = await prefs.setStringList(
      _completedLessonsKey,
      completed.toList(),
    );
    if (!saved) {
      throw StateError('Could not save lesson completion');
    }
  }

  Future<HomeProgress> calculateProgress(List<CourseLesson> allLessons) async {
    final completed = await getCompletedLessons();

    return calculateCourseProgress(allLessons, completed);
  }
}
