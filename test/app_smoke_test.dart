import 'package:electrician/main.dart';
import 'package:electrician/screens/course_screen.dart';
import 'package:electrician/screens/home_screen.dart';
import 'package:electrician/screens/lesson_screen.dart';
import 'package:electrician/screens/module_screen.dart';
import 'package:electrician/services/course_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/preferences_platform_fake.dart';

Future<void> _settle(WidgetTester tester) async {
  // Give real asset futures and the platform channel continuations a turn.
  for (var i = 0; i < 3; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  }
  await tester.pumpAndSettle();
}

Future<void> _reveal(
  WidgetTester tester,
  Finder target, {
  double scrollDelta = 300,
}) async {
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      scrollDelta,
      scrollable: find.byType(Scrollable).last,
    );
  }
  await tester.ensureVisible(target);
}

Future<void> _tap(
  WidgetTester tester,
  Finder target, {
  double scrollDelta = 300,
}) async {
  await _reveal(tester, target, scrollDelta: scrollDelta);
  await tester.tap(target);
  await _settle(tester);
}

void main() {
  testWidgets('app completes a real lesson and refreshes persisted progress', (
    tester,
  ) async {
    final preferences = PreferencesPlatformFake()..install();
    addTearDown(preferences.uninstall);
    // Resolve asset I/O in the real async zone before navigation fake time.
    await tester.runAsync(() async {
      final course = CourseService();
      await course.loadAllLessons();
      await course.loadLesson('assets/course/stage_0/lesson_01.json');
    });
    await tester.pumpWidget(const AutoElectricianApp());
    await _settle(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('0 из 32 уроков'), findsOneWidget);
    expect(preferences.values, isEmpty);

    await _tap(tester, find.widgetWithText(ListTile, 'Курс'));
    expect(find.byType(CourseScreen), findsOneWidget);
    await _tap(tester, find.widgetWithText(ListTile, 'Техника безопасности'));
    expect(find.byType(ModuleScreen), findsOneWidget);
    final firstLesson = find.widgetWithText(
      ListTile,
      '12 В — это тоже электричество',
    );
    expect(
      find.descendant(of: firstLesson, matching: find.byIcon(Icons.check)),
      findsNothing,
    );
    await _tap(tester, firstLesson);
    expect(find.byType(LessonScreen), findsOneWidget);
    final complete = find.widgetWithText(FilledButton, 'Завершить урок');
    await _reveal(tester, complete);
    expect(tester.widget<FilledButton>(complete).onPressed, isNull);
    await _tap(
      tester,
      find.widgetWithText(
        RadioListTile<int>,
        'Низкое напряжение уменьшает риск поражения током, '
        'но автомобильная электросистема всё равно может быть опасной',
      ),
      scrollDelta: -300,
    );
    await _tap(tester, find.widgetWithText(FilledButton, 'Проверить'));
    expect(find.text('✓ Правильно!'), findsOneWidget);
    await _reveal(tester, complete);
    expect(tester.widget<FilledButton>(complete).onPressed, isNotNull);
    await _tap(tester, complete);
    expect(find.byType(LessonScreen), findsNothing);
    expect(find.byType(ModuleScreen), findsOneWidget);
    expect(
      find.descendant(of: firstLesson, matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );
    expect(preferences.values['flutter.completed_lessons'], ['safety_01']);
    expect(preferences.writes, 1);

    await tester.pageBack();
    await _settle(tester);
    expect(find.byType(CourseScreen), findsOneWidget);
    await tester.pageBack();
    await _settle(tester);
    expect(find.text('1 из 32 уроков'), findsOneWidget);
    expect(find.text('Опасность большого тока'), findsOneWidget);

    // Recreate the app using the same fake persisted store, not widget state.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(const AutoElectricianApp());
    await _settle(tester);
    expect(find.text('1 из 32 уроков'), findsOneWidget);
    expect(find.text('Опасность большого тока'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
