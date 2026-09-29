class LessonBlock {
  final String type;

  // Обычный текстовый контент
  final String? title;
  final String? content;

  // Изображение
  final String? asset;
  final String? caption;

  // Обычный вопрос
  final String? question;
  final List<String>? answers;
  final int? correctAnswer;

  // Расчётная задача
  final double? correctValue;
  final double? tolerance;
  final String? unit;
  final String? hint;

  // Электрическая схема
  final String? circuitType;
  final bool? interactive;
  final bool? initiallyClosed;

  // Виртуальный мультиметр
  final String? multimeterMode;

  // Виртуальное измерение
  final String? measurementType;
  final double? sourceVoltage;

  // Измерение сопротивления
  final double? goodResistance;
  final bool? initiallyBroken;
  final bool? initiallyPowered;

  // Падение напряжения
  final double? faultVoltageDrop;
  final bool? initiallyLoaded;

  // Измерение тока
  final double? loadCurrent;
  final double? meterFuseRating;

  // Диагностические кейсы
  final String? faultType;
  final List<String>? diagnosisOptions;
  final int? correctDiagnosis;

  // Общее объяснение
  final String? explanation;

  LessonBlock({
    required this.type,
    this.title,
    this.content,
    this.asset,
    this.caption,
    this.question,
    this.answers,
    this.correctAnswer,
    this.correctValue,
    this.tolerance,
    this.unit,
    this.hint,
    this.circuitType,
    this.interactive,
    this.initiallyClosed,
    this.multimeterMode,
    this.measurementType,
    this.sourceVoltage,
    this.goodResistance,
    this.initiallyBroken,
    this.initiallyPowered,
    this.faultVoltageDrop,
    this.initiallyLoaded,
    this.loadCurrent,
    this.meterFuseRating,
    this.faultType,
    this.diagnosisOptions,
    this.correctDiagnosis,
    this.explanation,
  });

  factory LessonBlock.fromJson(
    Map<String, dynamic> json,
  ) {
    return LessonBlock(
      type: json['type'],
      title: json['title'],
      content: json['content'],
      asset: json['asset'],
      caption: json['caption'],
      question: json['question'],

      answers: json['answers'] != null
          ? List<String>.from(
              json['answers'],
            )
          : null,

      correctAnswer: json['correctAnswer'],

      correctValue:
          (json['correctValue'] as num?)
              ?.toDouble(),

      tolerance:
          (json['tolerance'] as num?)
              ?.toDouble(),

      unit: json['unit'],
      hint: json['hint'],

      circuitType: json['circuitType'],
      interactive: json['interactive'],
      initiallyClosed: json['initiallyClosed'],

      multimeterMode: json['multimeterMode'],

      measurementType:
          json['measurementType'],

      sourceVoltage:
          (json['sourceVoltage'] as num?)
              ?.toDouble(),

      goodResistance:
          (json['goodResistance'] as num?)
              ?.toDouble(),

      initiallyBroken:
          json['initiallyBroken'],

      initiallyPowered:
          json['initiallyPowered'],

      faultVoltageDrop:
          (json['faultVoltageDrop'] as num?)
              ?.toDouble(),

      initiallyLoaded:
          json['initiallyLoaded'],

      loadCurrent:
          (json['loadCurrent'] as num?)
              ?.toDouble(),

      meterFuseRating:
          (json['meterFuseRating'] as num?)
              ?.toDouble(),

      faultType: json['faultType'],

      diagnosisOptions:
          json['diagnosisOptions'] != null
              ? List<String>.from(
                  json['diagnosisOptions'],
                )
              : null,

      correctDiagnosis:
          json['correctDiagnosis'],

      explanation: json['explanation'],
    );
  }
}