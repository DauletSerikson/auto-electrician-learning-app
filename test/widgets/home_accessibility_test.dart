import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:electrician/models/course_lesson.dart';
import 'package:electrician/practice/practice_service.dart';
import 'package:electrician/screens/course_screen.dart';
import 'package:electrician/screens/home_screen.dart';
import 'package:electrician/screens/lesson_screen.dart';
import 'package:electrician/screens/practice_catalog_screen.dart';
import 'package:electrician/services/course_service.dart';
import 'package:electrician/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

Iterable<SemanticsNode> descendants(SemanticsNode node) sync* {
  yield node;
  final children = <SemanticsNode>[];
  node.visitChildren((child) {
    children.add(child);
    return true;
  });
  for (final child in children) {
    yield* descendants(child);
  }
}

void expectPosition(SemanticsNode node, int index) {
  var item = node;
  while (item.indexInParent == null) {
    item = item.parent!;
  }
  expect(item.indexInParent, index);
  var collection = item.parent!;
  while (collection.getSemanticsData().scrollChildCount == null) {
    collection = collection.parent!;
  }
  expect(collection.getSemanticsData().scrollChildCount, 5);
}

Future<void> inspectSemantics(
  WidgetTester tester,
  Future<void> Function() body,
) async {
  final handle = tester.ensureSemantics();
  try {
    await body();
  } finally {
    handle.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<CourseLesson> lessons;

  setUpAll(() async {
    final configFile = File('.dart_tool/package_config.json').absolute;
    final config = jsonDecode(await configFile.readAsString()) as Map;
    final packages = (config['packages'] as List).cast<Map>();
    final flutter = packages.singleWhere((p) => p['name'] == 'flutter');
    final sdk = Directory.fromUri(
      configFile.uri.resolve(flutter['rootUri'] as String),
    ).parent.parent;
    final loader = FontLoader('Roboto');
    for (final weight in ['regular', 'medium', 'bold']) {
      final bytes = await File(
        '${sdk.path}/bin/cache/artifacts/material_fonts/roboto-$weight.ttf',
      ).readAsBytes();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  });

  late PreferencesPlatformFake preferences;
  setUp(() => preferences = PreferencesPlatformFake()..install());
  tearDown(() => preferences.uninstall());

  Future<void> mount(
    WidgetTester tester, {
    int completed = 5,
    double width = 360,
    double scale = 1,
    bool dark = false,
  }) async {
    lessons = (await tester.runAsync(() => CourseService().loadAllLessons()))!;
    await tester.runAsync(() => PracticeService().loadCatalog());
    preferences.values['flutter.completed_lessons'] = lessons
        .take(completed)
        .map((item) => item.lesson.id)
        .toList();
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

  Future<SemanticsNode> reveal(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      220,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(target);
    await settle(tester);
    return tester.getSemantics(target);
  }

  Future<void> checkHome(WidgetTester tester, int completed) async {
    final banner = await reveal(
      tester,
      find.text('От основ электричества до диагностики автомобиля'),
    );
    expectPosition(banner, 0);
    final progressCard = find.ancestor(
      of: find.text('Общий прогресс'),
      matching: find.byType(Card),
    );
    final progress = await reveal(tester, progressCard);
    final data = progress.getSemanticsData();
    final percent = '${(completed / lessons.length * 100).round()}%';
    expect(data.label, 'Общий прогресс\n$percent\n$completed из 132 уроков');
    expect(RegExp(RegExp.escape(percent)).allMatches(data.label), hasLength(1));
    expect(data.value, isEmpty);
    expect(data.minValue, isNull);
    expect(data.maxValue, isNull);
    expect(data.role, isNot(ui.SemanticsRole.progressBar));
    expect(
      descendants(progress).where(
        (node) => node.getSemanticsData().role == ui.SemanticsRole.progressBar,
      ),
      isEmpty,
    );
    expectPosition(progress, 1);

    if (completed < lessons.length) {
      final next = await reveal(
        tester,
        find.widgetWithText(ListTile, 'Продолжить обучение'),
      );
      expect(
        next.getSemanticsData().label,
        contains(lessons[completed].module.title),
      );
      expect(
        next.getSemanticsData().label,
        contains(lessons[completed].lesson.title),
      );
      expect(next.getSemanticsData().hasAction(ui.SemanticsAction.tap), isTrue);
      expectPosition(next, 2);
    } else {
      final finished = await reveal(
        tester,
        find.text('✓ Все доступные уроки завершены!'),
      );
      expectPosition(finished, 2);
    }
    final course = await reveal(tester, find.widgetWithText(ListTile, 'Курс'));
    expect(
      course.getSemanticsData().label,
      contains('Учебных модулей: 14\nУроков: 132'),
    );
    expect(course.getSemanticsData().hasAction(ui.SemanticsAction.tap), isTrue);
    expectPosition(course, 3);
    final practice = await reveal(
      tester,
      find.byKey(const ValueKey('open_diagnostic_practice')),
    );
    expect(
      practice.getSemanticsData().label,
      contains('Диагностических кейсов: 18'),
    );
    expect(
      practice.getSemanticsData().hasAction(ui.SemanticsAction.tap),
      isTrue,
    );
    expectPosition(practice, 4);
    expect(preferences.writes, 0);
  }

  for (final width in [320.0, 360.0]) {
    for (final scale in [1.0, 1.3, 1.5, 2.0]) {
      for (final dark in [false, true]) {
        testWidgets('Home semantics width=$width scale=$scale dark=$dark', (
          tester,
        ) async {
          await inspectSemantics(tester, () async {
            await mount(tester, width: width, scale: scale, dark: dark);
            await checkHome(tester, 5);
          });
        });
      }
    }
  }

  for (final completed in [0, 1, 132]) {
    testWidgets('Home semantics completed=$completed', (tester) async {
      await inspectSemantics(tester, () async {
        await mount(tester, completed: completed);
        await checkHome(tester, completed);
      });
    });
  }

  testWidgets('Home cards still open through accessibility tap actions', (
    tester,
  ) async {
    await inspectSemantics(tester, () async {
      await mount(tester);
      for (final (target, destination) in [
        (find.widgetWithText(ListTile, 'Продолжить обучение'), LessonScreen),
        (find.widgetWithText(ListTile, 'Курс'), CourseScreen),
        (
          find.byKey(const ValueKey('open_diagnostic_practice')),
          PracticeCatalogScreen,
        ),
      ]) {
        final node = await reveal(tester, target);
        node.owner!.performAction(node.id, ui.SemanticsAction.tap);
        await settle(tester);
        expect(find.byType(destination), findsOneWidget);
        await tester.pageBack();
        await settle(tester);
      }
      expect(preferences.writes, 0);
    });
  });
}
