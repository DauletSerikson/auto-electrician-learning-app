import 'package:electrician/services/course_service.dart';
import 'package:electrician/services/progress_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('missing key is empty', () async {
    expect(await ProgressService().getCompletedLessons(), isEmpty);
  });

  test('existing IDs are deduplicated including unknown IDs', () async {
    SharedPreferences.setMockInitialValues({
      'completed_lessons': ['a', 'a', 'unknown'],
    });
    expect(await ProgressService().getCompletedLessons(), {'a', 'unknown'});
    expect(await ProgressService().isLessonCompleted('a'), isTrue);
    expect(await ProgressService().isLessonCompleted('b'), isFalse);
  });

  test(
    'completion is idempotent and survives service and cache recreation',
    () async {
      final service = ProgressService();
      await service.completeLesson('a');
      await service.completeLesson('a');
      await service.completeLesson('b');
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      expect(await ProgressService().getCompletedLessons(), {'a', 'b'});
      expect(prefs.getStringList('completed_lessons'), hasLength(2));
      expect(prefs.getKeys(), {'completed_lessons'});
    },
  );

  test('empty course ignores stored IDs', () async {
    await ProgressService().completeLesson('orphan');
    final result = await ProgressService().calculateProgress([]);
    expect(result.totalLessons, 0);
    expect(result.completedLessons, 0);
    expect(result.progress, 0);
    expect(result.nextLesson, isNull);
  });

  test('real course order and denominator determine home progress', () async {
    final lessons = await CourseService().loadAllLessons();
    expect(lessons, hasLength(42));
    for (var index = 1; index < lessons.length; index++) {
      final previous = lessons[index - 1];
      final current = lessons[index];
      expect(current.module.order, greaterThanOrEqualTo(previous.module.order));
      if (current.module.id == previous.module.id) {
        expect(
          current.lesson.order,
          greaterThanOrEqualTo(previous.lesson.order),
        );
      }
    }
    final service = ProgressService();
    await service.completeLesson('orphan');
    await service.completeLesson(lessons.first.lesson.id);
    final result = await service.calculateProgress(lessons);
    expect(result.totalLessons, 42);
    expect(result.completedLessons, 1);
    expect(result.progress, 1 / 42);
    expect(result.nextLesson, same(lessons[1]));
    for (final item in lessons.skip(1)) {
      await service.completeLesson(item.lesson.id);
    }
    final complete = await service.calculateProgress(lessons);
    expect(complete.progress, 1);
    expect(complete.completedLessons, 42);
    expect(complete.nextLesson, isNull);
  });
}
