import 'dart:io';
import 'dart:math' as math;

import 'package:electrician/domain/lesson_attempt.dart';
import 'package:electrician/models/lesson.dart';
import 'package:electrician/models/lesson_block.dart';
import 'package:electrician/services/course_service.dart';
import 'package:electrician/services/progress_service.dart';
import 'package:electrician/simulation/oscilloscope_simulation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Lesson> loadSafety(int order) => CourseService().loadLesson(
  'assets/course/stage_12/lesson_${order.toString().padLeft(2, '0')}.json',
);
String drawing(String stem) =>
    File('assets/images/safety_systems/source/$stem.svg').readAsStringSync();
Map<String, String> attributes(String tag) => {
  for (final m in RegExp(r'([\w-]+)="([^"]*)"').allMatches(tag))
    m.group(1)!: m.group(2)!,
};
List<Map<String, String>> elements(String stem, String tag) =>
    RegExp('<$tag ([^>]+)')
        .allMatches(drawing(stem))
        .map((m) => attributes(m.group(1)!))
        .toList();
List<(double, double)> trace(String name) {
  final a = elements(
    'sensor_signals',
    'polyline',
  ).singleWhere((a) => a['id'] == 'trace-$name');
  final top = double.parse(a['data-y']!),
      lo = double.parse(a['data-low']!),
      hi = double.parse(a['data-high']!);
  return a['points']!.split(' ').map((s) {
    final p = s.split(',').map(double.parse).toList();
    return ((p[0] - 45) / 255 * 40, hi - (p[1] - top) / 120 * (hi - lo));
  }).toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    rootBundle.clear();
    SharedPreferences.setMockInitialValues({});
  });
  test(
    '13 modules and 122 unique ordered lessons retain the 112 lesson prefix',
    () async {
      final course = CourseService(),
          modules = await CourseService().loadModules();
      expect(modules.map((m) => m.id), List.generate(13, (i) => 'stage_$i'));
      expect(modules.map((m) => m.order), List.generate(13, (i) => i));
      final all = await course.loadAllLessons();
      expect(all, hasLength(122));
      expect(all.map((e) => e.lesson.id).toSet(), hasLength(122));
      expect(all[111].lesson.id, 'body_electronics_10');
      expect(
        all.skip(112).map((e) => e.lesson.id),
        List.generate(
          10,
          (i) => 'safety_systems_${(i + 1).toString().padLeft(2, '0')}',
        ),
      );
    },
  );
  test(
    'all registered metadata typed blocks and 17 bundled image references load',
    () async {
      final summaries = await CourseService().loadLessons('stage_12');
      expect(summaries, hasLength(10));
      var blocks = 0, tasks = 0;
      final images = <String>{};
      for (final s in summaries) {
        final lesson = await loadSafety(s.order);
        expect(lesson.id, s.id);
        expect(lesson.title, s.title);
        expect(lesson.order, s.order);
        expect(lesson.description, s.description);
        expect(lesson.estimatedMinutes, s.estimatedMinutes);
        expect(lesson.moduleId, 'stage_12');
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
      expect(blocks, 156);
      expect(tasks, 68);
      expect(images, hasLength(17));
      expect(
        (await loadSafety(9)).blocks.whereType<QuestionLessonBlock>(),
        hasLength(15),
      );
    },
  );
  test(
    'all old completions and unknown IDs survive explicit new completion',
    () async {
      final all = await CourseService().loadAllLessons(),
          service = ProgressService();
      final old = all.take(112).map((e) => e.lesson.id).toSet();
      SharedPreferences.setMockInitialValues({
        'completed_lessons': [...old, 'orphan'],
      });
      final before = await service.calculateProgress(all);
      expect(before.completedLessons, 112);
      expect(before.progress, 112 / 122);
      expect(before.nextLesson?.lesson.id, 'safety_systems_01');
      await service.completeLesson('safety_systems_01');
      expect(await service.getCompletedLessons(), {
        ...old,
        'orphan',
        'safety_systems_01',
      });
      final after = await service.calculateProgress(all);
      expect(after.completedLessons, 113);
      expect(after.progress, 113 / 122);
      expect(after.nextLesson?.lesson.id, 'safety_systems_02');
    },
  );
  test('real quiz needs all 15 answers and 12 correct, ordinary cases need every answer correct', () async {
    final quiz = await loadSafety(10), ordinary = await loadSafety(9);
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
    final cases = {
      for (var i = 0; i < ordinary.blocks.length; i++)
        if (isScoredLessonBlock(ordinary.blocks[i])) i: true,
    };
    expect(evaluateLessonAttempt(ordinary, cases).canComplete, isTrue);
    cases[cases.keys.first] = false;
    expect(evaluateLessonAttempt(ordinary, cases).canComplete, isFalse);
  });
  test('all authored numeric answers follow encoder Ohm and steady motion arithmetic', () async {
    final expected = {
      3: [48 * 125 / 60, .014 * 100],
      6: [10 * .2],
      10: [48 * 125 / 60, .014 * 100, 1100 / 25],
    };
    for (final e in expected.entries) {
      final actual = (await loadSafety(e.key)).blocks
          .whereType<CalculationLessonBlock>()
          .toList();
      expect(actual, hasLength(e.value.length));
      for (var i = 0; i < actual.length; i++) {
        expect(actual[i].correctValue, closeTo(e.value[i], 1e-10));
        expect(actual[i].tolerance, lessThanOrEqualTo(.01));
      }
    }
  });
  test('actual encoder geometry has 48 passive teeth and 48 alternating active pairs', () {
    expect(
      elements(
        'passive_sensor',
        'line',
      ).where((a) => a.containsKey('data-tooth')),
      hasLength(48),
    );
    final poles = elements(
      'active_sensor',
      'path',
    ).where((a) => a.containsKey('data-pole')).toList();
    expect(poles, hasLength(96));
    for (var i = 0; i < poles.length; i++) {
      expect(poles[i]['data-pole'], '$i');
      expect(poles[i]['fill'], isNot(poles[(i + 1) % 96]['fill']));
    }
    final nodes = {
      for (final a in elements('active_sensor', 'circle'))
        if (a.containsKey('data-voltage'))
          a['data-node']: double.parse(a['data-voltage']!),
    };
    expect(nodes['S+'], 12);
    expect(nodes['S-'], closeTo(.014 * 100, 1e-10));
    expect(nodes['N'], 0);
    expect(nodes['S+']! - nodes['S-']!, 10.6);
  });
  test('passive SVG points reconstruct 100 and 200 Hz sine at 4 and 8 V', () {
    for (final record in [('P1', 4.0, 100.0), ('P1fast', 8.0, 200.0)]) {
      final pts = trace(record.$1);
      expect(pts, hasLength(801));
      for (final p in pts) {
        expect(
          p.$2,
          closeTo(
            record.$2 * math.sin(2 * math.pi * record.$3 * p.$1 / 1000),
            .00001,
          ),
        );
      }
      final peaks = [
        for (var i = 1; i < pts.length - 1; i++)
          if (pts[i].$2 > pts[i - 1].$2 && pts[i].$2 > pts[i + 1].$2) pts[i].$1,
      ];
      expect(peaks, hasLength(record.$3 == 100 ? 4 : 8));
      expect(peaks[1] - peaks[0], closeTo(1000 / record.$3, .00001));
    }
  });
  test('active SVG encodes current and receiver voltage, 50 percent duty and Ohm law', () {
    final current = trace('A1current'), voltage = trace('A1receiver');
    expect(current, hasLength(voltage.length));
    var area = 0.0;
    for (var i = 0; i < current.length; i++) {
      expect(current[i].$2, anyOf(closeTo(7, 1e-6), closeTo(14, 1e-6)));
      expect(voltage[i].$2, closeTo(current[i].$2 / 1000 * 100, 1e-6));
      expect(12 - voltage[i].$2, inInclusiveRange(8, 14));
      if (i > 0) {
        area +=
            (current[i].$1 - current[i - 1].$1) *
            (current[i].$2 + current[i - 1].$2) /
            2;
      }
    }
    expect(area / 40, closeTo(10.5, 1e-6));
    final rises = [
      for (var i = 1; i < current.length; i++)
        if (current[i].$2 > current[i - 1].$2) current[i].$1,
    ];
    expect(rises[1] - rises[0], closeTo(10, 1e-6));
  });
  test(
    'existing virtual sine solves only passive voltage-scale exercises',
    () async {
      const sim = OscilloscopeSimulation();
      for (final order in [3, 10]) {
        final b = (await loadSafety(order)).blocks
            .whereType<OscilloscopeLessonBlock>()
            .single;
        expect(b.scenario.signal.maximum, 4);
        expect(b.scenario.signal.minimum, -4);
        bool solve(ScopeSettings settings) => sim.evaluate(
          exercise: b.exercise,
          target: b.scenario,
          selected: b.scenario,
          capture: sim.capture(b.scenario.signal, settings),
        );
        expect(solve(b.initialSettings), isFalse);
        expect(solve(b.initialSettings.copyWith(voltsPerDiv: 2)), isTrue);
      }
    },
  );
  test('actual hydraulic valve rows implement isolated hold and return accumulator', () {
    final states = elements(
      'hydraulic_modes',
      'g',
    ).where((a) => a.containsKey('data-inlet')).toList();
    expect(states.map((a) => (a['data-inlet'], a['data-outlet'])), [
      ('open', 'closed'),
      ('closed', 'closed'),
      ('closed', 'open'),
    ]);
    expect(drawing('hydraulic_modes'), contains('R → M'));
    expect(drawing('hydraulic_modes'), contains('Нет слива наружу'));
  });
  test(
    'actual live table follows common-time straight motion and turn geometry',
    () {
      final rows = elements(
        'wheel_live_data',
        'g',
      ).where((a) => a.containsKey('data-fl')).toList();
      expect(rows, hasLength(3));
      for (final k in ['fl', 'fr', 'rl', 'rr']) {
        expect(double.parse(rows[0]['data-$k']!), 0);
        expect(double.parse(rows[1]['data-$k']!), 30);
      }
      final radii = {
        'fl': math.sqrt(9.2 * 9.2 + 2.5 * 2.5),
        'fr': math.sqrt(10.8 * 10.8 + 2.5 * 2.5),
        'rl': 9.2,
        'rr': 10.8,
      };
      for (final e in radii.entries) {
        expect(
          double.parse(rows[2]['data-${e.key}']!),
          closeTo(20 * e.value / 10, 1e-8),
        );
      }
    },
  );
  test('K1 actual timeline separates invalid placeholder from speed and preserves uncertainty', () async {
    final rows = elements(
      'case_speed',
      'g',
    ).where((a) => a.containsKey('data-time')).toList();
    expect(rows.map((a) => double.parse(a['data-time']!)), [0, .1, .2, .3, .4]);
    expect(rows.map((a) => double.parse(a['data-speed']!)), [
      30,
      30,
      0,
      75,
      30,
    ]);
    expect(rows.map((a) => a['data-valid']), [
      'true',
      'true',
      'false',
      'true',
      'true',
    ]);
    final lesson = await loadSafety(9);
    final record = lesson.blocks
        .whereType<TextLessonBlock>()
        .singleWhere((b) => b.title == 'K1 • данные и неопределённость')
        .content;
    expect(record, contains('нет полного периода'));
    expect(record, contains('75 km/h не вычисляется из постоянного тока'));
    expect(48 * (30 / 3.6 / 2), 200);
    expect(.007 * 100, closeTo(.7, 1e-10));
    expect(12 - .007 * 100, 11.3);
    final qs = lesson.blocks
        .whereType<QuestionLessonBlock>()
        .where((b) => b.question.startsWith('K1:'))
        .toList();
    expect(qs, hasLength(3));
    expect(
      qs[1].answers[qs[1].correctAnswer],
      contains('конкретный компонент не определён'),
    );
  });
  test('SRS quiz answers preserve professional boundary and distinct indicator meaning', () async {
    final blocks = (await loadSafety(10)).blocks
        .where(isScoredLessonBlock)
        .toList();
    final expected = [
      'Нет, нужна квалифицированная работа по заводской процедуре',
      'Сохранить отчёт/историю и передать на профессиональную OEM-оценку',
      'Как разные сведения с применимостью по руководству',
    ];
    for (var i = 0; i < 3; i++) {
      final block = blocks[11 + i];
      expect(block, isA<QuestionLessonBlock>());
      final q = block as QuestionLessonBlock;
      expect(q.answers[q.correctAnswer], expected[i]);
    }
  });
  test('K2 drawn independent count and elapsed times expose scale without proving pole count', () async {
    final counts = elements('case_hub', 'rect')
        .where((a) => a.containsKey('data-count'))
        .map((a) => double.parse(a['data-count']!))
        .toList();
    expect(counts, [1200, 1100]);
    expect(counts.last / 25, 44);
    expect(3.6 * 2 * (counts.last / 6) / 48, 27.5);
    expect(3.6 * 2 * (counts.last / 12) / 48, 13.75);
    final qs = (await loadSafety(9)).blocks
        .whereType<QuestionLessonBlock>()
        .where((b) => b.question.startsWith('K2:'))
        .toList();
    expect(qs, hasLength(3));
    expect(
      qs.first.answers[qs.first.correctAnswer],
      contains('ещё не доказано'),
    );
  });
  test('K3 drawn digital motion contradicts rest and steady turn without assigning component', () async {
    final rows = elements(
      'case_esc',
      'g',
    ).where((a) => a.containsKey('data-yaw')).toList();
    expect(double.parse(rows[0]['data-v']!), 0);
    expect(double.parse(rows[0]['data-yaw']!), 6);
    final v = double.parse(rows[1]['data-v']!) / 3.6,
        r = double.parse(rows[1]['data-yaw']!) * math.pi / 180,
        ay = double.parse(rows[1]['data-ay']!);
    expect(v * r, closeTo(3.04734, .0001));
    expect(v * r - ay, greaterThan(1));
    final qs = (await loadSafety(9)).blocks
        .whereType<QuestionLessonBlock>()
        .where((b) => b.question.startsWith('K3:'))
        .toList();
    expect(qs, hasLength(3));
    expect(
      qs[1].answers[qs[1].correctAnswer],
      contains('источника, единиц/осей/времени'),
    );
    expect(qs[2].answers[qs[2].correctAnswer], contains('со специалистом'));
  });
  test(
    'K4 actual synchronous potentials satisfy KVL and local supply loss',
    () {
      final rows = elements(
        'case_communication',
        'g',
      ).where((a) => a.containsKey('data-source')).toList();
      expect(rows, hasLength(3));
      for (final row in rows) {
        final source = double.parse(row['data-source']!),
            p = double.parse(row['data-p']!),
            g = double.parse(row['data-g']!),
            local = double.parse(row['data-local']!);
        expect(local, closeTo(p - g, 1e-10));
        expect(source - p + local + g, closeTo(source, 1e-10));
      }
      expect(
        double.parse(rows[1]['data-source']!) -
            double.parse(rows[1]['data-p']!),
        4,
      );
      expect(rows[1]['data-local'], '8.5');
    },
  );
  test(
    'SRS lessons and K5 allow conceptual images and prepared messages only',
    () async {
      for (final order in [7, 8]) {
        final lesson = await loadSafety(order);
        for (final b in lesson.blocks) {
          expect(
            b.type,
            isIn(['text', 'image', 'question', 'warning', 'remember']),
          );
        }
      }
      final cases = (await loadSafety(9)).blocks;
      final start = cases.indexWhere(
        (b) => b is TextLessonBlock && b.title.startsWith('K5'),
      );
      expect(start, greaterThan(0));
      for (final b in cases.skip(start)) {
        expect(
          b.type,
          isIn(['text', 'image', 'question', 'warning', 'remember']),
        );
      }
      final svg = drawing('srs_concept');
      expect(svg, contains('смысловые связи'));
      expect(svg, contains('резерва энергии'));
      expect(
        elements(
          'srs_concept',
          'circle',
        ).where((a) => a.containsKey('data-voltage')),
        isEmpty,
      );
      final text = (await loadSafety(8)).blocks
          .whereType<WarningLessonBlock>()
          .map((b) => b.content)
          .join(' ');
      for (final forbidden in [
        'прямые измерения',
        'тестовая лампа',
        'внешнее напряжение',
        'перемычки',
        'заводская документация',
      ]) {
        expect(text, contains(forbidden));
      }
      final questions = cases
          .whereType<QuestionLessonBlock>()
          .where((b) => b.question.startsWith('K5:'))
          .toList();
      expect(questions, hasLength(3));
      final answers = questions
          .map((b) => b.answers[b.correctAnswer])
          .join(' ');
      expect(answers, contains('специалист'));
      expect(answers, contains('отчёт'));
    },
  );
}
