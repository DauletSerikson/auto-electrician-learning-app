import 'dart:convert';

import 'package:electrician/models/lesson.dart';
import 'package:electrician/models/lesson_block.dart';
import 'package:electrician/widgets/lesson_blocks/diagnostic_choice_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _labels = [
  'Напряжение АКБ',
  'До предохранителя',
  'После предохранителя',
  'Плюс лампы',
  'Масса лампы',
];

DiagnosticChoiceLessonBlock _synthetic(
  String fault, {
  double voltage = 13.25,
  int correct = 2,
}) => DiagnosticChoiceLessonBlock(
  title: 'Synthetic diagnostic choice',
  question: 'Выбери диагноз',
  sourceVoltage: voltage,
  faultType: fault,
  diagnosisOptions: const ['Fuse', 'Positive wire', 'Ground', 'Lamp'],
  correctDiagnosis: correct,
  explanation: 'Synthetic explanation',
);

class _Exercise {
  final WidgetTester tester;
  final answers = <bool>[];
  int retries = 0;

  _Exercise(this.tester);

  Finder get check => find.widgetWithText(FilledButton, 'Проверить диагноз');
  Finder get retry =>
      find.widgetWithText(OutlinedButton, 'Попробовать ещё раз');
  Finder get history => find.byWidgetPredicate(
    (widget) => widget is ListTile && widget.trailing is Text,
  );
  RadioGroup<int> get group =>
      tester.widget<RadioGroup<int>>(find.byType(RadioGroup<int>));
  List<String> get historyLabels => tester
      .widgetList<ListTile>(history)
      .map((tile) => (tile.title! as Text).data!)
      .toList();
  List<String> get readings => tester
      .widgetList<ListTile>(history)
      .map((tile) => (tile.trailing! as Text).data!)
      .toList();

  Future<void> pump(DiagnosticChoiceLessonBlock block) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DiagnosticChoiceBlock(
            key: const ValueKey('diagnostic-choice'),
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

  Finder measurement(int index) =>
      find.widgetWithText(OutlinedButton, _labels[index]);
  Future<void> measure(int index) => tap(measurement(index));
  Future<void> select(int index) =>
      tap(find.byType(RadioListTile<int>).at(index));

  void expectEmptyHistory() {
    expect(history, findsNothing);
    expect(find.textContaining('Измерений пока нет.'), findsOneWidget);
  }

  void expectResult(bool success) {
    expect(
      find.text('✓ Диагноз правильный'),
      success ? findsOneWidget : findsNothing,
    );
    expect(
      find.textContaining('✗ Диагноз не подтверждается'),
      success ? findsNothing : findsOneWidget,
    );
    expect(retry, success ? findsNothing : findsOneWidget);
  }

  void expectInitial() {
    expectEmptyHistory();
    expect(group.groupValue, isNull);
    expect(tester.widget<FilledButton>(check).onPressed, isNull);
    expect(find.text('✓ Диагноз правильный'), findsNothing);
    expect(find.textContaining('✗ Диагноз не подтверждается'), findsNothing);
    expect(retry, findsNothing);
    for (var index = 0; index < 5; index++) {
      expect(
        tester.widget<OutlinedButton>(measurement(index)).onPressed,
        isNotNull,
      );
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DiagnosticChoiceLessonBlock realBlock;
  setUpAll(() async {
    final json = await rootBundle.loadString(
      'assets/course/stage_2/lesson_08.json',
    );
    final lesson = Lesson.fromJson(jsonDecode(json) as Map<String, dynamic>);
    realBlock = lesson.blocks.whereType<DiagnosticChoiceLessonBlock>().single;
  });

  testWidgets(
    'real groundOpen asset starts empty and exposes all five readings',
    (tester) async {
      final exercise = _Exercise(tester);
      await exercise.pump(realBlock);
      expect(realBlock.faultType, 'groundOpen');
      expect(realBlock.correctDiagnosis, 2);
      expect(realBlock.diagnosisOptions, [
        'Перегорел предохранитель',
        'Обрыв плюсового провода',
        'Обрыв массы лампы',
        'Неисправна сама лампа',
      ]);
      expect(find.byType(RadioListTile<int>), findsNWidgets(4));
      for (final option in realBlock.diagnosisOptions) {
        expect(find.text(option), findsOneWidget);
      }
      exercise.expectInitial();
      expect(exercise.answers, isEmpty);
      expect(exercise.retries, 0);
      for (var index = 0; index < 5; index++) {
        await exercise.measure(index);
        expect(exercise.readings, List.filled(index + 1, '12.60 V'));
      }
      expect(exercise.historyLabels, _labels);
      expect(exercise.group.groupValue, isNull);
      expect(tester.widget<FilledButton>(exercise.check).onPressed, isNull);
      expect(exercise.answers, isEmpty);
      expect(exercise.retries, 0);
    },
  );

  final tables = <String, List<String>>{
    'blownFuse': ['13.25 V', '13.25 V', '0.00 V', '0.00 V', '0.00 V'],
    'positiveWireOpen': ['13.25 V', '13.25 V', '13.25 V', '0.00 V', '0.00 V'],
    // Characterizes the fallback; this is not an officially supported fault.
    'unknownNonEmptyFault': [
      '13.25 V',
      '13.25 V',
      '13.25 V',
      '13.25 V',
      '0.00 V',
    ],
  };
  for (final entry in tables.entries) {
    testWidgets('${entry.key} observable measurement table', (tester) async {
      final exercise = _Exercise(tester);
      await exercise.pump(_synthetic(entry.key));
      for (var index = 0; index < 5; index++) {
        await exercise.measure(index);
      }
      expect(exercise.historyLabels, _labels);
      expect(exercise.readings, entry.value);
      expect(exercise.answers, isEmpty);
      expect(exercise.retries, 0);
    });
  }

  for (final success in [true, false]) {
    testWidgets(
      '${success ? 'correct' : 'wrong'} diagnosis without measurements',
      (tester) async {
        final exercise = _Exercise(tester);
        await exercise.pump(realBlock);
        await exercise.select(success ? 2 : 0);
        expect(exercise.group.groupValue, success ? 2 : 0);
        expect(
          tester.widget<FilledButton>(exercise.check).onPressed,
          isNotNull,
        );
        await exercise.tap(exercise.check);
        exercise.expectEmptyHistory();
        exercise.expectResult(success);
        expect(exercise.answers, [success]);
        expect(exercise.retries, 0);
      },
    );
  }

  for (final count in [1, 3]) {
    testWidgets('$count measurements are sufficient for a correct answer', (
      tester,
    ) async {
      final exercise = _Exercise(tester);
      await exercise.pump(realBlock);
      await exercise.measure(0);
      await exercise.select(0);
      for (var index = 1; index < count; index++) {
        await exercise.measure(index);
      }
      await exercise.select(2);
      expect(exercise.historyLabels, _labels.take(count).toList());
      await exercise.tap(exercise.check);
      exercise.expectResult(true);
      expect(exercise.answers, [true]);
    });
  }

  testWidgets(
    'measurement after diagnosis preserves selection and allows success',
    (tester) async {
      final exercise = _Exercise(tester);
      await exercise.pump(realBlock);
      await exercise.select(2);
      await exercise.measure(4);
      expect(exercise.group.groupValue, 2);
      expect(exercise.readings, ['12.60 V']);
      await exercise.tap(exercise.check);
      exercise.expectResult(true);
      expect(exercise.answers, [true]);
    },
  );

  testWidgets(
    'check without diagnosis stays disabled before and after measurements',
    (tester) async {
      final exercise = _Exercise(tester);
      await exercise.pump(realBlock);
      await exercise.tap(exercise.check);
      await exercise.measure(0);
      await exercise.measure(4);
      expect(tester.widget<FilledButton>(exercise.check).onPressed, isNull);
      await exercise.tap(exercise.check);
      expect(exercise.group.groupValue, isNull);
      expect(exercise.answers, isEmpty);
      expect(exercise.retries, 0);
      expect(find.text('✓ Диагноз правильный'), findsNothing);
      expect(find.textContaining('✗ Диагноз не подтверждается'), findsNothing);
    },
  );

  testWidgets(
    'history deduplicates tests and preserves first execution order',
    (tester) async {
      final exercise = _Exercise(tester);
      await exercise.pump(_synthetic('blownFuse'));
      await exercise.measure(3);
      expect(exercise.historyLabels, [_labels[3]]);
      expect(exercise.readings, ['0.00 V']);
      await exercise.measure(0);
      await exercise.measure(3);
      await exercise.measure(2);
      await exercise.measure(0);
      expect(exercise.historyLabels, [_labels[3], _labels[0], _labels[2]]);
      expect(exercise.readings, ['0.00 V', '13.25 V', '0.00 V']);
      expect(exercise.answers, isEmpty);
      expect(exercise.retries, 0);
    },
  );

  for (final success in [true, false]) {
    testWidgets(
      '${success ? 'successful' : 'failed'} check locks all controls',
      (tester) async {
        final exercise = _Exercise(tester);
        await exercise.pump(realBlock);
        await exercise.measure(0);
        final selected = success ? 2 : 0;
        await exercise.select(selected);
        await exercise.tap(exercise.check);
        for (var index = 0; index < 5; index++) {
          expect(
            tester
                .widget<OutlinedButton>(exercise.measurement(index))
                .onPressed,
            isNull,
          );
          await exercise.measure(index);
        }
        for (final tile in tester.widgetList<RadioListTile<int>>(
          find.byType(RadioListTile<int>),
        )) {
          expect(tile.enabled, isFalse);
        }
        await exercise.select(success ? 0 : 2);
        // RadioGroup retains its public handler, but the checked guard ignores it.
        exercise.group.onChanged(success ? 0 : 2);
        await tester.pump();
        expect(tester.widget<FilledButton>(exercise.check).onPressed, isNull);
        await exercise.tap(exercise.check);
        expect(exercise.group.groupValue, selected);
        expect(exercise.historyLabels, [_labels[0]]);
        expect(exercise.readings, ['12.60 V']);
        exercise.expectResult(success);
        expect(exercise.answers, [success]);
        expect(exercise.retries, 0);
      },
    );
  }

  testWidgets('retry resets the entire attempt and permits a correct answer', (
    tester,
  ) async {
    final exercise = _Exercise(tester);
    await exercise.pump(realBlock);
    await exercise.measure(0);
    await exercise.measure(4);
    await exercise.select(0);
    await exercise.tap(exercise.check);
    exercise.expectResult(false);
    await exercise.tap(exercise.retry);
    exercise.expectInitial();
    expect(exercise.answers, [false]);
    expect(exercise.retries, 1);
    await exercise.select(2);
    await exercise.tap(exercise.check);
    exercise.expectEmptyHistory();
    exercise.expectResult(true);
    expect(exercise.answers, [false, true]);
    expect(exercise.retries, 1);
  });

  testWidgets(
    'same-key parent rebuild preserves pending history and diagnosis',
    (tester) async {
      final exercise = _Exercise(tester);
      await exercise.pump(realBlock);
      await exercise.measure(3);
      await exercise.select(2);
      await exercise.pump(realBlock);
      expect(exercise.historyLabels, [_labels[3]]);
      expect(exercise.readings, ['12.60 V']);
      expect(exercise.group.groupValue, 2);
      expect(tester.widget<FilledButton>(exercise.check).onPressed, isNotNull);
      expect(exercise.answers, isEmpty);
      expect(exercise.retries, 0);
    },
  );

  for (final success in [true, false]) {
    testWidgets(
      'parent rebuild preserves ${success ? 'completed' : 'failed'} checked attempt',
      (tester) async {
        final exercise = _Exercise(tester);
        await exercise.pump(realBlock);
        await exercise.measure(4);
        await exercise.select(success ? 2 : 0);
        await exercise.tap(exercise.check);
        await exercise.pump(realBlock);
        expect(exercise.historyLabels, [_labels[4]]);
        expect(exercise.readings, ['12.60 V']);
        expect(exercise.group.groupValue, success ? 2 : 0);
        expect(tester.widget<FilledButton>(exercise.check).onPressed, isNull);
        exercise.expectResult(success);
        expect(exercise.answers, [success]);
        expect(exercise.retries, 0);
      },
    );
  }

  for (final success in [true, false]) {
    testWidgets(
      'same-key content replacement recalculates readings but retains ${success ? 'success' : 'failure'}',
      (tester) async {
        final exercise = _Exercise(tester);
        await exercise.pump(realBlock);
        for (var index = 0; index < 5; index++) {
          await exercise.measure(index);
        }
        final selected = success ? 2 : 0;
        await exercise.select(selected);
        await exercise.tap(exercise.check);
        await exercise.pump(
          _synthetic(
            'blownFuse',
            voltage: 14.4,
            correct: success ? 0 : selected,
          ),
        );
        expect(exercise.historyLabels, _labels);
        expect(exercise.readings, [
          '14.40 V',
          '14.40 V',
          '0.00 V',
          '0.00 V',
          '0.00 V',
        ]);
        expect(exercise.group.groupValue, selected);
        expect(find.text('Synthetic diagnostic choice'), findsOneWidget);
        expect(find.text('Ground'), findsOneWidget);
        expect(tester.widget<FilledButton>(exercise.check).onPressed, isNull);
        exercise.expectResult(success);
        expect(
          find.text('Synthetic explanation'),
          success ? findsOneWidget : findsNothing,
        );
        expect(exercise.answers, [success]);
        expect(exercise.retries, 0);
      },
    );
  }

  testWidgets(
    'content correct index determines correctness independently of fault',
    (tester) async {
      final exercise = _Exercise(tester);
      await exercise.pump(_synthetic('blownFuse', correct: 3));
      await exercise.measure(2);
      expect(exercise.readings, ['0.00 V']);
      await exercise.select(0);
      await exercise.tap(exercise.check);
      exercise.expectResult(false);
      await exercise.tap(exercise.retry);
      await exercise.select(3);
      await exercise.tap(exercise.check);
      exercise.expectResult(true);
      expect(exercise.answers, [false, true]);
      expect(exercise.retries, 1);
    },
  );
}
