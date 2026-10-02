import 'dart:convert';

import 'package:electrician/models/lesson.dart';
import 'package:electrician/models/lesson_block.dart';
import 'package:electrician/widgets/lesson_blocks/measurement_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _check = 'Проверить измерение';
const _retry = 'Попробовать ещё раз';
const _success = '✓ Измерение выполнено правильно';
const _beep = 'БИП! Непрерывность обнаружена.';
const _noBeep = 'Сигнала нет. Непрерывный путь не обнаружен.';
const _ohmicError =
    '✗ Нельзя выполнять измерение сопротивления или прозвонку на запитанной '
    'исследуемой цепи.\n\nСначала отключи питание.';
const _batteryDangerError =
    '✗ Выбран режим измерения тока и прибор подключён поперёк аккумулятора. '
    'Это опасная ошибка.';
const _batteryModeError =
    '✗ Неправильный режим.\n\nДля измерения постоянного напряжения '
    'аккумулятора выбери V DC.';
const _batteryPortError =
    '✗ Неправильное гнездо красного провода.\n\nДля измерения напряжения '
    'красный провод должен находиться в VΩ.';
const _batteryMissingError = '✗ Щупы подключены не полностью.';
const _polarityError =
    '✗ Полярность щупов обратная.\n\nДля задания подключи красный щуп к +, '
    'а чёрный к −.';
const _batterySameError =
    '✗ Оба щупа находятся на одном выводе. Напряжение измеряется между двумя точками.';

Future<T> _asset<T extends MeasurementLessonBlock>(
  String file, {
  int index = 0,
}) async {
  final json = await rootBundle.loadString('assets/course/stage_2/$file.json');
  return Lesson.fromJson(jsonDecode(json) as Map<String, dynamic>).blocks
      .whereType<T>()
      .elementAt(index);
}

ConductorMeasurementLessonBlock _conductor(
  String kind, {
  bool broken = false,
  bool powered = false,
  double resistance = 0.3,
}) => switch (kind) {
  'wireResistance' => WireResistanceMeasurementLessonBlock(
    title: 'Проводник',
    question: 'Измерь сопротивление.',
    goodResistance: resistance,
    initiallyBroken: broken,
    initiallyPowered: powered,
  ),
  'resistance' => ResistanceMeasurementLessonBlock(
    title: 'Проводник',
    question: 'Измерь сопротивление.',
    goodResistance: resistance,
    initiallyBroken: broken,
    initiallyPowered: powered,
  ),
  'wireContinuity' => WireContinuityMeasurementLessonBlock(
    title: 'Проводник',
    question: 'Прозвони проводник.',
    goodResistance: resistance,
    initiallyBroken: broken,
    initiallyPowered: powered,
  ),
  _ => throw ArgumentError.value(kind),
};

class _Harness {
  final MeasurementLessonBlock block;
  final answers = <bool>[];
  int retries = 0;

  _Harness(this.block);

  Widget host({int revision = 0}) => MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            Text('Parent revision $revision'),
            MeasurementBlock(
              key: const ValueKey('measurement'),
              block: block,
              onAnswered: answers.add,
              onRetry: () => retries++,
            ),
          ],
        ),
      ),
    ),
  );
}

Finder _chip(String label) => find.widgetWithText(ChoiceChip, label);
Finder _port(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byElementPredicate((element) {
    if (element.widget is! InkWell) return false;
    var insideSelector = false;
    element.visitAncestorElements((ancestor) {
      final widget = ancestor.widget;
      if (widget is ChoiceChip ||
          widget is SegmentedButton<WirePoint> ||
          widget is SegmentedButton<BatteryTerminal>) {
        insideSelector = true;
      }
      return true;
    });
    return !insideSelector;
  }),
);
Finder get _display => find.byWidgetPredicate(
  (widget) =>
      widget is Text &&
      widget.style?.fontFeatures?.contains(
            const FontFeature.tabularFigures(),
          ) ==
          true,
);
String _readout(WidgetTester tester) => tester.widget<Text>(_display).data!;

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _probe<T>(WidgetTester tester, int index, String label) => _tap(
  tester,
  find.descendant(
    of: find.byType(SegmentedButton<T>).at(index),
    matching: find.text(label),
  ),
);

Future<void> _battery(
  WidgetTester tester, {
  String mode = 'V DC',
  String port = 'VΩ',
  String red = '+',
  String black = '−',
}) async {
  await _tap(tester, _chip(mode));
  await _tap(tester, _port(port));
  await _probe<BatteryTerminal>(tester, 0, red);
  await _probe<BatteryTerminal>(tester, 1, black);
}

Future<void> _wire(
  WidgetTester tester, {
  String mode = 'Ω',
  String port = 'VΩ',
  String red = 'A',
  String black = 'B',
}) async {
  await _tap(tester, _chip(mode));
  await _tap(tester, _port(port));
  await _probe<WirePoint>(tester, 0, red);
  await _probe<WirePoint>(tester, 1, black);
}

bool _portSelected(WidgetTester tester, String label) {
  final circle = tester.widget<Container>(
    find.descendant(of: _port(label), matching: find.byType(Container)),
  );
  return (circle.decoration! as BoxDecoration).color != Colors.transparent;
}

void _expectReset(WidgetTester tester, MeasurementLessonBlock block) {
  expect(_readout(tester), '────');
  expect(tester.widget<ChoiceChip>(_chip('OFF')).selected, isTrue);
  expect(_portSelected(tester, 'VΩ'), isTrue);
  expect(_portSelected(tester, 'A'), isFalse);
  if (block is BatteryVoltageMeasurementLessonBlock) {
    for (final selector in tester.widgetList<SegmentedButton<BatteryTerminal>>(
      find.byType(SegmentedButton<BatteryTerminal>),
    )) {
      expect(selector.selected, {BatteryTerminal.none});
    }
  } else {
    for (final selector in tester.widgetList<SegmentedButton<WirePoint>>(
      find.byType(SegmentedButton<WirePoint>),
    )) {
      expect(selector.selected, {WirePoint.none});
    }
    expect(
      find.text(block.initiallyPowered! ? 'ПИТАНИЕ ВКЛ.' : 'ОБЕСТОЧЕНО'),
      findsOneWidget,
    );
    expect(
      find.text(
        block.initiallyBroken!
            ? 'Состояние: ОБРЫВ'
            : 'Состояние: провод исправен',
      ),
      findsOneWidget,
    );
  }
  expect(find.text('⚠'), findsNothing);
  expect(
    tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, _check))
        .onPressed,
    isNotNull,
  );
}

void _expectLocked(WidgetTester tester, MeasurementLessonBlock block) {
  for (final chip in tester.widgetList<ChoiceChip>(find.byType(ChoiceChip))) {
    expect(chip.onSelected, isNull);
  }
  for (final label in ['VΩ', 'A']) {
    expect(tester.widget<InkWell>(_port(label)).onTap, isNull);
  }
  if (block is BatteryVoltageMeasurementLessonBlock) {
    for (final selector in tester.widgetList<SegmentedButton<BatteryTerminal>>(
      find.byType(SegmentedButton<BatteryTerminal>),
    )) {
      expect(selector.onSelectionChanged, isNull);
    }
  } else {
    for (final selector in tester.widgetList<SegmentedButton<WirePoint>>(
      find.byType(SegmentedButton<WirePoint>),
    )) {
      expect(selector.onSelectionChanged, isNull);
    }
    for (final label in [
      'Создать обрыв',
      'Устранить обрыв',
      'Подать питание',
      'Отключить питание',
    ]) {
      final button = find.widgetWithText(OutlinedButton, label);
      if (button.evaluate().isNotEmpty) {
        expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
      }
    }
  }
  expect(
    tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, _check))
        .onPressed,
    isNull,
  );
}

// Only public widgets, rendered text and callbacks enter the transcript.
List<Object> _observable(WidgetTester tester, _Harness harness) => [
  _readout(tester),
  tester
      .widgetList<Text>(
        find.descendant(
          of: find.byType(MeasurementBlock),
          matching: find.byType(Text),
        ),
      )
      .map((text) => text.data)
      .toList(),
  tester
      .widgetList<ChoiceChip>(find.byType(ChoiceChip))
      .map((chip) => chip.selected)
      .toList(),
  _portSelected(tester, 'VΩ'),
  _portSelected(tester, 'A'),
  if (harness.block is BatteryVoltageMeasurementLessonBlock)
    tester
        .widgetList<SegmentedButton<BatteryTerminal>>(
          find.byType(SegmentedButton<BatteryTerminal>),
        )
        .map((selector) => selector.selected.toList())
        .toList()
  else
    tester
        .widgetList<SegmentedButton<WirePoint>>(
          find.byType(SegmentedButton<WirePoint>),
        )
        .map((selector) => selector.selected.toList())
        .toList(),
  tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, _check))
          .onPressed !=
      null,
  [...harness.answers],
  harness.retries,
];

void main() {
  // Do not reuse asset futures created in another widget test's async zone.
  setUp(() => rootBundle.clear());

  final batteryCases = [
    (
      name: 'correct',
      mode: 'V DC',
      port: 'VΩ',
      red: '+',
      black: '−',
      value: '12.60',
      error: null,
    ),
    (
      name: 'reversed',
      mode: 'V DC',
      port: 'VΩ',
      red: '−',
      black: '+',
      value: '-12.60',
      error: _polarityError,
    ),
    (
      name: 'port masks reversed polarity',
      mode: 'V DC',
      port: 'A',
      red: '−',
      black: '+',
      value: '0.00',
      error: _batteryPortError,
    ),
    (
      name: 'port masks missing probes',
      mode: 'V DC',
      port: 'A',
      red: 'Не подключён',
      black: 'Не подключён',
      value: '0.00',
      error: _batteryPortError,
    ),
    (
      name: 'ohmic mode masks port',
      mode: 'Ω',
      port: 'A',
      red: '+',
      black: '−',
      value: 'OL',
      error: _batteryModeError,
    ),
    (
      name: 'mode masks missing probes',
      mode: 'A',
      port: 'VΩ',
      red: 'Не подключён',
      black: 'Не подключён',
      value: '0.00',
      error: _batteryModeError,
    ),
    (
      name: 'missing red',
      mode: 'V DC',
      port: 'VΩ',
      red: 'Не подключён',
      black: '−',
      value: '0.00',
      error: _batteryMissingError,
    ),
    (
      name: 'missing black',
      mode: 'V DC',
      port: 'VΩ',
      red: '+',
      black: 'Не подключён',
      value: '0.00',
      error: _batteryMissingError,
    ),
    (
      name: 'both missing precedes same terminal',
      mode: 'V DC',
      port: 'VΩ',
      red: 'Не подключён',
      black: 'Не подключён',
      value: '0.00',
      error: _batteryMissingError,
    ),
    (
      name: 'same terminal',
      mode: 'V DC',
      port: 'VΩ',
      red: '+',
      black: '+',
      value: '0.00',
      error: _batterySameError,
    ),
    (
      name: 'danger precedes wrong mode',
      mode: 'A',
      port: 'A',
      red: '+',
      black: '−',
      value: '⚠',
      error: _batteryDangerError,
    ),
  ];
  for (final row in batteryCases) {
    testWidgets('lesson_02 battery ${row.name}', (tester) async {
      final harness = _Harness(
        await _asset<BatteryVoltageMeasurementLessonBlock>('lesson_02'),
      );
      await tester.pumpWidget(harness.host());
      await _battery(
        tester,
        mode: row.mode,
        port: row.port,
        red: row.red,
        black: row.black,
      );
      expect(_readout(tester), row.value);
      expect(harness.answers, isEmpty);
      expect(harness.retries, 0);
      await _tap(tester, find.text(_check));
      expect(harness.answers, [row.error == null]);
      expect(find.text(row.error ?? _success), findsOneWidget);
      _expectLocked(tester, harness.block);
    });
  }

  testWidgets(
    'battery danger has no persistent hardware consequence before check',
    (tester) async {
      final harness = _Harness(
        await _asset<BatteryVoltageMeasurementLessonBlock>('lesson_02'),
      );
      await tester.pumpWidget(harness.host());
      await _battery(tester, mode: 'A', port: 'A');
      expect(_readout(tester), '⚠');
      expect(find.textContaining('ОПАСНАЯ КОНФИГУРАЦИЯ'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, _check))
            .onPressed,
        isNotNull,
      );
      await _battery(tester);
      expect(_readout(tester), '12.60');
      expect(find.textContaining('ОПАСНАЯ КОНФИГУРАЦИЯ'), findsNothing);
      expect(find.text('FUSE'), findsNothing);
      expect(harness.answers, isEmpty);
      expect(harness.retries, 0);
      await _tap(tester, find.text(_check));
      expect(harness.answers, [true]);
      expect(find.text(_success), findsOneWidget);
    },
  );

  for (final continuity in [false, true]) {
    for (final broken in [false, true]) {
      for (final swapped in [false, true]) {
        testWidgets(
          'real conductor continuity=$continuity broken=$broken swapped=$swapped succeeds',
          (tester) async {
            final block = continuity
                ? await _asset<WireContinuityMeasurementLessonBlock>(
                    'lesson_04',
                    index: broken ? 1 : 0,
                  )
                : await _asset<WireResistanceMeasurementLessonBlock>(
                    'lesson_03',
                    index: broken ? 1 : 0,
                  );
            final harness = _Harness(block);
            await tester.pumpWidget(harness.host());
            await _wire(
              tester,
              mode: continuity ? '🔊' : 'Ω',
              red: swapped ? 'B' : 'A',
              black: swapped ? 'A' : 'B',
            );
            expect(_readout(tester), broken ? 'OL' : '0.3');
            if (continuity) {
              expect(find.text(broken ? _noBeep : _beep), findsOneWidget);
              expect(find.text(broken ? _beep : _noBeep), findsNothing);
            }
            await _tap(tester, find.text(_check));
            expect(harness.answers, [true]);
            expect(find.text(_success), findsOneWidget);
            _expectLocked(tester, block);
          },
        );
      }
    }
    testWidgets(
      'real conductor alternate ohmic mode reads but fails continuity=$continuity',
      (tester) async {
        final block = continuity
            ? await _asset<WireContinuityMeasurementLessonBlock>('lesson_04')
            : await _asset<WireResistanceMeasurementLessonBlock>('lesson_03');
        final harness = _Harness(block);
        await tester.pumpWidget(harness.host());
        await _wire(tester, mode: continuity ? 'Ω' : '🔊');
        expect(_readout(tester), '0.3');
        if (!continuity) expect(find.text(_beep), findsOneWidget);
        await _tap(tester, find.text(_check));
        expect(harness.answers, [false]);
        expect(find.text(_conductorError(continuity, 'mode')), findsOneWidget);
      },
    );
  }

  for (final resistance in [50.0, 50.01]) {
    testWidgets(
      'continuity threshold uses raw resistance $resistance without affecting success',
      (tester) async {
        final harness = _Harness(
          _conductor('wireContinuity', resistance: resistance),
        );
        await tester.pumpWidget(harness.host());
        await _wire(tester, mode: '🔊');
        expect(_readout(tester), '50.0');
        expect(find.text(resistance <= 50 ? _beep : _noBeep), findsOneWidget);
        expect(find.text(resistance <= 50 ? _noBeep : _beep), findsNothing);
        await _tap(tester, find.text(_check));
        expect(harness.answers, [true]);
        expect(find.text(_success), findsOneWidget);
        // Preserve the existing explanation, including its inaccurate >50 claim.
        expect(
          find.textContaining('поэтому симулятор подаёт звуковой сигнал.'),
          findsOneWidget,
        );
      },
    );
  }

  for (final kind in ['wireResistance', 'wireContinuity', 'resistance']) {
    for (final mode in ['Ω', '🔊']) {
      testWidgets(
        '$kind powered $mode danger ignores port, same point and fault',
        (tester) async {
          final harness = _Harness(_conductor(kind, powered: true));
          await tester.pumpWidget(harness.host());
          await _wire(tester, mode: mode);
          expect(_readout(tester), '⚠');
          expect(find.textContaining('НЕПРАВИЛЬНОЕ ИЗМЕРЕНИЕ'), findsOneWidget);
          if (mode == '🔊') {
            expect(find.text(_beep), findsNothing);
            expect(
              find.text('Прозвонка на запитанной цепи недопустима.'),
              findsOneWidget,
            );
          }
          await _tap(tester, _port('A'));
          expect(_readout(tester), '⚠');
          await _probe<WirePoint>(tester, 1, 'A');
          expect(_readout(tester), '⚠');
          await _tap(tester, find.text('Создать обрыв'));
          expect(_readout(tester), '⚠');
          await _probe<WirePoint>(tester, 0, 'Не подключён');
          expect(_readout(tester), '----');
          expect(find.textContaining('НЕПРАВИЛЬНОЕ ИЗМЕРЕНИЕ'), findsNothing);
          await _tap(tester, _port('VΩ'));
          expect(_readout(tester), 'OL');
          await _probe<WirePoint>(tester, 0, 'A');
          await _probe<WirePoint>(tester, 1, 'Не подключён');
          expect(_readout(tester), 'OL');
          expect(find.text('⚠'), findsNothing);
          await _probe<WirePoint>(tester, 1, 'B');
          expect(_readout(tester), '⚠');
          // Danger is reversible through normal controls, without any repair action.
          await _tap(tester, find.text('Отключить питание'));
          expect(_readout(tester), 'OL');
          await _tap(tester, find.text('Устранить обрыв'));
          expect(_readout(tester), '0.3');
          if (mode == '🔊') expect(find.text(_beep), findsOneWidget);
          expect(find.text('FUSE'), findsNothing);
          expect(harness.answers, isEmpty);
          expect(harness.retries, 0);
          await _tap(tester, find.text('Подать питание'));
          await _tap(tester, _port('A'));
          await _probe<WirePoint>(tester, 1, 'A');
          expect(
            tester
                .widget<FilledButton>(find.widgetWithText(FilledButton, _check))
                .onPressed,
            isNotNull,
          );
          await _tap(tester, find.text(_check));
          expect(harness.answers, [false]);
          expect(find.text(_ohmicError), findsOneWidget);
        },
      );
    }

    final priorityCases = [
      (
        reason: 'mode',
        mode: 'A',
        port: 'A',
        powered: true,
        red: 'Не подключён',
        black: 'Не подключён',
        value: '0.00',
      ),
      (
        reason: 'port',
        mode: '',
        port: 'A',
        powered: true,
        red: 'Не подключён',
        black: 'Не подключён',
        value: '----',
      ),
      (
        reason: 'power',
        mode: '',
        port: 'VΩ',
        powered: true,
        red: 'Не подключён',
        black: 'Не подключён',
        value: 'OL',
      ),
      (
        reason: 'missing',
        mode: '',
        port: 'VΩ',
        powered: false,
        red: 'Не подключён',
        black: 'Не подключён',
        value: 'OL',
      ),
      (
        reason: 'missing',
        mode: '',
        port: 'VΩ',
        powered: false,
        red: 'A',
        black: 'Не подключён',
        value: 'OL',
      ),
      (
        reason: 'same',
        mode: '',
        port: 'VΩ',
        powered: false,
        red: 'A',
        black: 'A',
        value: 'OL',
      ),
    ];
    for (final row in priorityCases) {
      testWidgets('$kind priority ${row.reason} ${row.red}/${row.black}', (
        tester,
      ) async {
        final continuity = kind == 'wireContinuity';
        final block = switch (kind) {
          'wireResistance' =>
            await _asset<WireResistanceMeasurementLessonBlock>('lesson_03'),
          'wireContinuity' =>
            await _asset<WireContinuityMeasurementLessonBlock>('lesson_04'),
          _ => await _asset<ResistanceMeasurementLessonBlock>('lesson_09'),
        };
        final harness = _Harness(block);
        await tester.pumpWidget(harness.host());
        if (block.initiallyPowered != row.powered) {
          await _tap(
            tester,
            find.text(
              block.initiallyPowered ? 'Отключить питание' : 'Подать питание',
            ),
          );
        }
        await _wire(
          tester,
          mode: row.mode.isEmpty ? (continuity ? '🔊' : 'Ω') : row.mode,
          port: row.port,
          red: row.red,
          black: row.black,
        );
        expect(_readout(tester), row.value);
        expect(find.text('⚠'), findsNothing);
        await _tap(tester, find.text(_check));
        expect(harness.answers, [false]);
        expect(
          find.text(_conductorError(continuity, row.reason)),
          findsOneWidget,
        );
      });
    }
  }

  for (final broken in [false, true]) {
    testWidgets(
      'lesson_03 port precedes missing/same probes and fault broken=$broken',
      (tester) async {
        final harness = _Harness(
          await _asset<WireResistanceMeasurementLessonBlock>(
            'lesson_03',
            index: broken ? 1 : 0,
          ),
        );
        await tester.pumpWidget(harness.host());
        await _wire(tester, red: 'Не подключён');
        expect(_readout(tester), 'OL');
        await _tap(tester, find.text(_check));
        expect(harness.answers, [false]);
        expect(find.text(_conductorError(false, 'missing')), findsOneWidget);
        await _tap(tester, find.text(_retry));
        _expectReset(tester, harness.block);
        await _wire(tester, red: 'B');
        expect(_readout(tester), 'OL');
        await _tap(tester, find.text(_check));
        expect(harness.answers, [false, false]);
        expect(find.text(_conductorError(false, 'same')), findsOneWidget);
        await _tap(tester, find.text(_retry));
        _expectReset(tester, harness.block);
        await _wire(tester, red: 'Не подключён');
        await _probe<WirePoint>(tester, 0, 'B');
        expect(_readout(tester), 'OL');
        await _tap(tester, _port('A'));
        expect(_readout(tester), '----');
        await _probe<WirePoint>(tester, 0, 'A');
        expect(_readout(tester), '----');
        await _probe<WirePoint>(tester, 0, 'Не подключён');
        expect(_readout(tester), '----');
        await _tap(tester, find.text(_check));
        expect(harness.answers, [false, false, false]);
        expect(harness.retries, 2);
        expect(find.text(_conductorError(false, 'port')), findsOneWidget);
      },
    );

    testWidgets('resistance subtypes observable equivalence broken=$broken', (
      tester,
    ) async {
      Future<List<List<Object>>> run(String kind) async {
        await tester.pumpWidget(const SizedBox.shrink());
        final harness = _Harness(
          _conductor(kind, broken: broken, powered: true),
        );
        await tester.pumpWidget(harness.host());
        final trace = <List<Object>>[_observable(tester, harness)];
        await _wire(tester, mode: '🔊', port: 'A', black: 'A');
        expect(_readout(tester), '⚠');
        trace.add(_observable(tester, harness));
        await _tap(tester, find.text(_check));
        expect(harness.answers, [false]);
        expect(find.text(_ohmicError), findsOneWidget);
        trace.add(_observable(tester, harness));
        await _tap(tester, find.text(_retry));
        _expectReset(tester, harness.block);
        trace.add(_observable(tester, harness));
        await _tap(tester, find.text('Отключить питание'));
        await _tap(
          tester,
          find.text(broken ? 'Устранить обрыв' : 'Создать обрыв'),
        );
        await _wire(tester, port: 'A');
        expect(_readout(tester), '----');
        trace.add(_observable(tester, harness));
        await _tap(tester, find.text(_check));
        expect(harness.answers, [false, false]);
        trace.add(_observable(tester, harness));
        await _tap(tester, find.text(_retry));
        _expectReset(tester, harness.block);
        expect(harness.retries, 2);
        trace.add(_observable(tester, harness));
        await _tap(tester, find.text('Отключить питание'));
        await _wire(tester);
        expect(_readout(tester), broken ? 'OL' : '0.3');
        await _tap(tester, find.text(_check));
        expect(harness.answers, [false, false, true]);
        expect(find.text(_success), findsOneWidget);
        trace.add(_observable(tester, harness));
        return trace;
      }

      final wire = await run('wireResistance');
      final resistance = await run('resistance');
      expect(resistance, wire);
    });
  }

  for (final kind in [
    'batteryVoltage',
    'wireResistance',
    'wireContinuity',
    'resistance',
  ]) {
    testWidgets(
      '$kind callbacks, locks and retry restore real initial content',
      (tester) async {
        final block = switch (kind) {
          'batteryVoltage' =>
            await _asset<BatteryVoltageMeasurementLessonBlock>('lesson_02'),
          'wireResistance' =>
            await _asset<WireResistanceMeasurementLessonBlock>(
              'lesson_03',
              index: 1,
            ),
          'wireContinuity' =>
            await _asset<WireContinuityMeasurementLessonBlock>(
              'lesson_04',
              index: 1,
            ),
          _ => await _asset<ResistanceMeasurementLessonBlock>('lesson_09'),
        };
        final harness = _Harness(block);
        await tester.pumpWidget(harness.host());
        if (kind == 'batteryVoltage') {
          await _battery(tester, mode: 'Ω', port: 'A', red: '−', black: '+');
        } else {
          await _tap(
            tester,
            find.text(
              block.initiallyBroken! ? 'Устранить обрыв' : 'Создать обрыв',
            ),
          );
          await _tap(
            tester,
            find.text(
              block.initiallyPowered! ? 'Отключить питание' : 'Подать питание',
            ),
          );
          await _wire(tester, mode: 'A', port: 'A');
        }
        expect(harness.answers, isEmpty);
        expect(harness.retries, 0);
        await _tap(tester, find.text(_check));
        expect(harness.answers, [false]);
        _expectLocked(tester, block);
        final before = _observable(tester, harness);
        await _tap(tester, find.text(_check));
        await _tap(tester, _chip('V DC'));
        await _tap(tester, _port('VΩ'));
        expect(_observable(tester, harness), before);
        await _tap(tester, find.text(_retry));
        expect(harness.retries, 1);
        expect(harness.answers, [false]);
        _expectReset(tester, block);
        expect(find.text(_retry), findsNothing);
        if (kind == 'batteryVoltage') {
          await _battery(tester);
        } else {
          if (block.initiallyPowered!) {
            await _tap(tester, find.text('Отключить питание'));
          }
          await _wire(tester, mode: kind == 'wireContinuity' ? '🔊' : 'Ω');
        }
        expect(harness.answers, [false]);
        await _tap(tester, find.text(_check));
        expect(harness.answers, [false, true]);
        expect(harness.retries, 1);
        expect(find.text(_success), findsOneWidget);
        expect(find.text(_retry), findsNothing);
        _expectLocked(tester, block);
        await _tap(tester, find.text(_check));
        expect(harness.answers, [false, true]);
      },
    );
  }

  for (final scenario in [
    'configured battery',
    'powered conductor danger',
    'checked exercise',
  ]) {
    testWidgets('parent rebuild preserves $scenario without callbacks', (
      tester,
    ) async {
      final harness = _Harness(
        scenario == 'powered conductor danger'
            ? await _asset<ResistanceMeasurementLessonBlock>('lesson_09')
            : await _asset<BatteryVoltageMeasurementLessonBlock>('lesson_02'),
      );
      await tester.pumpWidget(harness.host());
      if (scenario == 'powered conductor danger') {
        await _wire(tester, mode: '🔊', port: 'A', black: 'A');
        expect(_readout(tester), '⚠');
      } else {
        await _battery(tester);
        expect(_readout(tester), '12.60');
        if (scenario == 'checked exercise') {
          await _tap(tester, find.text(_check));
        }
      }
      final before = _observable(tester, harness);
      await tester.pumpWidget(harness.host(revision: 1));
      await tester.pumpAndSettle();
      expect(find.text('Parent revision 1'), findsOneWidget);
      expect(_observable(tester, harness), before);
      expect(
        harness.answers,
        scenario == 'checked exercise' ? [true] : isEmpty,
      );
      expect(harness.retries, 0);
      if (scenario == 'checked exercise') _expectLocked(tester, harness.block);
    });
  }
}

String _conductorError(bool continuity, String reason) => switch (reason) {
  'mode' =>
    continuity
        ? '✗ Неправильный режим.\n\nДля этого задания выбери режим прозвонки 🔊.'
        : '✗ Неправильный режим.\n\nДля проверки сопротивления провода выбери Ω.',
  'port' =>
    continuity
        ? '✗ Неправильное гнездо красного провода.\n\nДля прозвонки используй вход VΩ.'
        : '✗ Неправильное гнездо красного провода.\n\nДля измерения сопротивления используй вход VΩ.',
  'power' =>
    continuity
        ? '✗ Перед прозвонкой исследуемую цепь необходимо обесточить.'
        : '✗ Сначала необходимо обесточить исследуемую цепь.',
  'missing' =>
    continuity
        ? '✗ Подключи оба щупа к исследуемому участку.'
        : '✗ Подключи оба щупа к исследуемому проводу.',
  'same' => continuity ? '✗ Один щуп должен находиться на A, а второй — на B.' : '✗ Щупы должны находиться на разных концах исследуемого участка: один на A, другой на B.',
  _ => throw ArgumentError.value(reason),
};
