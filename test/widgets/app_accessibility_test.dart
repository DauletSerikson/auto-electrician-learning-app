import 'dart:ui' as ui;

import 'package:electrician/main.dart';
import 'package:electrician/models/course_module.dart';
import 'package:electrician/practice/practice_service.dart';
import 'package:electrician/screens/course_screen.dart';
import 'package:electrician/screens/home_screen.dart';
import 'package:electrician/screens/module_screen.dart';
import 'package:electrician/services/course_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/preferences_platform_fake.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  }
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  late PreferencesPlatformFake preferences;
  setUp(() => preferences = PreferencesPlatformFake()..install());
  tearDown(() => preferences.uninstall());

  for (final deviceLocale in [
    const Locale('kk', 'KZ'),
    const Locale('en', 'US'),
    const Locale('ru'),
  ]) {
    testWidgets('Russian app and speech locale on $deviceLocale device', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        tester.binding.platformDispatcher.localeTestValue = deviceLocale;
        addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);
        await tester.binding.setSurfaceSize(const Size(800, 1800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.runAsync(() async {
          await CourseService().loadAllLessons();
          await PracticeService().loadCatalog();
        });
        await tester.pumpWidget(const AutoElectricianApp());
        await settle(tester);
        final context = tester.element(find.byType(HomeScreen));
        expect(Localizations.localeOf(context), const Locale('ru'));
        expect(MaterialLocalizations.of(context).backButtonTooltip, 'Назад');
        expect(
          tester
              .getSemantics(find.widgetWithText(ListTile, 'Курс'))
              .getSemanticsData()
              .locale,
          const Locale('ru'),
        );
        await tester.tap(find.widgetWithText(ListTile, 'Курс'));
        await settle(tester);
        expect(find.byType(CourseScreen), findsOneWidget);
        expect(find.byTooltip('Назад'), findsOneWidget);
        expect(
          tester
              .getSemantics(find.byTooltip('Назад'))
              .getSemanticsData()
              .locale,
          const Locale('ru'),
        );
        expect(preferences.writes, 0);
      } finally {
        semantics.dispose();
      }
    });
  }

  for (final completed in [false, true]) {
    testWidgets('Lesson completion is announced once: completed=$completed', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.binding.setSurfaceSize(const Size(800, 1800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.runAsync(() => CourseService().loadLessons('stage_0'));
        if (completed) {
          preferences.values['flutter.completed_lessons'] = ['safety_01'];
        }
        await tester.pumpWidget(
          MaterialApp(
            home: ModuleScreen(
              module: CourseModule(
                id: 'stage_0',
                order: 0,
                title: 'Техника безопасности',
                description: '',
              ),
            ),
          ),
        );
        await settle(tester);
        const title = '12 В — это тоже электричество';
        final tile = find.widgetWithText(ListTile, title);
        final data = tester.getSemantics(tile).getSemanticsData();
        final status = completed ? 'Урок 1, завершён' : 'Урок 1, не завершён';
        expect(data.label, contains(status));
        expect(
          RegExp(RegExp.escape(status)).allMatches(data.label),
          hasLength(1),
        );
        expect(
          RegExp(RegExp.escape(title)).allMatches(data.label),
          hasLength(1),
        );
        expect(data.hasAction(ui.SemanticsAction.tap), isTrue);
        expect(preferences.writes, 0);
      } finally {
        semantics.dispose();
      }
    });
  }
}
