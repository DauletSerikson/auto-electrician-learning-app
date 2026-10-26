import 'dart:io';
import 'dart:math' as math;

import 'package:electrician/domain/lesson_attempt.dart';
import 'package:electrician/models/lesson.dart';
import 'package:electrician/models/lesson_block.dart';
import 'package:electrician/services/course_service.dart';
import 'package:electrician/services/progress_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Lesson> loadHybrid(int order) => CourseService().loadLesson(
  'assets/course/stage_13/lesson_${order.toString().padLeft(2, '0')}.json',
);
String drawing(String stem) =>
    File('assets/images/hybrid_ev/source/$stem.svg').readAsStringSync();
Map<String, String> attributes(String tag) => {
  for (final m in RegExp(r'([\w-]+)="([^"]*)"').allMatches(tag))
    m.group(1)!: m.group(2)!,
};
List<Map<String, String>> elements(String stem, String tag) =>
    RegExp('<$tag ([^>]+)')
        .allMatches(drawing(stem))
        .map((m) => attributes(m.group(1)!))
        .toList();
List<Map<String, String>> cards(String stem) => elements(
  stem,
  'g',
).where((a) => (a['id'] ?? '').startsWith('card-')).toList();
double n(Map<String, String> row, String key) =>
    double.parse(row['data-$key']!);
List<(double, double)> curve(String stem, String id) {
  final a = elements(stem, 'polyline').singleWhere((a) => a['id'] == id);
  return a['points']!.split(' ').map((s) {
    final p = s.split(',').map(double.parse).toList();
    return (
      (p[0] - 50) / 240 * 1.2,
      (double.parse(a['data-top']!) + 160 - p[1]) /
          160 *
          double.parse(a['data-high']!),
    );
  }).toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    rootBundle.clear();
    SharedPreferences.setMockInitialValues({});
  });
  test(
    '14 modules 132 unique ordered lessons retain the 122 lesson prefix',
    () async {
      final service = CourseService(),
          modules = await CourseService().loadModules();
      expect(modules.map((m) => m.id), List.generate(14, (i) => 'stage_$i'));
      expect(modules.map((m) => m.order), List.generate(14, (i) => i));
      final all = await service.loadAllLessons();
      expect(all, hasLength(132));
      expect(all.map((e) => e.lesson.id).toSet(), hasLength(132));
      expect(all[121].lesson.id, 'safety_systems_10');
      expect(
        all.skip(122).map((e) => e.lesson.id),
        List.generate(
          10,
          (i) => 'hybrid_ev_${(i + 1).toString().padLeft(2, '0')}',
        ),
      );
    },
  );
  test(
    'real indexed JSON metadata typed blocks and all image references load',
    () async {
      final summaries = await CourseService().loadLessons('stage_13');
      expect(summaries, hasLength(10));
      var blocks = 0, tasks = 0;
      final images = <String>{};
      for (final summary in summaries) {
        final lesson = await loadHybrid(summary.order);
        expect(lesson.id, summary.id);
        expect(lesson.order, summary.order);
        expect(lesson.title, summary.title);
        expect(lesson.description, summary.description);
        expect(lesson.estimatedMinutes, summary.estimatedMinutes);
        expect(lesson.moduleId, 'stage_13');
        expect(lesson.completion.isQuiz, summary.order == 10);
        expect(lesson.completion.passingScore, summary.order == 10 ? 80 : null);
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
          if (b case ImageLessonBlock(:final asset, :final caption)) {
            images.add(asset);
            expect(caption, isNotEmpty);
            expect(await rootBundle.load(asset), isNotNull);
          }
        }
      }
      expect(blocks, 152);
      expect(tasks, 68);
      expect(images, hasLength(20));
    },
  );
  test(
    'all 122 old completions plus unknown IDs survive new explicit completion',
    () async {
      final all = await CourseService().loadAllLessons(),
          service = ProgressService();
      final old = all.take(122).map((e) => e.lesson.id).toSet();
      SharedPreferences.setMockInitialValues({
        'completed_lessons': [...old, 'orphan'],
      });
      final before = await service.calculateProgress(all);
      expect(before.completedLessons, 122);
      expect(before.progress, 122 / 132);
      expect(before.nextLesson?.lesson.id, 'hybrid_ev_01');
      await service.completeLesson('hybrid_ev_01');
      expect(await service.getCompletedLessons(), {
        ...old,
        'orphan',
        'hybrid_ev_01',
      });
      final after = await ProgressService().calculateProgress(all);
      expect(after.completedLessons, 123);
      expect(after.progress, 123 / 132);
      expect(after.nextLesson?.lesson.id, 'hybrid_ev_02');
      expect((await SharedPreferences.getInstance()).getKeys(), {
        'completed_lessons',
      });
    },
  );
  test(
    'real quiz needs all 15 answers and 12 correct, ordinary cases all correct',
    () async {
      final quiz = await loadHybrid(10), lesson = await loadHybrid(9);
      final ids = [
        for (var i = 0; i < quiz.blocks.length; i++)
          if (isScoredLessonBlock(quiz.blocks[i])) i,
      ];
      expect(ids, hasLength(15));
      expect(quiz.blocks.whereType<QuestionLessonBlock>(), hasLength(12));
      expect(quiz.blocks.whereType<CalculationLessonBlock>(), hasLength(3));
      final answers = {for (var i = 0; i < 15; i++) ids[i]: i < 11};
      expect(evaluateLessonAttempt(quiz, answers).canComplete, isFalse);
      answers[ids[11]] = true;
      expect(evaluateLessonAttempt(quiz, answers).scorePercent, 80);
      expect(evaluateLessonAttempt(quiz, answers).canComplete, isTrue);
      answers.remove(ids.last);
      expect(evaluateLessonAttempt(quiz, answers).canComplete, isFalse);
      final cases = {
        for (var i = 0; i < lesson.blocks.length; i++)
          if (isScoredLessonBlock(lesson.blocks[i])) i: true,
      };
      expect(cases, hasLength(15));
      expect(evaluateLessonAttempt(lesson, cases).canComplete, isTrue);
      cases[cases.keys.first] = false;
      expect(evaluateLessonAttempt(lesson, cases).canComplete, isFalse);
    },
  );
  test('all authored calculations use independent arithmetic and meaningful tolerances', () async {
    final expected = <int, List<double>>{
      3: [2 * 50, 96 * 3.75 * 2 * 50 / 1000],
      4: [36 * .96 * .90, 20 * .90 * .96],
      5: [700 / .90],
      6: [230 * 16 * .90 / 1000, 6.624 / 3.312],
      7: [360 * (1 - math.exp(-.48 / (120 * .002)))],
      8: [.1 * 3500 * 5],
      10: [360 * 100 / 1000, 700 / .9, 360 * (1 - math.exp(-2))],
    };
    for (final e in expected.entries) {
      final actual = (await loadHybrid(e.key)).blocks
          .whereType<CalculationLessonBlock>()
          .toList();
      expect(actual, hasLength(e.value.length));
      for (var i = 0; i < actual.length; i++) {
        expect(actual[i].correctValue, closeTo(e.value[i], .00001));
        expect(actual[i].tolerance, greaterThan(0));
        expect(actual[i].tolerance, lessThanOrEqualTo(.01));
        expect(actual[i].unit.length, lessThanOrEqualTo(4));
      }
    }
  });
  test(
    'B0 actual graphic distinguishes 96s2p capacity energy and group count',
    () {
      final a = cards('battery_groups'),
          cellv = n(a[0], 'cellv'),
          cellah = n(a[0], 'cellah'),
          p = n(a[1], 'parallel'),
          s = n(a[2], 'series');
      expect(s * p, 192);
      expect(s, 96);
      expect(s * cellv, 360);
      expect(p * cellah, 100);
      expect(s * cellv * p * cellah / 1000, 36);
      expect(drawing('battery_groups'), contains('360 V / 100 Ah / 36 kWh'));
      expect(drawing('battery_groups'), contains('96 групповых напряжений'));
    },
  );
  test('M1 actual directed flow respects efficiency losses torque and regeneration', () {
    List<double> powers(String stem) => elements(stem, 'g')
        .where((a) => a.containsKey('data-power'))
        .map((a) => n(a, 'power'))
        .toList();
    final drive = powers('drive_flow'), regen = powers('regen_flow');
    expect(drive, hasLength(3));
    expect(regen, hasLength(3));
    expect(drive[1] / drive[0], .96);
    expect(drive[2] / drive[1], closeTo(.90, 1e-10));
    expect(drive.first - drive.last, 4896);
    expect(drive.last / (2 * math.pi * 3000 / 60), closeTo(99.007107, .000001));
    expect(regen[1] / regen[0], .90);
    expect(regen[2] / regen[1], .96);
    expect(regen.first - regen.last, 2720);
    expect(regen.last / 360, 48);
  });
  test('D0 actual LV balance reconstructs input output and heat rather than lossless ideal', () {
    final a = cards('dcdc_lv'),
        input = n(a[0], 'input'),
        eta = n(a[0], 'eta'),
        output = n(a[1], 'lv') * (n(a[1], 'load') + n(a[1], 'charge'));
    expect(output, 700);
    expect(input, closeTo(output / eta, 1e-6));
    expect(input - output, closeTo(77.777778, 1e-6));
    expect(input / n(a[0], 'hv'), closeTo(2.160494, 1e-6));
  });
  test(
    'C0 actual AC conditions yield OBC output and nonzero thermal loss',
    () async {
      final a = cards('ac_dc_charging').first;
      final input = n(a, 'vrms') * n(a, 'irms') * n(a, 'pf'),
          output = input * n(a, 'eta');
      expect(input, 3680);
      expect(output, 3312);
      expect(input - output, 368);
      expect(output / 360, 9.2);
      final question = (await loadHybrid(10)).blocks
          .whereType<QuestionLessonBlock>()
          .singleWhere((q) => q.question.startsWith('8.'));
      expect(question.answers[question.correctAnswer], contains('защиты'));
    },
  );
  test('P0 actual voltage and current SVG samples obey RC and finite energy balance', () {
    final a = cards('precharge_concept').first,
        u = n(a, 'u'),
        res = n(a, 'r'),
        cap = n(a, 'c'),
        tau = res * cap;
    final voltage = curve('precharge_plot', 'rc-voltage'),
        current = curve('precharge_plot', 'rc-current');
    expect(voltage, hasLength(601));
    expect(current, hasLength(601));
    expect(n(a, 'initial'), 0);
    expect(tau, .24);
    for (var i = 0; i < voltage.length; i++) {
      final p = voltage[i], ip = current[i];
      expect(p.$2, closeTo(u * (1 - math.exp(-p.$1 / tau)), .000001));
      expect(ip.$2, closeTo((u / res) * math.exp(-ip.$1 / tau), .000001));
      expect(p.$2 + ip.$2 * res, closeTo(u, .00001));
      if (i > 0) {
        expect(p.$2, greaterThan(voltage[i - 1].$2));
        expect(ip.$2, lessThan(current[i - 1].$2));
      }
    }
    expect(voltage.first.$2, 0);
    expect(voltage.last.$2, lessThan(u));
    final t90 = -tau * math.log(.1);
    expect(t90, closeTo(.5526204223, 1e-9));
    expect(.5 * cap * u * u, 129.6);
    expect(cap * u * u, 259.2);
    // Integrate actual polyline i and i² over the finite 1.2 s capture.
    var charge = 0.0, loss = 0.0;
    for (var i = 1; i < current.length; i++) {
      final dt = current[i].$1 - current[i - 1].$1,
          ia = current[i - 1].$2,
          ib = current[i].$2;
      charge += dt * (ia + ib) / 2;
      loss += res * dt * (ia * ia + ia * ib + ib * ib) / 3;
    }
    final stored = .5 * cap * math.pow(voltage.last.$2, 2);
    expect(u * charge, closeTo(stored + loss, .01));
  });
  test(
    'K3 actual record misses model goal without inventing fault R or safe zero',
    () async {
      final fault = curve('case_precharge', 'rc-fault');
      expect(fault.length, 5);
      final times = [0, .24, .48, .72, .96], values = [0, 80, 120, 150, 170];
      for (var i = 0; i < 5; i++) {
        expect(fault[i].$1, closeTo(times[i], 1e-9));
        expect(fault[i].$2, values[i]);
      }
      expect(fault.last.$2, lessThan(.9 * 360));
      expect(.5 * .002 * 170 * 170, closeTo(28.9, 1e-10));
      final qs = (await loadHybrid(9)).blocks
          .whereType<QuestionLessonBlock>()
          .where((q) => q.question.startsWith('K3:'))
          .toList();
      expect(qs, hasLength(3));
      expect(qs[1].answers[qs[1].correctAnswer], startsWith('Нет:'));
      expect(
        qs[2].answers[qs[2].correctAnswer],
        contains('прекратить самостоятельные попытки'),
      );
    },
  );
  test(
    'K1 actual LV current balance cannot prove local HV input or efficiency',
    () async {
      final a = cards('case_dcdc');
      expect(n(a[1], 'load'), n(a[1], 'converter') + n(a[1], 'battery'));
      expect(n(a[1], 'lv') * n(a[1], 'load'), 476);
      expect(n(a[0], 'bus'), 360);
      final qs = (await loadHybrid(9)).blocks
          .whereType<QuestionLessonBlock>()
          .where((q) => q.question.startsWith('K1:'))
          .toList();
      expect(qs, hasLength(3));
      expect(qs[1].answers[qs[1].correctAnswer], contains('неизвестны'));
      expect(qs[2].answers[qs[2].correctAnswer], contains('специалисту'));
    },
  );
  test('K2 actual cold and warm cards keep port heater and battery boundaries separate', () {
    final rows = cards('case_cold_charge');
    expect(rows, hasLength(2));
    for (final row in rows) {
      final battery = n(row, 'v') * n(row, 'current');
      expect(n(row, 'port'), battery + n(row, 'heater'));
    }
    expect(n(rows[0], 'port') / n(rows[0], 'v'), closeTo(15.555556, 1e-6));
    expect(n(rows[0], 'current'), 10);
    expect(n(rows[1], 'current'), 100);
  });
  test('K4 actual 95 plus one group sums actual voltages and power without nominal substitution', () async {
    final rows = cards('case_bms_spread');
    expect(rows, hasLength(2));
    for (final row in rows) {
      expect(n(row, 'count'), 95);
      expect(
        n(row, 'pack'),
        closeTo(n(row, 'count') * n(row, 'others') + n(row, 'suspect'), 1e-10),
      );
    }
    expect(n(rows[0], 'others') - n(rows[0], 'suspect'), .25);
    expect(n(rows[1], 'others') - n(rows[1], 'suspect'), .5);
    expect(n(rows[1], 'pack') * n(rows[1], 'current'), 17735);
    final qs = (await loadHybrid(9)).blocks
        .whereType<QuestionLessonBlock>()
        .where((q) => q.question.startsWith('K4:'))
        .toList();
    expect(
      qs.first.answers[qs.first.correctAnswer],
      contains('не различаются'),
    );
  });
  test('K5 actual inverter-branch current and shaft power respect M1 without proving pump cause', () async {
    final rows = cards('case_thermal_limit');
    for (final row in rows) {
      expect(
        n(row, 'shaft'),
        closeTo(n(row, 'u') * n(row, 'i') * .96 * .90, 1e-8),
      );
    }
    expect(n(rows[1], 'shaft') / n(rows[0], 'shaft'), .5);
    expect(n(rows[1], 'rpm'), 0);
    expect(n(rows[1], 'tinv'), 110);
    final qs = (await loadHybrid(9)).blocks
        .whereType<QuestionLessonBlock>()
        .where((q) => q.question.startsWith('K5:'))
        .toList();
    expect(qs[1].answers[qs[1].correctAnswer], startsWith('Нет:'));
    expect(
      qs[2].answers[qs[2].correctAnswer],
      contains('Прекратить эксплуатацию'),
    );
  });
  test(
    'T0 actual temperatures flow and cp reconstruct heat not pump power',
    () {
      final a = cards('thermal_paths').first;
      final heat = n(a, 'flow') * n(a, 'cp') * (n(a, 'tout') - n(a, 'tin'));
      expect(heat, 1750);
      expect(heat * 10 / 1000, 17.5);
      expect(drawing('thermal_paths'), contains('Не потребление насоса'));
    },
  );
  test(
    'all lessons stay within conceptual Q C whitelist and explicit HV boundary',
    () async {
      for (var order = 1; order <= 10; order++) {
        final lesson = await loadHybrid(order);
        final warning = lesson.blocks
            .whereType<WarningLessonBlock>()
            .map((b) => b.content)
            .join(' ');
        for (final phrase in [
          'Выключение автомобиля не гарантирует',
          'принудительное включение контакторов',
          'обход HVIL',
          'квалифицированный специалист',
        ]) {
          expect(warning, contains(phrase), reason: 'lesson $order');
        }
        for (final block in lesson.blocks) {
          expect(
            block.type,
            isIn([
              'text',
              'image',
              'question',
              'calculation',
              'warning',
              'remember',
            ]),
          );
        }
      }
      final quiz = (await loadHybrid(10)).blocks
          .where(isScoredLessonBlock)
          .toList();
      for (final i in [2, 10, 11, 14]) {
        expect(quiz[i], isA<QuestionLessonBlock>());
      }
      final hv = quiz[2] as QuestionLessonBlock;
      expect(hv.answers[hv.correctAnswer], startsWith('Нет:'));
      final next = quiz[14] as QuestionLessonBlock;
      expect(
        next.answers[next.correctAnswer],
        contains('Прекратить самостоятельную диагностику'),
      );
    },
  );
}
