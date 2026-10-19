part of 'lesson_block.dart';

/// One settings exercise = one result in the existing lesson attempt contract.
final class OscilloscopeLessonBlock extends LessonBlock {
  final String title;
  final String question;
  final ScopeScenario scenario;
  final ScopeExercise exercise;
  final ScopeSettings initialSettings;

  OscilloscopeLessonBlock({
    required this.title,
    required this.question,
    required this.scenario,
    required this.exercise,
    required this.initialSettings,
  }) {
    // The settings tasks need a periodic signal with non-zero range.
    // Constant and missing-pulse sources remain available for exploration.
    if (scenario.signal is! PeriodicScopeSignal) {
      throw const FormatException(
        'Scope exercise requires a periodic scenario',
      );
    }
  }

  @override
  String get type => 'oscilloscope';

  factory OscilloscopeLessonBlock.fromJson(Map<String, dynamic> json) {
    final raw = json['initialSettings'];
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('initialSettings must be an object');
    }
    try {
      return OscilloscopeLessonBlock(
        title: _requiredString(json, 'title'),
        question: _requiredString(json, 'question'),
        scenario: _scopeEnum(json, 'scenario', ScopeScenario.values),
        exercise: _scopeEnum(json, 'exercise', ScopeExercise.values),
        initialSettings: ScopeSettings(
          voltsPerDiv: _requiredDouble(raw, 'voltsPerDiv'),
          millisecondsPerDiv: _requiredDouble(raw, 'millisecondsPerDiv'),
          centerVoltage: _requiredDouble(raw, 'centerVoltage'),
          triggerLevel: _requiredDouble(raw, 'triggerLevel'),
          edge: _scopeEnum(raw, 'edge', ScopeEdge.values),
          mode: _scopeEnum(raw, 'mode', ScopeTriggerMode.values),
        ),
      );
    } on ArgumentError catch (error) {
      throw FormatException('Invalid oscilloscope settings: $error');
    }
  }
}

T _scopeEnum<T extends Enum>(
  Map<String, dynamic> json,
  String key,
  List<T> values,
) {
  final name = _requiredString(json, key);
  for (final value in values) {
    if (value.name == name) return value;
  }
  throw FormatException('Unknown $key: $name');
}
