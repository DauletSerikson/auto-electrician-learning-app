import '../models/course_lesson.dart';
import '../models/home_progress.dart';

/// Lessons are ordered by the content loader (module.order, then lesson.order).
/// Only current content contributes to progress; orphan IDs remain in storage.
HomeProgress calculateCourseProgress(
  List<CourseLesson> orderedLessons,
  Set<String> completedIds,
) {
  var completedCount = 0;
  CourseLesson? nextLesson;
  for (final item in orderedLessons) {
    if (completedIds.contains(item.lesson.id)) {
      completedCount++;
    } else {
      nextLesson ??= item;
    }
  }
  return HomeProgress(
    totalLessons: orderedLessons.length,
    completedLessons: completedCount,
    nextLesson: nextLesson,
  );
}
