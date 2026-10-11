import 'dart:io';

import 'package:electrician/domain/lesson_attempt.dart';
import 'package:electrician/models/lesson.dart';
import 'package:electrician/models/lesson_block.dart';
import 'package:electrician/services/course_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Lesson> loadPilot(int order) => CourseService().loadLesson(
  'assets/course/stage_6/lesson_${order.toString().padLeft(2, '0')}.json',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(rootBundle.clear);

  test(
    'approved pilot slices are indexed exactly once in the full module',
    () async {
      final course = CourseService();
      expect(await course.loadModules(), hasLength(7));
      expect(await course.loadAllLessons(), hasLength(62));
      final summaries = await course.loadLessons('stage_6');
      for (final order in [3, 4, 6]) {
        final matches = summaries.where((s) => s.order == order).toList();
        expect(matches, hasLength(1));
        expect(
          matches.single.id,
          'electronics_${order.toString().padLeft(2, '0')}',
        );
        expect(
          matches.single.file,
          'lesson_${order.toString().padLeft(2, '0')}.json',
        );
      }
      expect(
        Directory('assets/course/stage_6').listSync().where(
          (f) =>
              f.path.split(Platform.pathSeparator).last.startsWith('lesson_'),
        ),
        hasLength(10),
      );
      expect(File('assets/course/stage_6/lessons.json').existsSync(), isTrue);
    },
  );

  for (final entry in {3: (19, 7), 4: (22, 8), 6: (20, 9)}.entries) {
    test(
      'real pilot lesson ${entry.key} has complete typed content and scoring',
      () async {
        final lesson = await loadPilot(entry.key);
        expect(
          lesson.id,
          'electronics_${entry.key.toString().padLeft(2, '0')}',
        );
        expect(lesson.moduleId, 'stage_6');
        expect(lesson.order, entry.key);
        expect(lesson.completion.isQuiz, isFalse);
        expect(lesson.blocks, hasLength(entry.value.$1));
        final answers = <int, bool>{};
        for (var i = 0; i < lesson.blocks.length; i++) {
          final block = lesson.blocks[i];
          switch (block) {
            case TextLessonBlock(:final title, :final content):
              expect(title.trim(), isNotEmpty);
              expect(content.trim(), isNotEmpty);
            case RememberLessonBlock(:final content):
              expect(content.trim(), isNotEmpty);
            case WarningLessonBlock(:final content):
              expect(content.trim(), isNotEmpty);
            case ImageLessonBlock(:final asset, :final caption):
              expect(caption.trim(), isNotEmpty);
              expect(
                (await rootBundle.load(asset)).lengthInBytes,
                greaterThan(0),
              );
              expect(
                lesson.blocks
                    .skip(i + 1)
                    .takeWhile((next) => next is! ImageLessonBlock)
                    .whereType<QuestionLessonBlock>(),
                isNotEmpty,
                reason: 'The image must support a reading decision: $asset',
              );
            case QuestionLessonBlock(
              :final answers,
              :final correctAnswer,
              :final explanation,
            ):
              expect(answers.toSet(), hasLength(answers.length));
              expect(correctAnswer, inInclusiveRange(0, answers.length - 1));
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
            default:
              fail(
                'Pilot must not repurpose a simulator: ${block.runtimeType}',
              );
          }
          if (isScoredLessonBlock(block)) answers[i] = true;
        }
        expect(answers, hasLength(entry.value.$2));
        expect(evaluateLessonAttempt(lesson, {}).canComplete, isFalse);
        expect(evaluateLessonAttempt(lesson, answers).canComplete, isTrue);
        answers[answers.keys.first] = false;
        expect(evaluateLessonAttempt(lesson, answers).canComplete, isFalse);
        answers.remove(answers.keys.first);
        expect(evaluateLessonAttempt(lesson, answers).canComplete, isFalse);
      },
    );
  }

  test(
    'lesson calculations match independent circuit and timing balances',
    () async {
      final expected = {
        3: [5 * 500 / (2000 + 500)],
        4: [1 / (5 / 1000), 100 * 8 / 10],
        6: [5 - 0.2, 2.5 + 0.2],
      };
      for (final entry in expected.entries) {
        final lesson = await loadPilot(entry.key);
        final tasks = lesson.blocks
            .whereType<CalculationLessonBlock>()
            .toList();
        expect(tasks, hasLength(entry.value.length));
        for (var i = 0; i < tasks.length; i++) {
          expect(tasks[i].correctValue, closeTo(entry.value[i], 1e-9));
        }
      }
    },
  );

  test(
    'interpretation tasks select the evidence-limited technical conclusions',
    () async {
      final expected = {
        3: [
          'Сопротивление NTC и напряжение S–G уменьшаются',
          'Нет: открытый путь NTC/контакта может дать те же 5 V; нужно разделить гипотезы',
          'Изменение с 0,5 до 2,5 V',
          'Только число контактов: тип, питание и назначение выводов нужно уточнить',
          'Rp подтягивает S к 5 V, когда ключ не соединяет S с G',
          'Наблюдать сигнал между A/B и учитывать влияние скорости и зазора',
        ],
        4: [
          'Они имеют одинаковые 2,5 V по заданной характеристике, но разные горизонтальные оси',
          'Вход высокий; открытый контакт и обрыв пути к G пока могут давать одинаковое наблюдение',
          'Контакт замкнут и тянет S к G; это активное low состояние',
          'Период уменьшился вдвое, частота удвоилась, уровни остались 0/5 V',
          'D=20%, Q=5, f=100 Hz',
          'Форма не установлена; нужно наблюдение во времени при известном состоянии',
        ],
        6: [
          'Нет: reference и бортовое питание различаются; внешнее питание допустимо только по специальной процедуре',
          'Красный R, чёрный G',
          'Нет: без рабочей нагрузки не проверено падение на участке возврата',
          'Опоры различаются; нужно локализовать рабочее падение на возврате, учитывая общий ток и соединения',
          'По процедуре разделить и проверить питающий путь/контакты, исключая замыкание ветви',
          'Однозначное значение назначить нельзя; нужно уточнить схему и измерить разрешёнными точками',
          'Проверить связь концов S и вход ЭБУ; одного наблюдения ещё недостаточно для окончательной локализации',
        ],
      };
      for (final entry in expected.entries) {
        final lesson = await loadPilot(entry.key);
        expect(
          lesson.blocks.whereType<QuestionLessonBlock>().map(
            (block) => block.answers[block.correctAnswer],
          ),
          entry.value,
        );
      }
    },
  );
}
