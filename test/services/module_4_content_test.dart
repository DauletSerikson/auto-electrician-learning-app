import 'package:electrician/domain/course_progress.dart';
import 'package:electrician/domain/lesson_attempt.dart';
import 'package:electrician/models/lesson_block.dart';
import 'package:electrician/services/course_service.dart';
import 'package:electrician/services/progress_service.dart';
import 'package:electrician/simulation/voltage_drop_simulation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final course = CourseService();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'module 4 is last and its ten lessons have consecutive stable IDs',
    () async {
      final modules = await course.loadModules();
      expect(modules.map((m) => m.id), [
        'stage_0',
        'stage_1',
        'stage_2',
        'stage_3',
      ]);
      expect(modules.last.order, 3);
      expect(modules.last.title, 'Электрооборудование автомобиля');
      final summaries = await course.loadLessons('stage_3');
      expect(summaries.map((s) => s.order), List.generate(10, (i) => i + 1));
      expect(
        summaries.map((s) => s.id),
        List.generate(
          10,
          (i) => 'vehicle_${(i + 1).toString().padLeft(2, '0')}',
        ),
      );
      final all = await course.loadAllLessons();
      final previous = all
          .where((l) => l.module.id != 'stage_3')
          .map((l) => l.lesson.id)
          .toSet();
      final added = summaries.map((s) => s.id).toSet();
      expect(previous, hasLength(22));
      expect(added, hasLength(10));
      expect(previous.intersection(added), isEmpty);
      expect(all, hasLength(32));
    },
  );

  test(
    'every new lesson parses with matching metadata and bundled references',
    () async {
      var count = 0;
      for (final summary in await course.loadLessons('stage_3')) {
        final lesson = await course.loadLesson(
          'assets/course/stage_3/${summary.file}',
        );
        expect(lesson.id, summary.id);
        expect(lesson.moduleId, 'stage_3');
        expect(lesson.order, summary.order);
        expect(lesson.title, summary.title);
        expect(lesson.description, summary.description);
        expect(lesson.estimatedMinutes, summary.estimatedMinutes);
        expect(lesson.description.trim(), isNotEmpty);
        expect(lesson.estimatedMinutes, inInclusiveRange(10, 20));
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
      expect(count, 110);
    },
  );

  test('ordinary new lessons require every scored task correct', () async {
    for (final summary in (await course.loadLessons('stage_3')).take(9)) {
      final lesson = await course.loadLesson(
        'assets/course/stage_3/${summary.file}',
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
        'assets/course/stage_3/lesson_10.json',
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
    'all 22 previous completions survive course expansion and new writes',
    () async {
      final all = await course.loadAllLessons();
      final oldIds = all.take(22).map((l) => l.lesson.id).toSet();
      SharedPreferences.setMockInitialValues({
        'completed_lessons': oldIds.toList(),
      });
      final service = ProgressService();
      final before = await service.calculateProgress(all);
      expect(before.completedLessons, 22);
      expect(before.totalLessons, 32);
      expect(before.progress, 22 / 32);
      expect(before.nextLesson?.lesson.id, 'vehicle_01');
      for (final id in oldIds) {
        expect(await service.isLessonCompleted(id), isTrue);
      }
      await service.completeLesson('vehicle_01');
      final reloaded = ProgressService();
      expect(await reloaded.getCompletedLessons(), {...oldIds, 'vehicle_01'});
      final after = await reloaded.calculateProgress(all);
      expect(after.completedLessons, 23);
      expect(after.nextLesson?.lesson.id, 'vehicle_02');
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      expect(prefs.getKeys(), {'completed_lessons'});
    },
  );

  test('all 32 completed yields full progress with no next lesson', () async {
    final all = await course.loadAllLessons();
    final progress = calculateCourseProgress(
      all,
      all.map((l) => l.lesson.id).toSet(),
    );
    expect(progress.totalLessons, 32);
    expect(progress.completedLessons, 32);
    expect(progress.progress, 1);
    expect(progress.nextLesson, isNull);
  });

  test(
    'new voltage drop exercise keeps its positive-path topology and load rule',
    () async {
      final lesson = await course.loadLesson(
        'assets/course/stage_3/lesson_07.json',
      );
      final block = lesson.blocks.whereType<VoltageDropLessonBlock>().single;
      final loaded = VoltageDropSimulation(
        sourceVoltage: block.sourceVoltage,
        faultVoltageDrop: block.faultVoltageDrop,
        loadOn: true,
        redPoint: VoltageDropPoint.batteryPositive,
        blackPoint: VoltageDropPoint.afterFault,
      );
      final unloaded = VoltageDropSimulation(
        sourceVoltage: block.sourceVoltage,
        faultVoltageDrop: block.faultVoltageDrop,
        loadOn: block.initiallyLoaded,
        redPoint: VoltageDropPoint.batteryPositive,
        blackPoint: VoltageDropPoint.afterFault,
      );
      expect(loaded.meterReading, closeTo(2.4, 0.00001));
      expect(
        loaded.potentialAt(VoltageDropPoint.afterFault),
        closeTo(10.2, 0.00001),
      );
      expect(loaded.potentialAt(VoltageDropPoint.ground), 0);
      expect(loaded.correctSetup, isTrue);
      expect(unloaded.meterReading, 0);
      expect(unloaded.correctSetup, isFalse);
    },
  );
}
