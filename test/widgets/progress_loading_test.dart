import 'dart:async';

import 'package:electrician/domain/lesson_attempt.dart';
import 'package:electrician/models/course_module.dart';
import 'package:electrician/screens/home_screen.dart';
import 'package:electrician/screens/lesson_screen.dart';
import 'package:electrician/screens/module_screen.dart';
import 'package:electrician/services/course_service.dart';
import 'package:electrician/widgets/lesson_block_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/preferences_platform_fake.dart';

Widget screen(bool home) => home
    ? const HomeScreen()
    : ModuleScreen(
        module: CourseModule(
          id: 'stage_0',
          order: 0,
          title: 'Module',
          description: '',
        ),
      );

Future<void> flushAsync(WidgetTester tester) async {
  // Cached rootBundle futures originate in the real async zone. Let their
  // continuations run as well as widget frames, without a wall-clock timeout.
  for (var i = 0; i < 3; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  }
}

Future<void> settle(WidgetTester tester) async {
  await flushAsync(tester);
  await tester.pumpAndSettle();
}

void main() {
  late PreferencesPlatformFake platform;
  setUp(() {
    platform = PreferencesPlatformFake()..install();
  });
  tearDown(() => platform.uninstall());

  Future<void> mount(WidgetTester tester, bool home) async {
    // Resolve real assets before entering the widget's fake async lifecycle.
    await tester.runAsync(() async {
      final course = CourseService();
      for (final item in await course.loadAllLessons()) {
        await course.loadLesson(
          'assets/course/${item.module.id}/${item.lesson.file}',
        );
      }
    });
    await tester.binding.setSurfaceSize(const Size(800, 16000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: screen(home)));
    await flushAsync(tester);
  }

  for (final home in [true, false]) {
    final name = home ? 'Home' : 'Module';
    testWidgets('$name loading then confirmed success', (tester) async {
      final pending = Completer<void>();
      platform.onRead = () => pending.future;
      platform.values['flutter.completed_lessons'] = ['safety_01'];
      await mount(tester, home);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNothing);
      pending.complete();
      await settle(tester);
      if (home) {
        expect(find.text('1 из 42 уроков'), findsOneWidget);
      } else {
        expect(find.byIcon(Icons.check), findsOneWidget);
      }
    });

    testWidgets('$name read failure then retry recovers actual progress', (
      tester,
    ) async {
      platform.onRead = () async =>
          throw PlatformException(code: 'read_failed');
      await mount(tester, home);
      await settle(tester);
      expect(find.text('Не удалось загрузить прогресс'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('0 из 42 уроков'), findsNothing);
      expect(find.byIcon(Icons.check), findsNothing);
      final pending = Completer<void>();
      platform.onRead = () => pending.future;
      platform.values['flutter.completed_lessons'] = ['safety_01'];
      await tester.tap(find.text('Повторить'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      pending.complete();
      await settle(tester);
      expect(find.text('Не удалось загрузить прогресс'), findsNothing);
      if (home) {
        expect(find.text('1 из 42 уроков'), findsOneWidget);
      } else {
        expect(find.byIcon(Icons.check), findsOneWidget);
      }
    });

    for (final success in [false, true]) {
      testWidgets('$name dispose during read is safe: $success', (
        tester,
      ) async {
        final pending = Completer<void>();
        platform.onRead = () => pending.future;
        await mount(tester, home);
        await tester.pumpWidget(const SizedBox());
        if (success) {
          pending.complete();
        } else {
          pending.completeError(PlatformException(code: 'read_failed'));
        }
        await settle(tester);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
      '$name parent refreshes completion and shows recoverable refresh failure',
      (tester) async {
        await mount(tester, home);
        await settle(tester);
        await tester.tap(
          find.text(
            home ? 'Продолжить обучение' : '12 В — это тоже электричество',
          ),
        );
        await settle(tester);
        expect(find.byType(LessonScreen), findsOneWidget);
        for (final renderer in tester.widgetList<LessonBlockRenderer>(
          find.byType(LessonBlockRenderer),
        )) {
          if (isScoredLessonBlock(renderer.block)) renderer.onAnswered(true);
        }
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, 'Завершить урок'));
        await settle(tester);
        expect(find.byType(LessonScreen), findsNothing);
        if (home) {
          expect(find.text('1 из 42 уроков'), findsOneWidget);
        } else {
          expect(find.byIcon(Icons.check), findsOneWidget);
        }
        // The next parent refresh fails after an otherwise successful save.
        await tester.tap(
          find.text(
            home ? 'Продолжить обучение' : '12 В — это тоже электричество',
          ),
        );
        await settle(tester);
        for (final renderer in tester.widgetList<LessonBlockRenderer>(
          find.byType(LessonBlockRenderer),
        )) {
          if (isScoredLessonBlock(renderer.block)) renderer.onAnswered(true);
        }
        await tester.pump();
        platform.onWrite = () async {
          platform.onRead = () async =>
              throw PlatformException(code: 'refresh_failed');
          return true;
        };
        await tester.tap(find.widgetWithText(FilledButton, 'Завершить урок'));
        await settle(tester);
        expect(find.text('Не удалось загрузить прогресс'), findsOneWidget);
        expect(find.text('1 из 42 уроков'), findsNothing);
        expect(find.byIcon(Icons.check), findsNothing);
        platform.onRead = null;
        await tester.tap(find.text('Повторить'));
        await settle(tester);
        expect(find.text('Не удалось загрузить прогресс'), findsNothing);
      },
    );
  }
}
