import 'dart:async';

import 'package:electrician/models/lesson_block.dart';
import 'package:electrician/screens/lesson_screen.dart';
import 'package:electrician/theme/app_theme.dart';
import 'package:electrician/widgets/lesson_block_renderer.dart';
import 'package:electrician/widgets/lesson_blocks/calculation_block.dart';
import 'package:electrician/widgets/lesson_blocks/question_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../services/electronics_pilot_content_test.dart' show loadPilot;
import '../support/preferences_platform_fake.dart';

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  for (final dark in [false, true]) {
    testWidgets('pilot text and tasks fit 360 px at scale 1.3, dark=$dark', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 1050));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final order in [3, 4, 6]) {
        final lesson = (await tester.runAsync(() => loadPilot(order)))!;
        for (var index = 0; index < lesson.blocks.length; index++) {
          if (lesson.blocks[index] is ImageLessonBlock) continue;
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? AppTheme.dark : AppTheme.light,
              home: MediaQuery(
                data: const MediaQueryData(
                  size: Size(360, 1050),
                  textScaler: TextScaler.linear(1.3),
                ),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: LessonBlockRenderer(
                        key: ValueKey('$order-$index'),
                        block: lesson.blocks[index],
                        blockIndex: index,
                        onAnswered: (_) {},
                        onRetry: () {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: 'lesson $order, block $index',
          );
        }
      }
    });
  }
  for (final order in [3, 4, 6]) {
    testWidgets(
      'real pilot lesson $order requires all tasks and explicit completion',
      (tester) async {
        final preferences = PreferencesPlatformFake();
        preferences.values['flutter.completed_lessons'] = <String>[
          'diagnostics_01',
        ];
        preferences.install();
        addTearDown(preferences.uninstall);
        // Large surface keeps all lazy ListView children mounted for this
        // interaction test; narrow-screen readability is checked separately.
        await tester.binding.setSurfaceSize(const Size(800, 45000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final lesson = (await tester.runAsync(() => loadPilot(order)))!;
        await tester.runAsync(() async {
          for (final asset
              in lesson.blocks
                  .whereType<ImageLessonBlock>()
                  .map((block) => block.asset)
                  .toSet()) {
            final stream = AssetImage(asset).resolve(ImageConfiguration.empty);
            final ready = Completer<void>();
            final listener = ImageStreamListener(
              (_, _) => ready.complete(),
              onError: (Object error, StackTrace? stack) =>
                  ready.completeError(error, stack),
            );
            stream.addListener(listener);
            try {
              await ready.future.timeout(const Duration(seconds: 15));
            } finally {
              stream.removeListener(listener);
            }
          }
        });
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: FilledButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => LessonScreen(lesson: lesson),
                      ),
                    ),
                    child: const Text('Open pilot'),
                  ),
                );
              },
            ),
          ),
        );
        await tapVisible(tester, find.text('Open pilot'));
        final complete = find.widgetWithText(FilledButton, 'Завершить урок');
        expect(tester.widget<FilledButton>(complete).onPressed, isNull);
        var taskCount = 0;
        for (var index = 0; index < lesson.blocks.length; index++) {
          final block = lesson.blocks[index];
          switch (block) {
            case QuestionLessonBlock():
              final widget = find.byKey(ValueKey('question_$index'));
              if (taskCount == 0) {
                await tapVisible(
                  tester,
                  find.descendant(
                    of: widget,
                    matching: find.text(
                      block.answers[(block.correctAnswer + 1) %
                          block.answers.length],
                    ),
                  ),
                );
                await tapVisible(
                  tester,
                  find.descendant(of: widget, matching: find.text('Проверить')),
                );
                expect(tester.widget<FilledButton>(complete).onPressed, isNull);
                await tapVisible(
                  tester,
                  find.descendant(
                    of: widget,
                    matching: find.text('Попробовать ещё раз'),
                  ),
                );
              }
              await tapVisible(
                tester,
                find.descendant(
                  of: widget,
                  matching: find.text(block.answers[block.correctAnswer]),
                ),
              );
              await tapVisible(
                tester,
                find.descendant(of: widget, matching: find.text('Проверить')),
              );
              expect(tester.widget<QuestionBlock>(widget).block, same(block));
              taskCount++;
            case CalculationLessonBlock():
              final widget = find.byKey(ValueKey('calculation_$index'));
              final field = find.descendant(
                of: widget,
                matching: find.byType(TextField),
              );
              await tester.ensureVisible(field);
              await tester.enterText(
                field,
                block.correctValue.toString().replaceAll('.', ','),
              );
              await tester.pump();
              await tapVisible(
                tester,
                find.descendant(of: widget, matching: find.text('Проверить')),
              );
              expect(
                tester.widget<CalculationBlock>(widget).block,
                same(block),
              );
              taskCount++;
            default:
              continue;
          }
          expect(preferences.writes, 0);
        }
        expect(taskCount, {3: 7, 4: 8, 6: 9}[order]);
        expect(tester.widget<FilledButton>(complete).onPressed, isNotNull);
        await tapVisible(tester, complete);
        expect(find.byType(LessonScreen), findsNothing);
        expect(preferences.writes, 1);
        expect(preferences.values['flutter.completed_lessons'], [
          'diagnostics_01',
          lesson.id,
        ]);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
