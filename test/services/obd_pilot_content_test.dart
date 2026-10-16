import 'dart:io';

import 'package:electrician/domain/lesson_attempt.dart';
import 'package:electrician/models/lesson.dart';
import 'package:electrician/models/lesson_block.dart';
import 'package:electrician/services/course_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Lesson> loadObdPilot(int order) => CourseService().loadLesson(
  'assets/course/stage_7/lesson_${order.toString().padLeft(2, '0')}.json',
);

String textOf(Lesson lesson) => lesson.blocks
    .whereType<TextLessonBlock>()
    .map((b) => '${b.title}\n${b.content}')
    .join('\n');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(rootBundle.clear);

  test(
    'four preserved pilots are indexed exactly once in the full module',
    () async {
      final course = CourseService();
      expect(await course.loadModules(), hasLength(8));
      final old = await course.loadAllLessons();
      expect(old, hasLength(72));
      final ids = old.map((e) => e.lesson.id).toSet();
      for (final order in [4, 6, 7, 9]) {
        final id = (await loadObdPilot(order)).id;
        expect(old.where((e) => e.lesson.id == id), hasLength(1));
      }
      expect(ids, hasLength(72));
      final files = Directory('assets/course/stage_7')
          .listSync()
          .map((e) => e.path.split(Platform.pathSeparator).last)
          .toSet();
      expect(files, {
        'lessons.json',
        for (var n = 1; n <= 10; n++)
          'lesson_${n.toString().padLeft(2, '0')}.json',
      });
    },
  );

  for (final entry in {
    4: (16, 6),
    6: (13, 3),
    7: (18, 6),
    9: (22, 7),
  }.entries) {
    test('pilot ${entry.key} parses typed blocks and retains completion rules', () async {
      final lesson = await loadObdPilot(entry.key);
      expect(lesson.id, 'obd_${entry.key.toString().padLeft(2, '0')}');
      expect(lesson.moduleId, 'stage_7');
      expect(lesson.order, entry.key);
      expect(lesson.completion.isQuiz, isFalse);
      expect(lesson.blocks, hasLength(entry.value.$1));
      final answers = <int, bool>{};
      for (var i = 0; i < lesson.blocks.length; i++) {
        final block = lesson.blocks[i];
        switch (block) {
          case TextLessonBlock() ||
              RememberLessonBlock() ||
              WarningLessonBlock():
            break;
          case ImageLessonBlock(:final asset):
            expect(File(asset).existsSync(), isTrue);
            expect(
              File(
                asset
                    .replaceFirst('/obd/', '/obd/source/')
                    .replaceFirst('.png', '.svg'),
              ).existsSync(),
              isTrue,
            );
          case QuestionLessonBlock(
            :final answers,
            :final correctAnswer,
            :final explanation,
          ):
            expect(answers.toSet(), hasLength(answers.length));
            expect(correctAnswer, inInclusiveRange(0, answers.length - 1));
            expect(explanation.trim(), isNotEmpty);
          case CalculationLessonBlock(:final unit, :final correctValue):
            expect(unit, 'rpm');
            expect(correctValue, (256 * 12 + 128) / 4);
          default:
            fail(
              'OBD must not reuse electrical simulators: ${block.runtimeType}',
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
    });
  }

  test('DTC descriptions retain reviewed meanings and source boundaries', () async {
    final text = textOf(await loadObdPilot(4));
    for (final definition in {
      'P0300': 'случайные/множественные пропуски сгорания',
      'P0171': 'слишком бедная смесь, bank 1',
      'P0102': 'низкий входной сигнал цепи MAF',
      'P0562': 'низкое напряжение системы',
      'U0100': 'потеря связи с модулем управления двигателем',
    }.entries) {
      final block = (await loadObdPilot(4)).blocks
          .whereType<TextLessonBlock>()
          .singleWhere((b) => b.title.startsWith(definition.key));
      expect(block.content, contains(definition.value));
      expect(block.content, contains('Источник'));
      expect(block.content, contains('Синтетический'));
    }
    expect(
      text,
      contains(
        'P — силовой агрегат; B — кузов; C — шасси; U — сетевое взаимодействие',
      ),
    );
    expect(text, contains('manufacturer-controlled'));
    expect(text, contains('непосредственно не проверены'));
  });

  test(
    'FF-A is identical in lessons 6 and 9 and all frames have context',
    () async {
      String frame(Lesson l, String title) => l.blocks
          .whereType<TextLessonBlock>()
          .singleWhere((b) => b.title == title)
          .content;
      final six = await loadObdPilot(6);
      final a = frame(six, 'Полная запись FF-A');
      expect(frame(await loadObdPilot(9), 'K1 • Freeze Frame'), a);
      for (final pair in {
        'A': [
          'P0102',
          '88 °C',
          '800 rpm',
          '0 km/h',
          '22%',
          '14,180 V',
          '36 kPa',
        ],
        'B': [
          'P0171',
          '90 °C',
          '780 rpm',
          '0 km/h',
          '24%',
          '14,200 V',
          '42 kPa',
          '+18,8%',
          '+12,5%',
        ],
        'C': [
          'P0562',
          '90 °C',
          '750 rpm',
          '0 km/h',
          '35%',
          '10,800 V',
          '40 kPa',
        ],
      }.entries) {
        final value = frame(six, 'Полная запись FF-${pair.key}');
        for (final token in [
          ...pair.value,
          'Синтетический',
          'стоянка',
          'clock timestamp неизвестен',
        ]) {
          expect(value, contains(token));
        }
      }
    },
  );

  test(
    'Live Data distinguishes regimes, substitution, timing and units',
    () async {
      final seven = await loadObdPilot(7);
      final text = textOf(seven);
      for (final token in [
        '0…2 s',
        '30…32 s',
        '800 rpm',
        '2500 rpm',
        '24%',
        '18%',
        '2,80 g/s',
        '8,20 g/s',
        '+18,8%',
        '+3,1%',
        'MAP, абсолютное kPa',
        'поддержаны именно этим интерфейсом',
        'не момент измерения внутри ECU',
      ]) {
        expect(text, contains(token));
      }
      final ld = seven.blocks
          .whereType<TextLessonBlock>()
          .singleWhere((b) => b.title.startsWith('LD-C'))
          .content;
      expect(textOf(await loadObdPilot(9)), contains(ld));
      expect(text, contains('Это не требование SAE'));
      expect(text, contains('STFT/LTFT недоступны'));
    },
  );

  test(
    'P0102 requires independent path evidence and limits the conclusion',
    () async {
      final nine = await loadObdPilot(9);
      final text = textOf(nine);
      final voltage = text.indexOf('B+/B− = 14,20 V');
      final isolation = text.indexOf('сопротивление более 1 MΩ');
      final conclusion = text.indexOf('По совокупности данных вероятный');
      expect(voltage, greaterThan(0));
      expect(isolation, greaterThan(voltage));
      expect(conclusion, greaterThan(isolation));
      for (final token in [
        'S/G = 1,40 V',
        'E/G = 0,10 V',
        'G/B− = +0,03 V',
        '14,12 V',
        'Датчик и ECU отсоединены',
        'параллельных путей нет',
        'включает оконцевания',
        'не доказательство единственной неисправности',
        'Ремонт и его результаты ещё не представлены',
      ]) {
        expect(text, contains(token));
      }
      expect(14.15 - .03, closeTo(14.12, 1e-9));
      expect(1.4 - .1, closeTo(1.3, 1e-9));
      final correct = nine.blocks
          .whereType<QuestionLessonBlock>()
          .map((q) => q.answers[q.correctAnswer])
          .join('\n');
      expect(
        correct,
        contains(
          'W между X1/X2 вместе с оконцеваниями; точную точку ещё нужно найти',
        ),
      );
      expect(correct, contains('Ожидаемый S, низкий E и плохая проводимость'));
      expect(
        nine.blocks.whereType<WarningLessonBlock>().single.content,
        contains('программной блокировки'),
      );
    },
  );

  test('plotted coordinates independently match LD-A/B window summaries', () {
    final svg = File('assets/images/obd/source/live_graphs.svg')
        .readAsStringSync();
    for (final expected in {
      'rpmA': (1.0, 800.0, 120.0, 3000.0),
      'rpmB': (31.0, 2500.0, 120.0, 3000.0),
      'stftA': (1.0, 18.8, 400.0, 25.0),
      'stftB': (31.0, 3.1, 400.0, 25.0),
    }.entries) {
      final match = RegExp(
        '<circle cx="([^"]+)" cy="([^"]+)"[^>]+id="${expected.key}"',
      ).firstMatch(svg)!;
      final x = double.parse(match[1]!);
      final y = double.parse(match[2]!);
      expect((x - 62) * 32 / 232, closeTo(expected.value.$1, 1e-9));
      expect(
        (expected.value.$3 + 140 - y) * expected.value.$4 / 140,
        closeTo(expected.value.$2, 1e-9),
      );
    }
    expect(svg, isNot(contains('<polyline')));
    expect(svg, contains('Между окнами данных нет.'));
  });
}
