import 'package:electrician/main.dart';
import 'package:electrician/practice/attempt.dart';
import 'package:electrician/practice/definition.dart';
import 'package:electrician/practice/practice_controller.dart';
import 'package:electrician/practice/practice_service.dart';
import 'package:electrician/practice/practice_result_repository.dart';
import 'package:electrician/screens/practice_catalog_screen.dart';
import 'package:electrician/screens/practice_screen.dart';
import 'package:electrician/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../practice/practice_engine_test.dart'
    as engine
    show routes, preparePass;

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  }
  await tester.pumpAndSettle();
}

Future<void> reveal(
  WidgetTester tester,
  Finder target, {
  bool up = false,
  bool modal = false,
}) async {
  final scrollable = modal
      ? find.byType(Scrollable).last
      : find.byType(Scrollable).first;
  var direction = up ? 1.0 : -1.0;
  for (var i = 0; i < 180; i++) {
    if (target.hitTestable().evaluate().isNotEmpty) {
      await tester.ensureVisible(target);
      await settle(tester);
      return;
    }
    if (target.evaluate().isNotEmpty) {
      final y = tester.getCenter(target).dy;
      if (y.isFinite) {
        direction = y < tester.getTopLeft(scrollable).dy ? 1 : -1;
      }
    }
    final position = tester.state<ScrollableState>(scrollable).position;
    if (position.pixels >= position.maxScrollExtent && direction < 0) {
      direction = 1;
    } else if (position.pixels <= position.minScrollExtent && direction > 0) {
      direction = -1;
    }
    final origin =
        tester.getTopLeft(scrollable) +
        Offset(5, tester.getSize(scrollable).height / 2);
    await tester.dragFrom(origin, Offset(0, direction * 180));
    await settle(tester);
  }
  fail('Could not reveal $target');
}

Future<void> tap(
  WidgetTester tester,
  Finder target, {
  bool up = false,
  bool modal = false,
}) async {
  await reveal(tester, target, up: up, modal: modal);
  await tester.tap(target);
  await settle(tester);
}

Future<void> top(WidgetTester tester) async {
  tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position
      .jumpTo(0);
  await settle(tester);
}

Future<void> retry(WidgetTester tester) async {
  await tap(tester, find.byKey(const ValueKey('practice_retry')));
  expect(find.text('Начать новую попытку?'), findsOneWidget);
  await tester.tap(find.byKey(const ValueKey('practice_retry_confirm')));
  await settle(tester);
}

Future<PracticeDefinition> definition(WidgetTester tester, String id) async =>
    (await tester.runAsync(() => PracticeService().loadCatalog()))!
        .firstWhere((d) => d.id == id);

Future<void> check(WidgetTester tester, PracticeDefinition d, String id) async {
  await top(tester);
  await reveal(tester, find.text(d.actions[id]!.title));
  final card = find.byKey(ValueKey('action_$id'));
  await tap(
    tester,
    find.descendant(of: card, matching: find.text('Цель проверки')),
  );
  await tap(tester, find.byKey(ValueKey('purpose_${id}_p1')));
  final profile = find.byKey(ValueKey('profile_for_$id'));
  if (profile.evaluate().isNotEmpty) await tap(tester, profile);
  await tap(tester, find.byKey(ValueKey('perform_$id')));
  expect(find.byType(AlertDialog), findsOneWidget);
  expect(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.textContaining('Границы вывода:'),
    ),
    findsOneWidget,
  );
  await tester.tap(find.text('Закрыть запись'));
  await settle(tester);
}

void main() {
  setUp(() {
    // Asset futures created in a previous test's fake async zone must not leak.
    rootBundle.clear();
    SharedPreferences.setMockInitialValues({
      'completed_lessons': ['safety_01'],
    });
  });
  testWidgets(
    'Home opens isolated eighteen-case catalog without changing course progress',
    (tester) async {
      await tester.pumpWidget(const AutoElectricianApp());
      await settle(tester);
      expect(find.text('1 из 132 уроков'), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('open_diagnostic_practice')));
      expect(find.byType(PracticeCatalogScreen), findsOneWidget);
      final cases = await tester.runAsync(
        () => PracticeService().loadCatalog(),
      );
      expect(cases!.take(3).map((d) => d.id), ['dp01', 'dp13', 'dp05']);
      expect(cases, hasLength(18));
      expect(cases.map((d) => d.id).toSet(), {
        for (var i = 1; i <= 18; i++) 'dp${i.toString().padLeft(2, '0')}',
      });
      await tap(tester, find.byKey(const ValueKey('practice_case_dp01')));
      expect(find.byType(PracticeScreen), findsOneWidget);
      expect(find.text('Исходные симптомы'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('completed_lessons'), ['safety_01']);
      expect(prefs.getKeys(), {'completed_lessons'});
      expect(tester.takeException(), isNull);
    },
  );

  for (final id in ['dp01', 'dp13', 'dp05']) {
    for (final dark in [false, true]) {
      testWidgets(
        '$id ${dark ? 'dark' : 'light'} 360px 1.3 real scroll rebuild resize preserves controls and journal',
        (tester) async {
          final d = await definition(tester, id);
          final c = PracticeController(d);
          addTearDown(c.dispose);
          await tester.binding.setSurfaceSize(const Size(360, 800));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          Widget host() => MaterialApp(
            theme: dark ? AppTheme.dark : AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(1.3)),
              child: child!,
            ),
            home: PracticeScreen(
              key: const ValueKey('practice'),
              definition: d,
              controller: c,
            ),
          );
          await tester.pumpWidget(host());
          await settle(tester);
          await tap(tester, find.byKey(const ValueKey('practice_start')));
          final safe = d.actions.values
              .where((a) => a is! ForbiddenAction)
              .toList();
          final first = safe.first, last = safe.last;
          await check(tester, d, first.id);
          expect(c.state.journal, hasLength(1));
          await check(tester, d, last.id);
          for (var cycle = 0; cycle < 3; cycle++) {
            await reveal(tester, find.text(first.title), up: true);
            expect(c.state.purposes[first.id], 'p1');
            await reveal(tester, find.text(last.title));
            expect(c.state.purposes[last.id], 'p1');
          }
          await tester.binding.setSurfaceSize(const Size(600, 420));
          await tester.pumpWidget(host());
          await settle(tester);
          await reveal(tester, find.text(first.title), up: true);
          expect(c.state.purposes[first.id], 'p1');
          expect(c.state.journal, hasLength(2));
          await tester.binding.setSurfaceSize(const Size(360, 800));
          await settle(tester);
          await tester.tap(find.byKey(const ValueKey('practice_tab_1')));
          await settle(tester);
          expect(find.text('Запись #1'), findsOneWidget);
          expect(c.state.journal.first.conditions.id, first.profileId);
          await tester.tap(find.byKey(const ValueKey('practice_tab_2')));
          await settle(tester);
          final hypothesis = d.hypotheses.keys.first;
          await tap(
            tester,
            find.byKey(ValueKey('hypothesis_${hypothesis}_supported')),
          );
          expect(
            c.state.hypotheses[hypothesis]!.status,
            HypothesisStatus.supported,
          );
          await tester.tap(find.byKey(const ValueKey('practice_tab_0')));
          await settle(tester);
          expect(c.state.journal, hasLength(2));
          expect(c.state.purposes[first.id], 'p1');
          await tester.tap(find.byKey(const ValueKey('practice_tab_3')));
          await settle(tester);
          final diagnosis = d.conclusions.values.firstWhere(
            (c) => c.credit == 1,
          );
          await tap(tester, find.byKey(ValueKey('conclusion_${diagnosis.id}')));
          await tap(tester, find.byKey(const ValueKey('practice_submit')));
          expect(find.text('FAIL — вывод не подтверждён'), findsOneWidget);
          expect(c.state.evaluation!.passed, isFalse);
          await retry(tester);
          expect(c.state.journal, isEmpty);
          expect(c.state.purposes, isEmpty);
          expect(tester.takeException(), isNull);
        },
      );
    }
    testWidgets('$id UI grading freezes then retry resets current attempt', (
      tester,
    ) async {
      final d = await definition(tester, id);
      final c = PracticeController(d);
      addTearDown(c.dispose);
      c.edit((s) => engine.preparePass(s, engine.routes[id]!));
      await tester.pumpWidget(
        MaterialApp(
          home: PracticeScreen(definition: d, controller: c),
        ),
      );
      await settle(tester);
      await tap(tester, find.byKey(const ValueKey('practice_start')));
      await tester.tap(find.byKey(const ValueKey('practice_tab_3')));
      await settle(tester);
      await tap(tester, find.byKey(const ValueKey('practice_submit')));
      expect(find.text('PASS — обоснованный вывод'), findsOneWidget);
      expect(find.text('100.0 / 100'), findsOneWidget);
      expect(c.state.submitted, isTrue);
      await retry(tester);
      expect(c.state.submitted, isFalse);
      expect(c.state.journal, isEmpty);
      expect(c.state.responses, isEmpty);
      expect(c.state.purposes, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('completed_lessons'), ['safety_01']);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'complete headlamp route through actual controls, citations and common evaluation',
    (tester) async {
      final d = await definition(tester, 'dp05');
      final c = PracticeController(d);
      addTearDown(c.dispose);
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: PracticeScreen(definition: d, controller: c),
        ),
      );
      await settle(tester);
      await tap(tester, find.byKey(const ValueKey('practice_start')));
      for (final id in engine.routes['dp05']!) {
        await check(tester, d, id);
      }
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
          (ids) =>
              c.state.journal.map((r) => r.actionId).toSet().containsAll(ids),
        );
        for (final record in c.state.journal.where(
          (r) => route.contains(r.actionId),
        )) {
          await tap(
            tester,
            find.byKey(ValueKey('cite_${claim.id}_${record.sequence}')),
            modal: true,
          );
        }
        await tester.tap(find.byKey(const ValueKey('close_citations')));
        await settle(tester);
      }
      await top(tester);
      await tap(tester, find.byKey(const ValueKey('conclusion_positive')));
      await tap(tester, find.byKey(const ValueKey('practice_submit')));
      expect(find.text('PASS — обоснованный вывод'), findsOneWidget);
      expect(c.state.evaluation!.score, 100);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reopening starts a clean draft while retaining the completed result summary',
    (tester) async {
      final d = await definition(tester, 'dp01');
      final c = PracticeController(d);
      addTearDown(c.dispose);
      c.edit((s) {
        engine.preparePass(s, engine.routes['dp01']!);
        s.submit();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: PracticeScreen(definition: d, controller: c),
        ),
      );
      await settle(tester);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(MaterialApp(home: PracticeScreen(definition: d)));
      await settle(tester);
      await tap(tester, find.byKey(const ValueKey('practice_start')));
      await tester.tap(find.byKey(const ValueKey('practice_tab_1')));
      await settle(tester);
      expect(find.textContaining('Журнал пуст.'), findsOneWidget);
      expect(find.text('PASS — обоснованный вывод'), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), {
        'completed_lessons',
        PreferencesPracticeResultRepository.keyFor('dp01'),
      });
      final saved = await PreferencesPracticeResultRepository().read('dp01');
      expect(saved!.passed, isTrue);
      expect(saved.completedAttempts, 1);
      expect(prefs.getStringList('completed_lessons'), ['safety_01']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'premature diagnosis through UI fails and insufficient remains a distinct outcome',
    (tester) async {
      final d = await definition(tester, 'dp13');
      final c = PracticeController(d);
      addTearDown(c.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: PracticeScreen(definition: d, controller: c),
        ),
      );
      await settle(tester);
      await tap(tester, find.byKey(const ValueKey('practice_start')));
      await tester.tap(find.byKey(const ValueKey('practice_tab_3')));
      await settle(tester);
      await tap(tester, find.byKey(const ValueKey('conclusion_path')));
      await tap(tester, find.byKey(const ValueKey('practice_submit')));
      expect(find.text('FAIL — вывод не подтверждён'), findsOneWidget);
      expect(c.state.evaluation!.passed, isFalse);
      await retry(tester);
      await tester.tap(find.byKey(const ValueKey('practice_tab_3')));
      await settle(tester);
      await tap(tester, find.byKey(const ValueKey('practice_safety')));
      await tap(tester, find.byKey(const ValueKey('conclusion_more')));
      await tap(tester, find.text('Следующая безопасная проверка'));
      await tap(tester, find.byKey(const ValueKey('follow_up_choice_MF0')));
      await tap(tester, find.byKey(const ValueKey('practice_submit')));
      expect(find.text('Нужна дополнительная проверка'), findsOneWidget);
      expect(c.state.evaluation!.fractions[Criterion.diagnosis], .5);
      expect(c.state.evaluation!.passed, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
