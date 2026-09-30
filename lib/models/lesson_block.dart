abstract class LessonBlock {
  const LessonBlock();

  String get type;

  // Compatibility getters.
  //
  // Они временно сохраняют совместимость существующего UI с прежней
  // универсальной моделью LessonBlock. По мере миграции виджетов на
  // конкретные типы блоков эти getters будут удалены.
  String? get title => null;
  String? get content => null;

  String? get asset => null;
  String? get caption => null;

  String? get question => null;
  List<String>? get answers => null;
  int? get correctAnswer => null;

  double? get correctValue => null;
  double? get tolerance => null;
  String? get unit => null;
  String? get hint => null;

  String? get circuitType => null;
  bool? get interactive => null;
  bool? get initiallyClosed => null;

  String? get multimeterMode => null;

  String? get measurementType => null;
  double? get sourceVoltage => null;

  double? get goodResistance => null;
  bool? get initiallyBroken => null;
  bool? get initiallyPowered => null;

  double? get faultVoltageDrop => null;
  bool? get initiallyLoaded => null;

  double? get loadCurrent => null;
  double? get meterFuseRating => null;

  String? get faultType => null;
  List<String>? get diagnosisOptions => null;
  int? get correctDiagnosis => null;

  String? get explanation => null;

  factory LessonBlock.fromJson(Map<String, dynamic> json) {
    final type = _requiredString(json, 'type');

    return switch (type) {
      'text' => TextLessonBlock.fromJson(json),
      'remember' => RememberLessonBlock.fromJson(json),
      'warning' => WarningLessonBlock.fromJson(json),
      'image' => ImageLessonBlock.fromJson(json),
      'question' => QuestionLessonBlock.fromJson(json),
      'calculation' => CalculationLessonBlock.fromJson(json),
      'circuit' => CircuitLessonBlock.fromJson(json),
      'multimeter' => MultimeterLessonBlock.fromJson(json),
      'measurement' => MeasurementLessonBlock.fromJson(json),
      'voltageDrop' => VoltageDropLessonBlock.fromJson(json),
      'currentMeasurement' => CurrentMeasurementLessonBlock.fromJson(json),
      'diagnosticCase' => DiagnosticCaseLessonBlock.fromJson(json),
      'diagnosticChoice' => DiagnosticChoiceLessonBlock.fromJson(json),
      _ => throw FormatException('Unknown lesson block type: $type'),
    };
  }
}

final class TextLessonBlock extends LessonBlock {
  @override
  final String title;

  @override
  final String content;

  const TextLessonBlock({required this.title, required this.content});

  @override
  String get type => 'text';

  factory TextLessonBlock.fromJson(Map<String, dynamic> json) {
    return TextLessonBlock(
      title: _requiredString(json, 'title'),
      content: _requiredString(json, 'content'),
    );
  }
}

final class RememberLessonBlock extends LessonBlock {
  @override
  final String content;

  const RememberLessonBlock({required this.content});

  @override
  String get type => 'remember';

  factory RememberLessonBlock.fromJson(Map<String, dynamic> json) {
    return RememberLessonBlock(content: _requiredString(json, 'content'));
  }
}

final class WarningLessonBlock extends LessonBlock {
  @override
  final String title;

  @override
  final String content;

  const WarningLessonBlock({required this.title, required this.content});

  @override
  String get type => 'warning';

  factory WarningLessonBlock.fromJson(Map<String, dynamic> json) {
    return WarningLessonBlock(
      title: _requiredString(json, 'title'),
      content: _requiredString(json, 'content'),
    );
  }
}

final class ImageLessonBlock extends LessonBlock {
  @override
  final String asset;

  @override
  final String caption;

  const ImageLessonBlock({required this.asset, required this.caption});

  @override
  String get type => 'image';

  factory ImageLessonBlock.fromJson(Map<String, dynamic> json) {
    return ImageLessonBlock(
      asset: _requiredString(json, 'asset'),
      caption: _requiredString(json, 'caption'),
    );
  }
}

final class QuestionLessonBlock extends LessonBlock {
  @override
  final String question;

  @override
  final List<String> answers;

  @override
  final int correctAnswer;

  @override
  final String explanation;

  const QuestionLessonBlock({
    required this.question,
    required this.answers,
    required this.correctAnswer,
    required this.explanation,
  });

  @override
  String get type => 'question';

  factory QuestionLessonBlock.fromJson(Map<String, dynamic> json) {
    final answers = _requiredStringList(json, 'answers');

    final correctAnswer = _requiredInt(json, 'correctAnswer');

    if (answers.isEmpty) {
      throw const FormatException(
        'Question block must contain at least one answer.',
      );
    }

    if (correctAnswer < 0 || correctAnswer >= answers.length) {
      throw FormatException(
        'correctAnswer index $correctAnswer is outside '
        'the answers list.',
      );
    }

    return QuestionLessonBlock(
      question: _requiredString(json, 'question'),
      answers: answers,
      correctAnswer: correctAnswer,
      explanation: _requiredString(json, 'explanation'),
    );
  }
}

final class CalculationLessonBlock extends LessonBlock {
  @override
  final String question;

  @override
  final double correctValue;

  @override
  final double tolerance;

  @override
  final String unit;

  @override
  final String hint;

  @override
  final String explanation;

  const CalculationLessonBlock({
    required this.question,
    required this.correctValue,
    required this.tolerance,
    required this.unit,
    required this.hint,
    required this.explanation,
  });

  @override
  String get type => 'calculation';

  factory CalculationLessonBlock.fromJson(Map<String, dynamic> json) {
    return CalculationLessonBlock(
      question: _requiredString(json, 'question'),
      correctValue: _requiredDouble(json, 'correctValue'),
      tolerance: _requiredDouble(json, 'tolerance'),
      unit: _requiredString(json, 'unit'),
      hint: _requiredString(json, 'hint'),
      explanation: _requiredString(json, 'explanation'),
    );
  }
}

final class CircuitLessonBlock extends LessonBlock {
  @override
  final String circuitType;

  @override
  final String title;

  @override
  final bool interactive;

  @override
  final bool? initiallyClosed;

  @override
  final String caption;

  const CircuitLessonBlock({
    required this.circuitType,
    required this.title,
    required this.interactive,
    required this.caption,
    this.initiallyClosed,
  });

  @override
  String get type => 'circuit';

  factory CircuitLessonBlock.fromJson(Map<String, dynamic> json) {
    return CircuitLessonBlock(
      circuitType: _requiredString(json, 'circuitType'),
      title: _requiredString(json, 'title'),
      interactive: _requiredBool(json, 'interactive'),
      initiallyClosed: _optionalBool(json, 'initiallyClosed'),
      caption: _requiredString(json, 'caption'),
    );
  }
}

final class MultimeterLessonBlock extends LessonBlock {
  @override
  final String title;

  @override
  final bool interactive;

  @override
  final String multimeterMode;

  @override
  final String caption;

  const MultimeterLessonBlock({
    required this.title,
    required this.interactive,
    required this.multimeterMode,
    required this.caption,
  });

  @override
  String get type => 'multimeter';

  factory MultimeterLessonBlock.fromJson(Map<String, dynamic> json) {
    return MultimeterLessonBlock(
      title: _requiredString(json, 'title'),
      interactive: _requiredBool(json, 'interactive'),
      multimeterMode: _requiredString(json, 'multimeterMode'),
      caption: _requiredString(json, 'caption'),
    );
  }
}

abstract class MeasurementLessonBlock extends LessonBlock {
  const MeasurementLessonBlock();

  @override
  String get type => 'measurement';

  @override
  String get measurementType;

  @override
  String get title;

  @override
  String get question;

  factory MeasurementLessonBlock.fromJson(Map<String, dynamic> json) {
    final measurementType = _requiredString(json, 'measurementType');

    return switch (measurementType) {
      'batteryVoltage' => BatteryVoltageMeasurementLessonBlock.fromJson(json),
      'wireResistance' => WireResistanceMeasurementLessonBlock.fromJson(json),
      'wireContinuity' => WireContinuityMeasurementLessonBlock.fromJson(json),
      'resistance' => ResistanceMeasurementLessonBlock.fromJson(json),
      _ => throw FormatException('Unknown measurement type: $measurementType'),
    };
  }
}

final class BatteryVoltageMeasurementLessonBlock
    extends MeasurementLessonBlock {
  @override
  final String title;

  @override
  final String question;

  @override
  final double sourceVoltage;

  const BatteryVoltageMeasurementLessonBlock({
    required this.title,
    required this.question,
    required this.sourceVoltage,
  });

  @override
  String get measurementType => 'batteryVoltage';

  factory BatteryVoltageMeasurementLessonBlock.fromJson(
    Map<String, dynamic> json,
  ) {
    return BatteryVoltageMeasurementLessonBlock(
      title: _requiredString(json, 'title'),
      question: _requiredString(json, 'question'),
      sourceVoltage: _requiredDouble(json, 'sourceVoltage'),
    );
  }
}

abstract class ConductorMeasurementLessonBlock extends MeasurementLessonBlock {
  @override
  final String title;

  @override
  final String question;

  @override
  final double goodResistance;

  @override
  final bool initiallyBroken;

  @override
  final bool initiallyPowered;

  const ConductorMeasurementLessonBlock({
    required this.title,
    required this.question,
    required this.goodResistance,
    required this.initiallyBroken,
    required this.initiallyPowered,
  });
}

final class WireResistanceMeasurementLessonBlock
    extends ConductorMeasurementLessonBlock {
  const WireResistanceMeasurementLessonBlock({
    required super.title,
    required super.question,
    required super.goodResistance,
    required super.initiallyBroken,
    required super.initiallyPowered,
  });

  @override
  String get measurementType => 'wireResistance';

  factory WireResistanceMeasurementLessonBlock.fromJson(
    Map<String, dynamic> json,
  ) {
    return WireResistanceMeasurementLessonBlock(
      title: _requiredString(json, 'title'),
      question: _requiredString(json, 'question'),
      goodResistance: _requiredDouble(json, 'goodResistance'),
      initiallyBroken: _requiredBool(json, 'initiallyBroken'),
      initiallyPowered: _requiredBool(json, 'initiallyPowered'),
    );
  }
}

final class WireContinuityMeasurementLessonBlock
    extends ConductorMeasurementLessonBlock {
  const WireContinuityMeasurementLessonBlock({
    required super.title,
    required super.question,
    required super.goodResistance,
    required super.initiallyBroken,
    required super.initiallyPowered,
  });

  @override
  String get measurementType => 'wireContinuity';

  factory WireContinuityMeasurementLessonBlock.fromJson(
    Map<String, dynamic> json,
  ) {
    return WireContinuityMeasurementLessonBlock(
      title: _requiredString(json, 'title'),
      question: _requiredString(json, 'question'),
      goodResistance: _requiredDouble(json, 'goodResistance'),
      initiallyBroken: _requiredBool(json, 'initiallyBroken'),
      initiallyPowered: _requiredBool(json, 'initiallyPowered'),
    );
  }
}

final class ResistanceMeasurementLessonBlock
    extends ConductorMeasurementLessonBlock {
  const ResistanceMeasurementLessonBlock({
    required super.title,
    required super.question,
    required super.goodResistance,
    required super.initiallyBroken,
    required super.initiallyPowered,
  });

  @override
  String get measurementType => 'resistance';

  factory ResistanceMeasurementLessonBlock.fromJson(Map<String, dynamic> json) {
    return ResistanceMeasurementLessonBlock(
      title: _requiredString(json, 'title'),
      question: _requiredString(json, 'question'),
      goodResistance: _requiredDouble(json, 'goodResistance'),
      initiallyBroken: _requiredBool(json, 'initiallyBroken'),
      initiallyPowered: _requiredBool(json, 'initiallyPowered'),
    );
  }
}

final class VoltageDropLessonBlock extends LessonBlock {
  @override
  final String title;

  @override
  final String question;

  @override
  final double sourceVoltage;

  @override
  final double faultVoltageDrop;

  @override
  final bool initiallyLoaded;

  const VoltageDropLessonBlock({
    required this.title,
    required this.question,
    required this.sourceVoltage,
    required this.faultVoltageDrop,
    required this.initiallyLoaded,
  });

  @override
  String get type => 'voltageDrop';

  factory VoltageDropLessonBlock.fromJson(Map<String, dynamic> json) {
    return VoltageDropLessonBlock(
      title: _requiredString(json, 'title'),
      question: _requiredString(json, 'question'),
      sourceVoltage: _requiredDouble(json, 'sourceVoltage'),
      faultVoltageDrop: _requiredDouble(json, 'faultVoltageDrop'),
      initiallyLoaded: _requiredBool(json, 'initiallyLoaded'),
    );
  }
}

final class CurrentMeasurementLessonBlock extends LessonBlock {
  @override
  final String title;

  @override
  final String question;

  @override
  final double sourceVoltage;

  @override
  final double loadCurrent;

  @override
  final double meterFuseRating;

  const CurrentMeasurementLessonBlock({
    required this.title,
    required this.question,
    required this.sourceVoltage,
    required this.loadCurrent,
    required this.meterFuseRating,
  });

  @override
  String get type => 'currentMeasurement';

  factory CurrentMeasurementLessonBlock.fromJson(Map<String, dynamic> json) {
    return CurrentMeasurementLessonBlock(
      title: _requiredString(json, 'title'),
      question: _requiredString(json, 'question'),
      sourceVoltage: _requiredDouble(json, 'sourceVoltage'),
      loadCurrent: _requiredDouble(json, 'loadCurrent'),
      meterFuseRating: _requiredDouble(json, 'meterFuseRating'),
    );
  }
}

final class DiagnosticCaseLessonBlock extends LessonBlock {
  @override
  final String title;

  @override
  final String question;

  @override
  final double sourceVoltage;

  @override
  final String faultType;

  const DiagnosticCaseLessonBlock({
    required this.title,
    required this.question,
    required this.sourceVoltage,
    required this.faultType,
  });

  @override
  String get type => 'diagnosticCase';

  factory DiagnosticCaseLessonBlock.fromJson(Map<String, dynamic> json) {
    return DiagnosticCaseLessonBlock(
      title: _requiredString(json, 'title'),
      question: _requiredString(json, 'question'),
      sourceVoltage: _requiredDouble(json, 'sourceVoltage'),
      faultType: _requiredString(json, 'faultType'),
    );
  }
}

final class DiagnosticChoiceLessonBlock extends LessonBlock {
  @override
  final String title;

  @override
  final String question;

  @override
  final double sourceVoltage;

  @override
  final String faultType;

  @override
  final List<String> diagnosisOptions;

  @override
  final int correctDiagnosis;

  @override
  final String explanation;

  const DiagnosticChoiceLessonBlock({
    required this.title,
    required this.question,
    required this.sourceVoltage,
    required this.faultType,
    required this.diagnosisOptions,
    required this.correctDiagnosis,
    required this.explanation,
  });

  @override
  String get type => 'diagnosticChoice';

  factory DiagnosticChoiceLessonBlock.fromJson(Map<String, dynamic> json) {
    final diagnosisOptions = _requiredStringList(json, 'diagnosisOptions');

    final correctDiagnosis = _requiredInt(json, 'correctDiagnosis');

    if (diagnosisOptions.isEmpty) {
      throw const FormatException(
        'Diagnostic choice block must contain '
        'at least one diagnosis option.',
      );
    }

    if (correctDiagnosis < 0 || correctDiagnosis >= diagnosisOptions.length) {
      throw FormatException(
        'correctDiagnosis index $correctDiagnosis is outside '
        'the diagnosisOptions list.',
      );
    }

    return DiagnosticChoiceLessonBlock(
      title: _requiredString(json, 'title'),
      question: _requiredString(json, 'question'),
      sourceVoltage: _requiredDouble(json, 'sourceVoltage'),
      faultType: _requiredString(json, 'faultType'),
      diagnosisOptions: diagnosisOptions,
      correctDiagnosis: correctDiagnosis,
      explanation: _requiredString(json, 'explanation'),
    );
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];

  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Expected non-empty String for "$key".');
  }

  return value;
}

double _requiredDouble(Map<String, dynamic> json, String key) {
  final value = json[key];

  if (value is! num) {
    throw FormatException('Expected number for "$key".');
  }

  return value.toDouble();
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];

  if (value is! int) {
    throw FormatException('Expected int for "$key".');
  }

  return value;
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];

  if (value is! bool) {
    throw FormatException('Expected bool for "$key".');
  }

  return value;
}

bool? _optionalBool(Map<String, dynamic> json, String key) {
  final value = json[key];

  if (value == null) {
    return null;
  }

  if (value is! bool) {
    throw FormatException('Expected bool for "$key".');
  }

  return value;
}

List<String> _requiredStringList(Map<String, dynamic> json, String key) {
  final value = json[key];

  if (value is! List) {
    throw FormatException('Expected List for "$key".');
  }

  if (value.any((item) => item is! String)) {
    throw FormatException('Expected List<String> for "$key".');
  }

  return List<String>.from(value);
}
