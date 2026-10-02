import 'dart:convert';

import 'package:electrician/models/lesson.dart';
import 'package:electrician/models/lesson_block.dart';
import 'package:electrician/widgets/lesson_blocks/diagnostic_case_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _labels = [
  'Напряжение АКБ',
  'До предохранителя',
  'После предохранителя',
  'Плюс лампы',
  'Масса лампы',
  'Прозвонить провод',
];
const _descriptions = [
  'Напряжение непосредственно между выводами аккумулятора.',
  'Напряжение на входной стороне предохранителя относительно массы.',
  'Напряжение после предохранителя относительно массы.',
  'Напряжение на плюсовом выводе лампы относительно массы.',
  'Потенциал точки массы лампы относительно массы аккумулятора.',
  'Проверка участка провода между выходом предохранителя и плюсовым выводом лампы.',
];
const _required = [0, 2, 3, 5];
const _forbidden = 'НЕЛЬЗЯ: цепь запитана';
const _fallback = DiagnosticCaseLessonBlock(
  title: 'Synthetic fallback',
  question: 'Synthetic question',
  sourceVoltage: 13.25,
  faultType: 'unknownNonEmptyFault',
);

class _Exercise {
  final WidgetTester tester;
  final answers = <bool>[];
  int retries = 0;
  _Exercise(this.tester);

  Finder get check =>
      find.widgetWithText(FilledButton, 'Указать неисправность');
  Finder get retry =>
      find.widgetWithText(OutlinedButton, 'Начать диагностику заново');
  Finder get power => find.widgetWithText(
    OutlinedButton,
    find.text('ПИТАНИЕ ВКЛ.').evaluate().isNotEmpty
        ? 'Обесточить цепь'
        : 'Подать питание',
  );
  Finder get history => find.byType(ListTile);
  Finder action(int index) =>
      find.widgetWithText(OutlinedButton, _labels[index]);
  List<String> get historyLabels => tester
      .widgetList<ListTile>(history)
      .map((tile) => (tile.title! as Text).data!)
      .toList();
  List<String> get readings => tester
      .widgetList<ListTile>(history)
      .map((tile) => (tile.trailing! as Text).data!)
      .toList();

  Future<void> pump(DiagnosticCaseLessonBlock block) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DiagnosticCaseBlock(
            key: const ValueKey('diagnostic-case'),
            block: block,
            onAnswered: answers.add,
            onRetry: () => retries++,
          ),
        ),
      ),
    ),
  );
  Future<void> tap(Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> measure(int index) => tap(action(index));
  Future<void> measureAll(Iterable<int> tests) async {
    for (final index in tests) {
      await measure(index);
    }
  }

  Future<void> toggle() => tap(power);
  void expectPower(bool powered) {
    expect(find.text(powered ? 'ПИТАНИЕ ВКЛ.' : 'ОБЕСТОЧЕНО'), findsOneWidget);
  }

  void expectCurrent(int? index) {
    for (var i = 0; i < _descriptions.length; i++) {
      expect(
        find.text(_descriptions[i]),
        i == index ? findsOneWidget : findsNothing,
      );
    }
  }

  void expectResult(bool? success) {
    expect(
      find.text('✓ Неисправность найдена'),
      success == true ? findsOneWidget : findsNothing,
    );
    expect(retry, success == false ? findsOneWidget : findsNothing);
  }

  void expectInitial() {
    expectPower(true);
    expect(history, findsNothing);
    expect(find.text('Измерений пока нет.'), findsOneWidget);
    expectCurrent(null);
    expectResult(null);
    expect(tester.widget<FilledButton>(check).onPressed, isNotNull);
    expect(tester.widget<OutlinedButton>(power).onPressed, isNotNull);
    for (var i = 0; i < 6; i++) {
      expect(tester.widget<OutlinedButton>(action(i)).onPressed, isNotNull);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DiagnosticCaseLessonBlock realBlock;
  setUpAll(() async {
    final json = await rootBundle.loadString(
      'assets/course/stage_2/lesson_07.json',
    );
    realBlock = Lesson.fromJson(jsonDecode(json) as Map<String, dynamic>).blocks
        .whereType<DiagnosticCaseLessonBlock>()
        .single;
  });

  testWidgets('real asset initial state permits an immediate check', (
    tester,
  ) async {
    final e = _Exercise(tester);
    await e.pump(realBlock);
    expect(realBlock.faultType, 'positiveWireOpen');
    expect(realBlock.sourceVoltage, 12.6);
    e.expectInitial();
    expect(find.byType(OutlinedButton), findsNWidgets(7));
    expect(e.answers, isEmpty);
    expect(e.retries, 0);
  });

  for (final fallback in [false, true]) {
    for (final powered in [true, false]) {
      testWidgets(
        '${fallback ? 'fallback' : 'real positiveWireOpen'} full table powered=$powered',
        (tester) async {
          final e = _Exercise(tester);
          await e.pump(fallback ? _fallback : realBlock);
          if (!powered) {
            await e.toggle();
          }
          final source = fallback ? '13.25 V' : '12.60 V';
          final expected = powered
              ? [
                  source,
                  source,
                  source,
                  fallback ? source : '0.00 V',
                  '0.00 V',
                  _forbidden,
                ]
              : [
                  '12.60 V',
                  '0.00 V',
                  '0.00 V',
                  '0.00 V',
                  '0.00 V',
                  fallback ? '0.3 Ω / БИП' : 'OL',
                ];
          for (var i = 0; i < 6; i++) {
            await e.measure(i);
            e.expectCurrent(i);
            expect(e.readings, expected.take(i + 1).toList());
            expect(
              find.text(expected[i]),
              findsNWidgets(
                expected
                        .take(i + 1)
                        .where((value) => value == expected[i])
                        .length +
                    1,
              ),
            );
          }
          expect(e.historyLabels, _labels);
          e.expectPower(powered);
          expect(
            find.textContaining('⚠ Прозвонку выполняют'),
            powered ? findsOneWidget : findsNothing,
          );
          expect(e.answers, isEmpty);
          expect(e.retries, 0);
        },
      );
    }
  }

  testWidgets(
    'repeated tests update selection but preserve first execution history order',
    (tester) async {
      final e = _Exercise(tester);
      await e.pump(realBlock);
      await e.measure(3);
      expect(e.historyLabels, [_labels[3]]);
      await e.measure(0);
      e.expectCurrent(0);
      await e.measure(3);
      e.expectCurrent(3);
      await e.measure(2);
      await e.measure(0);
      e.expectCurrent(0);
      expect(e.historyLabels, [_labels[3], _labels[0], _labels[2]]);
      expect(e.readings, ['0.00 V', '12.60 V', '12.60 V']);
      await e.toggle();
      e.expectCurrent(null);
      expect(e.historyLabels, [_labels[3], _labels[0], _labels[2]]);
      expect(e.answers, isEmpty);
      expect(e.retries, 0);
    },
  );

  for (final initiallyPowered in [true, false]) {
    testWidgets(
      'continuity snapshot survives when power ${initiallyPowered ? 'turns off' : 'turns on'} and updates only after remeasurement',
      (tester) async {
        final e = _Exercise(tester);
        await e.pump(realBlock);
        if (!initiallyPowered) {
          await e.toggle();
        }
        await e.measure(5);
        expect(e.readings, [initiallyPowered ? _forbidden : 'OL']);
        await e.toggle();
        expect(e.historyLabels, [_labels[5]]);
        expect(e.readings, [initiallyPowered ? _forbidden : 'OL']);
        e.expectCurrent(null);
        await e.measure(5);
        expect(e.readings, [initiallyPowered ? 'OL' : _forbidden]);
        expect(e.historyLabels, [_labels[5]]);
        expect(
          find.text(initiallyPowered ? 'OL' : _forbidden),
          findsNWidgets(2),
        );
        e.expectCurrent(5);
        expect(e.answers, isEmpty);
        expect(e.retries, 0);
      },
    );
  }

  testWidgets(
    'battery and fuse snapshots survive toggles and update in place',
    (tester) async {
      final e = _Exercise(tester);
      await e.pump(_fallback);
      await e.measureAll([0, 1]);
      expect(e.readings, ['13.25 V', '13.25 V']);
      await e.toggle();
      expect(e.readings, ['13.25 V', '13.25 V']);
      await e.measure(0);
      expect(e.readings, ['12.60 V', '13.25 V']);
      expect(find.text('12.60 V'), findsNWidgets(2));
      e.expectCurrent(0);
      await e.measure(1);
      expect(e.readings, ['12.60 V', '0.00 V']);
      expect(find.text('0.00 V'), findsNWidgets(2));
      e.expectCurrent(1);
      await e.toggle();
      expect(e.readings, ['12.60 V', '0.00 V']);
      expect(e.historyLabels, [_labels[0], _labels[1]]);
      e.expectCurrent(null);
      expect(e.answers, isEmpty);
    },
  );

  testWidgets(
    'forbidden continuity fails completion and preserves history until retry',
    (tester) async {
      final e = _Exercise(tester);
      await e.pump(realBlock);
      await e.measureAll(_required);
      expect(e.readings.last, _forbidden);
      expect(find.textContaining('⚠ Прозвонку выполняют'), findsOneWidget);
      expect(e.answers, isEmpty);
      await e.toggle();
      expect(e.readings.last, _forbidden);
      await e.tap(e.check);
      e.expectResult(false);
      expect(
        find.text(
          'Ты сузил область поиска. Теперь на обесточенной цепи проверь целостность участка между предохранителем и лампой.',
        ),
        findsOneWidget,
      );
      expect(e.historyLabels, _required.map((i) => _labels[i]).toList());
      expect(e.readings, ['12.60 V', '12.60 V', '0.00 V', _forbidden]);
      await e.tap(e.check);
      await e.measure(5);
      expect(e.readings.last, _forbidden);
      expect(e.answers, [false]);
      expect(e.retries, 0);
      await e.tap(e.retry);
      e.expectInitial();
      expect(e.retries, 1);
      await e.toggle();
      await e.measureAll(_required);
      expect(e.readings.last, 'OL');
      await e.tap(e.check);
      e.expectResult(true);
      await e.tap(e.check);
      expect(e.answers, [false, true]);
      expect(e.retries, 1);
    },
  );

  testWidgets('forbidden continuity replaced by open loop permits completion', (
    tester,
  ) async {
    final e = _Exercise(tester);
    await e.pump(realBlock);
    await e.measure(5);
    expect(e.readings, [_forbidden]);
    await e.toggle();
    expect(e.readings, [_forbidden]);
    await e.measure(5);
    expect(e.historyLabels, [_labels[5]]);
    expect(e.readings, ['OL']);
    expect(find.text('OL'), findsNWidgets(2));
    await e.measureAll([0, 2, 3]);
    expect(e.historyLabels, [5, 0, 2, 3].map((i) => _labels[i]).toList());
    await e.tap(e.check);
    e.expectResult(true);
    await e.tap(e.check);
    expect(e.answers, [true]);
  });

  testWidgets('powered voltage tests then unpowered continuity succeed', (
    tester,
  ) async {
    final e = _Exercise(tester);
    await e.pump(realBlock);
    await e.measureAll([0, 2, 3]);
    await e.toggle();
    await e.measure(5);
    expect(e.readings, ['12.60 V', '12.60 V', '0.00 V', 'OL']);
    await e.tap(e.check);
    e.expectResult(true);
    await e.tap(e.check);
    expect(e.answers, [true]);
  });

  testWidgets('valid continuity replaced by forbidden no longer completes', (
    tester,
  ) async {
    final e = _Exercise(tester);
    await e.pump(realBlock);
    await e.toggle();
    await e.measureAll(_required);
    expect(e.readings.last, 'OL');
    await e.toggle();
    await e.measure(5);
    await e.toggle();
    expect(e.historyLabels, _required.map((i) => _labels[i]).toList());
    expect(e.readings.last, _forbidden);
    await e.tap(e.check);
    e.expectResult(false);
    expect(e.readings.last, _forbidden);
    await e.tap(e.check);
    expect(e.answers, [false]);
  });

  for (final order in [
    _required,
    [5, 3, 2, 0],
  ]) {
    testWidgets('required tests alone succeed unpowered in order $order', (
      tester,
    ) async {
      final e = _Exercise(tester);
      await e.pump(realBlock);
      await e.toggle();
      await e.measureAll(order);
      expect(e.historyLabels, order.map((i) => _labels[i]).toList());
      expect(e.historyLabels, isNot(contains(_labels[1])));
      expect(e.historyLabels, isNot(contains(_labels[4])));
      await e.tap(e.check);
      e.expectResult(true);
      expect(e.answers, [true]);
    });
  }

  final priorities = [
    (
      name: 'powered',
      tests: <int>[],
      powered: true,
      fallback: false,
      message: 'Диагностика ещё не завершена.\n\nПосле измерений напряжения подозрительный участок следует обесточить перед проверкой его целостности.',
    ),
    (
      name: 'missing battery',
      tests: <int>[],
      powered: false,
      fallback: false,
      message: 'Ты ещё не проверил источник питания. Начни с понимания, исправен ли сам аккумулятор.',
    ),
    (
      name: 'missing fuse output',
      tests: [0],
      powered: false,
      fallback: false,
      message: 'Нужно определить, выходит ли питание из предохранителя.',
    ),
    (
      name: 'missing lamp positive',
      tests: [0, 2],
      powered: false,
      fallback: false,
      message: 'Нужно проверить, доходит ли питание непосредственно до плюсового вывода лампы.',
    ),
    (
      name: 'missing continuity',
      tests: [0, 2, 3],
      powered: false,
      fallback: false,
      message: 'Ты сузил область поиска. Теперь на обесточенной цепи проверь целостность участка между предохранителем и лампой.',
    ),
    (
      name: 'generic fallback',
      tests: _required,
      powered: false,
      fallback: true,
      message: 'Продолжи последовательную диагностику цепи.',
    ),
  ];
  for (final scenario in priorities) {
    testWidgets('failure priority: ${scenario.name}', (tester) async {
      final e = _Exercise(tester);
      await e.pump(scenario.fallback ? _fallback : realBlock);
      if (!scenario.powered) {
        await e.toggle();
      }
      await e.measureAll(scenario.tests);
      await e.tap(e.check);
      expect(find.text(scenario.message), findsOneWidget);
      e.expectResult(false);
      expect(e.answers, [false]);
    });
  }

  testWidgets('complete required set still fails while powered', (
    tester,
  ) async {
    final e = _Exercise(tester);
    await e.pump(realBlock);
    await e.measureAll(_required);
    await e.tap(e.check);
    e.expectResult(false);
    expect(find.text(priorities.first.message), findsOneWidget);
    expect(e.answers, [false]);
  });

  for (final success in [true, false]) {
    testWidgets(
      '${success ? 'successful' : 'empty failed'} check locks power, measurements and check',
      (tester) async {
        final e = _Exercise(tester);
        await e.pump(realBlock);
        if (success) {
          await e.toggle();
          await e.measureAll(_required);
        }
        final labels = e.historyLabels;
        final readings = e.readings;
        await e.tap(e.check);
        expect(tester.widget<FilledButton>(e.check).onPressed, isNull);
        expect(tester.widget<OutlinedButton>(e.power).onPressed, isNull);
        await e.toggle();
        for (var i = 0; i < 6; i++) {
          expect(tester.widget<OutlinedButton>(e.action(i)).onPressed, isNull);
          await e.measure(i);
        }
        await e.tap(e.check);
        e.expectPower(!success);
        e.expectCurrent(success ? 5 : null);
        expect(e.historyLabels, labels);
        expect(e.readings, readings);
        e.expectResult(success);
        expect(e.answers, [success]);
        expect(e.retries, 0);
      },
    );
  }

  testWidgets(
    'retry resets power, history, selection and attempt before succeeding',
    (tester) async {
      final e = _Exercise(tester);
      await e.pump(realBlock);
      await e.toggle();
      await e.measureAll([0, 5]);
      await e.tap(e.check);
      e.expectResult(false);
      await e.tap(e.retry);
      e.expectInitial();
      expect(e.answers, [false]);
      expect(e.retries, 1);
      await e.toggle();
      await e.measureAll(_required);
      await e.tap(e.check);
      e.expectResult(true);
      expect(e.answers, [false, true]);
      expect(e.retries, 1);
    },
  );

  testWidgets(
    'parent rebuild preserves pending power, history and selected test',
    (tester) async {
      final e = _Exercise(tester);
      await e.pump(realBlock);
      await e.toggle();
      await e.measureAll([0, 5]);
      await e.pump(realBlock);
      e.expectPower(false);
      e.expectCurrent(5);
      expect(e.historyLabels, [_labels[0], _labels[5]]);
      expect(e.readings, ['12.60 V', 'OL']);
      expect(tester.widget<FilledButton>(e.check).onPressed, isNotNull);
      e.expectResult(null);
      expect(e.answers, isEmpty);
      expect(e.retries, 0);
    },
  );

  for (final success in [true, false]) {
    testWidgets(
      'parent rebuild preserves checked ${success ? 'success' : 'failure'}',
      (tester) async {
        final e = _Exercise(tester);
        await e.pump(realBlock);
        await e.toggle();
        await e.measureAll(success ? _required : [0, 5]);
        await e.tap(e.check);
        final labels = e.historyLabels;
        final readings = e.readings;
        await e.pump(realBlock);
        e.expectPower(false);
        e.expectCurrent(5);
        expect(e.historyLabels, labels);
        expect(e.readings, readings);
        expect(tester.widget<FilledButton>(e.check).onPressed, isNull);
        e.expectResult(success);
        expect(e.answers, [success]);
        expect(e.retries, 0);
      },
    );
  }

  testWidgets(
    'same-key pending replacement preserves voltage snapshots and current result',
    (tester) async {
      final e = _Exercise(tester);
      await e.pump(realBlock);
      await e.measureAll([0, 2, 3]);
      expect(e.readings, ['12.60 V', '12.60 V', '0.00 V']);
      await e.pump(_fallback);
      e.expectPower(true);
      e.expectCurrent(3);
      expect(e.historyLabels, [_labels[0], _labels[2], _labels[3]]);
      expect(e.readings, ['12.60 V', '12.60 V', '0.00 V']);
      expect(find.text('0.00 V'), findsNWidgets(2));
      expect(find.text('Synthetic fallback'), findsOneWidget);
      expect(find.text('Synthetic question'), findsOneWidget);
      expect(tester.widget<FilledButton>(e.check).onPressed, isNotNull);
      expect(e.answers, isEmpty);
      expect(e.retries, 0);
    },
  );

  testWidgets('remeasurement after replacement updates only its original row', (
    tester,
  ) async {
    final e = _Exercise(tester);
    await e.pump(realBlock);
    await e.measureAll([3, 0, 2]);
    await e.pump(_fallback);
    expect(e.readings, ['0.00 V', '12.60 V', '12.60 V']);
    await e.measure(3);
    expect(e.historyLabels, [_labels[3], _labels[0], _labels[2]]);
    expect(e.readings, ['13.25 V', '12.60 V', '12.60 V']);
    e.expectCurrent(3);
    expect(find.text('13.25 V'), findsNWidgets(2));
    expect(e.answers, isEmpty);
    expect(e.retries, 0);
  });

  for (final success in [true, false]) {
    testWidgets(
      'same-key replacement retains checked ${success ? 'success' : 'failure'} and continuity snapshot',
      (tester) async {
        final e = _Exercise(tester);
        await e.pump(realBlock);
        await e.toggle();
        await e.measureAll(success ? _required : [0, 5]);
        await e.tap(e.check);
        final labels = e.historyLabels;
        expect(e.readings.last, 'OL');
        await e.pump(_fallback);
        e.expectPower(false);
        e.expectCurrent(5);
        expect(e.historyLabels, labels);
        expect(e.readings.last, 'OL');
        expect(find.text('OL'), findsNWidgets(2));
        expect(find.text('АКБ 13.3 V'), findsOneWidget);
        expect(tester.widget<FilledButton>(e.check).onPressed, isNull);
        e.expectResult(success);
        expect(e.answers, [success]);
        expect(e.retries, 0);
      },
    );
  }
}
