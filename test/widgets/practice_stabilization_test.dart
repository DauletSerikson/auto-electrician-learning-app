import 'package:electrician/practice/attempt.dart';
import 'package:electrician/practice/practice_controller.dart';
import 'package:electrician/practice/practice_result_repository.dart';
import 'package:electrician/screens/practice_catalog_screen.dart';
import 'package:electrician/screens/practice_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../practice/practice_engine_test.dart'
    as engine
    show preparePass, routes, perform;
import 'practice_screen_test.dart' show settle, tap, definition, reveal;

class CountingRepository implements PracticeResultRepository {
  final delegate = PreferencesPracticeResultRepository();
  int writes = 0;
  bool fail = false;
  @override
  Future<PracticeResult?> read(String id) => delegate.read(id);
  @override
  Future<PracticeResult> complete({
    required String scenarioId,
    required String submissionId,
    required PracticeEvaluation evaluation,
    required DateTime completedAt,
  }) {
    writes++;
    if (fail) return Future.error(StateError('storage unavailable'));
    return delegate.complete(
      scenarioId: scenarioId,
      submissionId: submissionId,
      evaluation: evaluation,
      completedAt: completedAt,
    );
  }
}

void main() {
  setUp(() {
    rootBundle.clear();
    SharedPreferences.setMockInitialValues({
      'completed_lessons': ['safety_01'],
    });
  });
  testWidgets('catalog refreshes after submit, then survives app recreation', (
    tester,
  ) async {
    Widget host() => const MaterialApp(home: PracticeCatalogScreen());
    await tester.pumpWidget(host());
    await settle(tester);
    final status = find.byKey(const ValueKey('practice_status_dp01'));
    expect(tester.widget<Text>(status).data, contains('Не пройден'));
    await tap(tester, find.byKey(const ValueKey('practice_case_dp01')));
    final screen = tester.widget<PracticeScreen>(find.byType(PracticeScreen));
    final controller = screen.controller!;
    controller.edit((s) => engine.preparePass(s, engine.routes['dp01']!));
    await tap(tester, find.byKey(const ValueKey('practice_start')));
    await tester.tap(find.byKey(const ValueKey('practice_tab_3')));
    await settle(tester);
    await tap(tester, find.byKey(const ValueKey('practice_submit')));
    expect(
      find.textContaining('Результат сохранён на устройстве.'),
      findsOneWidget,
    );
    await tester.pageBack();
    await settle(tester);
    expect(
      tester.widget<Text>(status).data,
      contains('Пройден · лучший результат: 100.0'),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(host());
    await settle(tester);
    expect(
      tester.widget<Text>(status).data,
      contains('Пройден · лучший результат: 100.0'),
    );
    expect(
      (await PreferencesPracticeResultRepository().read('dp01'))!
          .completedAttempts,
      1,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'completed result survives rebuild; retry counts only next submission',
    (tester) async {
      final d = await definition(tester, 'dp05');
      final repository = CountingRepository();
      final c = PracticeController(d, repository: repository);
      addTearDown(c.dispose);
      c.edit((s) => engine.preparePass(s, engine.routes['dp05']!));
      Widget host() => MaterialApp(
        home: PracticeScreen(definition: d, controller: c),
      );
      await tester.pumpWidget(host());
      await settle(tester);
      await tap(tester, find.byKey(const ValueKey('practice_start')));
      await tester.tap(find.byKey(const ValueKey('practice_tab_3')));
      await settle(tester);
      await tap(tester, find.byKey(const ValueKey('practice_submit')));
      for (var i = 0; i < 3; i++) {
        await tester.pumpWidget(host());
        await settle(tester);
      }
      expect(repository.writes, 1);
      expect(find.text('100.0 / 100'), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('practice_retry')));
      expect(c.state.hypotheses, isEmpty);
      expect(c.state.responses, isEmpty);
      expect(c.state.journal, isEmpty);
      expect(repository.writes, 1);
      c.edit((s) => s.chooseConclusion('positive'));
      await tester.tap(find.byKey(const ValueKey('practice_tab_3')));
      await settle(tester);
      await tap(tester, find.byKey(const ValueKey('practice_submit')));
      final result = await tester.runAsync(() => repository.read('dp05'));
      expect(result!.completedAttempts, 2);
      expect(result.bestScore, 100);
      expect(result.passed, isTrue);
      expect(repository.writes, 2);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'failed save is visible, explicit retry does not duplicate completion',
    (tester) async {
      final d = await definition(tester, 'dp01');
      final r = CountingRepository()..fail = true;
      final c = PracticeController(d, repository: r);
      addTearDown(c.dispose);
      c.edit((s) => engine.preparePass(s, engine.routes['dp01']!));
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
      await reveal(tester, find.byKey(const ValueKey('practice_save_retry')));
      expect(
        find.textContaining('Не удалось сохранить результат.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('practice_retry')),
            )
            .onPressed,
        isNull,
      );
      r.fail = false;
      await tap(tester, find.byKey(const ValueKey('practice_save_retry')));
      expect(c.resultSaved, isTrue);
      final result = await tester.runAsync(() => r.read('dp01'));
      expect(result!.completedAttempts, 1);
      expect(r.writes, 2);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'catalog isolates corrupt record and still shows healthy scenario result',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        PreferencesPracticeResultRepository.keyFor('dp01'),
        '{bad',
      );
      final d = await definition(tester, 'dp13');
      final c = PracticeController(d);
      addTearDown(c.dispose);
      c.edit((s) {
        engine.preparePass(s, engine.routes['dp13']!);
        s.submit();
      });
      await settle(tester);
      await tester.pumpWidget(const MaterialApp(home: PracticeCatalogScreen()));
      await settle(tester);
      expect(
        find.textContaining('Не удалось прочитать сохранённый результат.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('practice_status_dp13')))
            .data,
        contains('Пройден · лучший результат: 100.0'),
      );
      expect(prefs.getStringList('completed_lessons'), ['safety_01']);
      expect(
        prefs.getString(PreferencesPracticeResultRepository.keyFor('dp01')),
        '{bad',
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'long journal scroll preserves hypothesis and cited evidence across rebuild',
    (tester) async {
      final d = await definition(tester, 'dp01');
      final c = PracticeController(d);
      addTearDown(c.dispose);
      c.edit((s) {
        for (var i = 0; i < 45; i++) {
          engine.perform(s, 'ST0');
        }
      });
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Widget host() => MaterialApp(
        home: PracticeScreen(definition: d, controller: c),
      );
      await tester.pumpWidget(host());
      await settle(tester);
      await tap(tester, find.byKey(const ValueKey('practice_start')));
      await tester.tap(find.byKey(const ValueKey('practice_tab_2')));
      await settle(tester);
      final h = d.hypotheses.keys.first;
      await tap(tester, find.byKey(ValueKey('hypothesis_${h}_supported')));
      await tap(tester, find.text('Связать записи (0)').first);
      await tap(tester, find.byKey(ValueKey('cite_${h}_1')), modal: true);
      await tester.tap(find.byKey(const ValueKey('close_citations')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('practice_tab_1')));
      await settle(tester);
      final scroll = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      // Scroll through a lazy, variable-height journal all the way to its end.
      for (var i = 0; i < 15; i++) {
        scroll.jumpTo(scroll.maxScrollExtent);
        await settle(tester);
      }
      expect(find.byKey(const ValueKey('record_45')), findsOneWidget);
      await tester.pumpWidget(host());
      await settle(tester);
      scroll.jumpTo(0);
      await settle(tester);
      expect(find.text('Запись #1'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('practice_tab_2')));
      await settle(tester);
      expect(c.state.hypotheses[h]!.status, HypothesisStatus.supported);
      expect(c.state.hypotheses[h]!.recordIds, {1});
      expect(find.text('Связать записи (1)'), findsOneWidget);
      expect(c.state.journal, hasLength(45));
      expect((await SharedPreferences.getInstance()).getKeys(), {
        'completed_lessons',
      });
      expect(tester.takeException(), isNull);
    },
  );
}
