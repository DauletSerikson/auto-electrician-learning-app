import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import 'attempt.dart';
import 'json_data.dart';

/// Summary only: no unfinished drafts, answers or measurement journal.
final class PracticeResult {
  final String scenarioId;
  final bool passed;
  final double bestScore;
  final int completedAttempts;
  final DateTime lastCompletedAt;
  final String lastSubmissionId;

  const PracticeResult({
    required this.scenarioId,
    required this.passed,
    required this.bestScore,
    required this.completedAttempts,
    required this.lastCompletedAt,
    required this.lastSubmissionId,
  });

  factory PracticeResult.parse(String raw, String scenarioId) {
    final j = JsonData(jsonDecode(raw), 'practiceResult');
    j.fields({
      'schemaVersion',
      'scenarioId',
      'passed',
      'bestScore',
      'completedAttempts',
      'lastCompletedAt',
      'lastSubmissionId',
    });
    if (j.integer('schemaVersion') != 1 || j.text('scenarioId') != scenarioId) {
      j.fail('incompatible version or scenario');
    }
    final score = j.number('bestScore');
    final date = DateTime.tryParse(j.text('lastCompletedAt'));
    if (score < 0 || score > 100 || date == null || !date.isUtc) {
      j.fail('invalid score or UTC completion date');
    }
    return PracticeResult(
      scenarioId: scenarioId,
      passed: j.flag('passed'),
      bestScore: score,
      completedAttempts: j.integer('completedAttempts'),
      lastCompletedAt: date,
      lastSubmissionId: j.text('lastSubmissionId'),
    );
  }

  String encode() => jsonEncode({
    'schemaVersion': 1,
    'scenarioId': scenarioId,
    'passed': passed,
    'bestScore': bestScore,
    'completedAttempts': completedAttempts,
    'lastCompletedAt': lastCompletedAt.toUtc().toIso8601String(),
    'lastSubmissionId': lastSubmissionId,
  });
}

abstract interface class PracticeResultRepository {
  Future<PracticeResult?> read(String scenarioId);
  Future<PracticeResult> complete({
    required String scenarioId,
    required String submissionId,
    required PracticeEvaluation evaluation,
    required DateTime completedAt,
  });
}

/// The queue covers the whole read/modify/write across repository instances.
/// A failed or incompatible record is left intact and reported to the caller.
final class PreferencesPracticeResultRepository
    implements PracticeResultRepository {
  static Future<void>? _writes;
  static String keyFor(String id) {
    if (!RegExp(r'^dp[0-9]{2}$').hasMatch(id)) {
      throw ArgumentError.value(id, 'scenarioId');
    }
    return 'diagnostic_practice.result.$id';
  }

  @override
  Future<PracticeResult?> read(String scenarioId) async {
    final key = keyFor(scenarioId);
    final prefs = await SharedPreferences.getInstance();
    // Do not present the plugin's optimistic cache as a confirmed write.
    await prefs.reload();
    final raw = prefs.get(key);
    if (raw == null) return null;
    if (raw is! String) throw const FormatException('Invalid practice record');
    return PracticeResult.parse(raw, scenarioId);
  }

  @override
  Future<PracticeResult> complete({
    required String scenarioId,
    required String submissionId,
    required PracticeEvaluation evaluation,
    required DateTime completedAt,
  }) {
    keyFor(scenarioId);
    if (submissionId.trim().isEmpty ||
        !evaluation.score.isFinite ||
        evaluation.score < 0 ||
        evaluation.score > 100) {
      throw ArgumentError('Invalid completion');
    }
    final operation = (_writes ?? Future<void>.value()).then((_) async {
      final old = await read(scenarioId);
      // Retry the same completion after an uncertain storage acknowledgement.
      if (old?.lastSubmissionId == submissionId) return old!;
      final result = PracticeResult(
        scenarioId: scenarioId,
        passed: (old?.passed ?? false) || evaluation.passed,
        bestScore: math.max(old?.bestScore ?? 0, evaluation.score),
        completedAttempts: (old?.completedAttempts ?? 0) + 1,
        lastCompletedAt: completedAt.toUtc(),
        lastSubmissionId: submissionId,
      );
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(keyFor(scenarioId), result.encode())) {
        throw StateError('Could not save practice result');
      }
      return result;
    });
    late final Future<void> tail;
    void release() {
      if (identical(_writes, tail)) _writes = null;
    }

    tail = operation.then<void>(
      (_) => release(),
      onError: (Object error, StackTrace stack) => release(),
    );
    _writes = tail;
    return operation;
  }
}
