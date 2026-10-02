import 'dart:convert';

import 'package:electrician/models/lesson.dart';
import 'package:electrician/models/lesson_block.dart';
import 'package:electrician/widgets/lesson_blocks/current_measurement_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _check = 'Проверить измерение';
const _replace = 'Заменить предохранитель мультиметра';
const _retry = 'Попробовать ещё раз';
const _connections = {
  CurrentConnection.disconnected: 'Не подключён',
  CurrentConnection.series: 'В разрыв цепи (последовательно)',
  CurrentConnection.acrossBattery: 'Между + и − аккумулятора',
  CurrentConnection.acrossLamp: 'Параллельно лампе',
};
const _modeError =
    '✗ Неправильный режим.\n\nДля этого задания необходимо '
    'измерить силу тока, поэтому выбери режим A.';
const _portError =
    '✗ Красный провод находится в VΩ.\n\nВ нашем учебном '
    'мультиметре для этого измерения его нужно переставить в токовое гнездо A.';
const _disconnectedError = '✗ Мультиметр не включён в электрическую цепь.';
const _parallelError =
    '✗ Амперметр нельзя подключать параллельно '
    'потребителю.\n\nЧтобы измерить ток лампы, разорви цепь и включи '
    'мультиметр последовательно.';

CurrentMeasurementLessonBlock _block({
  double voltage = 12.6,
  double current = 2,
  double rating = 10,
}) => CurrentMeasurementLessonBlock(
  title: 'Измерение тока',
  question: 'Измерь ток лампы.',
  sourceVoltage: voltage,
  loadCurrent: current,
  meterFuseRating: rating,
);

Future<CurrentMeasurementLessonBlock> _asset(String file) async {
  final json = await rootBundle.loadString('assets/course/stage_2/$file.json');
  return Lesson.fromJson(jsonDecode(json) as Map<String, dynamic>).blocks
      .whereType<CurrentMeasurementLessonBlock>()
      .single;
}

class _Harness {
  final CurrentMeasurementLessonBlock block;
  final answers = <bool>[];
  int retries = 0;

  _Harness(this.block);

  Widget host() => MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: CurrentMeasurementBlock(
          block: block,
          onAnswered: answers.add,
          onRetry: () => retries++,
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
    var insideChip = false;
    element.visitAncestorElements((ancestor) {
      if (ancestor.widget is ChoiceChip) insideChip = true;
      return true;
    });
    return !insideChip;
  }),
);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _configure(
  WidgetTester tester, {
  String mode = 'A',
  String port = 'A',
  CurrentConnection connection = CurrentConnection.series,
}) async {
  await _tap(tester, _chip(mode));
  await _tap(tester, _port(port));
  await _tap(tester, find.text(_connections[connection]!));
}

void _expectConfiguration(
  WidgetTester tester,
  String mode,
  String port,
  CurrentConnection connection,
) {
  for (final label in ['OFF', 'V DC', 'A']) {
    expect(tester.widget<ChoiceChip>(_chip(label)).selected, label == mode);
  }
  for (final label in ['VΩ', 'A']) {
    expect(
      find.descendant(of: _port(label), matching: find.text('красный')),
      label == port ? findsOneWidget : findsNothing,
    );
  }
  expect(
    tester
        .widget<RadioGroup<CurrentConnection>>(
          find.byType(RadioGroup<CurrentConnection>),
        )
        .groupValue,
    connection,
  );
}

void _expectReadout(String value, String unit) {
  // The LCD is the sole fixed-height Container containing the reading and unit.
  final lcd = find.byWidgetPredicate(
    (widget) => widget is Container && widget.constraints?.maxHeight == 86,
  );
  expect(lcd, findsOneWidget);
  expect(find.descendant(of: lcd, matching: find.text(value)), findsOneWidget);
  expect(find.descendant(of: lcd, matching: find.text(unit)), findsOneWidget);
}

void _expectCheck(WidgetTester tester, {required bool enabled}) {
  expect(
    tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, _check))
        .onPressed,
    enabled ? isNotNull : isNull,
  );
}

void _expectFuse({required bool blown}) {
  expect(find.text('FUSE'), blown ? findsOneWidget : findsNothing);
  expect(find.text(_replace), blown ? findsOneWidget : findsNothing);
  expect(
    find.textContaining('ОПАСНАЯ ОШИБКА'),
    blown ? findsOneWidget : findsNothing,
  );
}

Future<void> _expectLocked(
  WidgetTester tester, {
  required String mode,
  required String port,
  required CurrentConnection connection,
}) async {
  for (final label in ['OFF', 'V DC', 'A']) {
    expect(tester.widget<ChoiceChip>(_chip(label)).onSelected, isNull);
    await _tap(tester, _chip(label));
  }
  for (final label in ['VΩ', 'A']) {
    expect(tester.widget<InkWell>(_port(label)).onTap, isNull);
    await _tap(tester, _port(label));
  }
  // Radio controls retain handlers; attempted changes are ignored by the guard.
  for (final label in _connections.values) {
    await _tap(tester, find.text(label));
    _expectConfiguration(tester, mode, port, connection);
  }
  _expectCheck(tester, enabled: false);
  await _tap(tester, find.text(_check));
  _expectConfiguration(tester, mode, port, connection);
}

void main() {
  testWidgets(
    'real lesson_06 starts OFF, VΩ, disconnected with check enabled',
    (tester) async {
      final h = _Harness((await tester.runAsync(() => _asset('lesson_06')))!);
      await tester.pumpWidget(h.host());
      expect(find.text(h.block.title), findsOneWidget);
      expect(find.text(h.block.question), findsOneWidget);
      _expectConfiguration(tester, 'OFF', 'VΩ', CurrentConnection.disconnected);
      _expectReadout('────', 'OFF');
      _expectCheck(tester, enabled: true);
      _expectFuse(blown: false);
      expect(h.answers, isEmpty);
      expect(h.retries, 0);
    },
  );

  for (final file in ['lesson_06', 'lesson_09']) {
    testWidgets('$file correct measurement answers once and locks controls', (
      tester,
    ) async {
      final h = _Harness((await tester.runAsync(() => _asset(file)))!);
      await tester.pumpWidget(h.host());
      expect(find.text(h.block.title), findsOneWidget);
      expect(find.text(h.block.question), findsOneWidget);
      await _configure(tester);
      _expectReadout('2.00', 'A');
      expect(find.text('Ток через лампу: 2.00 A'), findsOneWidget);
      await _tap(tester, find.text(_check));
      expect(find.textContaining('✓ Правильно.\n\n'), findsOneWidget);
      expect(find.textContaining('Показание: 2.00 A.'), findsOneWidget);
      await _expectLocked(
        tester,
        mode: 'A',
        port: 'A',
        connection: CurrentConnection.series,
      );
      expect(h.answers, [true]);
      expect(h.retries, 0);
      expect(find.text(_retry), findsNothing);
    });
  }

  final errorCases = [
    (
      mode: 'OFF',
      port: 'VΩ',
      connection: CurrentConnection.disconnected,
      error: _modeError,
    ),
    (
      mode: 'V DC',
      port: 'VΩ',
      connection: CurrentConnection.acrossLamp,
      error: _modeError,
    ),
    (
      mode: 'A',
      port: 'VΩ',
      connection: CurrentConnection.disconnected,
      error: _portError,
    ),
    (
      mode: 'A',
      port: 'VΩ',
      connection: CurrentConnection.acrossLamp,
      error: _portError,
    ),
    (
      mode: 'A',
      port: 'A',
      connection: CurrentConnection.disconnected,
      error: _disconnectedError,
    ),
    (
      mode: 'A',
      port: 'A',
      connection: CurrentConnection.acrossLamp,
      error: _parallelError,
    ),
  ];
  for (final c in errorCases) {
    testWidgets('error priority: ${c.mode}/${c.port}/${c.connection.name}', (
      tester,
    ) async {
      final h = _Harness(_block());
      await tester.pumpWidget(h.host());
      await _configure(
        tester,
        mode: c.mode,
        port: c.port,
        connection: c.connection,
      );
      _expectFuse(blown: false);
      await _tap(tester, find.text(_check));
      for (final error in [
        _modeError,
        _portError,
        _disconnectedError,
        _parallelError,
      ]) {
        expect(
          find.text(error),
          error == c.error ? findsOneWidget : findsNothing,
        );
      }
      expect(h.answers, [false]);
      expect(find.text(_retry), findsOneWidget);
    });
  }

  for (final connection in CurrentConnection.values) {
    testWidgets('V DC ignores port for ${connection.name} readout', (
      tester,
    ) async {
      final h = _Harness(_block(voltage: 14.25));
      await tester.pumpWidget(h.host());
      for (final port in ['A', 'VΩ']) {
        await _configure(
          tester,
          mode: 'V DC',
          port: port,
          connection: connection,
        );
        _expectReadout(
          connection == CurrentConnection.acrossBattery ? '14.25' : '0.00',
          'V DC',
        );
        _expectFuse(blown: false);
      }
      expect(h.answers, isEmpty);
    });
    testWidgets('A with VΩ masks connection ${connection.name}', (
      tester,
    ) async {
      await tester.pumpWidget(_Harness(_block()).host());
      await _configure(tester, port: 'VΩ', connection: connection);
      _expectReadout('----', 'A');
      _expectFuse(blown: false);
    });
  }

  for (final c in [
    (connection: CurrentConnection.disconnected, reading: '0.00'),
    (connection: CurrentConnection.acrossLamp, reading: '⚠'),
  ]) {
    testWidgets(
      'A current port ${c.connection.name} has ${c.reading} without fuse blow',
      (tester) async {
        final h = _Harness(_block());
        await tester.pumpWidget(h.host());
        await _configure(tester, connection: c.connection);
        _expectReadout(c.reading, 'A');
        _expectFuse(blown: false);
        _expectCheck(tester, enabled: true);
        expect(h.answers, isEmpty);
      },
    );
  }

  testWidgets('OFF with current port across battery does not blow fuse', (
    tester,
  ) async {
    await tester.pumpWidget(_Harness(_block()).host());
    await _configure(
      tester,
      mode: 'OFF',
      connection: CurrentConnection.acrossBattery,
    );
    _expectReadout('────', 'OFF');
    _expectFuse(blown: false);
    _expectCheck(tester, enabled: true);
  });

  for (final lastAction in ['connection', 'mode', 'port']) {
    testWidgets('fuse blows without check when $lastAction completes danger', (
      tester,
    ) async {
      final h = _Harness(_block());
      await tester.pumpWidget(h.host());
      await _configure(
        tester,
        mode: lastAction == 'mode' ? 'V DC' : 'A',
        port: lastAction == 'port' ? 'VΩ' : 'A',
        connection: lastAction == 'connection'
            ? CurrentConnection.series
            : CurrentConnection.acrossBattery,
      );
      _expectFuse(blown: false);
      _expectCheck(tester, enabled: true);
      expect(h.answers, isEmpty);
      if (lastAction == 'connection') {
        await _tap(
          tester,
          find.text(_connections[CurrentConnection.acrossBattery]!),
        );
      } else if (lastAction == 'mode') {
        await _tap(tester, _chip('A'));
      } else {
        await _tap(tester, _port('A'));
      }
      _expectFuse(blown: true);
      _expectReadout('FUSE', 'A');
      await _expectLocked(
        tester,
        mode: 'A',
        port: 'A',
        connection: CurrentConnection.acrossBattery,
      );
      expect(h.answers, isEmpty);
      expect(h.retries, 0);
      expect(find.text(_retry), findsNothing);
    });
  }

  testWidgets(
    'blow, replace, reset and successful check preserve callback lifecycle',
    (tester) async {
      final h = _Harness(_block());
      await tester.pumpWidget(h.host());
      await _configure(tester, connection: CurrentConnection.acrossBattery);
      _expectFuse(blown: true);
      await _tap(tester, find.text(_replace));
      _expectFuse(blown: false);
      _expectConfiguration(tester, 'OFF', 'VΩ', CurrentConnection.disconnected);
      _expectReadout('────', 'OFF');
      _expectCheck(tester, enabled: true);
      expect(h.answers, isEmpty);
      expect(h.retries, 0);
      await _configure(tester);
      await _tap(tester, find.text(_check));
      expect(h.answers, [true]);
      expect(h.retries, 0);
      expect(find.textContaining('✓ Правильно.\n\n'), findsOneWidget);
    },
  );

  testWidgets(
    'incorrect check locks controls, retry resets, next check succeeds',
    (tester) async {
      final h = _Harness(_block());
      await tester.pumpWidget(h.host());
      await _configure(tester, connection: CurrentConnection.acrossLamp);
      await _tap(tester, find.text(_check));
      expect(find.text(_parallelError), findsOneWidget);
      await _expectLocked(
        tester,
        mode: 'A',
        port: 'A',
        connection: CurrentConnection.acrossLamp,
      );
      expect(h.answers, [false]);
      await _tap(tester, find.text(_retry));
      _expectConfiguration(tester, 'OFF', 'VΩ', CurrentConnection.disconnected);
      _expectReadout('────', 'OFF');
      _expectFuse(blown: false);
      _expectCheck(tester, enabled: true);
      expect(find.text(_parallelError), findsNothing);
      expect(find.text(_retry), findsNothing);
      expect(h.answers, [false]);
      expect(h.retries, 1);
      await _configure(tester);
      await _tap(tester, find.text(_check));
      expect(h.answers, [false, true]);
      expect(h.retries, 1);
    },
  );

  for (final phase in ['configured', 'blown', 'checked']) {
    testWidgets('ordinary rebuild preserves $phase state without callbacks', (
      tester,
    ) async {
      final h = _Harness(_block());
      await tester.pumpWidget(h.host());
      final connection = phase == 'blown'
          ? CurrentConnection.acrossBattery
          : CurrentConnection.acrossLamp;
      await _configure(tester, connection: connection);
      if (phase == 'checked') await _tap(tester, find.text(_check));
      await tester.pumpWidget(h.host());
      _expectConfiguration(tester, 'A', 'A', connection);
      _expectReadout(phase == 'blown' ? 'FUSE' : '⚠', 'A');
      _expectFuse(blown: phase == 'blown');
      _expectCheck(tester, enabled: phase == 'configured');
      expect(h.answers, phase == 'checked' ? [false] : isEmpty);
      expect(h.retries, 0);
      if (phase == 'checked') {
        expect(find.text(_parallelError), findsOneWidget);
        expect(find.text(_retry), findsOneWidget);
      }
    });
  }

  // These characterize existing simplifications, not physically correct fuse rules.
  testWidgets('series current above fuse rating remains successful', (
    tester,
  ) async {
    final h = _Harness(_block(current: 12, rating: 1));
    await tester.pumpWidget(h.host());
    await _configure(tester);
    _expectReadout('12.00', 'A');
    _expectFuse(blown: false);
    await _tap(tester, find.text(_check));
    expect(h.answers, [true]);
    expect(find.textContaining('Показание: 12.00 A.'), findsOneWidget);
  });

  for (final c in [
    (voltage: 12.6, rating: 0.1),
    (voltage: 12.6, rating: 1000.0),
    (voltage: 0.0, rating: 10.0),
  ]) {
    testWidgets(
      'danger ignores voltage ${c.voltage} and fuse rating ${c.rating}',
      (tester) async {
        final h = _Harness(_block(voltage: c.voltage, rating: c.rating));
        await tester.pumpWidget(h.host());
        await _configure(tester);
        _expectFuse(blown: false);
        await _tap(
          tester,
          find.text(_connections[CurrentConnection.acrossBattery]!),
        );
        _expectFuse(blown: true);
        _expectReadout('FUSE', 'A');
        _expectCheck(tester, enabled: false);
        expect(h.answers, isEmpty);
      },
    );
  }
}
