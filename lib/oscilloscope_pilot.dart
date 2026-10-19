import 'package:flutter/material.dart';

import 'pilots/oscilloscope_pilot_lesson.dart';
import 'screens/lesson_screen.dart';
import 'theme/app_theme.dart';

/// flutter run -t lib/oscilloscope_pilot.dart
void main() => runApp(const OscilloscopePilotApp());

class OscilloscopePilotApp extends StatelessWidget {
  const OscilloscopePilotApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Пилот осциллографа',
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    debugShowCheckedModeBanner: false,
    home: const _PilotHome(),
  );
}

class _PilotHome extends StatelessWidget {
  const _PilotHome();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Пилот осциллографа')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Изолированный учебный пилот. Основной курс не изменён. '
          'Все сигналы синтетические, подключения к автомобилю нет. '
          'Ответы и настройки действуют до выхода из урока. '
          'Кнопка завершения сохраняет только ID пилотного урока локально.',
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  LessonScreen(lesson: createOscilloscopePilotLesson()),
            ),
          ),
          child: const Text('Открыть пилот'),
        ),
      ],
    ),
  );
}
