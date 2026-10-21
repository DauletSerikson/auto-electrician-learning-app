import 'dart:io';

import 'package:electrician/domain/lesson_attempt.dart';
import 'package:electrician/models/lesson.dart';
import 'package:electrician/models/lesson_block.dart';
import 'package:electrician/services/course_service.dart';
import 'package:electrician/services/progress_service.dart';
import 'package:electrician/simulation/oscilloscope_simulation.dart';
import 'package:electrician/simulation/scope_signal.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Lesson> loadOscilloscope(int order) => CourseService().loadLesson(
  'assets/course/stage_10/lesson_${order.toString().padLeft(2, '0')}.json',
);

/// Recover physical coordinates from the actual SVG polyline, not an answer key.
List<(double, double)> signalTrace(String stem, String id) {
  final source = File('assets/images/oscilloscope/source/$stem.svg')
      .readAsStringSync();
  final polylines = RegExp(r'<polyline ([^>]+)').allMatches(source);
  final attrs = polylines
      .map(
        (line) => {
          for (final m in RegExp(
            r'([\w-]+)="([^"]*)"',
          ).allMatches(line.group(1)!))
            m.group(1)!: m.group(2)!,
        },
      )
      .singleWhere((a) => a['id'] == 'trace-$id');
  final window = double.parse(attrs['data-window']!);
  final bottom = double.parse(attrs['data-bottom']!);
  final top = double.parse(attrs['data-top']!);
  final y0 = double.parse(attrs['data-y']!);
  expect(double.parse(attrs['data-vdiv']!), closeTo((top - bottom) / 8, 1e-10));
  return [
    for (final pair in attrs['points']!.split(' '))
      (
        (double.parse(pair.split(',')[0]) - 46) / 258 * window,
        top - (double.parse(pair.split(',')[1]) - y0) / 160 * (top - bottom),
      ),
  ];
}

List<double> rising(List<(double, double)> points, double level) => [
  for (var i = 1; i < points.length; i++)
    if ((points[i].$1 - points[i - 1].$1).abs() < 1e-7 &&
        points[i - 1].$2 < level &&
        points[i].$2 > level)
      points[i].$1,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final course = CourseService();
  setUp(() {
    rootBundle.clear();
    SharedPreferences.setMockInitialValues({});
  });

  test('12 modules 112 unique lessons retain the 92 lesson prefix', () async {
    final modules = await course.loadModules();
    expect(modules.map((m) => m.id), List.generate(12, (i) => 'stage_$i'));
    expect(modules.map((m) => m.order), List.generate(12, (i) => i));
    expect(modules[10].title, 'Автомобильный осциллограф и анализ сигналов');
    final all = await course.loadAllLessons();
    expect(all, hasLength(112));
    expect(all.map((e) => e.lesson.id).toSet(), hasLength(112));
    expect(all.take(92).last.lesson.id, 'wiring_repair_10');
    expect(
      all.skip(92).take(10).map((e) => e.lesson.id),
      List.generate(
        10,
        (i) => 'oscilloscope_${(i + 1).toString().padLeft(2, '0')}',
      ),
    );
  });

  test('real metadata counts types and all asset references load', () async {
    final summaries = await course.loadLessons('stage_10');
    expect(summaries, hasLength(10));
    var blocks = 0, tasks = 0, scopes = 0;
    final images = <String>{};
    final interactiveLessons = <int>[];
    for (final summary in summaries) {
      final lesson = await loadOscilloscope(summary.order);
      expect(lesson.id, summary.id);
      expect(lesson.moduleId, 'stage_10');
      expect(lesson.title, summary.title);
      expect(lesson.description, summary.description);
      expect(lesson.estimatedMinutes, summary.estimatedMinutes);
      expect(lesson.order, summary.order);
      expect(lesson.completion.isQuiz, summary.order == 10);
      expect(lesson.completion.passingScore, summary.order == 10 ? 80 : null);
      blocks += lesson.blocks.length;
      tasks += lesson.blocks.where(isScoredLessonBlock).length;
      if (lesson.blocks.any((b) => b is OscilloscopeLessonBlock)) {
        interactiveLessons.add(summary.order);
      }
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
            'oscilloscope',
          ]),
        );
        if (block case OscilloscopeLessonBlock()) scopes++;
        if (block case ImageLessonBlock(:final asset, :final caption)) {
          expect(caption, isNotEmpty);
          expect(await rootBundle.load(asset), isNotNull);
          images.add(asset);
        }
      }
    }
    expect(blocks, 146);
    expect(tasks, 66);
    expect(scopes, 7);
    expect(interactiveLessons, [3, 4, 5, 9, 10]);
    expect(images, hasLength(18));
  });

  test('15 real quiz tasks require all answers and 12 correct, retry removes eligibility', () async {
    final quiz = await loadOscilloscope(10);
    final indices = [
      for (var i = 0; i < quiz.blocks.length; i++)
        if (isScoredLessonBlock(quiz.blocks[i])) i,
    ];
    expect(indices, hasLength(15));
    var answers = {for (var i = 0; i < indices.length; i++) indices[i]: i < 11};
    expect(evaluateLessonAttempt(quiz, answers).canComplete, isFalse);
    answers[indices[11]] = true;
    expect(evaluateLessonAttempt(quiz, answers).scorePercent, 80);
    expect(evaluateLessonAttempt(quiz, answers).canComplete, isTrue);
    answers.remove(indices.last);
    expect(evaluateLessonAttempt(quiz, answers).canComplete, isFalse);
    expect(quiz.blocks.whereType<OscilloscopeLessonBlock>(), hasLength(1));
    expect(quiz.blocks.whereType<QuestionLessonBlock>(), hasLength(9));
    expect(quiz.blocks.whereType<CalculationLessonBlock>(), hasLength(5));
  });

  test(
    '92 old completions unknown and pilot ID survive module 11 completion',
    () async {
      final all = await course.loadAllLessons();
      final old = all.take(92).map((e) => e.lesson.id).toSet();
      SharedPreferences.setMockInitialValues({
        'completed_lessons': [...old, 'orphan', 'pilot_oscilloscope_mvp'],
      });
      final before = await ProgressService().calculateProgress(all);
      expect(before.totalLessons, 112);
      expect(before.completedLessons, 92);
      expect(before.nextLesson?.lesson.id, 'oscilloscope_01');
      await ProgressService().completeLesson('oscilloscope_01');
      expect(await ProgressService().getCompletedLessons(), {
        ...old,
        'orphan',
        'pilot_oscilloscope_mvp',
        'oscilloscope_01',
      });
      final after = await ProgressService().calculateProgress(all);
      expect(after.completedLessons, 93);
      expect(after.progress, 93 / 112);
      expect(after.nextLesson?.lesson.id, 'oscilloscope_02');
      expect((await SharedPreferences.getInstance()).getKeys(), {
        'completed_lessons',
      });
    },
  );

  test('every real scope task starts unsolved and has an actual valid capture solution', () async {
    const simulation = OscilloscopeSimulation();
    for (var i = 1; i <= 10; i++) {
      for (final block in (await loadOscilloscope(
        i,
      )).blocks.whereType<OscilloscopeLessonBlock>()) {
        final initial = simulation.capture(
          block.scenario.signal,
          block.initialSettings,
        );
        bool evaluate(ScopeCapture capture) => simulation.evaluate(
          exercise: block.exercise,
          target: block.scenario,
          selected: block.scenario,
          capture: capture,
        );
        expect(evaluate(initial), isFalse);
        final settings = ScopeSettings(
          voltsPerDiv: block.scenario == ScopeScenario.sine ? 2 : 1,
          centerVoltage: block.scenario == ScopeScenario.sine ? 0 : 2.5,
        );
        final solved = simulation.capture(block.scenario.signal, settings);
        expect(solved.status, ScopeCaptureStatus.triggered);
        expect(evaluate(solved), isTrue, reason: 'lesson $i');
        expect(
          block.scenario.signal.minimum,
          block.scenario == ScopeScenario.sine ? -4 : 0,
        );
      }
    }
  });

  test(
    'all calculation answers follow independent dimensional calculations',
    () async {
      final expected = <int, List<double>>{
        3: [4 * 2],
        4: [(2.6 - 2.4) / 2],
        5: [1 / .01, 3 / 10 * 100, .6 * 10, 5 * .3],
        6: [60000 / 600, 25 / 100 * 360],
        7: [8 / 20 * 100, (36 * .5 + 12 * 11.5) / 20],
        8: [3.5 - 1.5, (3.5 + 1.5) / 2, 1 / .0001 / 1000],
        10: [4 * 2, 5 * 2, 1 / .01, 3 / 10 * 100, 3.5 - 1.5],
      };
      for (final entry in expected.entries) {
        final blocks = (await loadOscilloscope(entry.key)).blocks
            .whereType<CalculationLessonBlock>()
            .toList();
        expect(blocks, hasLength(entry.value.length));
        for (var i = 0; i < blocks.length; i++) {
          expect(blocks[i].correctValue, closeTo(entry.value[i], 1e-10));
          expect(blocks[i].tolerance, inInclusiveRange(.001, .1));
          expect(blocks[i].unit, isNotEmpty);
        }
      }
    },
  );

  test('SVG sine and ramp coordinates match the independently stated physical functions', () {
    for (final (time, voltage) in signalTrace('scale_axes', 'S1')) {
      // Five-point landmarks suffice to distinguish the stated 100 Hz / 4 V sine.
      if ((time - 2.5).abs() < 1e-6) expect(voltage, closeTo(4, 1e-5));
      if ((time - 7.5).abs() < 1e-6) expect(voltage, closeTo(-4, 1e-5));
    }
    final ramp = signalTrace('analog_ramp', 'S2');
    expect(ramp.first.$2, closeTo(1, 1e-5));
    expect(ramp.last.$2, closeTo(4, 1e-5));
    expect(ramp.last.$1, closeTo(100, 1e-5));
  });

  test('SVG PWM spans 3/6ms highs and missing pulse has no event at 20ms', () {
    for (final (stem, id, high) in [
      ('pwm_compare', 'A', 3.0),
      ('pwm_compare', 'B', 6.0),
    ]) {
      final pts = signalTrace(stem, id);
      final falls = [
        for (var i = 1; i < pts.length; i++)
          if ((pts[i].$1 - pts[i - 1].$1).abs() < 1e-7 &&
              pts[i - 1].$2 > 2.5 &&
              pts[i].$2 < 2.5)
            pts[i].$1,
      ];
      expect(falls.first, closeTo(high, 1e-5));
      expect(rising(pts, 2.5)[1] - rising(pts, 2.5)[0], closeTo(10, 1e-5));
    }
    final missing = signalTrace('missing_pulse', 'S4');
    expect(rising(missing, 2.5).any((t) => (t - 20).abs() < 1e-5), isFalse);
    expect(rising(missing, 2.5), contains(closeTo(30, 1e-5)));
  });

  test(
    'Hall SVG geometry shows 12 minus 1 and CKP/CMP share the 200ms axis',
    () {
      final crank = rising(signalTrace('crank_cam', 'CKP'), 2.5);
      expect(crank.any((t) => (t - 100).abs() < 1e-4), isTrue);
      final gaps = [
        for (var i = 1; i < crank.length; i++) crank[i] - crank[i - 1],
      ];
      expect(gaps, contains(closeTo(100 / 12, 1e-4)));
      expect(gaps, contains(closeTo(2 * 100 / 12, 1e-4)));
      final cam = rising(signalTrace('crank_cam', 'CMP'), 2.5);
      expect(cam, hasLength(1));
      expect(cam.single, closeTo(25, 1e-5));
      final faster = rising(signalTrace('hall_crank', 'B'), 2.5);
      expect(faster[1] - faster[0], closeTo(50 / 12, 1e-4));
    },
  );

  test('actual SVG low-side clamp area equals 7.8 V mean without inferring current', () {
    final pts = signalTrace('actuator_low', 'Q');
    var area = 0.0;
    for (var i = 1; i < pts.length; i++) {
      area += (pts[i].$1 - pts[i - 1].$1) * (pts[i].$2 + pts[i - 1].$2) / 2;
    }
    expect(area / 40, closeTo(7.8, 1e-4));
    expect(
      pts.map((p) => p.$2).reduce((a, b) => a > b ? a : b),
      closeTo(36, 1e-5),
    );
  });

  test(
    'CAN SVG traces satisfy differential and common-mode with microsecond axes',
    () {
      for (final (stem, delta) in [('can_levels', 2.0), ('can_suspect', 1.0)]) {
        final h = signalTrace(stem, 'CANH'),
            l = signalTrace(stem, 'CANL'),
            d = signalTrace(stem, 'H');
        expect(h.length, l.length);
        expect(h.length, d.length);
        for (var i = 0; i < h.length; i++) {
          expect(h[i].$1, closeTo(l[i].$1, 1e-5));
          expect((h[i].$2 + l[i].$2) / 2, closeTo(2.5, 1e-5));
          expect(h[i].$2 - l[i].$2, closeTo(d[i].$2, 1e-5));
        }
        expect(
          d.map((p) => p.$2).reduce((a, b) => a > b ? a : b),
          closeTo(delta, 1e-5),
        );
        expect(
          File('assets/images/oscilloscope/source/$stem.svg')
              .readAsStringSync(),
          contains('data-unit="µs"'),
        );
      }
    },
  );

  test(
    'LIN SVG has a 100 microsecond bit interval and distinct suspect dominant',
    () {
      final normal = signalTrace('lin_levels', 'LIN'),
          suspect = signalTrace('lin_suspect', 'LIN');
      expect(
        normal.map((p) => p.$2).reduce((a, b) => a < b ? a : b),
        closeTo(0, 1e-5),
      );
      expect(
        suspect.map((p) => p.$2).reduce((a, b) => a < b ? a : b),
        closeTo(3, 1e-5),
      );
      expect(
        normal.map((p) => p.$2).reduce((a, b) => a > b ? a : b),
        closeTo(12, 1e-5),
      );
      expect(normal.last.$1, closeTo(2, 1e-5));
      expect(normal[1].$1, closeTo(.2, 1e-5)); // Initial two recessive bits.
    },
  );

  test(
    'finite-window means in captions agree with actual drawn step areas',
    () {
      for (final (stem, id, expected) in [
        ('missing_pulse', 'S4', 1.125),
        ('hall_crank', 'A', 1.375),
        ('hall_crank', 'B', 1.375),
        ('crank_cam', 'CMP', .5),
        ('can_levels', 'CANH', 2.95),
        ('can_levels', 'CANL', 2.05),
        ('can_suspect', 'CANH', 2.725),
        ('can_suspect', 'CANL', 2.275),
        ('lin_levels', 'LIN', 6.6),
        ('lin_suspect', 'LIN', 7.95),
      ]) {
        final points = signalTrace(stem, id);
        var area = 0.0;
        for (var i = 1; i < points.length; i++) {
          area +=
              (points[i].$1 - points[i - 1].$1) *
              (points[i].$2 + points[i - 1].$2) /
              2;
        }
        expect(
          area / (points.last.$1 - points.first.$1),
          closeTo(expected, 1e-4),
          reason: '$stem $id',
        );
      }
    },
  );
}
