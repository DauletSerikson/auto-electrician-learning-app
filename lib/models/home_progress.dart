import 'course_lesson.dart';

class HomeProgress {
  final int totalLessons;
  final int completedLessons;
  final CourseLesson? nextLesson;

  HomeProgress({
    required this.totalLessons,
    required this.completedLessons,
    required this.nextLesson,
  });

  double get progress {
    if (totalLessons == 0) {
      return 0;
    }

    return completedLessons / totalLessons;
  }
}
