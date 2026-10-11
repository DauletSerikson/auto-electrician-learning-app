import 'package:electrician/domain/course_progress.dart';
import 'package:electrician/domain/lesson_attempt.dart';
import 'package:electrician/models/lesson_block.dart';
import 'package:electrician/services/course_service.dart';
import 'package:electrician/services/progress_service.dart';
import 'package:electrician/simulation/diagnostic_case_measurements.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final course = CourseService();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('module 5 keeps its position and its ten lessons have consecutive stable IDs', () async {
    final modules = await course.loadModules();
    expect(modules.map((m) => m.id), [
      'stage_0',
      'stage_1',
      'stage_2',
      'stage_3',
      'stage_4',
      'stage_5',
      'stage_6',
    ]);
    expect(modules[4].order, 4);
    expect(modules[4].title, 'Чтение автомобильных электрических схем');
    final summaries = await course.loadLessons('stage_4');
    expect(summaries.map((s) => s.order), List.generate(10, (i) => i + 1));
    expect(
      summaries.map((s) => s.id),
      List.generate(10, (i) => 'wiring_${(i + 1).toString().padLeft(2, '0')}'),
    );
    final all = await course.loadAllLessons();
    final previous = all
        .where((l) => l.module.order < 4)
        .map((l) => l.lesson.id)
        .toSet();
    final added = summaries.map((s) => s.id).toSet();
    expect(previous, hasLength(32));
    expect(added, hasLength(10));
    expect(previous.intersection(added), isEmpty);
    expect(all, hasLength(62));
  });

  test(
    'every new lesson parses with matching metadata and bundled references',
    () async {
      var count = 0;
      for (final summary in await course.loadLessons('stage_4')) {
        final lesson = await course.loadLesson(
          'assets/course/stage_4/${summary.file}',
        );
        expect(lesson.id, summary.id);
        expect(lesson.moduleId, 'stage_4');
        expect(lesson.order, summary.order);
        expect(lesson.title, summary.title);
        expect(lesson.description, summary.description);
        expect(lesson.estimatedMinutes, summary.estimatedMinutes);
        expect(lesson.description.trim(), isNotEmpty);
        expect(
          lesson.estimatedMinutes,
          summary.order == 10 ? 25 : inInclusiveRange(10, 20),
        );
        expect(lesson.blocks.whereType<TextLessonBlock>(), isNotEmpty);
        expect(lesson.blocks.whereType<WarningLessonBlock>(), isNotEmpty);
        expect(lesson.blocks.last, isA<RememberLessonBlock>());
        expect(lesson.blocks.where(isScoredLessonBlock), isNotEmpty);
        for (final block in lesson.blocks) {
          switch (block) {
            case ImageLessonBlock(:final asset):
              expect(
                (await rootBundle.load(asset)).lengthInBytes,
                greaterThan(0),
              );
            case QuestionLessonBlock(
              :final answers,
              :final correctAnswer,
              :final explanation,
            ):
              expect(answers, hasLength(3));
              expect(correctAnswer, inInclusiveRange(0, answers.length - 1));
              expect(explanation.trim(), isNotEmpty);
            default:
              break;
          }
        }
        count += lesson.blocks.length;
        expect(lesson.completion.type, summary.order == 10 ? 'quiz' : 'lesson');
        expect(
          lesson.completion.passingScore,
          summary.order == 10 ? 80 : isNull,
        );
      }
      expect(count, 138);
    },
  );

  test('ordinary new lessons require every scored task correct', () async {
    for (final summary in (await course.loadLessons('stage_4')).take(9)) {
      final lesson = await course.loadLesson(
        'assets/course/stage_4/${summary.file}',
      );
      final indices = [
        for (var i = 0; i < lesson.blocks.length; i++)
          if (isScoredLessonBlock(lesson.blocks[i])) i,
      ];
      final answers = {for (final i in indices) i: true};
      expect(evaluateLessonAttempt(lesson, {}).canComplete, isFalse);
      expect(evaluateLessonAttempt(lesson, answers).canComplete, isTrue);
      answers[indices.last] = false;
      expect(evaluateLessonAttempt(lesson, answers).canComplete, isFalse);
    }
  });

  test(
    'real final quiz rejects 11/15 and accepts 12/15 only with all answered',
    () async {
      final lesson = await course.loadLesson(
        'assets/course/stage_4/lesson_10.json',
      );
      final indices = [
        for (var i = 0; i < lesson.blocks.length; i++)
          if (isScoredLessonBlock(lesson.blocks[i])) i,
      ];
      expect(indices, hasLength(15));
      final answers = {
        for (var i = 0; i < indices.length; i++) indices[i]: i < 11,
      };
      expect(evaluateLessonAttempt(lesson, answers).canComplete, isFalse);
      answers[indices[11]] = true;
      final passed = evaluateLessonAttempt(lesson, answers);
      expect(passed.scorePercent, 80);
      expect(passed.canComplete, isTrue);
      answers.remove(indices.last);
      expect(evaluateLessonAttempt(lesson, answers).canComplete, isFalse);
      answers[indices.last] = false;
      expect(evaluateLessonAttempt(lesson, answers).canComplete, isTrue);
    },
  );

  test(
    'all 32 previous completions survive course expansion and new writes',
    () async {
      final all = await course.loadAllLessons();
      final oldIds = all.take(32).map((l) => l.lesson.id).toSet();
      SharedPreferences.setMockInitialValues({
        'completed_lessons': oldIds.toList(),
      });
      final service = ProgressService();
      final before = await service.calculateProgress(all);
      expect(before.completedLessons, 32);
      expect(before.totalLessons, 62);
      expect(before.progress, 32 / 62);
      expect(before.nextLesson?.lesson.id, 'wiring_01');
      for (final id in oldIds) {
        expect(await service.isLessonCompleted(id), isTrue);
      }
      await service.completeLesson('wiring_01');
      final reloaded = ProgressService();
      expect(await reloaded.getCompletedLessons(), {...oldIds, 'wiring_01'});
      final after = await reloaded.calculateProgress(all);
      expect(after.completedLessons, 33);
      expect(after.nextLesson?.lesson.id, 'wiring_02');
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      expect(prefs.getKeys(), {'completed_lessons'});
    },
  );

  test('all 62 completed yields full progress with no next lesson', () async {
    final all = await course.loadAllLessons();
    final progress = calculateCourseProgress(
      all,
      all.map((l) => l.lesson.id).toSet(),
    );
    expect(progress.totalLessons, 62);
    expect(progress.completedLessons, 62);
    expect(progress.progress, 1);
    expect(progress.nextLesson, isNull);
  });

  test(
    'only supported simulation topologies accompany matching diagrams',
    () async {
      final first = await course.loadLesson(
        'assets/course/stage_4/lesson_01.json',
      );
      expect(
        first.blocks.whereType<CircuitLessonBlock>().map((b) => b.circuitType),
        ['simpleLamp', 'twoLamps'],
      );
      final diagnostic = await course.loadLesson(
        'assets/course/stage_4/lesson_09.json',
      );
      final exercise = diagnostic.blocks
          .whereType<DiagnosticCaseLessonBlock>()
          .single;
      expect(exercise.faultType, 'positiveWireOpen');
      expect(exercise.sourceVoltage, 12.6);
      final loss = diagnostic.blocks.whereType<CalculationLessonBlock>().single;
      expect(loss.correctValue, closeTo(4 * 0.3, 0.00001));
      expect(loss.unit, 'V');
      for (final summary in await course.loadLessons('stage_4')) {
        final lesson = await course.loadLesson(
          'assets/course/stage_4/${summary.file}',
        );
        if (summary.order != 9) {
          expect(lesson.blocks.whereType<VoltageDropLessonBlock>(), isEmpty);
        } else {
          final drop = lesson.blocks.whereType<VoltageDropLessonBlock>().single;
          expect(drop.sourceVoltage, 12.6);
          expect(drop.faultVoltageDrop, 1.8);
          expect(drop.initiallyLoaded, isFalse);
        }
        expect(lesson.blocks.whereType<DiagnosticChoiceLessonBlock>(), isEmpty);
        if (summary.order != 1) {
          expect(lesson.blocks.whereType<CircuitLessonBlock>(), isEmpty);
        }
        if (summary.order != 9) {
          expect(lesson.blocks.whereType<DiagnosticCaseLessonBlock>(), isEmpty);
        }
      }
    },
  );

  test(
    'lesson 9 diagnosis needs powered boundaries and isolated continuity',
    () async {
      final lesson = await course.loadLesson(
        'assets/course/stage_4/lesson_09.json',
      );
      final block = lesson.blocks.whereType<DiagnosticCaseLessonBlock>().single;
      DiagnosticMeasurementRecord measure(DiagnosticTest test, bool powered) =>
          DiagnosticMeasurementRecord(
            test: test,
            powered: powered,
            result: DiagnosticCaseMeasurements(
              faultType: block.faultType,
              sourceVoltage: block.sourceVoltage,
              powered: powered,
            ).resultFor(test),
          );
      final evidence = [
        measure(DiagnosticTest.batteryVoltage, true),
        measure(DiagnosticTest.fuseOutputVoltage, true),
        measure(DiagnosticTest.lampPositiveVoltage, true),
      ];
      expect(
        hasPositiveWireOpenEvidence(evidence, block.sourceVoltage),
        isFalse,
      );
      evidence.add(measure(DiagnosticTest.wireContinuity, true));
      expect(evidence.last.result, isA<DiagnosticCaseForbidden>());
      expect(
        hasPositiveWireOpenEvidence(evidence, block.sourceVoltage),
        isFalse,
      );
      evidence.add(measure(DiagnosticTest.wireContinuity, false));
      expect(
        hasPositiveWireOpenEvidence(evidence, block.sourceVoltage),
        isTrue,
      );
      expect(evidence[1].powered, isTrue);
      expect((evidence[1].result as DiagnosticCaseVoltage).value, 12.6);
    },
  );

  test('each quiz task reads its immediately preceding diagram', () async {
    final quiz = await course.loadLesson(
      'assets/course/stage_4/lesson_10.json',
    );
    final referenced = <String>{};
    for (var i = 0; i < quiz.blocks.length; i++) {
      if (quiz.blocks[i] case QuestionLessonBlock(:final question)) {
        expect(quiz.blocks[i - 1], isA<ImageLessonBlock>());
        referenced.add((quiz.blocks[i - 1] as ImageLessonBlock).asset);
        expect(question.trim(), isNotEmpty);
      }
    }
    expect(referenced, hasLength(12));
    expect(
      referenced,
      containsAll([
        'assets/images/wiring/quiz_branches.png',
        'assets/images/wiring/quiz_connector.png',
      ]),
    );
  });
}
