import 'dart:convert';

import 'package:electrician/practice/attempt.dart';
import 'package:electrician/practice/practice_result_repository.dart';
import 'package:electrician/services/progress_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'completed_lessons': ['safety_01'],
    }),
  );
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

  test('empty storage reads absent without writing any keys', () async {
    expect(await PreferencesPracticeResultRepository().read('dp01'), isNull);
    expect((await SharedPreferences.getInstance()).getKeys(), {
      'completed_lessons',
    });
  });
  test(
    'completion persists a typed summary after repository recreation',
    () async {
      await save(
        PreferencesPracticeResultRepository(),
        'a',
        92.5,
        passed: true,
      );
      SharedPreferences.resetStatic();
      final read = await PreferencesPracticeResultRepository().read('dp01');
      expect(read!.scenarioId, 'dp01');
      expect(read.passed, isTrue);
      expect(read.bestScore, 92.5);
      expect(read.completedAttempts, 1);
      expect(read.lastCompletedAt, date);
      final raw = jsonDecode(
        (await SharedPreferences.getInstance()).getString(
          PreferencesPracticeResultRepository.keyFor('dp01'),
        )!,
      ) as Map;
      expect(raw.keys.toSet(), {
        'schemaVersion',
        'scenarioId',
        'passed',
        'bestScore',
        'completedAttempts',
        'lastCompletedAt',
        'lastSubmissionId',
      });
    },
  );
  test(
    'better and worse repeats count once each, retain PASS and maximum',
    () async {
      final r = PreferencesPracticeResultRepository();
      await save(r, 'a', 40);
      await save(r, 'b', 100, passed: true);
      final result = await save(
        r,
        'c',
        10,
        at: date.add(const Duration(days: 1)),
      );
      expect(result.bestScore, 100);
      expect(result.passed, isTrue);
      expect(result.completedAttempts, 3);
      expect(result.lastCompletedAt, date.add(const Duration(days: 1)));
    },
  );
  test('best numerical FAIL is distinct from successful completion', () async {
    final r = PreferencesPracticeResultRepository();
    await save(r, 'a', 95);
    final result = await save(r, 'b', 90, passed: true);
    expect(result.bestScore, 95);
    expect(result.passed, isTrue);
  });
  test(
    'same completion retry is idempotent across repository instances',
    () async {
      await save(
        PreferencesPracticeResultRepository(),
        'same',
        100,
        passed: true,
      );
      await save(
        PreferencesPracticeResultRepository(),
        'same',
        100,
        passed: true,
      );
      expect(
        (await PreferencesPracticeResultRepository().read('dp01'))!
            .completedAttempts,
        1,
      );
    },
  );
  test('concurrent repositories serialize read modify write', () async {
    await Future.wait([
      save(PreferencesPracticeResultRepository(), 'a', 70),
      save(PreferencesPracticeResultRepository(), 'b', 100, passed: true),
      save(PreferencesPracticeResultRepository(), 'b', 100, passed: true),
    ]);
    final result = await PreferencesPracticeResultRepository().read('dp01');
    expect(result!.completedAttempts, 2);
    expect(result.bestScore, 100);
  });
  test(
    'scenarios and lesson progress remain independent in both directions',
    () async {
      final r = PreferencesPracticeResultRepository();
      await save(r, 'a', 100, passed: true);
      await save(r, 'b', 30, id: 'dp13');
      await ProgressService().completeLesson('new_lesson');
      expect((await r.read('dp01'))!.bestScore, 100);
      expect((await r.read('dp13'))!.bestScore, 30);
      expect(await r.read('dp05'), isNull);
      expect(await ProgressService().getCompletedLessons(), {
        'safety_01',
        'new_lesson',
      });
    },
  );
  for (final corrupt in <Object>[
    '{broken',
    5,
    jsonEncode({'schemaVersion': 99}),
    jsonEncode({
      'schemaVersion': 1,
      'scenarioId': 'dp13',
      'passed': true,
      'bestScore': 100,
      'completedAttempts': 1,
      'lastCompletedAt': date.toIso8601String(),
      'lastSubmissionId': 'a',
    }),
  ]) {
    test(
      'corrupt or incompatible record is reported and preserved: $corrupt',
      () async {
        final key = PreferencesPracticeResultRepository.keyFor('dp01');
        SharedPreferences.setMockInitialValues({
          key: corrupt,
          'completed_lessons': ['safety_01'],
        });
        final r = PreferencesPracticeResultRepository();
        await expectLater(r.read('dp01'), throwsFormatException);
        await expectLater(save(r, 'new', 100), throwsFormatException);
        await save(r, 'other', 20, id: 'dp05');
        expect((await SharedPreferences.getInstance()).get(key), corrupt);
        expect(await ProgressService().getCompletedLessons(), {'safety_01'});
      },
    );
  }
  for (final entry in <String, Object>{
    'schemaVersion': 2,
    'bestScore': -1,
    'completedAttempts': 0,
    'lastCompletedAt': 'invalid',
    'passed': 'true',
    'lastSubmissionId': '',
  }.entries) {
    test('strict stored field validation: ${entry.key}', () async {
      final r = PreferencesPracticeResultRepository();
      final valid = await save(r, 'a', 100, passed: true);
      final raw = jsonDecode(valid.encode()) as Map<String, Object?>;
      raw[entry.key] = entry.value;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        PreferencesPracticeResultRepository.keyFor('dp01'),
        jsonEncode(raw),
      );
      await expectLater(r.read('dp01'), throwsFormatException);
    });
  }
}
