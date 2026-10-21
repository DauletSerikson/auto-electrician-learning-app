import 'dart:io';

import 'package:electrician/domain/lesson_attempt.dart';
import 'package:electrician/models/lesson.dart';
import 'package:electrician/models/lesson_block.dart';
import 'package:electrician/services/course_service.dart';
import 'package:electrician/services/progress_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Lesson> loadWiringRepair(int n) => CourseService().loadLesson(
  'assets/course/stage_9/lesson_${n.toString().padLeft(2, '0')}.json',
);

String section(Lesson lesson, String title) => lesson.blocks
    .whereType<TextLessonBlock>()
    .singleWhere((b) => b.title == title)
    .content;

double number(String text, String pattern) {
  final matches = RegExp(pattern).allMatches(text).toList();
  expect(matches, hasLength(1), reason: pattern);
  return double.parse(matches.single.group(1)!.replaceAll(',', '.'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final course = CourseService();
  setUp(() {
    rootBundle.clear();
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'twelve modules and 112 ordered unique lessons retain the old prefix',
    () async {
      final modules = await course.loadModules();
      expect(modules.map((m) => m.id), List.generate(12, (i) => 'stage_$i'));
      expect(modules.map((m) => m.order), List.generate(12, (i) => i));
      final all = await course.loadAllLessons();
      expect(all, hasLength(112));
      expect(all.map((e) => e.lesson.id).toSet(), hasLength(112));
      expect(all.take(82).last.lesson.id, 'starting_charging_10');
      expect(
        all.skip(82).take(10).map((e) => e.lesson.id),
        List.generate(
          10,
          (i) => 'wiring_repair_${(i + 1).toString().padLeft(2, '0')}',
        ),
      );
    },
  );

  test(
    'all ten real lessons parse metadata, static typed blocks and images',
    () async {
      final summaries = await course.loadLessons('stage_9');
      expect(summaries, hasLength(10));
      final images = <String>{};
      var blocks = 0;
      var tasks = 0;
      var calculations = 0;
      for (final s in summaries) {
        final lesson = await loadWiringRepair(s.order);
        expect(lesson.id, s.id);
        expect(lesson.moduleId, 'stage_9');
        expect(lesson.order, s.order);
        expect(lesson.title, s.title);
        expect(lesson.description, s.description);
        expect(lesson.estimatedMinutes, s.estimatedMinutes);
        expect(lesson.completion.isQuiz, s.order == 10);
        expect(lesson.completion.passingScore, s.order == 10 ? 80 : null);
        blocks += lesson.blocks.length;
        tasks += lesson.blocks.where(isScoredLessonBlock).length;
        for (final b in lesson.blocks) {
          expect(
            b.type,
            isIn([
              'text',
              'image',
              'question',
              'calculation',
              'warning',
              'remember',
            ]),
          );
          if (b case QuestionLessonBlock(
            :final answers,
            :final correctAnswer,
            :final explanation,
          )) {
            expect(answers.toSet(), hasLength(answers.length));
            expect(correctAnswer, inInclusiveRange(0, answers.length - 1));
            expect(explanation, isNotEmpty);
          }
          if (b case CalculationLessonBlock(
            :final correctValue,
            :final tolerance,
            :final unit,
          )) {
            calculations++;
            expect(correctValue, greaterThanOrEqualTo(0));
            expect(tolerance, greaterThan(0));
            expect(unit, isNotEmpty);
          }
          if (b case ImageLessonBlock(:final asset)) {
            images.add(asset);
            expect(
              (await rootBundle.load(asset)).lengthInBytes,
              greaterThan(0),
            );
          }
        }
      }
      expect(blocks, 150);
      expect(tasks, 67);
      expect(calculations, 7);
      expect(images, hasLength(15));
    },
  );

  test(
    'real final has 15 tasks, 11 fail, 12 pass, missing answer blocks',
    () async {
      final quiz = await loadWiringRepair(10);
      expect(quiz.blocks.whereType<QuestionLessonBlock>(), hasLength(13));
      expect(quiz.blocks.whereType<CalculationLessonBlock>(), hasLength(2));
      final indices = [
        for (var i = 0; i < quiz.blocks.length; i++)
          if (isScoredLessonBlock(quiz.blocks[i])) i,
      ];
      expect(indices, hasLength(15));
      final answers = {for (var i = 0; i < 15; i++) indices[i]: i < 11};
      expect(evaluateLessonAttempt(quiz, answers).scorePercent, 73);
      expect(evaluateLessonAttempt(quiz, answers).canComplete, isFalse);
      answers[indices[11]] = true;
      expect(evaluateLessonAttempt(quiz, answers).scorePercent, 80);
      expect(evaluateLessonAttempt(quiz, answers).canComplete, isTrue);
      answers.remove(indices.last);
      expect(evaluateLessonAttempt(quiz, answers).canComplete, isFalse);
    },
  );

  test(
    '82 previous IDs and unknown ID survive new completion and reload',
    () async {
      final all = await course.loadAllLessons();
      final oldIds = all.take(82).map((e) => e.lesson.id).toSet();
      expect(oldIds, hasLength(82));
      SharedPreferences.setMockInitialValues({
        'completed_lessons': [...oldIds, 'orphan_id'],
      });
      final before = await ProgressService().calculateProgress(all);
      expect(before.completedLessons, 82);
      expect(before.totalLessons, 112);
      expect(before.progress, 82 / 112);
      expect(before.nextLesson?.lesson.id, 'wiring_repair_01');
      await ProgressService().completeLesson('wiring_repair_01');
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      expect(await ProgressService().getCompletedLessons(), {
        ...oldIds,
        'orphan_id',
        'wiring_repair_01',
      });
      final after = await ProgressService().calculateProgress(all);
      expect(after.completedLessons, 83);
      expect(after.progress, 83 / 112);
      expect(after.nextLesson?.lesson.id, 'wiring_repair_02');
      expect(prefs.getKeys(), {'completed_lessons'});
    },
  );

  test(
    'W03 geometry, units, potentials, power and all calculation answers agree',
    () async {
      final lesson = await loadWiringRepair(2);
      final tasks = lesson.blocks.whereType<CalculationLessonBlock>().toList();
      final input = tasks.first.question;
      final rho = number(input, r'ρ=([\d,]+) Ω·mm²/m');
      final length = number(input, r'по ([\d,]+) m');
      final area = number(input, r'A=([\d,]+) mm²');
      final current = number(input, r'ток ([\d,]+) A');
      final source = number(input, r'Источник ([\d,]+) V');
      final resistance = rho * 2 * length / area;
      final drop = resistance * current;
      final power = drop * current;
      for (final (task, expected) in [
        (tasks[0], resistance),
        (tasks[1], drop),
        (tasks[2], power),
      ]) {
        expect(task.correctValue, closeTo(expected, 1e-10));
        expect(task.tolerance, lessThan(expected / 20));
      }
      final card = section(lesson, 'Проверим рабочую точку');
      final p = number(card, r'P=([\d,]+) V');
      final q = number(card, r'Q=([\d,]+) V');
      final t = number(card, r'T=([\d,]+) V');
      final n = number(card, r'N=([\d,]+) V');
      expect(p - q + t - n, closeTo(drop, 1e-10));
      expect(q - t, closeTo(source - drop, 1e-10));
      final load = number(card, r'R=([\d,]+) Ω');
      expect(source / (load + resistance), closeTo(current, 1e-10));
      expect(
        source * current,
        closeTo(current * current * load + power, 1e-10),
      );
      final finalTasks = (await loadWiringRepair(10)).blocks
          .whereType<CalculationLessonBlock>()
          .toList();
      expect(finalTasks[0].correctValue, closeTo(resistance, 1e-10));
      expect(finalTasks[1].correctValue, 4 * 4 * .25);
    },
  );

  for (final name in [
    'C1 • тусклая фара',
    'C3 • влага и коррозия',
    'C5 • перегрев splice',
  ]) {
    test(
      '$name recomputes current, KVL and power before and after repair',
      () async {
        final lesson = await loadWiringRepair(9);
        final input = section(lesson, '$name • условия');
        final measured = section(lesson, '$name • измерения');
        final repaired = section(lesson, '$name • после ремонта');
        final isC1 = name.startsWith('C1');
        final isC3 = name.startsWith('C3');
        final source = number(
          input,
          isC3
              ? r'P\(\+([\d,]+) V'
              : isC1
              ? r'P\(\+([\d,]+) V'
              : r'Us=([\d,]+) V',
        );
        final rw = isC3 ? 0.0 : number(input, r'Rwire=([\d,]+) Ω');
        final rc = number(
          input,
          isC1
              ? r'X1=([\d,]+) Ω'
              : isC3
              ? r'X3 ([\d,]+) Ω'
              : r'заданный R=([\d,]+) Ω',
        );
        final rl = number(
          input,
          isC3
              ? r'Rload ([\d,]+) Ω'
              : isC1
              ? r'Rload=([\d,]+) Ω'
              : r'R нагрузки=([\d,]+) Ω',
        );
        final current = number(input, r'I=([\d,]+) A');
        expect(current, closeTo(source / (rw + rc + rl), 1e-10));
        final contactDropPattern = isC1
            ? r'U\(B,C\)=([\d,]+) V'
            : isC3
            ? r'; T–N=([\d,]+) V'
            : r'U\(A,B\)=([\d,]+) V';
        final loadDropPattern = isC1
            ? r'U\(C,D\)=([\d,]+) V'
            : isC3
            ? r'A–T=([\d,]+) V'
            : r'B–N=([\d,]+) V';
        final uc = number(measured, contactDropPattern);
        final ul = number(measured, loadDropPattern);
        expect(uc, closeTo(current * rc, 1e-10));
        expect(ul, closeTo(current * rl, 1e-10));
        expect(current * rw + uc + ul, closeTo(source, 1e-10));
        expect(
          number(measured, r'Pcontact=([\d,]+) W'),
          closeTo(current * uc, 1e-10),
        );
        expect(
          number(measured, r'Pload=([\d,]+) W'),
          closeTo(current * ul, 1e-10),
        );
        expect(
          source * current,
          closeTo(current * current * rw + current * uc + current * ul, 1e-10),
        );
        final newRc = number(repaired, r'Rcontact=([\d,]+) Ω');
        final newCurrent = number(repaired, r'I=([\d,]+) A');
        final expectedCurrent = source / (rw + newRc + rl);
        expect(newCurrent, closeTo(expectedCurrent, 1e-6));
        expect(newCurrent, greaterThan(current));
        expect(
          number(repaired, r'Pcontact=([\d,]+) W'),
          closeTo(expectedCurrent * expectedCurrent * newRc, 1e-6),
        );
        final pc = number(repaired, r'Pcontact=([\d,]+) W');
        final pl = number(repaired, r'Pload=([\d,]+) W');
        final pw = isC3 ? 0.0 : number(repaired, r'Pwire=([\d,]+) W');
        expect(pl, closeTo(expectedCurrent * expectedCurrent * rl, 1e-6));
        expect(pw, closeTo(expectedCurrent * expectedCurrent * rw, 1e-6));
        expect(
          number(repaired, r'Psource=([\d,]+) W'),
          closeTo(pc + pl + pw, 2e-6),
        );
        final dropAfter = number(
          repaired,
          isC1
              ? r'U\(B,C\)=([\d,]+) V'
              : isC3
              ? r'U\(T,N\)=([\d,]+) V'
              : r'U\(A,B\)=([\d,]+) V',
        );
        expect(dropAfter, closeTo(expectedCurrent * newRc, 1e-6));
        expect(dropAfter, lessThan(uc));
      },
    );
  }

  test(
    'actual node potentials agree with probe order and reverse polarity',
    () async {
      final lesson = await loadWiringRepair(9);
      final card = section(lesson, 'C1 • тусклая фара • измерения');
      final b = number(card, r'B=([\d,]+) V');
      final c = number(card, r'C=([\d,]+) V');
      expect(b - c, closeTo(number(card, r'U\(B,C\)=([\d,]+) V'), 1e-10));
      expect(c - b, closeTo(-2.20, 1e-10));
      final card5 = section(lesson, 'C5 • перегрев splice • измерения');
      final a = number(card5, r'A–N=([\d,]+) V');
      final b5 = number(card5, r'B–N=([\d,]+) V');
      expect(a - b5, closeTo(number(card5, r'U\(A,B\)=([\d,]+) V'), 1e-10));
      expect(b5 - a, closeTo(-1, 1e-10));
    },
  );

  test(
    'C2 phases obey the declared path and do not assign an unknown signal',
    () async {
      final lesson = await loadWiringRepair(9);
      final input = section(
        lesson,
        'C2 • прерывание питания датчика • условия',
      );
      final data = section(
        lesson,
        'C2 • прерывание питания датчика • измерения',
      );
      final source = number(input, r'P\(\+([\d,]+) V');
      final segment = number(input, r'R\(A,B\)=([\d,]+) Ω');
      final load = number(input, r'→([\d,]+) Ω');
      final good = data.split('Отказ:').first;
      final bad = data.split('Отказ:').last.split('Ω-тест').first;
      final i = source / (segment + load);
      expect(number(good, r'I=([\d,]+) A'), closeTo(i, 1e-10));
      expect(number(good, r'Q/B=([\d,]+) V'), closeTo(i * load, 1e-10));
      expect(
        number(good, r'Psegment=([\d,]+) W'),
        closeTo(i * i * segment, 1e-10),
      );
      expect(number(bad, r'I=([\d,]+) A'), 0);
      expect(number(bad, r'Q/B=([\d,]+) V'), 0);
      expect(number(bad, r'U\(A,B\)=([\d,]+) V'), source);
      expect(number(bad, r'Psegment=([\d,]+) W'), 0);
      expect(input, contains('его уровень модель не задаёт'));
      expect(data, contains('оба конца A–B изолированы'));
    },
  );

  test(
    'C4 open fuse and isolated resistance are distinct from a live fault',
    () async {
      final lesson = await loadWiringRepair(9);
      final input = section(lesson, 'C4 • перетёртый провод • условия');
      final data = section(lesson, 'C4 • перетёртый провод • измерения');
      final after = section(lesson, 'C4 • перетёртый провод • после ремонта');
      final source = number(input, r'P\(\+([\d,]+) V');
      final load = number(input, r'нагрузка ([\d,]+) Ω');
      expect(source / load, number(input, r'I=([\d,]+) A'));
      expect(source * source / load, number(input, r'Pload=([\d,]+) W'));
      expect(number(data, r'I=([\d,]+) A'), 0);
      expect(number(data, r'Pload=([\d,]+) W'), 0);
      expect(number(after, r'I=([\d,]+) A'), source / load);
      expect(data, contains('нагрузка и модули отсоединены'));
      expect(data, contains('выше диапазона 20 MΩ'));
      expect(after, contains('не предсказывает ток/время'));
    },
  );

  test(
    'case diagram nodes and highlighted contact follow stated probe order',
    () {
      for (final (stem, first, second) in [
        ('headlamp_contact', 'B', 'C'),
        ('wet_ground_connector', 'T', 'N'),
        ('bad_splice_heating', 'A', 'B'),
      ]) {
        final svg = File('assets/images/wiring_repair/source/$stem.svg')
            .readAsStringSync();
        double y(String node) =>
            number(svg, 'cy="([\\d.]+)"[^>]*id="node-$node"');
        final top = y(first);
        final bottom = y(second);
        expect(top, lessThan(bottom));
        final contactY = number(
          svg,
          'id="contact-$first$second"[^>]*y="([\\d.]+)"',
        );
        expect(contactY, greaterThan(top));
        expect(contactY + 36, lessThan(bottom));
        expect(svg, contains('source-plus'));
        expect(svg, contains('resistor-'));
        expect(svg, contains('Красный $first / чёрный $second'));
      }
    },
  );
}
