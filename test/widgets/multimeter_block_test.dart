import 'dart:convert';

import 'package:electrician/models/lesson.dart';
import 'package:electrician/models/lesson_block.dart';
import 'package:electrician/widgets/lesson_blocks/multimeter_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _modes = [
  (initial: 'off', label: 'OFF', reading: '────'),
  (initial: 'dcVoltage', label: 'V DC', reading: '0.00'),
  (initial: 'acVoltage', label: 'V AC', reading: '0.00'),
  (initial: 'resistance', label: 'Ω', reading: 'OL'),
  (initial: 'current', label: 'A', reading: '0.00'),
];
const _warning =
    '⚠ Даже при правильно переставленном красном щупе '
    'мультиметр в режиме A нельзя подключать напрямую '
    'параллельно аккумулятору.';
const _voltageError =
    'Красный щуп находится в токовом гнезде A. '
    'Для измерения напряжения переставь его в VΩ.';
const _correctMessages = {
  'V DC':
      '✓ Для измерения постоянного напряжения '
      'красный щуп находится в правильном гнезде VΩ.',
  'V AC':
      '✓ Для измерения переменного напряжения '
      'красный щуп находится в правильном гнезде VΩ.',
  'Ω':
      '✓ Для измерения сопротивления красный '
      'щуп находится в правильном гнезде VΩ.',
  'A':
      '✓ Для учебного режима измерения тока красный '
      'щуп переставлен в токовое гнездо A.',
};
const _incorrectMessages = {
  'V DC': _voltageError,
  'V AC': _voltageError,
  'Ω':
      'Красный щуп находится в токовом гнезде A. '
      'Для измерения сопротивления переставь его в VΩ.',
  'A':
      'Красный щуп находится в VΩ. Для выбранного '
      'учебного режима измерения тока переставь его в гнездо A.',
};

MultimeterLessonBlock _block(String mode, {bool interactive = true}) =>
    MultimeterLessonBlock(
      title: 'Учебный мультиметр',
      interactive: interactive,
      multimeterMode: mode,
      caption: 'Выбери режим и вход.',
    );

Widget _host(MultimeterLessonBlock block) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(child: MultimeterBlock(block: block)),
  ),
);

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

void _expectMode(WidgetTester tester, String label, String reading) {
  for (final mode in _modes) {
    expect(
      tester.widget<ChoiceChip>(_chip(mode.label)).selected,
      mode.label == label,
    );
  }
  expect(find.text(reading), findsOneWidget);
  // Exclude selector/port labels: A occurs in both controls and the display.
  final displayUnit = find.byElementPredicate((element) {
    if (element.widget case Text(data: final data) when data == label) {
      var isControlLabel = false;
      element.visitAncestorElements((ancestor) {
        if (ancestor.widget is ChoiceChip || ancestor.widget is InkWell) {
          isControlLabel = true;
        }
        return true;
      });
      return !isControlLabel;
    }
    return false;
  });
  expect(displayUnit, findsOneWidget);
}

void _expectPort(String selected) {
  for (final label in ['VΩ', 'A']) {
    expect(
      find.descendant(of: _port(label), matching: find.text('красный щуп')),
      label == selected ? findsOneWidget : findsNothing,
    );
  }
}

void _expectStatus(String mode, String port) {
  final correct = mode == 'A' ? port == 'A' : port == 'VΩ';
  final expected = mode == 'OFF'
      ? null
      : (correct ? _correctMessages[mode] : _incorrectMessages[mode]);
  for (final message in {
    ..._correctMessages.values,
    ..._incorrectMessages.values,
  }) {
    expect(
      find.text(message),
      message == expected ? findsOneWidget : findsNothing,
    );
  }
  expect(
    find.byIcon(Icons.check_circle_outline),
    mode != 'OFF' && correct ? findsOneWidget : findsNothing,
  );
  expect(
    find.byIcon(Icons.warning_amber),
    mode != 'OFF' && !correct ? findsOneWidget : findsNothing,
  );
}

void main() {
  group('initialization', () {
    for (final mode in _modes) {
      testWidgets('${mode.label} starts with the red probe in VΩ', (
        tester,
      ) async {
        await tester.pumpWidget(_host(_block(mode.initial)));
        _expectMode(tester, mode.label, mode.reading);
        _expectPort('VΩ');
      });
    }
    testWidgets('unknown nonempty initial mode falls back to OFF', (
      tester,
    ) async {
      await tester.pumpWidget(_host(_block('unsupported')));
      _expectMode(tester, 'OFF', '────');
      _expectPort('VΩ');
      _expectStatus('OFF', 'VΩ');
    });
  });

  group('mode × red port', () {
    for (final mode in _modes) {
      for (final port in ['VΩ', 'A']) {
        testWidgets('${mode.label} + $port: display, unit and status', (
          tester,
        ) async {
          await tester.pumpWidget(_host(_block(mode.initial)));
          await _tap(tester, _port(port));
          _expectMode(tester, mode.label, mode.reading);
          _expectPort(port);
          _expectStatus(mode.label, port);
        });
      }
    }
  });

  testWidgets(
    'current warning remains for both ports and disappears outside A',
    (tester) async {
      await tester.pumpWidget(_host(_block('current')));
      expect(find.text(_warning), findsOneWidget);
      await _tap(tester, _port('A'));
      expect(find.text(_warning), findsOneWidget);
      for (final mode in _modes.where((mode) => mode.label != 'A')) {
        await _tap(tester, _chip(mode.label));
        expect(find.text(_warning), findsNothing);
        await _tap(tester, _chip('A'));
        expect(find.text(_warning), findsOneWidget);
      }
    },
  );

  testWidgets(
    'mode changes preserve VΩ and then A through other modes and OFF',
    (tester) async {
      await tester.pumpWidget(_host(_block('off')));
      for (final mode in _modes) {
        await _tap(tester, _chip(mode.label));
        _expectMode(tester, mode.label, mode.reading);
        _expectPort('VΩ');
      }
      await _tap(tester, _port('A'));
      for (final mode in [..._modes.reversed, _modes.last]) {
        await _tap(tester, _chip(mode.label));
        _expectMode(tester, mode.label, mode.reading);
        _expectPort('A');
      }
    },
  );

  for (final mode in _modes) {
    testWidgets(
      '${mode.label}: changing ports preserves demonstration reading',
      (tester) async {
        await tester.pumpWidget(_host(_block(mode.initial)));
        for (final port in ['A', 'VΩ']) {
          await _tap(tester, _port(port));
          _expectPort(port);
          _expectMode(tester, mode.label, mode.reading);
        }
      },
    );
  }

  for (final initial in [_modes.first, _modes.last]) {
    testWidgets(
      'non-interactive initial ${initial.label} ignores mode and port taps',
      (tester) async {
        await tester.pumpWidget(
          _host(_block(initial.initial, interactive: false)),
        );
        for (final mode in _modes) {
          await _tap(tester, _chip(mode.label));
          _expectMode(tester, initial.label, initial.reading);
          _expectPort('VΩ');
          _expectStatus(initial.label, 'VΩ');
        }
        for (final port in ['A', 'VΩ']) {
          await _tap(tester, _port(port));
          _expectMode(tester, initial.label, initial.reading);
          _expectPort('VΩ');
          _expectStatus(initial.label, 'VΩ');
        }
        expect(
          find.text(_warning),
          initial.label == 'A' ? findsOneWidget : findsNothing,
        );
      },
    );
  }

  testWidgets('ordinary rebuild preserves selected mode and red port', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_block('off')));
    await _tap(tester, _chip('Ω'));
    await _tap(tester, _port('A'));
    // Same widget type and position; a new configuration triggers a rebuild.
    await tester.pumpWidget(_host(_block('off')));
    _expectMode(tester, 'Ω', 'OL');
    _expectPort('A');
    _expectStatus('Ω', 'A');
  });

  testWidgets(
    'real course block presents title, caption, fixed COM and selected red port',
    (tester) async {
      final json = await rootBundle.loadString(
        'assets/course/stage_2/lesson_01.json',
      );
      final lesson = Lesson.fromJson(jsonDecode(json) as Map<String, dynamic>);
      final block = lesson.blocks.whereType<MultimeterLessonBlock>().single;
      await tester.pumpWidget(_host(block));
      expect(find.text('Виртуальный мультиметр'), findsOneWidget);
      expect(
        find.text('Попробуй последовательно выбрать OFF, V DC, V AC, Ω и A.'),
        findsOneWidget,
      );
      _expectMode(tester, 'OFF', '────');
      _expectPort('VΩ');
      for (final port in ['A', 'VΩ']) {
        await _tap(tester, _port(port));
        _expectPort(port);
        expect(find.text('COM'), findsOneWidget);
        expect(find.text('чёрный щуп'), findsOneWidget);
        expect(find.widgetWithText(InkWell, 'COM'), findsNothing);
        // The fixed black probe and selected red probe both retain a cable icon.
        expect(find.byIcon(Icons.cable), findsNWidgets(2));
      }
    },
  );
}
