import 'dart:convert';

import 'package:electrician/models/lesson.dart';
import 'package:electrician/models/lesson_block.dart';
import 'package:electrician/widgets/lesson_blocks/voltage_drop_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Exercise {
  final WidgetTester tester;
  final answers = <bool>[];
  var retries = 0;

  _Exercise(this.tester);

  Finder get selectors => find.byType(SegmentedButton<VoltageDropPoint>);
  Finder get checkButton =>
      find.widgetWithText(FilledButton, 'Проверить измерение');

  Future<void> pump({bool quiz = false}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: VoltageDropBlock(
              block: _blocks[quiz]!,
              onAnswered: answers.add,
              onRetry: () => retries++,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> tap(Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
  }

  Future<void> probe(int index, String point) =>
      tap(find.descendant(of: selectors.at(index), matching: find.text(point)));

  Future<void> connect(String red, String black) async {
    await probe(0, red);
    await probe(1, black);
  }

  void expectInitial({required bool loaded}) {
    expect(find.text(loaded ? 'ЛАМПА ВКЛ.' : 'ЛАМПА ВЫКЛ.'), findsOneWidget);
    expect(find.text('---- V'), findsOneWidget);
    for (final selector in tester.widgetList<SegmentedButton<VoltageDropPoint>>(
      selectors,
    )) {
      expect(selector.selected, isEmpty);
      expect(selector.onSelectionChanged, isNotNull);
    }
    expect(tester.widget<FilledButton>(checkButton).onPressed, isNotNull);
    expect(find.textContaining('✓ Правильно.'), findsNothing);
    expect(find.textContaining('✗'), findsNothing);
    expect(find.text('Попробовать ещё раз'), findsNothing);
  }

  Future<void> expectLocked({
    required String reading,
    required bool loaded,
  }) async {
    expect(tester.widget<FilledButton>(checkButton).onPressed, isNull);
    for (final selector in tester.widgetList<SegmentedButton<VoltageDropPoint>>(
      selectors,
    )) {
      expect(selector.onSelectionChanged, isNull);
    }
    final loadButton = find.widgetWithText(
      OutlinedButton,
      loaded ? 'Выключить лампу' : 'Включить лампу',
    );
    expect(tester.widget<OutlinedButton>(loadButton).onPressed, isNull);
    final previousAnswers = List<bool>.of(answers);
    await tap(checkButton);
    await probe(0, 'C');
    await tap(loadButton);
    expect(answers, previousAnswers);
    expect(find.text(reading), findsOneWidget);
    expect(find.text(loaded ? 'ЛАМПА ВКЛ.' : 'ЛАМПА ВЫКЛ.'), findsOneWidget);
  }
}

final _blocks = <bool, VoltageDropLessonBlock>{};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final quiz in [false, true]) {
      final json = await rootBundle.loadString(
        'assets/course/stage_2/lesson_${quiz ? '09' : '05'}.json',
      );
      final lesson = Lesson.fromJson(jsonDecode(json) as Map<String, dynamic>);
      _blocks[quiz] = lesson.blocks.whereType<VoltageDropLessonBlock>().single;
    }
  });
  for (final quiz in [false, true]) {
    testWidgets('initial state follows ${quiz ? 'quiz' : 'lesson'} asset', (
      tester,
    ) async {
      final exercise = _Exercise(tester);
      await exercise.pump(quiz: quiz);
      exercise.expectInitial(loaded: !quiz);
      expect(
        find.text('После плохого контакта\n${quiz ? '12.6' : '8.6'} V'),
        findsOneWidget,
      );
      expect(exercise.answers, isEmpty);
      expect(exercise.retries, 0);
    });
  }

  testWidgets('A to B under load succeeds and locks the exercise', (
    tester,
  ) async {
    final exercise = _Exercise(tester);
    await exercise.pump();
    await exercise.connect('A', 'B');
    expect(find.text('4.00 V'), findsOneWidget);
    expect(exercise.answers, isEmpty);
    await exercise.tap(exercise.checkButton);
    expect(exercise.answers, [true]);
    expect(find.textContaining('✓ Правильно.'), findsOneWidget);
    expect(find.text('Попробовать ещё раз'), findsNothing);
    await exercise.expectLocked(reading: '4.00 V', loaded: true);
    expect(exercise.retries, 0);
  });

  testWidgets('reversed probes show negative drop and fail assessment', (
    tester,
  ) async {
    final exercise = _Exercise(tester);
    await exercise.pump();
    await exercise.connect('B', 'A');
    expect(find.text('-4.00 V'), findsOneWidget);
    await exercise.tap(exercise.checkButton);
    expect(exercise.answers, [false]);
    expect(find.textContaining('но поменял щупы местами.'), findsOneWidget);
    await exercise.expectLocked(reading: '-4.00 V', loaded: true);
  });

  testWidgets('turning load off removes drop and fails assessment', (
    tester,
  ) async {
    final exercise = _Exercise(tester);
    await exercise.pump();
    await exercise.connect('A', 'B');
    expect(find.text('4.00 V'), findsOneWidget);
    await exercise.tap(find.text('Выключить лампу'));
    expect(find.text('0.00 V'), findsOneWidget);
    expect(find.text('После плохого контакта\n12.6 V'), findsOneWidget);
    await exercise.tap(exercise.checkButton);
    expect(exercise.answers, [false]);
    expect(find.textContaining('✗ Нагрузка выключена.'), findsOneWidget);
    await exercise.expectLocked(reading: '0.00 V', loaded: false);
  });

  final wrongConfigurations = [
    (
      red: 'A',
      black: null,
      reading: '---- V',
      message: '✗ Подключены не оба щупа.',
    ),
    (red: 'A', black: 'A', reading: '0.00 V', message: 'в одной точке.'),
    (red: 'A', black: 'C', reading: '12.60 V', message: 'напряжение всей цепи'),
    (
      red: 'B',
      black: 'C',
      reading: '8.60 V',
      message: 'напряжение, которое осталось',
    ),
  ];
  for (final configuration in wrongConfigurations) {
    testWidgets(
      'rejects ${configuration.red} to ${configuration.black ?? 'disconnected'}',
      (tester) async {
        final exercise = _Exercise(tester);
        await exercise.pump();
        await exercise.probe(0, configuration.red);
        if (configuration.black case final black?) {
          await exercise.probe(1, black);
        }
        expect(find.text(configuration.reading), findsOneWidget);
        await exercise.tap(exercise.checkButton);
        expect(exercise.answers, [false]);
        expect(find.textContaining(configuration.message), findsOneWidget);
        expect(find.text('Попробовать ещё раз'), findsOneWidget);
      },
    );
  }

  for (final quiz in [false, true]) {
    testWidgets(
      'retry restores ${quiz ? 'unloaded quiz' : 'loaded lesson'} and permits a new answer',
      (tester) async {
        final exercise = _Exercise(tester);
        await exercise.pump(quiz: quiz);
        await exercise.tap(
          find.text(quiz ? 'Включить лампу' : 'Выключить лампу'),
        );
        await exercise.connect('B', 'A');
        await exercise.tap(exercise.checkButton);
        expect(exercise.answers, [false]);
        await exercise.tap(find.text('Попробовать ещё раз'));
        expect(exercise.retries, 1);
        expect(exercise.answers, [false]);
        exercise.expectInitial(loaded: !quiz);
        if (quiz) {
          await exercise.tap(find.text('Включить лампу'));
        }
        await exercise.connect('A', 'B');
        expect(find.text(quiz ? '2.40 V' : '4.00 V'), findsOneWidget);
        await exercise.tap(exercise.checkButton);
        expect(exercise.answers, [false, true]);
        expect(exercise.retries, 1);
      },
    );
  }
}
