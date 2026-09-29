import 'package:electrician/models/lesson.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Lesson.fromJson', () {
    test('parses normal lesson', () {
      final lesson = Lesson.fromJson({
        'id': 'electricity_01',
        'moduleId': 'stage_1',
        'order': 1,
        'title': 'Что такое электричество',
        'description': 'Основные понятия',
        'estimatedMinutes': 10,
        'completion': {
          'type': 'lesson',
        },
        'blocks': [
          {
            'type': 'text',
            'title': 'Введение',
            'content': 'Текст урока',
          },
          {
            'type': 'question',
            'question': 'Тестовый вопрос',
            'answers': [
              'Ответ 1',
              'Ответ 2',
            ],
            'correctAnswer': 0,
          },
        ],
      });

      expect(
        lesson.id,
        'electricity_01',
      );

      expect(
        lesson.moduleId,
        'stage_1',
      );

      expect(lesson.order, 1);

      expect(
        lesson.title,
        'Что такое электричество',
      );

      expect(
        lesson.description,
        'Основные понятия',
      );

      expect(
        lesson.estimatedMinutes,
        10,
      );

      expect(
        lesson.completion.isQuiz,
        false,
      );

      expect(
        lesson.blocks.length,
        2,
      );

      expect(
        lesson.blocks[0].type,
        'text',
      );

      expect(
        lesson.blocks[1].type,
        'question',
      );
    });

    test(
      'parses quiz completion settings',
      () {
        final lesson = Lesson.fromJson({
          'id': 'quiz_01',
          'moduleId': 'stage_1',
          'order': 8,
          'title': 'Итоговая проверка',
          'description': 'Проверка знаний',
          'estimatedMinutes': 20,
          'completion': {
            'type': 'quiz',
            'passingScore': 80,
          },
          'blocks': [],
        });

        expect(
          lesson.completion.isQuiz,
          true,
        );

        expect(
          lesson.completion.passingScore,
          80,
        );
      },
    );

    test(
      'uses default lesson completion when completion is absent',
      () {
        final lesson = Lesson.fromJson({
          'id': 'lesson_without_completion',
          'moduleId': 'stage_0',
          'order': 1,
          'title': 'Урок',
          'description': 'Описание',
          'estimatedMinutes': 5,
          'blocks': [],
        });

        expect(
          lesson.completion.isQuiz,
          false,
        );

        expect(
          lesson.completion.type,
          'lesson',
        );

        expect(
          lesson.completion.passingScore,
          isNull,
        );
      },
    );
  });
}