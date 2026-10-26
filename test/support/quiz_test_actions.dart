import 'package:electrician/models/lesson.dart';
import 'package:electrician/models/lesson_block.dart';
import 'package:electrician/simulation/voltage_drop_simulation.dart';
import 'package:electrician/widgets/lesson_blocks/measurement_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widgets/oscilloscope_block_test.dart' as scope_support show select;

Future<void> settleQuiz(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  }
  await tester.pumpAndSettle();
}

Future<void> revealQuiz(
  WidgetTester tester,
  Finder target, {
  double? direction,
  bool card = false,
}) async {
  var step = direction?.sign ?? 1.0;
  for (var i = 0; i < 300; i++) {
    if (target.evaluate().isNotEmpty) {
      final anchor = card
          ? find.descendant(of: target, matching: find.byType(Text)).first
          : target;
      if (anchor.hitTestable().evaluate().isNotEmpty) {
        await tester.ensureVisible(anchor);
        await settleQuiz(tester);
        return;
      }
      if (direction == null) {
        final y = tester.getCenter(anchor).dy;
        if (y.isFinite) step = y < 70 ? -1 : 1;
      }
    }
    final scrollable = find.byType(Scrollable).first;
    final origin =
        tester.getTopLeft(scrollable) +
        Offset(5, tester.getSize(scrollable).height / 2);
    await tester.dragFrom(origin, Offset(0, -step * 150));
    await settleQuiz(tester);
  }
  fail(
    'Could not reveal $target at ${tester.state<ScrollableState>(find.byType(Scrollable).first).position}',
  );
}

Future<void> tapQuiz(WidgetTester tester, Finder target) async {
  await revealQuiz(tester, target);
  await tester.tap(target);
  await settleQuiz(tester);
}

List<int> quizTaskIndices(Lesson lesson) => [
  for (var i = 0; i < lesson.blocks.length; i++)
    if (lesson.blocks[i] is QuestionLessonBlock ||
        lesson.blocks[i] is CalculationLessonBlock ||
        lesson.blocks[i] is MeasurementLessonBlock ||
        lesson.blocks[i] is VoltageDropLessonBlock ||
        lesson.blocks[i] is CurrentMeasurementLessonBlock ||
        lesson.blocks[i] is OscilloscopeLessonBlock)
      i,
];

Finder quizCard(Lesson lesson, int index) {
  final type = switch (lesson.blocks[index]) {
    VoltageDropLessonBlock() => 'voltage_drop',
    CurrentMeasurementLessonBlock() => 'current',
    _ => lesson.blocks[index].type,
  };
  return find.byKey(ValueKey('${type}_$index'));
}

Future<void> prepareQuizTask(
  WidgetTester tester,
  Lesson lesson,
  int index, {
  bool correct = true,
}) async {
  final block = lesson.blocks[index], card = quizCard(lesson, index);
  Finder within(Finder finder) => find.descendant(of: card, matching: finder);
  await revealQuiz(tester, card, card: true);
  Future<void> chip(String label) =>
      tapQuiz(tester, within(find.widgetWithText(ChoiceChip, label)));
  Future<void> probe<T>(int index, String label) => tapQuiz(
    tester,
    find.descendant(
      of: within(find.byType(SegmentedButton<T>)).at(index),
      matching: find.text(label),
    ),
  );
  switch (block) {
    case QuestionLessonBlock(:final correctAnswer, :final answers):
      await tapQuiz(
        tester,
        within(find.byType(RadioListTile<int>))
            .at(correct ? correctAnswer : (correctAnswer + 1) % answers.length),
      );
    case CalculationLessonBlock(:final correctValue):
      final field = within(find.byType(TextField));
      await revealQuiz(tester, field);
      await tester.enterText(
        field,
        '${correct ? correctValue : correctValue + 1}'.replaceAll('.', ','),
      );
      await settleQuiz(tester);
    case OscilloscopeLessonBlock(:final exercise):
      final (id, right, wrong) = switch (exercise.name) {
        'voltageScale' => ('volts', '2.0 V/div', '5.0 V/div'),
        'timeScale' => ('time', '4.0 ms/div', '1.0 ms/div'),
        _ => ('level', '2.5 V', '6.0 V'),
      };
      await scope_support.select(tester, id, right, within: card);
      if (exercise.name == 'trigger') {
        await scope_support.select(
          tester,
          'edge',
          'Положительный ↑',
          within: card,
        );
      }
      if (!correct) await scope_support.select(tester, id, wrong, within: card);
    case BatteryVoltageMeasurementLessonBlock():
      await chip('V DC');
      await probe<BatteryTerminal>(0, correct ? '+' : '−');
      await probe<BatteryTerminal>(1, '−');
    case ConductorMeasurementLessonBlock():
      if (correct && block.initiallyPowered == true) {
        await tapQuiz(
          tester,
          within(find.widgetWithText(OutlinedButton, 'Отключить питание')),
        );
      }
      await chip('Ω');
      await probe<WirePoint>(0, 'A');
      await probe<WirePoint>(1, correct ? 'B' : 'A');
    case VoltageDropLessonBlock(:final initiallyLoaded):
      await probe<VoltageDropPoint>(0, 'A');
      await probe<VoltageDropPoint>(1, correct ? 'B' : 'A');
      if (!initiallyLoaded) {
        await tapQuiz(
          tester,
          within(find.widgetWithText(OutlinedButton, 'Включить лампу')),
        );
      }
    case CurrentMeasurementLessonBlock():
      await chip('A');
      // A port is a separate InkWell, outside the mode ChoiceChip.
      final port = find.ancestor(
        of: within(find.text('A')),
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
      await tapQuiz(tester, port);
      await tapQuiz(
        tester,
        within(
          find.text(
            correct ? 'В разрыв цепи (последовательно)' : 'Параллельно лампе',
          ),
        ),
      );
    default:
      throw StateError('Uncovered quiz task ${block.type}');
  }
}

Future<void> fillQuiz(
  WidgetTester tester,
  Lesson lesson, {
  required Set<int> wrongTasks,
}) async {
  tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position
      .jumpTo(0);
  await settleQuiz(tester);
  final ids = quizTaskIndices(lesson);
  for (var task = 0; task < ids.length; task++) {
    await prepareQuizTask(
      tester,
      lesson,
      ids[task],
      correct: !wrongTasks.contains(task),
    );
  }
}

Future<void> submitQuiz(WidgetTester tester) async {
  await tapQuiz(tester, find.byKey(const ValueKey('quiz_submit')));
  await revealQuiz(
    tester,
    find.widgetWithText(FilledButton, 'Завершить проверку'),
  );
}

Future<void> retryQuiz(WidgetTester tester) =>
    tapQuiz(tester, find.byKey(const ValueKey('quiz_retry')));
