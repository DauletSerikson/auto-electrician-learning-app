import 'package:electrician/domain/lesson_attempt.dart';
import 'package:electrician/models/lesson.dart';
import 'package:electrician/models/lesson_block.dart';
import 'package:electrician/models/lesson_completion.dart';
import 'package:electrician/services/course_service.dart';
import 'package:flutter_test/flutter_test.dart';

Lesson lesson({int tasks = 0, int? threshold}) => Lesson(
  id: 'test',
  moduleId: 'test',
  order: 1,
  title: '',
  description: '',
  estimatedMinutes: 1,
  completion: LessonCompletion(
    type: threshold == null ? 'lesson' : 'quiz',
    passingScore: threshold,
  ),
  blocks: List.generate(
    tasks,
    (_) => const QuestionLessonBlock(
      question: '?',
      answers: ['a'],
      correctAnswer: 0,
      explanation: '',
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('zero task ordinary lesson can complete explicitly, score is zero', () {
    final result = evaluateLessonAttempt(lesson(), {});
    expect(result.totalTasks, 0);
    expect(result.answeredTasks, 0);
    expect(result.scorePercent, 0);
    expect(result.allAnswered, isTrue);
    expect(result.canComplete, isTrue);
  });

  for (final answer in [null, false, true]) {
    test('one task result $answer', () {
      final result = evaluateLessonAttempt(
        lesson(tasks: 1),
        answer == null ? <int, bool>{} : {0: answer},
      );
      expect(result.totalTasks, 1);
      expect(result.answeredTasks, answer == null ? 0 : 1);
      expect(result.correctTasks, answer == true ? 1 : 0);
      expect(result.canComplete, answer == true);
    });
  }

  test('multiple tasks and retry replace or remove current result without mutating snapshots', () {
    final content = lesson(tasks: 3);
    final answers = {0: true, 1: false};
    final before = evaluateLessonAttempt(content, answers);
    expect(before.canComplete, isFalse);
    answers[2] = true;
    expect(evaluateLessonAttempt(content, answers).canComplete, isFalse);
    answers.remove(1);
    expect(evaluateLessonAttempt(content, answers).answeredTasks, 2);
    answers[1] = true;
    expect(evaluateLessonAttempt(content, answers).canComplete, isTrue);
    expect(before.correctTasks, 1);
    expect(before.answeredTasks, 2);
  });

  test('quiz requires every answer even with a passing current score', () {
    final result = evaluateLessonAttempt(lesson(tasks: 5, threshold: 80), {
      0: true,
      1: true,
      2: true,
      3: true,
    });
    expect(result.scorePercent, 80);
    expect(result.allAnswered, isFalse);
    expect(result.canComplete, isFalse);
  });

  for (final boundary in [
    (5, 3, 60, false),
    (5, 4, 80, true),
    (5, 5, 100, true),
    (13, 10, 77, false),
    (13, 11, 85, true),
    (12, 9, 75, false),
    (12, 10, 83, true),
  ]) {
    test('quiz boundary ${boundary.$2}/${boundary.$1}', () {
      final result = evaluateLessonAttempt(
        lesson(tasks: boundary.$1, threshold: 80),
        {for (var i = 0; i < boundary.$1; i++) i: i < boundary.$2},
      );
      expect(result.scorePercent, boundary.$3);
      expect(result.canComplete, boundary.$4);
    });
  }

  test('rounding uses raw fraction and threshold compares rounded percent', () {
    final result = evaluateLessonAttempt(lesson(tasks: 6, threshold: 17), {
      for (var i = 0; i < 6; i++) i: i == 0,
    });
    expect(result.scoreFraction, 1 / 6);
    expect(result.scorePercent, 17);
    expect(result.canComplete, isTrue);
  });

  test('non-task and out-of-range callbacks cannot affect scored results', () {
    final content = lesson(tasks: 1);
    content.blocks.insert(0, const TextLessonBlock(title: '', content: ''));
    final result = evaluateLessonAttempt(content, {
      0: true,
      1: false,
      99: true,
    });
    expect(result.totalTasks, 1);
    expect(result.answeredTasks, 1);
    expect(result.correctTasks, 0);
    expect(result.canComplete, isFalse);
  });

  test('real content retains all task subtype classification and stage quiz counts', () async {
    final course = CourseService();
    final seen = <Type>{};
    final excluded = <Type>{};
    final quizCounts = <String, int>{};
    for (final item in await course.loadAllLessons()) {
      final content = await course.loadLesson(
        'assets/course/${item.module.id}/${item.lesson.file}',
      );
      final answers = <int, bool>{};
      for (var i = 0; i < content.blocks.length; i++) {
        final block = content.blocks[i];
        final expected =
            block is QuestionLessonBlock ||
            block is CalculationLessonBlock ||
            block is MeasurementLessonBlock ||
            block is VoltageDropLessonBlock ||
            block is CurrentMeasurementLessonBlock ||
            block is DiagnosticCaseLessonBlock ||
            block is DiagnosticChoiceLessonBlock;
        expect(isScoredLessonBlock(block), expected);
        (expected ? seen : excluded).add(block.runtimeType);
        if (expected) answers[i] = true;
      }
      final result = evaluateLessonAttempt(content, answers);
      expect(result.canComplete, isTrue);
      if (content.completion.isQuiz) {
        expect(result.passingScore, 80);
        quizCounts[item.module.id] = result.totalTasks;
      }
    }
    expect(quizCounts, {
      'stage_0': 5,
      'stage_1': 13,
      'stage_2': 12,
      'stage_3': 15,
      'stage_4': 15,
      'stage_5': 15,
      'stage_6': 15,
    });
    expect(
      seen,
      containsAll([
        QuestionLessonBlock,
        CalculationLessonBlock,
        BatteryVoltageMeasurementLessonBlock,
        WireResistanceMeasurementLessonBlock,
        WireContinuityMeasurementLessonBlock,
        ResistanceMeasurementLessonBlock,
        VoltageDropLessonBlock,
        CurrentMeasurementLessonBlock,
        DiagnosticCaseLessonBlock,
        DiagnosticChoiceLessonBlock,
      ]),
    );
    expect(excluded, containsAll([CircuitLessonBlock, MultimeterLessonBlock]));
  });
}
