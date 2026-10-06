import 'dart:async';

import 'package:electrician/screens/lesson_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/preferences_platform_fake.dart';
import 'lesson_screen_test.dart' show fixture, completionButton;

void main() {
  late PreferencesPlatformFake platform;
  setUp(() {
    platform = PreferencesPlatformFake()..install();
  });
  tearDown(() => platform.uninstall());

  Future<List<bool?>> open(WidgetTester tester) async {
    final results = <bool?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                results.add(
                  await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LessonScreen(lesson: fixture()),
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return results;
  }

  testWidgets(
    'delayed save blocks system/app bar back and double tap, returns once',
    (tester) async {
      final pending = Completer<bool>();
      platform.onWrite = () => pending.future;
      final results = await open(tester);
      final originalCallback = tester
          .widget<FilledButton>(completionButton)
          .onPressed!;
      originalCallback();
      originalCallback();
      await tester.pump();
      expect(platform.writes, 1);
      expect(find.text('Сохранение прогресса…'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.tap(find.byType(BackButton));
      await tester.pump();
      expect(results, isEmpty);
      pending.complete(true);
      await tester.pumpAndSettle();
      expect(results, [true]);
      expect(platform.values['flutter.completed_lessons'], ['fixture']);
    },
  );

  for (final throws in [false, true]) {
    testWidgets('delayed failure stays on lesson and allows retry: $throws', (
      tester,
    ) async {
      final pending = Completer<bool>();
      platform.onWrite = () => pending.future;
      final results = await open(tester);
      await tester.tap(completionButton);
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();
      if (throws) {
        pending.completeError(PlatformException(code: 'write_failed'));
      } else {
        pending.complete(false);
      }
      await tester.pumpAndSettle();
      expect(results, isEmpty);
      expect(
        find.textContaining('Не удалось сохранить прогресс'),
        findsOneWidget,
      );
      expect(platform.values, isEmpty);
      platform.onWrite = null;
      await tester.tap(completionButton);
      await tester.pumpAndSettle();
      expect(results, [true]);
      expect(platform.writes, 2);
    });
  }

  for (final success in [false, true]) {
    testWidgets('dispose during delayed save is safe: $success', (
      tester,
    ) async {
      final pending = Completer<bool>();
      platform.onWrite = () => pending.future;
      await open(tester);
      await tester.tap(completionButton);
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      pending.complete(success);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
