import '../models/lesson.dart';
import '../models/lesson_block.dart';
import '../models/lesson_completion.dart';
import '../simulation/oscilloscope_simulation.dart';
import '../simulation/scope_signal.dart';

/// Isolated fixture. Never registered in the course or module navigation.
Lesson createOscilloscopePilotLesson() => Lesson(
  id: 'pilot_oscilloscope_mvp',
  moduleId: 'pilot',
  order: 1,
  title: 'Пилот: учебный осциллограф',
  description: 'Масштабы, запуск и интерпретация синтетических сигналов.',
  estimatedMinutes: 15,
  completion: LessonCompletion(type: 'lesson'),
  blocks: [
    const TextLessonBlock(
      title: 'Напряжение во времени',
      content:
          'Все сигналы синтетические, относительно N = 0 V; вход идеальный '
          'высокоомный, связь по постоянному току. Экран не связан с настоящим '
          'прибором. Изменение масштаба не изменяет источник. '
          'В каждом задании можно исследовать другие сигналы, затем вернуться '
          'к указанному. Изменение проверенных настроек снимает ответ.',
    ),
    OscilloscopeLessonBlock(
      title: '1. Масштаб напряжения',
      question:
          'Для синусоиды выберите V/div и центр так, чтобы размах занимал '
          '50–90% высоты сетки, без обрезания. Сначала восстановите вид сигнала.',
      scenario: ScopeScenario.sine,
      exercise: ScopeExercise.voltageScale,
      initialSettings: ScopeSettings(voltsPerDiv: 0.5, centerVoltage: 0),
    ),
    OscilloscopeLessonBlock(
      title: '2. Масштаб времени',
      question:
          'Для прямоугольных импульсов покажите 2–5 полных периодов в окне '
          'без обрезания по напряжению. Используйте ms/div.',
      scenario: ScopeScenario.square,
      exercise: ScopeExercise.timeScale,
      initialSettings: ScopeSettings(millisecondsPerDiv: 1),
    ),
    OscilloscopeLessonBlock(
      title: '3. Уровень триггера',
      question:
          'Для ШИМ A найдите пересекаемый уровень. Нужны Normal, '
          'положительный фронт, синхронизация и отсутствие обрезания. '
          'После проверки сравните ШИМ A и ШИМ B при одинаковых масштабах: '
          'как изменяется длительность высокого уровня?',
      scenario: ScopeScenario.pwm30,
      exercise: ScopeExercise.trigger,
      initialSettings: ScopeSettings(triggerLevel: 6),
    ),
    const TextLessonBlock(
      title: 'Чтение шкалы',
      content:
          'Верните прямоугольные импульсы в любом тренажёре выше. '
          'При 2 ms/div расстояние между одинаковыми фронтами — 5 делений. '
          'Определите T, затем переведите его в секунды для f = 1/T. '
          'Проверка настройки и параметры генератора не заменяют чтение шкалы.',
    ),
    const CalculationLessonBlock(
      question: 'Один период занимает 5 делений при 2 ms/div. Чему равен T?',
      correctValue: 10,
      tolerance: 0.01,
      unit: 'ms',
      hint: 'Умножьте число делений на время одного деления.',
      explanation: 'T = 5 × 2 = 10 ms = 0,010 s.',
    ),
    const CalculationLessonBlock(
      question: 'По шкале T = 10 ms. Чему равна частота?',
      correctValue: 100,
      tolerance: 0.1,
      unit: 'Hz',
      hint: 'Переведите ms в s, затем f = 1/T.',
      explanation: 'f = 1/0,010 = 100 Hz.',
    ),
    const QuestionLessonBlock(
      question:
          'Сравните ШИМ A и B в тренажёре: T одинаков, '
          'высокий уровень у B длится дольше. Что изменилось?',
      answers: [
        'Увеличилось заполнение высокого уровня, частота прежняя',
        'Увеличилась частота, заполнение прежнее',
        'Одинаковый период означает одинаковую форму и среднее напряжение',
      ],
      correctAnswer: 0,
      explanation:
          'A: 0/5 V, T=10 ms, tHigh=3 ms, DHigh=30%, среднее 1,5 V. '
          'B: T=10 ms, tHigh=6 ms, DHigh=60%, среднее 3 V. '
          'Оба сигнала 100 Hz. Это параметры идеальной модели, не вывод о токе нагрузки.',
    ),
  ],
);
