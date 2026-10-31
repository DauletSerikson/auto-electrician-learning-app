import 'dart:async';

import 'package:electrician/practice/attempt.dart';
import 'package:electrician/practice/practice_controller.dart';
import 'package:electrician/practice/practice_result_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/preferences_platform_fake.dart';
import 'practice_engine_test.dart' as engine show loadCase, preparePass, routes;

PracticeEvaluation evaluation(double score, {bool passed = false}) =>
    PracticeEvaluation(
      fractions: {},
      groups: {},
      interpretations: {},
      score: score,
      passed: passed,
      needsMoreEvidence: false,
      feedback: [],
    );
final date = DateTime.utc(2026, 10, 31, 12);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<PracticeResult> save(
    PracticeResultRepository r,
    String token,
    double score, {
    String id = 'dp01',
    bool passed = false,
    DateTime? at,
  }) => r.complete(
    scenarioId: id,
    submissionId: token,
    evaluation: evaluation(score, passed: passed),
    completedAt: at ?? date,
  );

  test(
    'failed storage acknowledgement does not appear saved and queue recovers',
    () async {
      final fake = PreferencesPlatformFake()..install();
      addTearDown(fake.uninstall);
      fake.onWrite = () async => false;
      final r = PreferencesPracticeResultRepository();
      await expectLater(save(r, 'a', 100), throwsStateError);
      expect(await r.read('dp01'), isNull);
      fake.onWrite = null;
      await save(r, 'a', 100);
      expect((await r.read('dp01'))!.completedAttempts, 1);
    },
  );
  test('read failure does not overwrite existing values', () async {
    final fake = PreferencesPlatformFake()..install();
    addTearDown(fake.uninstall);
    fake.onRead = () async => throw StateError('read unavailable');
    await expectLater(
      save(PreferencesPracticeResultRepository(), 'a', 100),
      throwsA(isA<PlatformException>()),
    );
    expect(fake.writes, 0);
  });
  test('controller saves submit only, freezes during write, retry starts new count', () async {
    final fake = PreferencesPlatformFake()..install();
    addTearDown(fake.uninstall);
    final gate = Completer<bool>();
    fake.onWrite = () => gate.future;
    final c = PracticeController(engine.loadCase('dp01'));
    addTearDown(c.dispose);
    c.edit((s) => engine.preparePass(s, engine.routes['dp01']!));
    expect(fake.writes, 0);
    c.edit((s) => s.submit());
    expect(c.saving, isTrue);
    expect(() => c.edit((s) => s.retry()), throwsStateError);
    final pendingRetry = c.saveResult();
    gate.complete(true);
    await pendingRetry;
    while (c.saving) {
      await Future<void>.delayed(Duration.zero);
    }
    await c.saveResult();
    expect(fake.writes, 1);
    c.edit((s) => s.retry());
    expect(c.state.journal, isEmpty);
    expect(c.resultSaved, isFalse);
    c.edit((s) {
      s.chooseConclusion('control');
      s.submit();
    });
    while (c.saving) {
      await Future<void>.delayed(Duration.zero);
    }
    expect((await c.repository.read('dp01'))!.completedAttempts, 2);
  });
  test(
    'controller exposes write error and retries the same completion once',
    () async {
      final fake = PreferencesPlatformFake()..install();
      addTearDown(fake.uninstall);
      fake.onWrite = () async => false;
      final c = PracticeController(engine.loadCase('dp05'));
      addTearDown(c.dispose);
      c.edit((s) {
        engine.preparePass(s, engine.routes['dp05']!);
        s.submit();
      });
      while (c.saving) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(c.saveError, isNotNull);
      expect(c.resultSaved, isFalse);
      fake.onWrite = null;
      await c.saveResult();
      expect(c.resultSaved, isTrue);
      expect((await c.repository.read('dp05'))!.completedAttempts, 1);
      await c.saveResult();
      expect(fake.writes, 2);
    },
  );
}
