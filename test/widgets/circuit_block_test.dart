import 'package:electrician/models/lesson_block.dart';
import 'package:electrician/widgets/lesson_blocks/circuit_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _parallelFault =
    'Обрыв произошёл только в ветви лампы 1. '
    'Ветка лампы 2 остаётся замкнутой, поэтому '
    'лампа 2 продолжает работать.';
const _seriesFault =
    'Обрыв лампы 1 разорвал единственный путь тока. '
    'Поэтому ток не проходит ни через лампу 1, ни через лампу 2.';

CircuitLessonBlock _block(
  String type, {
  bool interactive = true,
  bool? initiallyClosed,
}) => CircuitLessonBlock.fromJson({
  'circuitType': type,
  'title': 'Заголовок схемы',
  'caption': 'Подпись схемы',
  'interactive': interactive,
  'initiallyClosed': ?initiallyClosed,
});

Future<void> _pump(WidgetTester tester, CircuitLessonBlock block) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: CircuitBlock(key: const ValueKey('circuit'), block: block),
        ),
      ),
    ),
  );
}

Future<void> _tap(WidgetTester tester, String label) async {
  final button = find.text(label);
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void _expectSimple(bool closed, {bool interactive = true}) {
  expect(
    find.text(
      closed
          ? 'Цепь замкнута. Лампа включена.'
          : 'Цепь разомкнута. Лампа выключена.',
    ),
    findsOneWidget,
  );
  expect(
    find.text(
      closed
          ? 'Цепь разомкнута. Лампа выключена.'
          : 'Цепь замкнута. Лампа включена.',
    ),
    findsNothing,
  );
  expect(
    find.widgetWithText(
      FilledButton,
      closed ? 'Разомкнуть цепь' : 'Замкнуть цепь',
    ),
    interactive ? findsOneWidget : findsNothing,
  );
  expect(find.text(closed ? 'Замкнуть цепь' : 'Разомкнуть цепь'), findsNothing);
}

void _expectLamp(int number, String indication, bool works) {
  final label = find.text('Лампа $number: $indication');
  expect(label, findsOneWidget);
  final row = find.ancestor(of: label, matching: find.byType(Row));
  expect(row, findsOneWidget);
  expect(
    find.descendant(
      of: row,
      matching: find.text(works ? 'РАБОТАЕТ' : 'НЕ РАБОТАЕТ'),
    ),
    findsOneWidget,
  );
  expect(
    find.descendant(
      of: row,
      matching: find.text(works ? 'НЕ РАБОТАЕТ' : 'РАБОТАЕТ'),
    ),
    findsNothing,
  );
}

void _expectTwo({required bool parallel, required bool fault}) {
  expect(
    find.text(
      parallel ? 'ПАРАЛЛЕЛЬНОЕ СОЕДИНЕНИЕ' : 'ПОСЛЕДОВАТЕЛЬНОЕ СОЕДИНЕНИЕ',
    ),
    findsOneWidget,
  );
  expect(
    find.text(
      parallel ? 'ПОСЛЕДОВАТЕЛЬНОЕ СОЕДИНЕНИЕ' : 'ПАРАЛЛЕЛЬНОЕ СОЕДИНЕНИЕ',
    ),
    findsNothing,
  );
  expect(find.text('Источник: 12 V'), findsOneWidget);
  _expectLamp(1, fault ? 'обрыв' : (parallel ? '12 V' : '≈ 6 V'), !fault);
  _expectLamp(
    2,
    parallel ? '12 V' : (fault ? 'ток не проходит' : '≈ 6 V'),
    parallel || !fault,
  );
  expect(
    find.text(
      parallel
          ? 'Каждая лампа находится в собственной ветви.'
          : 'Обе лампы находятся в одном пути тока.',
    ),
    findsOneWidget,
  );
  expect(
    find.text(_parallelFault),
    fault && parallel ? findsOneWidget : findsNothing,
  );
  expect(
    find.text(_seriesFault),
    fault && !parallel ? findsOneWidget : findsNothing,
  );
}

void main() {
  group('simpleLamp', () {
    for (final initial in <bool?>[false, true, null]) {
      testWidgets('initiallyClosed=$initial initializes the visible state', (
        tester,
      ) async {
        await _pump(tester, _block('simpleLamp', initiallyClosed: initial));
        _expectSimple(initial ?? false);
      });
    }

    testWidgets('switches open -> closed -> open with matching button labels', (
      tester,
    ) async {
      await _pump(tester, _block('simpleLamp', initiallyClosed: false));
      _expectSimple(false);
      await _tap(tester, 'Замкнуть цепь');
      _expectSimple(true);
      await _tap(tester, 'Разомкнуть цепь');
      _expectSimple(false);
    });

    for (final closed in [false, true]) {
      testWidgets('non-interactive circuit displays closed=$closed', (
        tester,
      ) async {
        await _pump(
          tester,
          _block('simpleLamp', interactive: false, initiallyClosed: closed),
        );
        _expectSimple(closed, interactive: false);
        expect(find.byType(FilledButton), findsNothing);
        expect(find.byType(OutlinedButton), findsNothing);
      });
    }

    testWidgets('ordinary rebuild preserves the switched state', (
      tester,
    ) async {
      final block = _block('simpleLamp');
      await _pump(tester, block);
      await _tap(tester, 'Замкнуть цепь');
      await _pump(tester, block);
      _expectSimple(true);
    });
  });

  group('twoLamps', () {
    for (final parallel in [true, false]) {
      for (final fault in [false, true]) {
        testWidgets('parallel=$parallel, lamp1Open=$fault', (tester) async {
          await _pump(tester, _block('twoLamps'));
          if (!parallel) await _tap(tester, 'Показать последовательное');
          if (fault) await _tap(tester, 'Создать обрыв лампы 1');
          _expectTwo(parallel: parallel, fault: fault);
          expect(
            find.widgetWithText(
              FilledButton,
              parallel ? 'Показать последовательное' : 'Показать параллельное',
            ),
            findsOneWidget,
          );
          expect(
            find.widgetWithText(
              OutlinedButton,
              fault ? 'Устранить обрыв лампы 1' : 'Создать обрыв лампы 1',
            ),
            findsOneWidget,
          );
        });
      }
    }

    testWidgets('fault survives topology changes in both directions', (
      tester,
    ) async {
      await _pump(tester, _block('twoLamps'));
      await _tap(tester, 'Создать обрыв лампы 1');
      _expectTwo(parallel: true, fault: true);
      await _tap(tester, 'Показать последовательное');
      _expectTwo(parallel: false, fault: true);
      await _tap(tester, 'Показать параллельное');
      _expectTwo(parallel: true, fault: true);
    });

    for (final parallel in [true, false]) {
      testWidgets('repair restores lamps in parallel=$parallel', (
        tester,
      ) async {
        await _pump(tester, _block('twoLamps'));
        if (!parallel) await _tap(tester, 'Показать последовательное');
        await _tap(tester, 'Создать обрыв лампы 1');
        _expectTwo(parallel: parallel, fault: true);
        await _tap(tester, 'Устранить обрыв лампы 1');
        _expectTwo(parallel: parallel, fault: false);
        expect(find.text('Создать обрыв лампы 1'), findsOneWidget);
        expect(find.text('Устранить обрыв лампы 1'), findsNothing);
      });
    }

    testWidgets('non-interactive circuit shows healthy parallel lamps', (
      tester,
    ) async {
      await _pump(tester, _block('twoLamps', interactive: false));
      _expectTwo(parallel: true, fault: false);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
    });

    for (final initial in <bool?>[false, true, null]) {
      testWidgets('ignores initiallyClosed=$initial', (tester) async {
        await _pump(tester, _block('twoLamps', initiallyClosed: initial));
        _expectTwo(parallel: true, fault: false);
      });
    }

    testWidgets('ordinary rebuild preserves topology and fault', (
      tester,
    ) async {
      final block = _block('twoLamps');
      await _pump(tester, block);
      await _tap(tester, 'Показать последовательное');
      await _tap(tester, 'Создать обрыв лампы 1');
      await _pump(tester, block);
      _expectTwo(parallel: false, fault: true);
      expect(find.text('Показать параллельное'), findsOneWidget);
      expect(find.text('Устранить обрыв лампы 1'), findsOneWidget);
    });
  });

  for (final type in ['simpleLamp', 'twoLamps']) {
    testWidgets('$type displays title and caption', (tester) async {
      await _pump(tester, _block(type));
      expect(find.text('Заголовок схемы'), findsOneWidget);
      expect(find.text('Подпись схемы'), findsOneWidget);
    });
  }

  testWidgets('parser-accepted unknown circuit type displays fallback', (
    tester,
  ) async {
    // The current parser requires a non-empty string, not a known circuit type.
    await _pump(tester, _block('unknownCircuit'));
    expect(find.text('Неизвестный тип электрической схемы'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  });
}
