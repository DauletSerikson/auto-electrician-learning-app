import 'package:electrician/models/lesson_block.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LessonBlock.fromJson', () {
    test('parses text block', () {
      final block = LessonBlock.fromJson({
        'type': 'text',
        'title': 'Напряжение',
        'content': 'Напряжение измеряется в вольтах.',
      });

      expect(block.type, 'text');
      expect(block.title, 'Напряжение');
      expect(
        block.content,
        'Напряжение измеряется в вольтах.',
      );
    });

    test('parses question block', () {
      final block = LessonBlock.fromJson({
        'type': 'question',
        'question': 'Что измеряется в вольтах?',
        'answers': [
          'Напряжение',
          'Ток',
          'Сопротивление',
        ],
        'correctAnswer': 0,
        'explanation': 'Вольт — единица напряжения.',
      });

      expect(block.type, 'question');

      expect(
        block.question,
        'Что измеряется в вольтах?',
      );

      expect(
        block.answers,
        [
          'Напряжение',
          'Ток',
          'Сопротивление',
        ],
      );

      expect(block.correctAnswer, 0);

      expect(
        block.explanation,
        'Вольт — единица напряжения.',
      );
    });

    test('parses calculation numbers as doubles', () {
      final block = LessonBlock.fromJson({
        'type': 'calculation',
        'correctValue': 12,
        'tolerance': 0.5,
        'unit': 'V',
      });

      expect(block.correctValue, 12.0);
      expect(block.tolerance, 0.5);
      expect(block.unit, 'V');
    });

    test('parses voltage drop block', () {
      final block = LessonBlock.fromJson({
        'type': 'voltageDrop',
        'sourceVoltage': 12.6,
        'faultVoltageDrop': 4,
        'initiallyLoaded': true,
      });

      expect(block.type, 'voltageDrop');
      expect(block.sourceVoltage, 12.6);
      expect(block.faultVoltageDrop, 4.0);
      expect(block.initiallyLoaded, true);
    });

    test('parses current measurement block', () {
      final block = LessonBlock.fromJson({
        'type': 'currentMeasurement',
        'sourceVoltage': 12.6,
        'loadCurrent': 2,
        'meterFuseRating': 10,
      });

      expect(
        block.type,
        'currentMeasurement',
      );

      expect(block.sourceVoltage, 12.6);
      expect(block.loadCurrent, 2.0);
      expect(block.meterFuseRating, 10.0);
    });

    test('parses diagnostic choice block', () {
      final block = LessonBlock.fromJson({
        'type': 'diagnosticChoice',
        'faultType': 'groundOpen',
        'diagnosisOptions': [
          'Перегорел предохранитель',
          'Обрыв плюсового провода',
          'Обрыв массы лампы',
          'Неисправна лампа',
        ],
        'correctDiagnosis': 2,
      });

      expect(
        block.type,
        'diagnosticChoice',
      );

      expect(
        block.faultType,
        'groundOpen',
      );

      expect(
        block.diagnosisOptions,
        [
          'Перегорел предохранитель',
          'Обрыв плюсового провода',
          'Обрыв массы лампы',
          'Неисправна лампа',
        ],
      );

      expect(
        block.correctDiagnosis,
        2,
      );
    });

    test(
      'keeps unrelated optional fields null',
      () {
        final block = LessonBlock.fromJson({
          'type': 'text',
          'content': 'Обычный текст.',
        });

        expect(block.question, isNull);
        expect(block.answers, isNull);
        expect(block.correctValue, isNull);
        expect(block.sourceVoltage, isNull);
        expect(block.faultType, isNull);
        expect(
          block.diagnosisOptions,
          isNull,
        );
      },
    );
  });
}