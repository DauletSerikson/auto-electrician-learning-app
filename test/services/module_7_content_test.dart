import 'dart:io';

import 'package:electrician/domain/course_progress.dart';
import 'package:electrician/domain/lesson_attempt.dart';
import 'package:electrician/models/lesson.dart';
import 'package:electrician/models/lesson_block.dart';
import 'package:electrician/services/course_service.dart';
import 'package:electrician/services/progress_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Lesson> loadElectronics(int order) => CourseService().loadLesson(
  'assets/course/stage_6/lesson_${order.toString().padLeft(2, '0')}.json',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final course = CourseService();
  setUp(() {
    rootBundle.clear();
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'seven modules and all 62 lessons keep unique, consecutive ordering',
    () async {
      final modules = await course.loadModules();
      expect(modules.map((m) => m.id), List.generate(7, (i) => 'stage_$i'));
      expect(modules.map((m) => m.order), List.generate(7, (i) => i));
      expect(
        modules.last.title,
        'Автомобильная электроника и электронные системы управления',
      );
      final all = await course.loadAllLessons();
      expect(all, hasLength(62));
      expect(all.map((l) => l.lesson.id).toSet(), hasLength(62));
      final expectedCounts = [5, 8, 9, 10, 10, 10, 10];
      for (var i = 0; i < modules.length; i++) {
        final summaries = await course.loadLessons(modules[i].id);
        expect(summaries, hasLength(expectedCounts[i]));
        expect(
          summaries.map((s) => s.order),
          List.generate(expectedCounts[i], (n) => n + 1),
        );
      }
      expect(all.take(52).last.lesson.id, 'diagnostics_10');
      expect(
        all.skip(52).map((l) => l.lesson.id),
        List.generate(
          10,
          (i) => 'electronics_${(i + 1).toString().padLeft(2, '0')}',
        ),
      );
    },
  );

  test('every indexed electronics lesson parses, matches metadata and has bundled images', () async {
    var count = 0;
    var scored = 0;
    final usedAssets = <String>{};
    for (final summary in await course.loadLessons('stage_6')) {
      final lesson = await loadElectronics(summary.order);
      expect(lesson.id, summary.id);
      expect(lesson.moduleId, 'stage_6');
      expect(lesson.order, summary.order);
      expect(lesson.title, summary.title);
      expect(lesson.description, summary.description);
      expect(lesson.estimatedMinutes, summary.estimatedMinutes);
      expect(lesson.estimatedMinutes, inInclusiveRange(15, 30));
      expect(lesson.blocks.whereType<TextLessonBlock>(), isNotEmpty);
      expect(lesson.blocks.whereType<WarningLessonBlock>(), isNotEmpty);
      expect(lesson.blocks.last, isA<RememberLessonBlock>());
      expect(lesson.completion.type, summary.order == 10 ? 'quiz' : 'lesson');
      expect(lesson.completion.passingScore, summary.order == 10 ? 80 : isNull);
      for (var index = 0; index < lesson.blocks.length; index++) {
        final block = lesson.blocks[index];
        switch (block) {
          case ImageLessonBlock(:final asset, :final caption):
            expect(caption.trim(), isNotEmpty);
            expect(
              (await rootBundle.load(asset)).lengthInBytes,
              greaterThan(0),
            );
            usedAssets.add(asset);
            expect(
              lesson.blocks
                  .skip(index + 1)
                  .takeWhile((b) => b is! ImageLessonBlock)
                  .whereType<QuestionLessonBlock>(),
              isNotEmpty,
              reason: 'Each image requires an interpretation task: $asset',
            );
          case QuestionLessonBlock(
            :final answers,
            :final correctAnswer,
            :final explanation,
          ):
            expect(answers, hasLength(3));
            expect(answers.toSet(), hasLength(3));
            expect(correctAnswer, inInclusiveRange(0, 2));
            expect(explanation.trim(), isNotEmpty);
          case CalculationLessonBlock(
            :final correctValue,
            :final tolerance,
            :final hint,
            :final explanation,
          ):
            expect(correctValue.isFinite, isTrue);
            expect(correctValue, greaterThanOrEqualTo(0));
            expect(tolerance, greaterThan(0));
            expect(hint.trim(), isNotEmpty);
            expect(explanation.trim(), isNotEmpty);
          case TextLessonBlock(:final title, :final content):
            expect(title.trim(), isNotEmpty);
            expect(content.trim(), isNotEmpty);
          case WarningLessonBlock(:final content):
            expect(content.trim(), isNotEmpty);
          case RememberLessonBlock(:final content):
            expect(content.trim(), isNotEmpty);
          default:
            fail(
              'Electronic signals must not reuse fixed simulators: ${block.runtimeType}',
            );
        }
        if (isScoredLessonBlock(block)) scored++;
      }
      count += lesson.blocks.length;
    }
    expect(count, 167);
    expect(scored, 70);
    expect(usedAssets, hasLength(19));
    expect(
      usedAssets,
      Directory('assets/images/electronics')
          .listSync()
          .where((f) => f.path.endsWith('.png'))
          .map((f) => f.path.replaceAll('\\', '/'))
          .toSet(),
    );
  });

  test(
    'ordinary lessons require all scored answers, including every added lesson',
    () async {
      for (var order = 1; order <= 9; order++) {
        final lesson = await loadElectronics(order);
        final indices = [
          for (var i = 0; i < lesson.blocks.length; i++)
            if (isScoredLessonBlock(lesson.blocks[i])) i,
        ];
        expect(indices, isNotEmpty);
        final answers = {for (final i in indices) i: true};
        expect(evaluateLessonAttempt(lesson, {}).canComplete, isFalse);
        expect(evaluateLessonAttempt(lesson, answers).canComplete, isTrue);
        for (final index in indices) {
          answers[index] = false;
          expect(evaluateLessonAttempt(lesson, answers).canComplete, isFalse);
          answers.remove(index);
          expect(evaluateLessonAttempt(lesson, answers).canComplete, isFalse);
          answers[index] = true;
        }
      }
    },
  );

  test('real quiz has exactly 15 questions: 11 fail, 12 pass only when all answered', () async {
    final lesson = await loadElectronics(10);
    final indices = [
      for (var i = 0; i < lesson.blocks.length; i++)
        if (isScoredLessonBlock(lesson.blocks[i])) i,
    ];
    expect(lesson.blocks.whereType<QuestionLessonBlock>(), hasLength(15));
    expect(lesson.blocks.whereType<CalculationLessonBlock>(), isEmpty);
    expect(indices, hasLength(15));
    expect(lesson.completion.isQuiz, isTrue);
    expect(lesson.completion.passingScore, 80);
    final answers = {
      for (var n = 0; n < indices.length; n++) indices[n]: n < 11,
    };
    expect(evaluateLessonAttempt(lesson, answers).scorePercent, 73);
    expect(evaluateLessonAttempt(lesson, answers).canComplete, isFalse);
    answers[indices[11]] = true;
    expect(evaluateLessonAttempt(lesson, answers).scorePercent, 80);
    expect(evaluateLessonAttempt(lesson, answers).canComplete, isTrue);
    answers.remove(indices.last);
    expect(evaluateLessonAttempt(lesson, answers).canComplete, isFalse);
    answers[indices.last] = false;
    expect(evaluateLessonAttempt(lesson, answers).canComplete, isTrue);
  });

  test(
    'all 52 old completions survive expansion and persistence recreation',
    () async {
      final all = await course.loadAllLessons();
      final oldIds = all.take(52).map((l) => l.lesson.id).toSet();
      SharedPreferences.setMockInitialValues({
        'completed_lessons': [...oldIds, 'unknown_saved_id'],
      });
      final service = ProgressService();
      final before = await service.calculateProgress(all);
      expect(before.totalLessons, 62);
      expect(before.completedLessons, 52);
      expect(before.progress, 52 / 62);
      expect(before.nextLesson?.lesson.id, 'electronics_01');
      for (final id in oldIds) {
        expect(await service.isLessonCompleted(id), isTrue);
      }
      await service.completeLesson('electronics_01');
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final reloaded = ProgressService();
      expect(await reloaded.getCompletedLessons(), {
        ...oldIds,
        'unknown_saved_id',
        'electronics_01',
      });
      final after = await reloaded.calculateProgress(all);
      expect(after.completedLessons, 53);
      expect(after.nextLesson?.lesson.id, 'electronics_02');
      expect(prefs.getKeys(), {'completed_lessons'});
      final full = calculateCourseProgress(
        all,
        all.map((l) => l.lesson.id).toSet(),
      );
      expect(full.totalLessons, 62);
      expect(full.completedLessons, 62);
      expect(full.progress, 1);
      expect(full.nextLesson, isNull);
    },
  );

  test(
    'all eight calculations independently match declared physical models',
    () async {
      final expected = {
        3: [5 * 500 / (2000 + 500)],
        4: [1 / (5 / 1000), 100 * 8 / 10],
        5: [100 * (10 - 4) / 10],
        6: [5 - 0.2, 2.5 + 0.2],
        7: [3.5 - 1.5, 1 / (1 / 120 + 1 / 120)],
      };
      for (final entry in expected.entries) {
        final lesson = await loadElectronics(entry.key);
        final calculations = lesson.blocks
            .whereType<CalculationLessonBlock>()
            .toList();
        expect(calculations, hasLength(entry.value.length));
        for (var i = 0; i < calculations.length; i++) {
          expect(calculations[i].correctValue, closeTo(entry.value[i], 1e-9));
        }
      }
      for (final order in [1, 2, 8, 9, 10]) {
        expect(
          (await loadElectronics(order)).blocks
              .whereType<CalculationLessonBlock>(),
          isEmpty,
        );
      }
    },
  );

  test('diagnostic answers preserve uncertainty and require evidence before replacement', () async {
    final lesson = await loadElectronics(9);
    expect(
      lesson.blocks.whereType<QuestionLessonBlock>().map(
        (b) => b.answers[b.correctAnswer],
      ),
      [
        'Датчик реагирует у своего выхода; нужно различить провод/контакт и вход ЭБУ',
        'Обесточить по процедуре, отсоединить оба конца S и проверить изолированный путь',
        'Открыт проверенный путь; локализовать контакт/провод и повторить ON сигнал на обоих концах',
        'По разрешённой процедуре разделить ветви и наблюдать R–G, исключая внешнюю подачу напряжения',
        'Ветвь B влияет на просадку; нужно разделить датчик и её проводку',
        'Наблюдать форму S–G допустимым осциллографом при подтверждённых условиях',
        'Возврат и выбранные опорные точки; затем локализовать падение, не заменяя сразу датчик',
      ],
    );
    final cards = lesson.blocks
        .whereType<TextLessonBlock>()
        .map((b) => b.content)
        .join('\n');
    expect(cards, contains('Показание 0,5 V у ЭБУ — наблюдение'));
    expect(cards, contains('оба конца сигнального участка отсоединены'));
    expect(
      cards,
      contains('это не доказанный внутренний отказ'.replaceFirst('это', 'Это')),
    );
  });
}
