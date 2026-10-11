import 'package:electrician/models/lesson.dart';
import 'package:electrician/models/lesson_completion.dart';
import 'package:electrician/services/course_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final json in [
    null,
    <String, dynamic>{},
    {'type': null},
    {'type': 'lesson'},
  ]) {
    test('default/current ordinary policy: $json', () {
      final completion = LessonCompletion.fromJson(json);
      expect(completion.type, 'lesson');
      expect(completion.isQuiz, isFalse);
      expect(completion.passingScore, isNull);
    });
  }

  for (final score in [1, 80, 100]) {
    test('quiz threshold $score is valid', () {
      final completion = LessonCompletion.fromJson({
        'type': 'quiz',
        'passingScore': score,
      });
      expect(completion.isQuiz, isTrue);
      expect(completion.passingScore, score);
    });
  }

  test(
    'ordinary policy retains compatibility with an optional valid threshold',
    () {
      final completion = LessonCompletion.fromJson({
        'type': 'lesson',
        'passingScore': 80,
      });
      expect(completion.isQuiz, isFalse);
      expect(completion.passingScore, 80);
    },
  );

  for (final type in ['unknown', '', 1, false, <String>[]]) {
    test('invalid type $type fails clearly', () {
      expect(
        () => LessonCompletion.fromJson({'type': type}),
        throwsA(isA<FormatException>()),
      );
    });
  }

  for (final json in [
    {'type': 'quiz'},
    {'type': 'quiz', 'passingScore': null},
  ]) {
    test('quiz threshold is required: $json', () {
      expect(
        () => LessonCompletion.fromJson(json),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('passingScore'),
          ),
        ),
      );
    });
  }

  for (final score in [-1, 0, 101, 80.0, '80', true, <int>[]]) {
    test('malformed threshold $score fails clearly', () {
      expect(
        () =>
            LessonCompletion.fromJson({'type': 'quiz', 'passingScore': score}),
        throwsA(isA<FormatException>()),
      );
    });
  }

  for (final json in ['quiz', 80, true, <String>[]]) {
    test('completion must be a JSON object: $json', () {
      expect(
        () => LessonCompletion.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });
  }

  test('direct construction enforces the same policy invariants', () {
    expect(
      () => LessonCompletion(type: 'unknown'),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => LessonCompletion(type: 'quiz'),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => LessonCompletion(type: 'quiz', passingScore: 0),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => LessonCompletion(type: 'lesson', passingScore: 101),
      throwsA(isA<FormatException>()),
    );
  });

  test('Lesson parser reports malformed completion metadata clearly', () {
    final json = <String, dynamic>{
      'id': 'test',
      'moduleId': 'test',
      'order': 1,
      'title': 'Test',
      'description': '',
      'estimatedMinutes': 1,
      'blocks': [],
      'completion': 'quiz',
    };
    expect(() => Lesson.fromJson(json), throwsA(isA<FormatException>()));
    json['completion'] = {'type': 'quiz'};
    expect(() => Lesson.fromJson(json), throwsA(isA<FormatException>()));
  });

  test('all 62 current assets keep their completion policies', () async {
    final course = CourseService();
    var ordinary = 0;
    var quizzes = 0;
    for (final item in await course.loadAllLessons()) {
      final content = await course.loadLesson(
        'assets/course/${item.module.id}/${item.lesson.file}',
      );
      if (content.completion.isQuiz) {
        quizzes++;
        expect(content.completion.passingScore, 80);
      } else {
        ordinary++;
        expect(content.completion.type, 'lesson');
        expect(content.completion.passingScore, isNull);
      }
    }
    expect(ordinary, 55);
    expect(quizzes, 7);
  });
}
