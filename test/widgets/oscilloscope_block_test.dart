import 'dart:io';
import 'dart:ui' as ui;

import 'package:electrician/domain/lesson_attempt.dart';
import 'package:electrician/models/lesson_block.dart';
import 'package:electrician/oscilloscope_pilot.dart';
import 'package:electrician/pilots/oscilloscope_pilot_lesson.dart';
import 'package:electrician/screens/lesson_screen.dart';
import 'package:electrician/services/course_service.dart';
import 'package:electrician/simulation/oscilloscope_simulation.dart';
import 'package:electrician/theme/app_theme.dart';
import 'package:electrician/widgets/lesson_block_renderer.dart';
import 'package:electrician/widgets/lesson_blocks/oscilloscope_block.dart';
import 'package:electrician/widgets/lesson_blocks/scope_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/preferences_platform_fake.dart';

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> select(
  WidgetTester tester,
  String id,
  String option, {
  Finder? within,
}) async {
  var field = find.byWidgetPredicate(
    (widget) =>
        widget.key is ValueKey<String> &&
        (widget.key! as ValueKey<String>).value.startsWith('scope_${id}_'),
  );
  if (within != null) field = find.descendant(of: within, matching: field);
  await tap(tester, field);
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

OscilloscopeLessonBlock get voltageBlock => createOscilloscopePilotLesson()
    .blocks
    .whereType<OscilloscopeLessonBlock>()
    .first;

Future<void> mount(
  WidgetTester tester, {
  OscilloscopeLessonBlock? block,
  ValueChanged<bool>? onAnswered,
  VoidCallback? onRetry,
  bool dark = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? AppTheme.dark : AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(360, 800),
          textScaler: TextScaler.linear(1.3),
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            child: RepaintBoundary(
              key: const ValueKey('scope_preview'),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: LessonBlockRenderer(
                  block: block ?? voltageBlock,
                  blockIndex: 0,
                  onAnswered: onAnswered ?? (_) {},
                  onRetry: onRetry ?? () {},
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ScopeCapture currentCapture(WidgetTester tester) =>
    tester.widget<ScopeDisplay>(find.byType(ScopeDisplay)).capture;

void main() {
  setUpAll(() async {
    final font = Platform.environment['R14_PREVIEW_FONT'];
    if (font != null) {
      await ui.loadFontFromList(
        await File(font).readAsBytes(),
        fontFamily: 'Roboto',
      );
    }
    final icons = Platform.environment['R14_PREVIEW_ICONS'];
    if (icons != null) {
      await ui.loadFontFromList(
        await File(icons).readAsBytes(),
        fontFamily: 'MaterialIcons',
      );
    }
  });

  testWidgets(
    'renderer dispatches, scaling changes drawing, check/retry are real',
    (tester) async {
      final answers = <bool>[];
      var retries = 0;
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await mount(tester, onAnswered: answers.add, onRetry: () => retries++);
      expect(find.byType(OscilloscopeBlock), findsOneWidget);
      expect(currentCapture(tester).clipped, isTrue);
      expect(find.byKey(const ValueKey('scope_parameters')), findsNothing);
      await tap(tester, find.byKey(const ValueKey('scope_check')));
      expect(answers, [false]);
      await select(tester, 'volts', '2.0 V/div');
      expect(retries, 1);
      expect(currentCapture(tester).clipped, isFalse);
      expect(currentCapture(tester).settings.voltsPerDiv, 2);
      await tap(tester, find.byKey(const ValueKey('scope_check')));
      expect(answers, [false, true]);
      await select(tester, 'center', '5.0 V');
      expect(retries, 2);
      expect(currentCapture(tester).settings.centerVoltage, 5);
      await tap(tester, find.byKey(const ValueKey('scope_reset')));
      expect(retries, 3);
      expect(currentCapture(tester).settings.voltsPerDiv, .5);
      expect(currentCapture(tester).settings.centerVoltage, 0);
      expect(find.byKey(const ValueKey('scope_parameters')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'every control affects the capture; normal auto and single are distinct',
    (tester) async {
      final block = createOscilloscopePilotLesson().blocks
          .whereType<OscilloscopeLessonBlock>()
          .last;
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await mount(tester, block: block);
      expect(currentCapture(tester).status, ScopeCaptureStatus.waiting);
      expect(currentCapture(tester).points, isEmpty);
      await select(tester, 'mode', 'Auto · свободный при отсутствии события');
      expect(currentCapture(tester).status, ScopeCaptureStatus.freeRunning);
      expect(currentCapture(tester).triggerSeconds, isNull);
      await select(tester, 'level', '2.5 V');
      expect(currentCapture(tester).status, ScopeCaptureStatus.triggered);
      final rising = currentCapture(tester).triggerSeconds!;
      await select(tester, 'edge', 'Отрицательный ↓');
      expect(currentCapture(tester).triggerSeconds, isNot(rising));
      await select(tester, 'time', '2.0 ms/div');
      expect(
        currentCapture(tester).points.last.seconds -
            currentCapture(tester).startSeconds,
        closeTo(.02, 1e-12),
      );
      await select(tester, 'mode', 'Single · одиночный захват');
      expect(currentCapture(tester).status, ScopeCaptureStatus.armed);
      await tap(tester, find.byKey(const ValueKey('scope_capture')));
      final stopped = currentCapture(tester);
      expect(stopped.status, ScopeCaptureStatus.triggered);
      await tester.pump(const Duration(seconds: 1));
      expect(identical(stopped, currentCapture(tester)), isTrue);
      await select(tester, 'level', '6.0 V');
      expect(currentCapture(tester).points, isEmpty);
      await tap(tester, find.byKey(const ValueKey('scope_capture')));
      expect(currentCapture(tester).status, ScopeCaptureStatus.armed);
      await select(tester, 'signal', 'Пропадающий импульс');
      await select(tester, 'mode', 'Auto · свободный при отсутствии события');
      expect(currentCapture(tester).points, isNotEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'constant and missing event show only meaningful model parameters',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await mount(tester);
      await select(tester, 'signal', 'Постоянное напряжение');
      await select(tester, 'mode', 'Auto · свободный при отсутствии события');
      await tap(tester, find.byKey(const ValueKey('scope_check')));
      final text = tester
          .widget<Text>(find.byKey(const ValueKey('scope_parameters')))
          .data!;
      expect(text, contains('не применимы'));
      expect(text, isNot(contains('f =')));
      await select(tester, 'signal', 'Пропадающий импульс');
      await tap(tester, find.byKey(const ValueKey('scope_check')));
      final eventText = tester
          .widget<Text>(find.byKey(const ValueKey('scope_parameters')))
          .data!;
      expect(eventText, contains('общего периода записи нет'));
      expect(eventText, contains('20.0–23.0 ms'));
      expect(tester.takeException(), isNull);
    },
  );

  for (final dark in [false, true]) {
    testWidgets('360px scale 1.3 all signals and controls fit, dark=$dark', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await mount(tester, dark: dark);
      for (final name in [
        'Прямоугольные импульсы',
        'ШИМ A',
        'ШИМ B',
        'Пропадающий импульс',
        'Постоянное напряжение',
        'Синусоида',
      ]) {
        await select(tester, 'signal', name);
        await tap(tester, find.byKey(const ValueKey('scope_check')));
        expect(tester.takeException(), isNull, reason: name);
      }
      await tap(tester, find.byKey(const ValueKey('scope_reset')));
      await select(tester, 'volts', '2.0 V/div');
      await tap(tester, find.byKey(const ValueKey('scope_check')));
      expect(tester.takeException(), isNull);
      final captureDir = Platform.environment['R14_CAPTURE_DIR'];
      if (captureDir != null) {
        await tester.binding.setSurfaceSize(const Size(360, 2500));
        // Fresh layout avoids capturing a display list culled by the previous
        // scrolled 800px viewport. Interactions above still run at 360x800.
        await tester.pumpWidget(const SizedBox.shrink());
        await mount(tester, dark: dark);
        await select(tester, 'volts', '2.0 V/div');
        await tap(tester, find.byKey(const ValueKey('scope_check')));
        // Render the whole screen with normal fonts when requested explicitly.
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('scope_preview')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(captureDir).create(recursive: true);
          await File('$captureDir/scope_${dark ? 'dark' : 'light'}_360.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    });
  }

  testWidgets(
    'pilot uses old completion storage and all six tasks including reset',
    (tester) async {
      final preferences = PreferencesPlatformFake();
      preferences.values['flutter.completed_lessons'] = [
        'safety_01',
        'unknown_future_id',
      ];
      preferences.install();
      addTearDown(preferences.uninstall);
      await tester.binding.setSurfaceSize(const Size(800, 20000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const OscilloscopePilotApp());
      await tap(tester, find.text('Открыть пилот'));
      expect(find.byType(LessonScreen), findsOneWidget);
      final scopes = find.byType(OscilloscopeBlock);
      expect(scopes, findsNWidgets(3));
      Finder scoped(int i, String key) => find.descendant(
        of: scopes.at(i),
        matching: find.byKey(ValueKey(key)),
      );
      final complete = find.widgetWithText(FilledButton, 'Завершить урок');
      expect(tester.widget<FilledButton>(complete).onPressed, isNull);
      await select(tester, 'volts', '2.0 V/div', within: scopes.at(0));
      await select(tester, 'time', '4.0 ms/div', within: scopes.at(1));
      await select(tester, 'level', '2.5 V', within: scopes.at(2));
      for (var i = 0; i < 3; i++) {
        await tap(tester, scoped(i, 'scope_check'));
      }
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '10');
      await tester.enterText(fields.at(1), '100');
      for (final button
          in find
              .widgetWithText(FilledButton, 'Проверить')
              .evaluate()
              .toList()
              .take(2)) {
        await tap(tester, find.byWidget(button.widget));
      }
      await tap(tester, find.byType(RadioListTile<int>).first);
      await tap(tester, find.widgetWithText(FilledButton, 'Проверить').last);
      expect(tester.widget<FilledButton>(complete).onPressed, isNotNull);
      expect(preferences.writes, 0);
      await select(tester, 'volts', '5.0 V/div', within: scopes.at(0));
      expect(tester.widget<FilledButton>(complete).onPressed, isNull);
      await tap(tester, scoped(0, 'scope_check'));
      expect(tester.widget<FilledButton>(complete).onPressed, isNull);
      await tap(tester, scoped(0, 'scope_reset'));
      await select(tester, 'volts', '2.0 V/div', within: scopes.at(0));
      await tap(tester, scoped(0, 'scope_check'));
      expect(tester.widget<FilledButton>(complete).onPressed, isNotNull);
      await tap(tester, complete);
      expect(find.byType(LessonScreen), findsNothing);
      expect(preferences.writes, 1);
      expect(preferences.values['flutter.completed_lessons'], [
        'safety_01',
        'unknown_future_id',
        'pilot_oscilloscope_mvp',
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'pilot remains outside the course and scoring formula is unchanged',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final pilot = createOscilloscopePilotLesson();
      final scored = [
        for (var i = 0; i < pilot.blocks.length; i++)
          if (isScoredLessonBlock(pilot.blocks[i])) i,
      ];
      expect(scored.length, 6);
      expect(evaluateLessonAttempt(pilot, {}).canComplete, isFalse);
      final answers = {for (final i in scored) i: true};
      expect(evaluateLessonAttempt(pilot, answers).canComplete, isTrue);
      answers.remove(scored.first);
      expect(evaluateLessonAttempt(pilot, answers).canComplete, isFalse);
      final lessons = await CourseService().loadAllLessons();
      expect(lessons.length, 102);
      expect(lessons.any((item) => item.lesson.id == pilot.id), isFalse);
      expect((await CourseService().loadModules()).length, 11);
    },
  );
}
