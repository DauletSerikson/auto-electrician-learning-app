import 'package:electrician/models/lesson_block.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LessonBlock.fromJson', () {
    test('creates TextLessonBlock', () {
      final block = LessonBlock.fromJson({
        'type': 'text',
        'title': 'Напряжение',
        'content': 'Напряжение измеряется в вольтах.',
      });

      expect(block, isA<TextLessonBlock>());
      expect(block.type, 'text');
      expect(block.title, 'Напряжение');
      expect(block.content, 'Напряжение измеряется в вольтах.');
    });

    test('creates RememberLessonBlock', () {
      final block = LessonBlock.fromJson({
        'type': 'remember',
        'content': 'Запомни это правило.',
      });

      expect(block, isA<RememberLessonBlock>());
      expect(block.type, 'remember');
      expect(block.content, 'Запомни это правило.');
    });

    test('creates WarningLessonBlock', () {
      final block = LessonBlock.fromJson({
        'type': 'warning',
        'title': 'Внимание',
        'content': 'Не допускай короткого замыкания.',
      });

      expect(block, isA<WarningLessonBlock>());
      expect(block.type, 'warning');
      expect(block.title, 'Внимание');
    });

    test('creates ImageLessonBlock', () {
      final block = LessonBlock.fromJson({
        'type': 'image',
        'asset': 'assets/images/battery.jpg',
        'caption': 'Автомобильный аккумулятор',
      });

      expect(block, isA<ImageLessonBlock>());
      expect(block.asset, 'assets/images/battery.jpg');
      expect(block.caption, 'Автомобильный аккумулятор');
    });

    test('creates QuestionLessonBlock', () {
      final block = LessonBlock.fromJson({
        'type': 'question',
        'question': 'Что измеряется в вольтах?',
        'answers': ['Напряжение', 'Ток', 'Сопротивление'],
        'correctAnswer': 0,
        'explanation': 'Вольт — единица напряжения.',
      });

      expect(block, isA<QuestionLessonBlock>());

      expect(block.question, 'Что измеряется в вольтах?');

      expect(block.answers, ['Напряжение', 'Ток', 'Сопротивление']);

      expect(block.correctAnswer, 0);

      expect(block.explanation, 'Вольт — единица напряжения.');
    });

    test('creates CalculationLessonBlock', () {
      final block = LessonBlock.fromJson({
        'type': 'calculation',
        'question': '12 В / 6 Ом = ?',
        'correctValue': 2,
        'tolerance': 0.01,
        'unit': 'A',
        'hint': 'Используй закон Ома.',
        'explanation': 'I = U / R = 2 A.',
      });

      expect(block, isA<CalculationLessonBlock>());

      expect(block.correctValue, 2.0);
      expect(block.tolerance, 0.01);
      expect(block.unit, 'A');
    });

    test('creates CircuitLessonBlock', () {
      final block = LessonBlock.fromJson({
        'type': 'circuit',
        'circuitType': 'simpleLamp',
        'title': 'Простейшая цепь',
        'interactive': true,
        'initiallyClosed': false,
        'caption': 'Учебная схема.',
      });

      expect(block, isA<CircuitLessonBlock>());
      expect(block.circuitType, 'simpleLamp');
      expect(block.interactive, true);
      expect(block.initiallyClosed, false);
    });

    test('creates MultimeterLessonBlock', () {
      final block = LessonBlock.fromJson({
        'type': 'multimeter',
        'title': 'Виртуальный мультиметр',
        'interactive': true,
        'multimeterMode': 'off',
        'caption': 'Выбери режим.',
      });

      expect(block, isA<MultimeterLessonBlock>());

      expect(block.multimeterMode, 'off');
      expect(block.interactive, true);
    });

    test('creates BatteryVoltageMeasurementLessonBlock', () {
      final block = LessonBlock.fromJson({
        'type': 'measurement',
        'measurementType': 'batteryVoltage',
        'title': 'Напряжение АКБ',
        'question': 'Измерь напряжение.',
        'sourceVoltage': 12.6,
      });

      expect(block, isA<BatteryVoltageMeasurementLessonBlock>());

      expect(block.measurementType, 'batteryVoltage');

      expect(block.sourceVoltage, 12.6);
    });

    test('creates WireResistanceMeasurementLessonBlock', () {
      final block = LessonBlock.fromJson({
        'type': 'measurement',
        'measurementType': 'wireResistance',
        'title': 'Проверка провода',
        'question': 'Измерь сопротивление.',
        'goodResistance': 0.3,
        'initiallyBroken': false,
        'initiallyPowered': false,
      });

      expect(block, isA<WireResistanceMeasurementLessonBlock>());

      expect(block.measurementType, 'wireResistance');

      expect(block.goodResistance, 0.3);
      expect(block.initiallyBroken, false);
      expect(block.initiallyPowered, false);
    });

    test('creates WireContinuityMeasurementLessonBlock', () {
      final block = LessonBlock.fromJson({
        'type': 'measurement',
        'measurementType': 'wireContinuity',
        'title': 'Прозвонка провода',
        'question': 'Прозвони провод.',
        'goodResistance': 0.3,
        'initiallyBroken': true,
        'initiallyPowered': false,
      });

      expect(block, isA<WireContinuityMeasurementLessonBlock>());

      expect(block.measurementType, 'wireContinuity');
    });

    test('creates ResistanceMeasurementLessonBlock', () {
      final block = LessonBlock.fromJson({
        'type': 'measurement',
        'measurementType': 'resistance',
        'title': 'Проверка сопротивления',
        'question': 'Измерь сопротивление.',
        'goodResistance': 0.3,
        'initiallyBroken': false,
        'initiallyPowered': true,
      });

      expect(block, isA<ResistanceMeasurementLessonBlock>());

      expect(block.measurementType, 'resistance');

      expect(block.initiallyPowered, true);
    });

    test('creates VoltageDropLessonBlock', () {
      final block = LessonBlock.fromJson({
        'type': 'voltageDrop',
        'title': 'Падение напряжения',
        'question': 'Найди потерю напряжения.',
        'sourceVoltage': 12.6,
        'faultVoltageDrop': 4,
        'initiallyLoaded': true,
      });

      expect(block, isA<VoltageDropLessonBlock>());

      expect(block.sourceVoltage, 12.6);
      expect(block.faultVoltageDrop, 4.0);
      expect(block.initiallyLoaded, true);
    });

    test('creates CurrentMeasurementLessonBlock', () {
      final block = LessonBlock.fromJson({
        'type': 'currentMeasurement',
        'title': 'Измерение тока',
        'question': 'Измерь ток лампы.',
        'sourceVoltage': 12.6,
        'loadCurrent': 2,
        'meterFuseRating': 10,
      });

      expect(block, isA<CurrentMeasurementLessonBlock>());

      expect(block.sourceVoltage, 12.6);
      expect(block.loadCurrent, 2.0);
      expect(block.meterFuseRating, 10.0);
    });

    test('creates DiagnosticCaseLessonBlock', () {
      final block = LessonBlock.fromJson({
        'type': 'diagnosticCase',
        'title': 'Диагностика',
        'question': 'Найди неисправность.',
        'sourceVoltage': 12.6,
        'faultType': 'positiveWireOpen',
      });

      expect(block, isA<DiagnosticCaseLessonBlock>());

      expect(block.faultType, 'positiveWireOpen');
    });

    test('creates DiagnosticChoiceLessonBlock', () {
      final block = LessonBlock.fromJson({
        'type': 'diagnosticChoice',
        'title': 'Поставь диагноз',
        'question': 'Выбери неисправность.',
        'sourceVoltage': 12.6,
        'faultType': 'groundOpen',
        'diagnosisOptions': [
          'Перегорел предохранитель',
          'Обрыв плюсового провода',
          'Обрыв массы лампы',
          'Неисправна лампа',
        ],
        'correctDiagnosis': 2,
        'explanation': 'Неисправна масса.',
      });

      expect(block, isA<DiagnosticChoiceLessonBlock>());

      expect(block.faultType, 'groundOpen');

      expect(block.diagnosisOptions, [
        'Перегорел предохранитель',
        'Обрыв плюсового провода',
        'Обрыв массы лампы',
        'Неисправна лампа',
      ]);

      expect(block.correctDiagnosis, 2);
    });
  });

  group('LessonBlock validation', () {
    test('rejects unknown block type', () {
      expect(
        () => LessonBlock.fromJson({'type': 'unknown'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects missing required field', () {
      expect(
        () => LessonBlock.fromJson({'type': 'text', 'title': 'Заголовок'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects invalid question answer index', () {
      expect(
        () => LessonBlock.fromJson({
          'type': 'question',
          'question': 'Вопрос',
          'answers': ['Первый', 'Второй'],
          'correctAnswer': 5,
          'explanation': 'Объяснение',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects unknown measurement type', () {
      expect(
        () => LessonBlock.fromJson({
          'type': 'measurement',
          'measurementType': 'unknown',
          'title': 'Измерение',
          'question': 'Выполни измерение.',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('keeps unrelated compatibility fields null', () {
      final block = LessonBlock.fromJson({
        'type': 'text',
        'title': 'Обычный текст',
        'content': 'Содержимое.',
      });

      expect(block.question, isNull);
      expect(block.answers, isNull);
      expect(block.correctValue, isNull);
      expect(block.sourceVoltage, isNull);
      expect(block.faultType, isNull);
      expect(block.diagnosisOptions, isNull);
    });
  });
}
