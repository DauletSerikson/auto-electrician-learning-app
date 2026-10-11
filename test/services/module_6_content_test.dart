import 'package:electrician/domain/course_progress.dart';
import 'package:electrician/domain/lesson_attempt.dart';
import 'package:electrician/models/lesson_block.dart';
import 'package:electrician/simulation/conductor_measurement_simulation.dart';
import 'package:electrician/simulation/multimeter.dart';
import 'package:electrician/services/course_service.dart';
import 'package:electrician/services/progress_service.dart';
import 'package:electrician/simulation/diagnostic_case_measurements.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final course = CourseService();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('module 6 keeps its position and its ten lessons have consecutive stable IDs', () async {
    final modules = await course.loadModules();
    expect(modules.map((m) => m.id), [
      'stage_0',
      'stage_1',
      'stage_2',
      'stage_3',
      'stage_4',
      'stage_5',
      'stage_6',
    ]);
    expect(modules[5].order, 5);
    expect(
      modules[5].title,
      'Диагностика электрических неисправностей автомобиля',
    );
    final summaries = await course.loadLessons('stage_5');
    expect(summaries.map((s) => s.order), List.generate(10, (i) => i + 1));
    expect(
      summaries.map((s) => s.id),
      List.generate(
        10,
        (i) => 'diagnostics_${(i + 1).toString().padLeft(2, '0')}',
      ),
    );
    final all = await course.loadAllLessons();
    final previous = all
        .where((l) => l.module.order < 5)
        .map((l) => l.lesson.id)
        .toSet();
    final added = summaries.map((s) => s.id).toSet();
    expect(previous, hasLength(42));
    expect(added, hasLength(10));
    expect(previous.intersection(added), isEmpty);
    expect(all, hasLength(62));
  });

  test(
    'every new lesson parses with matching metadata and bundled references',
    () async {
      var count = 0;
      for (final summary in await course.loadLessons('stage_5')) {
        final lesson = await course.loadLesson(
          'assets/course/stage_5/${summary.file}',
        );
        expect(lesson.id, summary.id);
        expect(lesson.moduleId, 'stage_5');
        expect(lesson.order, summary.order);
        expect(lesson.title, summary.title);
        expect(lesson.description, summary.description);
        expect(lesson.estimatedMinutes, summary.estimatedMinutes);
        expect(lesson.description.trim(), isNotEmpty);
        expect(
          lesson.estimatedMinutes,
          summary.order >= 9 ? 25 : inInclusiveRange(10, 20),
        );
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
      expect(count, 154);
    },
  );

  test('ordinary new lessons require every scored task correct', () async {
    for (final summary in (await course.loadLessons('stage_5')).take(9)) {
      final lesson = await course.loadLesson(
        'assets/course/stage_5/${summary.file}',
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
        'assets/course/stage_5/lesson_10.json',
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
    'all 42 previous completions survive course expansion and new writes',
    () async {
      final all = await course.loadAllLessons();
      final oldIds = all.take(42).map((l) => l.lesson.id).toSet();
      SharedPreferences.setMockInitialValues({
        'completed_lessons': oldIds.toList(),
      });
      final service = ProgressService();
      final before = await service.calculateProgress(all);
      expect(before.completedLessons, 42);
      expect(before.totalLessons, 62);
      expect(before.progress, 42 / 62);
      expect(before.nextLesson?.lesson.id, 'diagnostics_01');
      for (final id in oldIds) {
        expect(await service.isLessonCompleted(id), isTrue);
      }
      await service.completeLesson('diagnostics_01');
      final reloaded = ProgressService();
      expect(await reloaded.getCompletedLessons(), {
        ...oldIds,
        'diagnostics_01',
      });
      final after = await reloaded.calculateProgress(all);
      expect(after.completedLessons, 43);
      expect(after.nextLesson?.lesson.id, 'diagnostics_02');
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      expect(prefs.getKeys(), {'completed_lessons'});
    },
  );

  test('all 62 completed yields full progress with no next lesson', () async {
    final all = await course.loadAllLessons();
    final progress = calculateCourseProgress(
      all,
      all.map((l) => l.lesson.id).toSet(),
    );
    expect(progress.totalLessons, 62);
    expect(progress.completedLessons, 62);
    expect(progress.progress, 1);
    expect(progress.nextLesson, isNull);
  });

  Future<String> card(int order, String title) async {
    final lesson = await course.loadLesson(
      'assets/course/stage_5/lesson_${order.toString().padLeft(2, '0')}.json',
    );
    return lesson.blocks
        .whereType<TextLessonBlock>()
        .singleWhere((b) => b.title == title)
        .content;
  }

  // Extract numbers from the actual learning text; no independent mock table.
  double reading(String text, String label) {
    final match = RegExp(
      '${RegExp.escape(label)} = ([-−]?\\d+(?:,\\d+)?)',
      caseSensitive: false,
    ).firstMatch(text);
    expect(match, isNotNull, reason: '$label absent in $text');
    return double.parse(
      match!.group(1)!.replaceAll(',', '.').replaceAll('−', '-'),
    );
  }

  test(
    'D01 nominal load and unloaded harness preserve distinct conclusions',
    () async {
      final on = await card(1, 'D01 • Эталон ON');
      expect(reading(on, 'B1+/N'), 12.6);
      expect(reading(on, 'Q/N'), 12.6);
      expect(reading(on, 'G1/N'), 0);
      expect(reading(on, 'I') * reading(on, 'R'), closeTo(12.6, 1e-9));
      final off = await card(1, 'D01 • Без рабочего тока');
      expect(reading(off, 'I'), 0);
      expect(reading(off, 'Q/N'), 12.6);
      expect(off, contains('не имеет заданного потенциала'));
      final lesson = await course.loadLesson(
        'assets/course/stage_5/lesson_01.json',
      );
      expect(
        lesson.blocks
            .whereType<BatteryVoltageMeasurementLessonBlock>()
            .single
            .sourceVoltage,
        12.6,
      );
    },
  );

  test(
    'D02 real case requires all four safe records and preserves ON evidence',
    () async {
      final lesson = await course.loadLesson(
        'assets/course/stage_5/lesson_09.json',
      );
      final block = lesson.blocks.whereType<DiagnosticCaseLessonBlock>().single;
      expect(block.faultType, 'positiveWireOpen');
      expect(block.sourceVoltage, 12.6);
      final on = DiagnosticCaseMeasurements(
        faultType: block.faultType,
        sourceVoltage: block.sourceVoltage,
        powered: true,
      );
      final off = DiagnosticCaseMeasurements(
        faultType: block.faultType,
        sourceVoltage: block.sourceVoltage,
        powered: false,
      );
      final text = await card(9, 'D02 • Сопоставление результата');
      expect(
        (on.resultFor(
          DiagnosticTest.fuseOutputVoltage,
        ) as DiagnosticCaseVoltage).value,
        reading(text, 'P/N'),
      );
      expect(
        (on.resultFor(
          DiagnosticTest.lampPositiveVoltage,
        ) as DiagnosticCaseVoltage).value,
        reading(text, 'Q/N'),
      );
      expect(
        on.resultFor(DiagnosticTest.wireContinuity),
        isA<DiagnosticCaseForbidden>(),
      );
      final records = [
        for (final test in [
          DiagnosticTest.batteryVoltage,
          DiagnosticTest.fuseOutputVoltage,
          DiagnosticTest.lampPositiveVoltage,
        ])
          DiagnosticMeasurementRecord(
            test: test,
            result: on.resultFor(test),
            powered: true,
          ),
        DiagnosticMeasurementRecord(
          test: DiagnosticTest.wireContinuity,
          result: off.resultFor(DiagnosticTest.wireContinuity),
          powered: false,
        ),
      ];
      expect(hasPositiveWireOpenEvidence(records, block.sourceVoltage), isTrue);
      for (var i = 0; i < records.length; i++) {
        expect(
          hasPositiveWireOpenEvidence([
            ...records.take(i),
            ...records.skip(i + 1),
          ], block.sourceVoltage),
          isFalse,
        );
      }
      expect(records[1].powered, isTrue);
      expect((records[1].result as DiagnosticCaseVoltage).value, 12.6);
      expect(
        text,
        contains('не доказывают потенциал произвольной плавающей точки'),
      );
    },
  );

  test(
    'D03 actual 80-ohm exercise is finite silent conduction, not OL',
    () async {
      final lesson = await course.loadLesson(
        'assets/course/stage_5/lesson_03.json',
      );
      final blocks = lesson.blocks
          .whereType<WireContinuityMeasurementLessonBlock>()
          .toList();
      expect(blocks, hasLength(2));
      expect(blocks.map((b) => b.initiallyPowered), [false, false]);
      expect(blocks.map((b) => b.initiallyBroken), [true, false]);
      expect(blocks.map((b) => b.goodResistance), [0.3, 80]);
      for (final b in blocks) {
        final simulation = ConductorMeasurementSimulation(
          mode: MultimeterMode.continuity,
          redPort: MultimeterPort.voltageResistance,
          redWirePoint: WirePoint.pointA,
          blackWirePoint: WirePoint.pointB,
          powered: b.initiallyPowered,
          broken: b.initiallyBroken,
          resistance: b.goodResistance,
          kind: ConductorMeasurementKind.continuity,
        );
        expect(simulation.success, isTrue);
        expect(simulation.continuityBeep, isFalse);
        if (b.initiallyBroken) {
          expect(simulation.readout, isA<ConductorOpenLoopReadout>());
        } else {
          expect((simulation.readout as ConductorNumericReadout).value, 80);
        }
      }
      expect(await card(3, 'D03 • Изолированные образцы'), contains('50 Ω'));
    },
  );

  test('D04 isolated short is in Wdown; healthy load is excluded', () async {
    final text = await card(4, 'D04 • Данные изоляции');
    expect(reading(text, 'R(выход держателя F1,G)'), 0.2);
    expect(text, contains('R(Wup,G) = OL'));
    expect(reading(text, 'R(Wdown,G)'), 0.2);
    expect(text, contains('F1 и нагрузка сняты'));
    expect(text, contains('нет ECU или параллельных путей'));
    expect(text, contains('остаточное U исключено'));
  });

  test(
    'D05 interwire connection only after removing all external paths',
    () async {
      final text = await card(4, 'D05 • Межпроводная связь');
      expect(reading(text, 'R(A1,B1)'), 0.4);
      expect(text, contains('Все источники, нагрузки/ECU отсоединены'));
      expect(text, contains('скрытых штатных связей нет'));
      expect(text, contains('в исправном эквиваленте здесь OL'));
    },
  );

  test('D06 overload through load is distinct from a bypass short and timing curve', () async {
    final text = await card(4, 'D06 • До открытия F1');
    expect(reading(text, 'F1'), 5);
    expect(reading(text, 'I'), 8);
    expect(reading(text, 'R нагрузки') * reading(text, 'I'), 12);
    expect(text, contains('Нет обхода H1'));
    final after = await card(4, 'D06 • После открытия F1');
    expect(reading(after, 'вход F1/N'), 12);
    expect(reading(after, 'выход F1/N'), 0);
    expect(reading(after, 'I'), 0);
    expect(after, contains('Точное время открытия нельзя вывести'));
  });

  test(
    'D07 compatible positive-loss model matches ON/OFF and calculations',
    () async {
      final lesson = await course.loadLesson(
        'assets/course/stage_5/lesson_05.json',
      );
      final block = lesson.blocks.whereType<VoltageDropLessonBlock>().single;
      final on = await card(5, 'D07 • Измерения ON');
      final off = await card(5, 'D07 • Измерения OFF');
      expect(block.sourceVoltage, reading(on, 'P/N'));
      expect(block.faultVoltageDrop, reading(on, 'U(P,Q)'));
      expect(block.initiallyLoaded, isFalse);
      expect(
        reading(on, 'P/N') - reading(on, 'Q/N'),
        closeTo(block.faultVoltageDrop, 1e-9),
      );
      expect(reading(on, 'I') * reading(on, 'Rк'), block.faultVoltageDrop);
      expect(reading(off, 'I'), 0);
      expect(reading(off, 'P/N') - reading(off, 'Q/N'), 0);
      expect(
        lesson.blocks.whereType<CalculationLessonBlock>().map(
          (b) => b.correctValue,
        ),
        [0.6, 9.6],
      );
      expect((await card(2, 'D07 • Измерения ON')), contains('Q/N = 10,2 V'));
    },
  );

  test('D08 ground loss requires current and load voltage is 11.4 V', () async {
    final text = await card(2, 'D08 • Измерения ON');
    expect(reading(text, 'I') * reading(text, 'Rк'), reading(text, 'T/N'));
    expect(
      reading(text, 'I') * reading(text, 'R H1'),
      closeTo(12.6 - reading(text, 'T/N'), 1e-9),
    );
    final lesson = await course.loadLesson(
      'assets/course/stage_5/lesson_02.json',
    );
    expect(
      lesson.blocks.whereType<CalculationLessonBlock>().single.correctValue,
      11.4,
    );
    expect(lesson.blocks.whereType<VoltageDropLessonBlock>(), isEmpty);
    expect(reading(await card(2, 'D08 • Без тока'), 'T/N'), 0);
  });

  test('D09 fuse output zero is distinguished from absent input', () async {
    final open = await card(6, 'D09 • Открытый F1');
    final noInput = await card(6, 'D09 • Нет входного питания');
    expect(reading(open, 'A/N'), 12.6);
    expect(reading(noInput, 'A/N'), 0);
    expect(reading(open, 'P/N'), 0);
    expect(reading(noInput, 'P/N'), 0);
    expect(open, contains('Ω F1 = OL'));
    expect(noInput, contains('Сам F1 исправен'));
  });

  test(
    'D10 coil command and loaded power contact are separate boundaries',
    () async {
      final off = await card(6, 'D10 • Нет команды');
      expect(reading(off, '86/N') - reading(off, '85/N'), 0);
      expect(reading(off, '30/N') - reading(off, '87/N'), 12.6);
      expect(reading(off, 'I H1'), 0);
      final on = await card(6, 'D10 • Потери контакта ON');
      expect(reading(on, '86/N') - reading(on, '85/N'), 12.6);
      expect(reading(on, '30/N') - reading(on, '87/N'), closeTo(2.4, 1e-9));
      expect(
        reading(on, 'I H1') * reading(on, 'R контакта'),
        closeTo(2.4, 1e-9),
      );
    },
  );

  test(
    'D11 starter return changes motor and solenoid voltages together',
    () async {
      final none = await card(7, 'D11 • Нет разрешения');
      final click = await card(7, 'D11 • Один щелчок');
      expect(reading(none, '50/N'), 0);
      expect(reading(click, '50/N'), 12.6);
      expect(reading(click, 'M+/N'), 0);
      final slow = await card(7, 'D11 • Медленное вращение');
      expect(
        reading(slow, 'M+/N') - reading(slow, 'G3/N'),
        closeTo(10.2, 1e-9),
      );
      expect(
        reading(slow, '50/N') - reading(slow, 'G3/N'),
        closeTo(10.2, 1e-9),
      );
      expect(
        reading(slow, 'I') * reading(slow, 'R возврата'),
        reading(slow, 'G3/N'),
      );
      expect(await card(7, 'D11 • Частые щелчки'), contains('не заданы'));
    },
  );

  test(
    'D12 generation and reversed return loss use separate specified modes',
    () async {
      final off = await card(8, 'D12 • Двигатель OFF');
      expect(reading(off, 'A/D'), reading(off, 'B/D'));
      final plus = await card(8, 'D12 • Плюсовая потеря ON');
      expect(reading(plus, 'A/D') - reading(plus, 'B/D'), closeTo(1.6, 1e-9));
      expect(
        reading(plus, 'I') * reading(plus, 'R плюсового участка'),
        closeTo(1.6, 1e-9),
      );
      final ground = await card(8, 'D12 • Обратная потеря ON');
      expect(reading(ground, 'C/D'), -0.8);
      expect(
        -reading(ground, 'I') * reading(ground, 'R возврата'),
        reading(ground, 'C/D'),
      );
      expect(
        reading(ground, 'A/D') - reading(ground, 'C/D'),
        closeTo(reading(ground, 'A–C'), 1e-9),
      );
      expect(
        await card(8, 'D12 • Режим неизвестен'),
        contains('ток и команда регулятора не заданы'),
      );
    },
  );

  test('only approved existing simulations appear in module 6', () async {
    final types = <String, int>{};
    final diagrams = <String>{};
    for (final summary in await course.loadLessons('stage_5')) {
      final lesson = await course.loadLesson(
        'assets/course/stage_5/${summary.file}',
      );
      for (final b in lesson.blocks) {
        types.update(b.type, (n) => n + 1, ifAbsent: () => 1);
        if (b is ImageLessonBlock) diagrams.add(b.asset);
        if (b is DiagnosticCaseLessonBlock) expect(summary.order, 9);
        if (b is VoltageDropLessonBlock) expect(summary.order, 5);
      }
    }
    expect(types, {
      'text': 43,
      'image': 30,
      'question': 50,
      'remember': 10,
      'warning': 10,
      'measurement': 3,
      'calculation': 6,
      'voltageDrop': 1,
      'diagnosticCase': 1,
    });
    expect(diagrams, hasLength(12));
  });
}
