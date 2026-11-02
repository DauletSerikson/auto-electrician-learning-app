import 'dart:io';
import 'dart:ui' as ui;

import 'package:electrician/practice/attempt.dart';
import 'package:electrician/practice/definition.dart';
import 'package:electrician/practice/practice_controller.dart';
import 'package:electrician/screens/practice_catalog_screen.dart';
import 'package:electrician/screens/practice_screen.dart';
import 'package:electrician/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../practice/full_catalog_routes.dart';
import '../practice/practice_engine_test.dart'
    as engine
    show loadCase, preparePass;
import 'practice_screen_test.dart' show settle, tap, top, reveal, retry;

const captureKey = ValueKey('acceptance_capture');

Future<void> capture(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(captureKey),
  );
  await tester.runAsync(() async {
    final picture = await boundary.toImage(pixelRatio: 1);
    final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
    picture.dispose();
    final file = File('build/verification/r18_5/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
  });
}

Future<void> performUi(
  WidgetTester tester,
  PracticeController c,
  PracticeDefinition d,
  String id, {
  String? screenshot,
}) async {
  await top(tester);
  final action = d.actions[id]!;
  await reveal(tester, find.text(action.title));
  final card = find.byKey(ValueKey('action_$id'));
  await tap(
    tester,
    find.descendant(of: card, matching: find.text('Цель проверки')),
  );
  await tap(tester, find.byKey(ValueKey('purpose_${id}_p1')));
  final profile = find.byKey(ValueKey('profile_for_$id'));
  if (profile.evaluate().isNotEmpty) await tap(tester, profile);
  await tap(tester, find.byKey(ValueKey('perform_$id')));
  final dialog = find.byType(AlertDialog);
  final record = c.state.journal.last;
  final expected = d.observationFor(d.selectedVariantId, id);
  expect(record.conditions, same(d.profiles[action.profileId]));
  expect(record.observation.display, expected.display);
  expect(
    find.descendant(of: dialog, matching: find.text(expected.display)),
    findsOneWidget,
  );
  expect(
    find.descendant(
      of: dialog,
      matching: find.text(record.conditions.description),
    ),
    findsOneWidget,
  );
  expect(
    find.descendant(
      of: dialog,
      matching: find.text('Границы вывода: ${action.scope}'),
    ),
    findsOneWidget,
  );
  if (screenshot != null) await capture(tester, screenshot);
  await tester.tap(find.text('Закрыть запись'));
  await settle(tester);
}

Future<void> interpretUi(
  WidgetTester tester,
  PracticeController c,
  PracticeDefinition d,
) async {
  await tester.tap(find.byKey(const ValueKey('practice_tab_3')));
  await settle(tester);
  await tap(tester, find.byKey(const ValueKey('practice_safety')));
  for (final claim in d.claims.values) {
    await top(tester);
    await tap(
      tester,
      find.byKey(ValueKey('claim_${claim.id}_${claim.correctOptionId}')),
    );
    await tap(tester, find.byKey(ValueKey('link_${claim.id}')));
    final route = claim.requirement.alternatives.firstWhere(
      (ids) => c.state.journal.map((r) => r.actionId).toSet().containsAll(ids),
    );
    for (final r in c.state.journal.where((r) => route.contains(r.actionId))) {
      await citeUi(tester, 'cite_${claim.id}_${r.sequence}');
    }
    await tester.tap(find.byKey(const ValueKey('close_citations')));
    await settle(tester);
  }
  await tap(
    tester,
    find.byKey(
      ValueKey(
        'conclusion_${d.conclusions.values.firstWhere((c) => c.credit == 1).id}',
      ),
    ),
  );
}

Future<void> citeUi(WidgetTester tester, String key) async {
  // A prepared packet can be taller than the sheet. Tap its visible title,
  // rather than the centre of the entire (possibly very tall) checkbox tile.
  final sequence = key.split('_').last;
  final title = find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.byWidgetPredicate(
      (w) => w is Text && (w.data?.startsWith('#$sequence — ') ?? false),
    ),
  );
  await tap(tester, title, modal: true);
}

void main() {
  setUp(() {
    rootBundle.clear();
    final previous = WidgetController.hitTestWarningShouldBeFatal;
    WidgetController.hitTestWarningShouldBeFatal = true;
    addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = previous);
    SharedPreferences.setMockInitialValues({
      'completed_lessons': ['safety_01'],
    });
  });
  for (final id in fullRoutes.keys) {
    for (final alternate in [false, true]) {
      testWidgets(
        '$id ${alternate ? 'alternative dark' : 'primary light'} full UI conditions explanations restart',
        (tester) async {
          final d = engine.loadCase(id);
          final c = PracticeController(d);
          addTearDown(c.dispose);
          await tester.binding.setSurfaceSize(const Size(360, 800));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          Widget host() => RepaintBoundary(
            key: captureKey,
            child: MaterialApp(
              theme: alternate ? AppTheme.dark : AppTheme.light,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(1.3)),
                child: child!,
              ),
              home: PracticeScreen(definition: d, controller: c),
            ),
          );
          await tester.pumpWidget(host());
          await settle(tester);
          expect(find.text('Сложность: ${d.difficulty}'), findsOneWidget);
          expect(find.text(d.symptoms), findsOneWidget);
          await tester.scrollUntilVisible(
            find.text(d.topology),
            180,
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.text(d.topology), findsOneWidget);
          expect(find.text(d.explanation), findsNothing);
          await tap(tester, find.byKey(const ValueKey('practice_start')));
          final route = alternate ? fullAlternateRoutes[id]! : fullRoutes[id]!;
          for (final action in route) {
            await performUi(
              tester,
              c,
              d,
              action,
              screenshot: id == 'dp16' && action == (alternate ? 'T4' : 'T1')
                  ? 'signal_${alternate ? 'dark' : 'light'}'
                  : null,
            );
          }
          // Change a hypothesis twice, link actual evidence, then scroll/rebuild.
          await tester.tap(find.byKey(const ValueKey('practice_tab_2')));
          await settle(tester);
          final h = d.hypotheses.keys.first;
          await tap(tester, find.byKey(ValueKey('hypothesis_${h}_supported')));
          await tap(
            tester,
            find.byKey(ValueKey('hypothesis_${h}_contradicted')),
          );
          await tap(tester, find.text('Связать записи (0)').first);
          await citeUi(tester, 'cite_${h}_1');
          await tester.tap(find.byKey(const ValueKey('close_citations')));
          await settle(tester);
          final last = d.hypotheses.keys.last;
          await reveal(
            tester,
            find.byKey(ValueKey('hypothesis_${last}_supported')),
          );
          await tester.pumpWidget(host());
          await settle(tester);
          await top(tester);
          expect(c.state.hypotheses[h]!.status, HypothesisStatus.contradicted);
          expect(c.state.hypotheses[h]!.recordIds, {1});
          expect(find.text('Связать записи (1)'), findsOneWidget);
          final beforeSubmit = DateTime.now().toUtc();
          await interpretUi(tester, c, d);
          final responses = c.state.responses;
          await tester.pumpWidget(host());
          await settle(tester);
          expect(c.state.responses, same(responses));
          await tap(tester, find.byKey(const ValueKey('practice_submit')));
          expect(c.state.evaluation!.passed, isTrue);
          expect(find.text('100.0 / 100'), findsOneWidget);
          expect(find.text(d.explanation), findsWidgets);
          if (id == 'dp18') {
            await capture(tester, 'srs_${alternate ? 'dark' : 'light'}');
          }
          final saved = (await tester.runAsync(() => c.repository.read(id)))!;
          expect(saved.passed, isTrue);
          expect(saved.bestScore, 100);
          expect(saved.completedAttempts, 1);
          expect(saved.lastCompletedAt.isBefore(beforeSubmit), isFalse);
          expect(
            saved.lastCompletedAt.isAfter(DateTime.now().toUtc()),
            isFalse,
          );
          await tester.pumpWidget(host());
          await settle(tester);
          final again = (await tester.runAsync(() => c.repository.read(id)))!;
          expect(again.completedAttempts, 1);
          expect(again.lastCompletedAt, saved.lastCompletedAt);
          await retry(tester);
          expect(c.state.journal, isEmpty);
          expect(c.state.hypotheses, isEmpty);
          expect(c.state.responses, isEmpty);
          // Destroy the route and plugin singleton: persisted summary, clean draft.
          await tester.pumpWidget(const SizedBox());
          SharedPreferences.resetStatic();
          await tester.pumpWidget(
            const MaterialApp(home: PracticeCatalogScreen()),
          );
          await settle(tester);
          await reveal(tester, find.byKey(ValueKey('practice_status_$id')));
          expect(
            tester
                .widget<Text>(find.byKey(ValueKey('practice_status_$id')))
                .data,
            contains('Пройден · лучший результат: 100.0'),
          );
          expect(
            (await SharedPreferences.getInstance()).getStringList(
              'completed_lessons',
            ),
            ['safety_01'],
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'retry cancellation and barrier dismissal preserve work and do not save again',
    (tester) async {
      final d = engine.loadCase('dp05');
      final c = PracticeController(d);
      addTearDown(c.dispose);
      c.edit((s) {
        engine.preparePass(s, fullRoutes['dp05']!);
        s.submit();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: PracticeScreen(definition: d, controller: c),
        ),
      );
      await settle(tester);
      await tap(tester, find.byKey(const ValueKey('practice_start')));
      await tester.tap(find.byKey(const ValueKey('practice_tab_4')));
      await settle(tester);
      final original = c.state;
      await tap(tester, find.byKey(const ValueKey('practice_retry')));
      expect(
        find.textContaining('Сохранённый лучший результат'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('practice_retry_cancel')));
      await settle(tester);
      expect(c.state, same(original));
      await tap(tester, find.byKey(const ValueKey('practice_retry')));
      await tester.tapAt(const Offset(2, 2));
      await settle(tester);
      expect(c.state, same(original));
      expect(
        (await tester.runAsync(() => c.repository.read('dp05')))!
            .completedAttempts,
        1,
      );
      await retry(tester);
      expect(c.state.id, original.id + 1);
      expect(c.state.journal, isEmpty);
    },
  );
  for (final change in ['safety', 'profile', 'polarity']) {
    testWidgets(
      'exit warns for $change alone with no journal answers or hypotheses',
      (tester) async {
        final d = engine.loadCase('dp05');
        final c = PracticeController(d);
        addTearDown(c.dispose);
        c.edit((s) {
          if (change == 'safety') s.decideSafety(true);
          if (change == 'profile') {
            s.changeProfile(
              d.profiles.keys.firstWhere((id) => id != d.initialProfileId),
            );
          }
          if (change == 'polarity') {
            s.choosePolarity(
              d.actions.values.whereType<ReadingAction>().first.id,
              true,
            );
          }
        });
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          PracticeScreen(definition: d, controller: c),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await settle(tester);
        await tester.pageBack();
        await settle(tester);
        expect(find.text('Выйти из попытки?'), findsOneWidget);
        await tester.tap(find.text('Остаться'));
        await settle(tester);
        expect(find.byType(PracticeScreen), findsOneWidget);
        expect(c.state.journal, isEmpty);
        expect(c.state.responses, isEmpty);
        expect(c.state.hypotheses, isEmpty);
        await tester.pageBack();
        await settle(tester);
        await tester.tap(find.text('Выйти'));
        await settle(tester);
        expect(find.text('open'), findsOneWidget);
        expect((await SharedPreferences.getInstance()).getKeys(), {
          'completed_lessons',
        });
      },
    );
  }
}
