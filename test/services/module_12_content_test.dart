import 'dart:io';
import 'dart:math' as math;

import 'package:electrician/domain/lesson_attempt.dart';
import 'package:electrician/models/lesson.dart';
import 'package:electrician/models/lesson_block.dart';
import 'package:electrician/services/course_service.dart';
import 'package:electrician/services/progress_service.dart';
import 'package:electrician/simulation/oscilloscope_simulation.dart';
import 'package:electrician/simulation/voltage_drop_simulation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Lesson> loadBody(int order) => CourseService().loadLesson(
  'assets/course/stage_11/lesson_${order.toString().padLeft(2, '0')}.json',
);

String drawing(String stem) =>
    File('assets/images/body_electronics/source/$stem.svg').readAsStringSync();
Map<String, String> attributes(String tag) => {
  for (final m in RegExp(r'([\w-]+)="([^"]*)"').allMatches(tag))
    m.group(1)!: m.group(2)!,
};
List<Map<String, String>> elements(String stem, String tag) =>
    RegExp('<$tag ([^>]+)')
        .allMatches(drawing(stem))
        .map((m) => attributes(m.group(1)!))
        .toList();
Map<String, double> potentials(String stem) => {
  for (final a in elements(stem, 'circle'))
    if (a.containsKey('data-voltage'))
      a['data-node']!: double.parse(a['data-voltage']!),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    rootBundle.clear();
    SharedPreferences.setMockInitialValues({});
  });

  test(
    '13 modules and 122 unique lessons retain the old ordered prefix',
    () async {
      final course = CourseService();
      final modules = await course.loadModules();
      expect(modules.map((m) => m.id), List.generate(13, (i) => 'stage_$i'));
      expect(modules.map((m) => m.order), List.generate(13, (i) => i));
      final all = await course.loadAllLessons();
      expect(all, hasLength(122));
      expect(all.map((e) => e.lesson.id).toSet(), hasLength(122));
      expect(all[101].lesson.id, 'oscilloscope_10');
      expect(
        all.skip(102).take(10).map((e) => e.lesson.id),
        List.generate(
          10,
          (i) => 'body_electronics_${(i + 1).toString().padLeft(2, '0')}',
        ),
      );
    },
  );

  test(
    'all real metadata blocks and image references parse and load',
    () async {
      final summaries = await CourseService().loadLessons('stage_11');
      var blocks = 0, tasks = 0;
      final images = <String>{};
      for (final s in summaries) {
        final lesson = await loadBody(s.order);
        expect(lesson.id, s.id);
        expect(lesson.title, s.title);
        expect(lesson.order, s.order);
        expect(lesson.description, s.description);
        expect(lesson.estimatedMinutes, s.estimatedMinutes);
        expect(lesson.moduleId, 'stage_11');
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
              'voltageDrop',
              'oscilloscope',
            ]),
          );
          if (b case ImageLessonBlock(:final asset, :final caption)) {
            images.add(asset);
            expect(caption, isNotEmpty);
            expect(await rootBundle.load(asset), isNotNull);
          }
        }
      }
      expect(blocks, 172);
      expect(tasks, 71);
      expect(images, hasLength(16));
      expect(
        (await loadBody(9)).blocks.whereType<QuestionLessonBlock>(),
        hasLength(15),
      );
    },
  );

  test(
    'all 102 previous completions and unknown ID survive new completion',
    () async {
      final all = await CourseService().loadAllLessons();
      final old = all.take(102).map((e) => e.lesson.id).toSet();
      SharedPreferences.setMockInitialValues({
        'completed_lessons': [...old, 'orphan'],
      });
      final service = ProgressService();
      final before = await service.calculateProgress(all);
      expect(before.completedLessons, 102);
      expect(before.progress, 102 / 122);
      expect(before.nextLesson?.lesson.id, 'body_electronics_01');
      await service.completeLesson('body_electronics_01');
      expect(await service.getCompletedLessons(), {
        ...old,
        'orphan',
        'body_electronics_01',
      });
      final after = await service.calculateProgress(all);
      expect(after.completedLessons, 103);
      expect(after.progress, 103 / 122);
      expect(after.nextLesson?.lesson.id, 'body_electronics_02');
    },
  );

  test('real mixed quiz requires all 15 answers and 12 correct', () async {
    final quiz = await loadBody(10);
    final ids = [
      for (var i = 0; i < quiz.blocks.length; i++)
        if (isScoredLessonBlock(quiz.blocks[i])) i,
    ];
    expect(ids, hasLength(15));
    expect(quiz.blocks.whereType<QuestionLessonBlock>(), hasLength(11));
    expect(quiz.blocks.whereType<CalculationLessonBlock>(), hasLength(3));
    expect(quiz.blocks.whereType<OscilloscopeLessonBlock>(), hasLength(1));
    final answers = {for (var i = 0; i < 15; i++) ids[i]: i < 11};
    expect(evaluateLessonAttempt(quiz, answers).canComplete, isFalse);
    answers[ids[11]] = true;
    expect(evaluateLessonAttempt(quiz, answers).scorePercent, 80);
    expect(evaluateLessonAttempt(quiz, answers).canComplete, isTrue);
    answers.remove(ids.last);
    expect(evaluateLessonAttempt(quiz, answers).canComplete, isFalse);
  });

  test('every authored calculation follows independent electrical or range arithmetic', () async {
    final expected = <int, List<double>>{
      2: [(12.0 - 0).abs()],
      4: [11.7 - 2.7, 12.0 * 4 / 10],
      6: [12.0 * 2],
      7: [2.5 / 5 * 100, 12 * math.sqrt(4 / 10)],
      10: [11.7 - 2.7, 12.0 * 4 / 10, 12.0 * 2],
    };
    for (final entry in expected.entries) {
      final actual = (await loadBody(entry.key)).blocks
          .whereType<CalculationLessonBlock>()
          .toList();
      expect(actual, hasLength(entry.value.length));
      for (var i = 0; i < actual.length; i++) {
        expect(
          actual[i].correctValue,
          closeTo(entry.value[i], actual[i].tolerance),
        );
        expect(actual[i].tolerance, lessThanOrEqualTo(.01));
      }
    }
  });

  test(
    'K4 stated timeout observation matches stopped supply and intact RUN',
    () async {
      final record = (await loadBody(9)).blocks
          .whereType<TextLessonBlock>()
          .singleWhere((b) => b.title == 'K4 • предоставленные измерения')
          .content;
      final stop = RegExp(r'После OFF\+(\d+) s: P/N=(\d+) V и I=(\d+)')
          .firstMatch(record)!;
      expect(int.parse(stop.group(1)!), 2);
      expect(int.parse(stop.group(2)!) * int.parse(stop.group(3)!), 0);
      final running = RegExp(r'RUN: P/N=(\d+) V, ток мотора (\d+) A')
          .firstMatch(record)!;
      expect(int.parse(running.group(1)!) * int.parse(running.group(2)!), 36);
      final statements = (await loadBody(9)).blocks
          .whereType<QuestionLessonBlock>()
          .where((b) => b.question.startsWith('K4:'))
          .toList();
      expect(statements, hasLength(3));
      expect(
        statements[1].answers[statements[1].correctAnswer],
        contains('K–S'),
      );
    },
  );

  test('M1 actual visible state rows agree with independent bridge paths', () {
    final states = elements(
      'h_bridge',
      'g',
    ).where((a) => a.containsKey('data-closed')).toList();
    expect(states, hasLength(5));
    for (final state in states) {
      final closed = state['data-closed']!.split(' ').toSet();
      for (final leg in ['A', 'B']) {
        expect(
          closed.contains('Q${leg}H') && closed.contains('Q${leg}L'),
          isFalse,
        );
        final expected = closed.contains('Q${leg}H')
            ? '12'
            : closed.contains('Q${leg}L')
            ? '0'
            : 'None';
        expect(state['data-${leg.toLowerCase()}'], expected);
      }
    }
    final forward = states.singleWhere((s) => s['id'] == 'state-forward');
    final reverse = states.singleWhere((s) => s['id'] == 'state-reverse');
    expect(
      double.parse(forward['data-a']!) - double.parse(forward['data-b']!),
      12,
    );
    expect(
      double.parse(reverse['data-a']!) - double.parse(reverse['data-b']!),
      -12,
    );
    expect(
      states.singleWhere((s) => s['id'] == 'state-coast')['data-a'],
      'None',
    );
  });

  test('K1 and K2 actual drawn potentials distinguish voltage transfer and reverse absence', () async {
    final k1 = potentials('case_lock');
    expect(k1['DA']! - k1['A']!, 12);
    expect(k1['A']! - k1['B']!, 0);
    expect(
      elements(
        'case_lock',
        'line',
      ).any((a) => a['data-from'] == 'DA' && a['data-to'] == 'A'),
      isFalse,
    );
    expect(
      elements(
        'door_lock',
        'line',
      ).any((a) => a['data-from'] == 'DA' && a['data-to'] == 'A'),
      isTrue,
    );
    final k2 = potentials('case_window');
    expect(k2['A-95']! - k2['B-95']!, 12);
    expect(k2['A-300']! - k2['B-300']!, 0);
    final quiz = await loadBody(10);
    final polarity = quiz.blocks.whereType<QuestionLessonBlock>().singleWhere(
      (b) => b.question.startsWith('4.'),
    );
    expect(polarity.answers[polarity.correctAnswer], '−12 V');
  });

  test('K3 reconstructs resistances potentials current losses and power from actual drawing', () async {
    final rs = elements('case_lamp', 'rect')
        .where((a) => a.containsKey('data-resistance'))
        .map((a) => double.parse(a['data-resistance']!))
        .toList();
    final v = potentials('case_lamp');
    final source = v['B+']! - v['N']!;
    final i = source / rs.reduce((a, b) => a + b);
    expect(i, 3);
    expect(v['B+']! - v['P']!, closeTo(i * rs[0], 1e-10));
    expect(v['P']! - v['G']!, closeTo(i * rs[1], 1e-10));
    expect(v['G']! - v['N']!, closeTo(i * rs[2], 1e-10));
    expect(i * i * rs.reduce((a, b) => a + b), source * i);
    final answer = (await loadBody(10)).blocks
        .whereType<CalculationLessonBlock>()
        .first;
    expect(answer.correctValue, closeTo(v['P']! - v['G']!, answer.tolerance));
    expect(i * i * rs[2], closeTo(8.1, 1e-10));
  });

  test(
    'P1 integrate actual waveform mean RMS and resistor power independently',
    () async {
      final trace = elements('pwm_power', 'polyline').single;
      final pts = trace['points']!
          .split(' ')
          .map((s) => s.split(',').map(double.parse).toList())
          .toList();
      var area = 0.0, square = 0.0;
      for (var i = 1; i < pts.length; i++) {
        final dt = (pts[i][0] - pts[i - 1][0]) / 62 * 10;
        final a = (340 - pts[i - 1][1]) / 140 * 12;
        final b = (340 - pts[i][1]) / 140 * 12;
        area += dt * (a + b) / 2;
        square += dt * (a * a + a * b + b * b) / 3;
      }
      final mean = area / 40, rms = math.sqrt(square / 40);
      expect(mean, closeTo(4.8, 1e-9));
      expect(rms, closeTo(12 * math.sqrt(.4), 1e-9));
      expect(rms * rms / 6, closeTo(9.6, 1e-9));
      expect(mean * mean / 6, isNot(closeTo(9.6, .1)));
      final lessons = [
        await loadBody(4),
        await loadBody(7),
        await loadBody(10),
      ];
      for (final lesson in lessons) {
        for (final b in lesson.blocks.whereType<CalculationLessonBlock>()) {
          if (b.question.contains('среднее') ||
              b.question.contains('Среднее')) {
            expect(b.correctValue, closeTo(mean, b.tolerance));
          }
          if (b.question.contains('RMS')) {
            expect(b.correctValue, closeTo(rms, b.tolerance));
          }
        }
      }
    },
  );

  test('W1 healthy signal path and K4 interruption have distinct drawn connectivity and pull-up levels', () {
    bool connected(String stem) => elements(
      stem,
      'line',
    ).any((a) => a['data-from'] == 'K' && a['data-to'] == 'S');
    expect(connected('wiper_park'), isTrue);
    expect(connected('case_park'), isFalse);
    final healthy = potentials('wiper_park'), faulty = potentials('case_park');
    expect(healthy['S'], healthy['K']);
    expect(faulty['K'], 0);
    expect(faulty['S'], 5);
    expect(5 / 10000 * 1000, .5);
    // OFF timeout is a stated M/A algorithm, not a new production state machine.
    expect(drawing('case_park'), contains('2 s'));
  });

  test('K5 actual selector graphic never closes multiple paths or depicts protection bypass in LOW', () {
    final selectors = elements(
      'blower_steps',
      'line',
    ).where((a) => (a['id'] ?? '').startsWith('selector-')).toList();
    expect(selectors, hasLength(3));
    expect(
      selectors.where((a) => a['data-closed'] == 'true').map((a) => a['id']),
      ['selector-LOW'],
    );
    final doc = drawing('blower_steps');
    expect(doc, contains('T: OL'));
    expect(doc, contains('HIGH обходит R и T.'));
  });

  test('V1 remains positive-side exercise and scope tasks solve using existing 5 V source', () async {
    final v = (await loadBody(4)).blocks
        .whereType<VoltageDropLessonBlock>()
        .single;
    final simulation = VoltageDropSimulation(
      sourceVoltage: v.sourceVoltage,
      faultVoltageDrop: v.faultVoltageDrop,
      loadOn: true,
      redPoint: VoltageDropPoint.batteryPositive,
      blackPoint: VoltageDropPoint.afterFault,
    );
    expect(simulation.meterReading, closeTo(1.2, 1e-10));
    expect(simulation.correctSetup, isTrue);
    const scope = OscilloscopeSimulation();
    for (final order in [7, 10]) {
      final b = (await loadBody(order)).blocks
          .whereType<OscilloscopeLessonBlock>()
          .single;
      final initial = scope.capture(b.scenario.signal, b.initialSettings);
      expect(
        scope.evaluate(
          exercise: b.exercise,
          target: b.scenario,
          selected: b.scenario,
          capture: initial,
        ),
        isFalse,
      );
      final settings = b.initialSettings.copyWith(millisecondsPerDiv: 4);
      final result = scope.capture(b.scenario.signal, settings);
      expect(
        scope.evaluate(
          exercise: b.exercise,
          target: b.scenario,
          selected: b.scenario,
          capture: result,
        ),
        isTrue,
      );
      expect(b.scenario.signal.maximum, 5);
    }
  });
}
