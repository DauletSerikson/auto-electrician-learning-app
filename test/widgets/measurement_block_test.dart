import 'dart:convert';

import 'package:electrician/models/lesson.dart';
import 'package:electrician/models/lesson_block.dart';
import 'package:electrician/widgets/lesson_blocks/measurement_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('quiz resistance requires power off and can be completed', (
    tester,
  ) async {
    final json = await rootBundle.loadString(
      'assets/course/stage_2/lesson_09.json',
    );
    final lesson = Lesson.fromJson(jsonDecode(json) as Map<String, dynamic>);
    final block = lesson.blocks
        .whereType<ResistanceMeasurementLessonBlock>()
        .single;
    final answers = <bool>[];
    var retries = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MeasurementBlock(
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

    expect(find.text('ИССЛЕДУЕМЫЙ ПРОВОД'), findsOneWidget);
    expect(find.text('ПИТАНИЕ ВКЛ.'), findsOneWidget);

    Future<void> configure() async {
      await tap(find.widgetWithText(ChoiceChip, 'Ω'));
      final selectors = find.byType(SegmentedButton<WirePoint>);
      await tap(find.descendant(of: selectors.at(0), matching: find.text('A')));
      await tap(find.descendant(of: selectors.at(1), matching: find.text('B')));
    }

    await configure();
    expect(find.text('⚠'), findsOneWidget);
    await tap(find.text('Проверить измерение'));
    expect(answers, [false]);
    expect(find.textContaining('Сначала отключи питание.'), findsOneWidget);

    await tap(find.text('Попробовать ещё раз'));
    expect(retries, 1);
    expect(find.text('ПИТАНИЕ ВКЛ.'), findsOneWidget);
    final selectors = tester.widgetList<SegmentedButton<WirePoint>>(
      find.byType(SegmentedButton<WirePoint>),
    );
    expect(
      selectors.every((selector) => selector.selected.contains(WirePoint.none)),
      isTrue,
    );

    await configure();
    await tap(find.text('Отключить питание'));
    expect(find.text('0.3'), findsOneWidget);
    await tap(find.text('Проверить измерение'));
    expect(answers, [false, true]);
    expect(find.text('✓ Измерение выполнено правильно'), findsOneWidget);
    expect(
      find.textContaining('Получено низкое сопротивление 0.3 Ω.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Проверить измерение'),
          )
          .onPressed,
      isNull,
    );
  });
}
