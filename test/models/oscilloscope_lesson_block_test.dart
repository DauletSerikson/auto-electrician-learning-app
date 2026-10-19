import 'package:electrician/models/lesson_block.dart';
import 'package:electrician/simulation/oscilloscope_simulation.dart';
import 'package:electrician/simulation/scope_signal.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> scopeJson() => {
  'type': 'oscilloscope',
  'title': 'Масштаб',
  'question': 'Настройте экран',
  'scenario': 'sine',
  'exercise': 'voltageScale',
  'initialSettings': {
    'voltsPerDiv': 2,
    'millisecondsPerDiv': 4,
    'centerVoltage': 0,
    'triggerLevel': 2.5,
    'edge': 'rising',
    'mode': 'normal',
  },
};

void main() {
  test('new JSON dispatches to its concrete strongly typed subtype', () {
    final block = LessonBlock.fromJson(scopeJson()) as OscilloscopeLessonBlock;
    expect(block.type, 'oscilloscope');
    expect(block.scenario, ScopeScenario.sine);
    expect(block.exercise, ScopeExercise.voltageScale);
    expect(block.initialSettings.voltsPerDiv, 2);
    expect(block.initialSettings.edge, ScopeEdge.rising);
  });

  for (final key in [
    'title',
    'question',
    'scenario',
    'exercise',
    'initialSettings',
  ]) {
    test('missing $key is an explicit parsing failure', () {
      expect(
        () => LessonBlock.fromJson(scopeJson()..remove(key)),
        throwsFormatException,
      );
    });
  }
  for (final key in [
    'voltsPerDiv',
    'millisecondsPerDiv',
    'centerVoltage',
    'triggerLevel',
    'edge',
    'mode',
  ]) {
    test('missing initial $key is not silently defaulted', () {
      final json = scopeJson();
      (json['initialSettings'] as Map<String, dynamic>).remove(key);
      expect(() => LessonBlock.fromJson(json), throwsFormatException);
    });
  }
  test('reject unknown enums incompatible scenarios and malformed object', () {
    for (final (key, value) in [
      ('scenario', 'unknown'),
      ('exercise', 'unknown'),
      ('scenario', 'constant'),
      ('scenario', 'missingPulse'),
      ('initialSettings', 1),
      ('title', ''),
    ]) {
      expect(
        () => LessonBlock.fromJson(scopeJson()..[key] = value),
        throwsFormatException,
      );
    }
  });
  test('reject invalid nonfinite unsupported scales and trigger modes', () {
    for (final (key, value) in [
      ('voltsPerDiv', 0),
      ('voltsPerDiv', double.nan),
      ('millisecondsPerDiv', double.infinity),
      ('millisecondsPerDiv', '4'),
      ('centerVoltage', 123),
      ('triggerLevel', double.nan),
      ('edge', 'both'),
      ('mode', 'unknown'),
    ]) {
      final json = scopeJson();
      (json['initialSettings'] as Map<String, dynamic>)[key] = value;
      expect(() => LessonBlock.fromJson(json), throwsFormatException);
    }
  });
  test('unreachable trigger level is valid exercise input', () {
    final json = scopeJson();
    (json['initialSettings'] as Map<String, dynamic>)['triggerLevel'] = 6;
    expect(
      (LessonBlock.fromJson(
        json,
      ) as OscilloscopeLessonBlock).initialSettings.triggerLevel,
      6,
    );
  });
  test('old types and unknown type retain their existing parsing contract', () {
    expect(
      LessonBlock.fromJson({'type': 'text', 'title': 'T', 'content': 'C'}),
      isA<TextLessonBlock>(),
    );
    expect(
      LessonBlock.fromJson({
        'type': 'question',
        'question': '?',
        'answers': ['a'],
        'correctAnswer': 0,
        'explanation': 'ok',
      }),
      isA<QuestionLessonBlock>(),
    );
    expect(
      () => LessonBlock.fromJson({'type': 'unknown'}),
      throwsFormatException,
    );
  });
}
