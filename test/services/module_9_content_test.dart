import 'dart:io';

import 'package:electrician/domain/lesson_attempt.dart';
import 'package:electrician/models/lesson.dart';
import 'package:electrician/models/lesson_block.dart';
import 'package:electrician/services/course_service.dart';
import 'package:electrician/services/progress_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Lesson> loadStartingCharging(int n) => CourseService().loadLesson(
  'assets/course/stage_8/lesson_${n.toString().padLeft(2, '0')}.json',
);

String section(Lesson lesson, String title) => lesson.blocks
    .whereType<TextLessonBlock>()
    .singleWhere((b) => b.title == title)
    .content;

double number(String text, String pattern, [int group = 1]) {
  final matches = RegExp(pattern).allMatches(text).toList();
  expect(matches, hasLength(1), reason: pattern);
  return double.parse(
    matches.single.group(group)!.replaceAll(',', '.').replaceAll('−', '-'),
  );
}

List<(double, double)> points(String stem, String id) {
  final svg = File('assets/images/starting_charging/source/$stem.svg')
      .readAsStringSync();
  final match = RegExp('<polyline id="$id" points="([^"]+)"')
      .allMatches(svg)
      .single;
  return match.group(1)!.split(' ').map((p) {
    final xy = p.split(',').map(double.parse).toList();
    return (xy[0], xy[1]);
  }).toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final course = CourseService();
  setUp(() {
    rootBundle.clear();
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'ten modules and 102 distinct lessons retain ordered old prefix',
    () async {
      final modules = await course.loadModules();
      expect(modules.map((m) => m.id), List.generate(11, (i) => 'stage_$i'));
      expect(modules.map((m) => m.order), List.generate(11, (i) => i));
      expect(modules[8].title, 'Запуск, зарядка и паразитное потребление');
      final all = await course.loadAllLessons();
      expect(all, hasLength(102));
      expect(all.map((e) => e.lesson.id).toSet(), hasLength(102));
      expect(all.take(72).last.lesson.id, 'obd_10');
      expect(
        all.skip(72).take(10).map((e) => e.lesson.id),
        List.generate(
          10,
          (i) => 'starting_charging_${(i + 1).toString().padLeft(2, '0')}',
        ),
      );
    },
  );

  test(
    'ten real lessons parse supported blocks with matching metadata and assets',
    () async {
      final summaries = await course.loadLessons('stage_8');
      expect(summaries, hasLength(10));
      expect(summaries.map((s) => s.order), List.generate(10, (i) => i + 1));
      var blocks = 0;
      var tasks = 0;
      final images = <String>{};
      for (final s in summaries) {
        final lesson = await loadStartingCharging(s.order);
        expect(lesson.id, s.id);
        expect(lesson.moduleId, 'stage_8');
        expect(lesson.order, s.order);
        expect(lesson.title, s.title);
        expect(lesson.description, s.description);
        expect(lesson.estimatedMinutes, s.estimatedMinutes);
        expect(s.file, 'lesson_${s.order.toString().padLeft(2, '0')}.json');
        expect(lesson.completion.isQuiz, s.order == 10);
        expect(lesson.completion.passingScore, s.order == 10 ? 80 : null);
        blocks += lesson.blocks.length;
        tasks += lesson.blocks.where(isScoredLessonBlock).length;
        for (final block in lesson.blocks) {
          expect(
            block.type,
            isIn([
              'text',
              'remember',
              'warning',
              'image',
              'question',
              'calculation',
            ]),
          );
          if (block case ImageLessonBlock(:final asset)) {
            images.add(asset);
            expect(
              (await rootBundle.load(asset)).lengthInBytes,
              greaterThan(0),
            );
            expect(
              File(
                asset
                    .replaceFirst(
                      '/starting_charging/',
                      '/starting_charging/source/',
                    )
                    .replaceFirst('.png', '.svg'),
              ).existsSync(),
              isTrue,
            );
          }
        }
        final answers = <int, bool>{
          for (var i = 0; i < lesson.blocks.length; i++)
            if (isScoredLessonBlock(lesson.blocks[i])) i: true,
        };
        expect(evaluateLessonAttempt(lesson, answers).canComplete, isTrue);
        if (s.order != 10) {
          answers[answers.keys.first] = false;
          expect(evaluateLessonAttempt(lesson, answers).canComplete, isFalse);
        }
      }
      expect(blocks, 134);
      expect(tasks, 60);
      expect(images, hasLength(15));
    },
  );

  test(
    'real quiz has exactly 15 tasks, 11 fail, 12 pass, missing answer blocks',
    () async {
      final quiz = await loadStartingCharging(10);
      expect(quiz.blocks.whereType<QuestionLessonBlock>(), hasLength(15));
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

  test('72 old IDs and unknown ID survive adding and reloading module 9 completion', () async {
    final all = await course.loadAllLessons();
    final old = all.take(72).map((e) => e.lesson.id).toSet();
    expect(old, hasLength(72));
    SharedPreferences.setMockInitialValues({
      'completed_lessons': [...old, 'orphan_id'],
    });
    final service = ProgressService();
    final before = await service.calculateProgress(all);
    expect(before.completedLessons, 72);
    expect(before.totalLessons, 102);
    expect(before.progress, 72 / 102);
    expect(before.nextLesson?.lesson.id, 'starting_charging_01');
    await service.completeLesson('starting_charging_01');
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final reloaded = ProgressService();
    expect(await reloaded.getCompletedLessons(), {
      ...old,
      'orphan_id',
      'starting_charging_01',
    });
    final after = await reloaded.calculateProgress(all);
    expect(after.completedLessons, 73);
    expect(after.progress, 73 / 102);
    expect(after.nextLesson?.lesson.id, 'starting_charging_02');
    expect(prefs.getKeys(), {'completed_lessons'});
  });

  test('battery impulse geometry agrees with text, resistance and calculation answer', () async {
    final lesson = await loadStartingCharging(2);
    final b = section(lesson, 'Одинаковое напряжение — разный ответ');
    final e = number(b, r'E=([\d,]+) V');
    final r = number(b, r'r=([\d,]+) Ω\. До');
    final current = number(b, r'при заданных ([\d,]+) A');
    final loaded = number(b, r'при заданных 100 A U\(P,N\)=([\d,]+) V');
    expect(e - current * r, closeTo(loaded, 1e-9));
    for (final entry in {'battery6': r, 'battery12': .012}.entries) {
      final xy = points('battery_pulse', entry.key);
      final times = xy.map((p) => (p.$1 - 50) / 80).toList();
      final volts = xy.map((p) => (310 - p.$2) / 15).toList();
      expect(times, [0, 1, 1, 2, 2, 3]);
      expect(volts[0], closeTo(e, 1e-9));
      expect(volts[2], closeTo(e - current * entry.value, 1e-9));
      expect(volts[3], closeTo(volts[2], 1e-9));
    }
    expect(
      lesson.blocks.whereType<CalculationLessonBlock>().single.correctValue,
      closeTo((e - loaded) / current, 1e-9),
    );
  });

  test(
    'starter S1 and G obey KVL, references and mass drop polarity',
    () async {
      final lesson = await loadStartingCharging(4);
      final good = section(lesson, 'Точки и кадр сравнения').split('S1:').last;
      final bad = section(lesson, 'Масса под нагрузкой');
      for (final data in [good, bad.split('При START').last]) {
        final e = number(data, r'E=([\d,]+) V');
        final r = number(data, r'r=([\d,]+) Ω');
        final i = number(data, r'I=([\d,]+) A');
        final terminal = number(data, r'U\(P,N\)=([\d,]+) V');
        final plus = number(data, r'U\(P,A\)=([\d,]+) V');
        final k = number(data, r'U\(A,M\)=([\d,]+) V');
        final ground = number(data, r'U\(G,N\)=([\d,]+) V\.', 1);
        final motor = number(data, r'U\(M,G\)=([\d,]+) V');
        expect(terminal, closeTo(e - i * r, 1e-9));
        expect(e, closeTo(i * r + plus + k + motor + ground, 1e-9));
        expect(plus, closeTo(i * number(data, r'R\+=([\d,]+) Ω'), 1e-9));
        expect(k, closeTo(i * number(data, r'RK=([\d,]+) Ω'), 1e-9));
        expect(ground, closeTo(i * number(data, r'R−=([\d,]+) Ω'), 1e-9));
        final m = number(data, r'M=([\d,]+) V');
        final g = number(data, r'G=([\d,]+) V');
        expect(m - g, closeTo(motor, 1e-9));
      }
      expect(bad, contains('до START ток моторной ветви 0 A и U(G,N)=0,00 V'));
      final svg = File(
        'assets/images/starting_charging/source/starter_drop_points.svg',
      ).readAsStringSync();
      expect(svg, contains('G / N • возврат'));
      expect(svg, contains('G: +1,20 V'));
      expect(svg, contains('G: 9,60 V'));
    },
  );

  test(
    'charging C0 C1: negative generator ground, positive return drop and KCL',
    () async {
      final data = section(
        await loadStartingCharging(6),
        'Кадры стабильного и нестабильного соединения',
      );
      final output = number(data, r'U\(H,G\)=([\d,]+) V');
      final gen = number(data, r'Iген=([\d,]+) A');
      final load = number(data, r'Iпотреб=([\d,]+) A');
      final battery = number(data, r'IАКБ=\+([\d,]+) A');
      expect(gen, load + battery);
      for (final frame in [
        data.split('Кадр C0:')[1].split('Кадр отказа')[0],
        data.split('Кадр отказа C1:')[1].split('В обоих')[0],
      ]) {
        final plus = number(frame, r'U\(H,P\)=([\d,]+) V');
        final ret = number(frame, r'U\(N,G\)=([\d,]+) V');
        final terminal = number(frame, r'U\(P,N\)=([\d,]+) V');
        expect(output, closeTo(plus + terminal + ret, 1e-9));
        expect(plus, closeTo(gen * number(frame, r'Rc\+=([\d,]+) Ω'), 1e-9));
        expect(ret, closeTo(gen * number(data, r'Rc−=([\d,]+) Ω'), 1e-9));
        final ground = number(data, r'V\(G\)=−([\d,]+) V');
        expect(ret, closeTo(ground, 1e-9));
        final h = number(data, r'V\(H\)=([\d,]+) V');
        expect(h - (-ground), closeTo(output, 1e-9));
      }
      final svg = File(
        'assets/images/starting_charging/source/charging_power.svg',
      ).readAsStringSync();
      expect(svg, contains('N → G'));
      expect(svg, contains('U(N,G)&gt;0'));
      expect(svg, contains('V(G) к N при зарядке &lt; 0.'));
    },
  );

  test('smart charging two working points retain current balance and resistive losses', () async {
    final data = section(
      await loadStartingCharging(6),
      'Два режима интеллектуальной стратегии',
    );
    final resistance = number(data, r'Rc\+=Rc−=([\d,]+) Ω');
    final frames = [
      data.split(' A:')[1].split(' B:')[0],
      data.split(' B:')[1].split('Rc+=')[0],
    ];
    for (final frame in frames) {
      final output = number(frame, r'U\(H,G\)=([\d,]+) V');
      final terminal = number(frame, r'U\(P,N\)=([\d,]+) V');
      final gen = number(frame, r'Iген=([\d,]+) A');
      final load = number(frame, r'Iпотреб=([\d,]+) A');
      final battery = number(frame, r'IАКБ=([+−\d,]+) A');
      expect(gen, load + battery);
      expect(output - terminal, closeTo(gen * 2 * resistance, 1e-9));
    }
  });

  test('fuse-specific characteristic and night charge agree with actual calculation blocks', () async {
    final lesson = await loadStartingCharging(8);
    final data = section(lesson, 'Предохранитель как измеряемый участок');
    final pairs = RegExp(r'([\d,]+) A → ([\d,]+) mV')
        .allMatches(data)
        .map(
          (m) => (
            double.parse(m[1]!.replaceAll(',', '.')),
            double.parse(m[2]!.replaceAll(',', '.')),
          ),
        )
        .toList();
    expect(pairs, hasLength(3));
    final resistance = number(data, r'R=([\d,]+) Ω');
    for (final p in pairs) {
      expect(p.$2 / 1000, closeTo(p.$1 * resistance, 1e-9));
    }
    expect(
      lesson.blocks.whereType<CalculationLessonBlock>().single.correctValue,
      pairs.last.$1,
    );
    final total = number(data, r'Общий ток ([\d,]+) A');
    final base = number(data, r'штатные ветви ([\d,]+) A');
    expect(total, closeTo(base + pairs.last.$1, 1e-9));
    final caseText = section(
      await loadStartingCharging(9),
      'P • АКБ разряжается за ночь',
    );
    expect(
      total * 10,
      closeTo(number(caseText, r'общий расход ([\d,]+) Ah'), 1e-9),
    );
    expect(
      caseText,
      contains('После сервисной изоляции Fd и повторного sleep'),
    );
  });

  test('sleep and wake geometry has correct half-open intervals, average and branch sum', () async {
    final lesson = await loadStartingCharging(7);
    final data = section(lesson, 'Три временные модели');
    expect(
      data,
      contains('[0,2) min: 3,00 A; [2,10): 0,60 A; [10,30): 0,15 A'),
    );
    final normal = points('sleep_profiles', 'T0');
    final extra = points('sleep_profiles', 'T1');
    for (var n = 0; n < normal.length; n++) {
      expect((normal[n].$1 - 50) / 6, [0, 2, 2, 10, 10, 30, 30, 40][n]);
      expect((normal[n].$2 - extra[n].$2) / 60, closeTo(.8, 1e-9));
    }
    final xy = points('wake_profile', 'T2');
    double area = 0;
    var highMinutes = 0.0;
    for (var n = 1; n < xy.length; n++) {
      final minutes = (xy[n].$1 - xy[n - 1].$1) / 4;
      final amps = (340 - xy[n - 1].$2) / 140;
      expect(minutes, greaterThanOrEqualTo(0));
      area += minutes * amps;
      if (amps > .1) highMinutes += minutes;
    }
    expect(xy.first.$1, 50);
    expect(xy.last.$1, 290);
    expect(highMinutes, 6);
    final explained = section(lesson, 'Средний ток и вмешательство');
    expect(area / 60, closeTo(number(explained, r'=([\d,]+) A, расход'), 1e-9));
    expect(area / 60, closeTo(.177, 1e-9));
    final wake = section(
      await loadStartingCharging(9),
      'W • Модуль периодически пробуждает сеть',
    );
    expect(wake, contains('Fw=0,50 A, остальные ветви суммарно 1,00 A'));
    expect(.50 + 1.00, 1.5);
  });

  test('five cases expose evidence and limits rather than a fake simulator sequence', () async {
    final lesson = await loadStartingCharging(9);
    expect(lesson.blocks.whereType<QuestionLessonBlock>(), hasLength(10));
    for (final code in ['S0 •', 'P •', 'C1 •', 'G •', 'W •']) {
      final b = lesson.blocks.whereType<TextLessonBlock>().singleWhere(
        (b) => b.title.startsWith(code),
      );
      expect(b.content, contains('A'));
    }
    expect(
      section(lesson, 'Как решаются кейсы'),
      contains('не принуждают к порядку действий'),
    );
    expect(lesson.blocks.whereType<DiagnosticCaseLessonBlock>(), isEmpty);
    expect(lesson.blocks.whereType<DiagnosticChoiceLessonBlock>(), isEmpty);
  });
}
