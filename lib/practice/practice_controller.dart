import 'package:flutter/foundation.dart';

import 'attempt.dart';
import 'definition.dart';
import 'practice_result_repository.dart';

/// Route-scoped Flutter adapter; the diagnostic engine remains pure Dart.
final class PracticeController extends ChangeNotifier {
  final PracticeSession _session;
  final PracticeResultRepository repository;
  static int _sequence = 0;
  final String _routeId =
      '${DateTime.now().microsecondsSinceEpoch}_${_sequence++}';
  bool _disposed = false;
  bool saving = false;
  Object? saveError;
  bool resultSaved = false;
  DateTime? _completedAt;
  Future<void>? _pendingSave;
  Future<void> get pendingSave => _pendingSave ?? Future<void>.value();
  PracticeController(
    PracticeDefinition definition, {
    PracticeResultRepository? repository,
  }) : _session = PracticeSession(definition),
       repository = repository ?? PreferencesPracticeResultRepository();
  PracticeAttempt get state => _session.state;
  void edit(void Function(PracticeSession session) change) {
    if (state.submitted && (saving || saveError != null)) {
      throw StateError('Save the completed attempt before retry');
    }
    final wasSubmitted = state.submitted;
    change(_session);
    if (!wasSubmitted && state.submitted) {
      _completedAt = DateTime.now().toUtc();
      saveResult();
    } else if (!state.submitted) {
      resultSaved = false;
    }
    _notify();
  }

  /// Called only on submit or explicit storage retry, never from build.
  Future<void> saveResult() {
    if (!state.submitted || saving || resultSaved || _completedAt == null) {
      return pendingSave;
    }
    return _pendingSave = _saveResult();
  }

  Future<void> _saveResult() async {
    saving = true;
    saveError = null;
    _notify();
    try {
      await repository.complete(
        scenarioId: _session.definition.id,
        submissionId: '$_routeId:${state.id}',
        evaluation: state.evaluation!,
        completedAt: _completedAt!,
      );
      resultSaved = true;
    } catch (error) {
      saveError = error;
    } finally {
      saving = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
