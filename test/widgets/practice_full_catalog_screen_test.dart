import 'package:electrician/practice/attempt.dart';
import 'package:electrician/practice/practice_controller.dart';
import 'package:electrician/practice/practice_result_repository.dart';
import 'package:electrician/screens/practice_catalog_screen.dart';
import 'package:electrician/screens/practice_screen.dart';
import 'package:electrician/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../practice/full_catalog_routes.dart';
import '../practice/practice_engine_test.dart'
    as engine
    show loadCase, preparePass;
import 'practice_screen_test.dart' show settle, tap, top, check;

void main() {
  setUp(() {
    rootBundle.clear();
    SharedPreferences.setMockInitialValues({
      'completed_lessons': ['safety_01'],
    });
  });
  for (final id in fullRoutes.keys.where(
    (id) => !['dp01', 'dp05', 'dp13'].contains(id),
  )) {
    for (final dark in [false, true]) {
      testWidgets(
        '$id ${dark ? 'dark' : 'light'} 360px x1.3 symptoms record and retry',
        (tester) async {
          final d = engine.loadCase(id);
          final c = PracticeController(d);
          addTearDown(c.dispose);
          await tester.binding.setSurfaceSize(const Size(360, 800));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? AppTheme.dark : AppTheme.light,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(1.3)),
                child: child!,
              ),
              home: PracticeScreen(definition: d, controller: c),
            ),
          );
          await settle(tester);
          await tap(tester, find.byKey(const ValueKey('practice_start')));
          await check(tester, d, fullRoutes[id]!.first);
          final first = c.state.journal.single;
          await tester.tap(find.byKey(const ValueKey('practice_tab_1')));
          await settle(tester);
          expect(find.text('Запись #1'), findsOneWidget);
          expect(c.state.journal.single, same(first));
          await tester.tap(find.byKey(const ValueKey('practice_tab_3')));
          await settle(tester);
          await tap(
            tester,
            find.byKey(
              ValueKey(
                'conclusion_${d.conclusions.values.firstWhere((x) => x.credit == 1).id}',
              ),
            ),
          );
          await tap(tester, find.byKey(const ValueKey('practice_submit')));
          expect(c.state.evaluation!.passed, isFalse);
          await tap(tester, find.byKey(const ValueKey('practice_retry')));
          expect(c.state.journal, isEmpty);
          expect(c.state.responses, isEmpty);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'all eighteen statuses survive real catalog scrolling and repository recreation',
    (tester) async {
      final repo = PreferencesPracticeResultRepository();
      await tester.runAsync(() async {
        for (final id in fullRoutes.keys) {
          final s = PracticeSession(engine.loadCase(id));
          engine.preparePass(s, fullRoutes[id]!);
          await repo.complete(
            scenarioId: id,
            submissionId: id,
            evaluation: s.submit(),
            completedAt: DateTime.utc(2026, 11, 2),
          );
        }
      });
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MaterialApp(home: PracticeCatalogScreen()));
      await settle(tester);
      expect(find.text('Диагностические сценарии: 18'), findsOneWidget);
      for (final id in fullRoutes.keys) {
        await tap(tester, find.byKey(ValueKey('practice_case_$id')));
        expect(find.byType(PracticeScreen), findsOneWidget);
        await tester.pageBack();
        await settle(tester);
        final status = find.byKey(ValueKey('practice_status_$id'));
        // Returning reloads the catalog but preserves the lazy scroll position.
        if (status.evaluate().isEmpty) {
          await top(tester);
        }
        await tester.scrollUntilVisible(
          status,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await settle(tester);
        expect(
          tester.widget<Text>(status).data,
          contains('Пройден · лучший результат: 100.0'),
        );
      }
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('completed_lessons'), ['safety_01']);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'SRS full UI interpretation and citations earn bounded referral PASS',
    (tester) async {
      final d = engine.loadCase('dp18');
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
      for (final id in fullRoutes['dp18']!) {
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
        final proof = claim.requirement.alternatives.first;
        for (final r in c.state.journal.where(
          (r) => proof.contains(r.actionId),
        )) {
          await tap(
            tester,
            find.byKey(ValueKey('cite_${claim.id}_${r.sequence}')),
            modal: true,
          );
        }
        await tester.tap(find.byKey(const ValueKey('close_citations')));
        await settle(tester);
      }
      await tap(tester, find.byKey(const ValueKey('conclusion_supported')));
      await tap(tester, find.byKey(const ValueKey('practice_submit')));
      expect(find.text('PASS — обоснованный вывод'), findsOneWidget);
      expect(find.text('100.0 / 100'), findsOneWidget);
      final summary = await tester.runAsync(() => c.repository.read('dp18'));
      expect(summary!.passed, isTrue);
      expect(summary.completedAttempts, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
