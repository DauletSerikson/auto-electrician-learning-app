import 'package:electrician/domain/course_progress.dart';
import 'package:electrician/models/course_lesson.dart';
import 'package:electrician/models/course_module.dart';
import 'package:electrician/models/lesson_summary.dart';
import 'package:flutter_test/flutter_test.dart';

CourseLesson item(
  String id, {
  String module = 'module',
  int moduleOrder = 1,
  int lessonOrder = 1,
}) => CourseLesson(
  module: CourseModule(
    id: module,
    order: moduleOrder,
    title: module,
    description: '',
  ),
  lesson: LessonSummary(
    id: id,
    order: lessonOrder,
    title: id,
    description: '',
    estimatedMinutes: 1,
    file: '$id.json',
  ),
);

void main() {
  test('empty course has no next lesson and zero fraction', () {
    final result = calculateCourseProgress([], {'orphan'});
    expect(result.totalLessons, 0);
    expect(result.completedLessons, 0);
    expect(result.progress, 0);
    expect(result.nextLesson, isNull);
  });

  test(
    'partial progress counts current lessons and rounds only for display',
    () {
      final lessons = [item('a'), item('b'), item('c')];
      final result = calculateCourseProgress(lessons, {'a'});
      expect(result.totalLessons, 3);
      expect(result.completedLessons, 1);
      expect(result.progress, 1 / 3);
      expect((result.progress * 100).round(), 33);
      expect(result.nextLesson, same(lessons[1]));
    },
  );

  test('unknown IDs do not inflate numerator or change next lesson', () {
    final lessons = [item('a'), item('b')];
    final completed = {'unknown', 'orphan', 'b'};
    final result = calculateCourseProgress(lessons, completed);
    expect(result.completedLessons, 1);
    expect(result.progress, .5);
    expect(result.nextLesson, same(lessons.first));
    expect(completed, {'unknown', 'orphan', 'b'});
  });

  test('all complete has no next lesson and fraction never exceeds one', () {
    final result = calculateCourseProgress(
      [item('a'), item('b')],
      {'a', 'b', 'orphan'},
    );
    expect(result.totalLessons, 2);
    expect(result.completedLessons, 2);
    expect(result.progress, 1);
    expect(result.nextLesson, isNull);
  });

  test('adding lesson increases current denominator without completing it', () {
    final lessons = [item('a')];
    final before = calculateCourseProgress(lessons, {'a'});
    lessons.add(item('new'));
    final after = calculateCourseProgress(lessons, {'a'});
    expect(before.progress, 1);
    expect(after.progress, .5);
    expect(after.nextLesson!.lesson.id, 'new');
    expect(before.totalLessons, 1);
  });

  test('removing lesson changes denominator without deleting orphan ID', () {
    final completed = {'a', 'removed'};
    final result = calculateCourseProgress([item('a'), item('b')], completed);
    expect(result.totalLessons, 2);
    expect(result.completedLessons, 1);
    expect(completed, contains('removed'));
  });

  test('moving lesson to another module preserves completion by ID', () {
    final before = calculateCourseProgress([item('a', module: 'old')], {'a'});
    final after = calculateCourseProgress(
      [item('a', module: 'new', moduleOrder: 2)],
      {'a'},
    );
    expect(before.completedLessons, after.completedLessons);
    expect(after.progress, 1);
    expect(after.nextLesson, isNull);
  });

  test(
    'next lesson uses supplied content order across modules and lessons',
    () {
      final lessons = [
        item('a', lessonOrder: 1),
        item('b', lessonOrder: 2),
        item('c', module: 'second', moduleOrder: 2, lessonOrder: 1),
      ];
      expect(
        calculateCourseProgress(lessons, {'a', 'c'}).nextLesson,
        same(lessons[1]),
      );
      expect(
        calculateCourseProgress(lessons, {'a', 'b'}).nextLesson,
        same(lessons[2]),
      );
      expect(lessons.map((item) => item.lesson.id), ['a', 'b', 'c']);
    },
  );

  test('changed ID is a new incomplete lesson', () {
    final result = calculateCourseProgress([item('renamed')], {'old'});
    expect(result.completedLessons, 0);
    expect(result.nextLesson!.lesson.id, 'renamed');
  });
}
