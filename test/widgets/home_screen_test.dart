import 'dart:convert';
import 'dart:io';

import 'package:electrician/screens/course_screen.dart';
import 'package:electrician/screens/home_screen.dart';
import 'package:electrician/screens/lesson_screen.dart';
import 'package:electrician/screens/module_screen.dart';
import 'package:electrician/screens/practice_catalog_screen.dart';
import 'package:electrician/screens/practice_screen.dart';
import 'package:electrician/practice/practice_service.dart';
import 'package:electrician/services/course_service.dart';
import 'package:electrician/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

Future<void> reveal(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    220,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.ensureVisible(target);
  await settle(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Use the Android font shipped with the active Flutter SDK. Ahem has
    // different metrics and would report false positives at smaller scales.
    final configFile = File('.dart_tool/package_config.json').absolute;
    final config =
        jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
    final packages = (config['packages'] as List).cast<Map<String, dynamic>>();
    final flutter = packages.singleWhere((p) => p['name'] == 'flutter');
    final sdk = Directory.fromUri(
      configFile.uri.resolve(flutter['rootUri'] as String),
    ).parent.parent;
    final loader = FontLoader('Roboto');
    for (final weight in ['Regular', 'Medium', 'Bold']) {
      final bytes = await File(
        '${sdk.path}/bin/cache/artifacts/material_fonts/Roboto-$weight.ttf',
      ).readAsBytes();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  });

  late PreferencesPlatformFake preferences;
  setUp(() => preferences = PreferencesPlatformFake()..install());
  tearDown(() => preferences.uninstall());

  Future<void> mount(
    WidgetTester tester,
    double width,
    double scale,
    bool dark,
  ) async {
    await tester.runAsync(() async {
      await CourseService().loadAllLessons();
      await PracticeService().loadCatalog();
    });
    await tester.binding.setSurfaceSize(Size(width, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? AppTheme.dark : AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const HomeScreen(),
      ),
    );
    await settle(tester);
  }

  for (final width in [320.0, 360.0]) {
    for (final scale in [1.0, 1.3, 1.5, 2.0]) {
      for (final dark in [false, true]) {
        testWidgets(
          'Home width=$width scale=$scale dark=$dark scroll and routes',
          (tester) async {
            await mount(tester, width, scale, dark);
            expect(find.text('0 из 132 уроков'), findsOneWidget);

            final course = find.widgetWithText(ListTile, 'Курс');
            await reveal(tester, course);
            expect(
              find.text('Учебных модулей: 14\nУроков: 132'),
              findsOneWidget,
            );
            await tester.tap(course);
            await settle(tester);
            expect(find.byType(CourseScreen), findsOneWidget);

            final modules = (await tester.runAsync(
              () => CourseService().loadModules(),
            ))!;
            expect(modules.length, 14);
            // Scroll every real module card, including the long titles.
            for (final module in modules) {
              await reveal(tester, find.text(module.title));
            }
            await tester.tap(find.text(modules.last.title));
            await settle(tester);
            expect(find.byType(ModuleScreen), findsOneWidget);
            await tester.pageBack();
            await settle(tester);
            await tester.pageBack();
            await settle(tester);

            final practice = find.byKey(
              const ValueKey('open_diagnostic_practice'),
            );
            await reveal(tester, practice);
            expect(find.text('Практика диагноста'), findsOneWidget);
            expect(
              find.text(
                'Диагностических кейсов: 18\nПроверки и доказательства',
              ),
              findsOneWidget,
            );
            await tester.tap(practice);
            await settle(tester);
            expect(find.byType(PracticeCatalogScreen), findsOneWidget);
            final firstCase = find.byKey(const ValueKey('practice_case_dp01'));
            await reveal(tester, firstCase);
            await tester.tap(firstCase);
            await settle(tester);
            expect(find.byType(PracticeScreen), findsOneWidget);
            expect(preferences.writes, 0);
          },
        );
      }
    }
  }

  for (final dark in [false, true]) {
    for (final completed in [false, true]) {
      testWidgets('Home 320 scale=2 dark=$dark completed=$completed progress', (
        tester,
      ) async {
        final lessons = (await tester.runAsync(
          () => CourseService().loadAllLessons(),
        ))!;
        final next = lessons.indexWhere((item) => item.module.id == 'stage_9');
        preferences.values['flutter.completed_lessons'] = lessons
            .take(completed ? lessons.length : next)
            .map((item) => item.lesson.id)
            .toList();
        await tester.runAsync(
          () => CourseService().loadLesson(
            'assets/course/${lessons[next].module.id}/${lessons[next].lesson.file}',
          ),
        );
        await mount(tester, 320, 2, dark);
        if (completed) {
          expect(find.text('100%'), findsOneWidget);
          final finished = find.text('✓ Все доступные уроки завершены!');
          await reveal(tester, finished);
          expect(find.text('Продолжить обучение'), findsNothing);
        } else {
          final continueCard = find.widgetWithText(
            ListTile,
            'Продолжить обучение',
          );
          await reveal(tester, continueCard);
          expect(find.text(lessons[next].module.title), findsOneWidget);
          expect(find.text(lessons[next].lesson.title), findsOneWidget);
          await tester.tap(continueCard);
          await settle(tester);
          expect(find.byType(LessonScreen), findsOneWidget);
          expect(
            tester.widget<LessonScreen>(find.byType(LessonScreen)).lesson.id,
            lessons[next].lesson.id,
          );
        }
        expect(preferences.writes, 0);
      });
    }
  }
}
