import 'package:flutter/material.dart';

import '../../models/lesson_block.dart';
import '../quiz_task_controller.dart';
import '../../simulation/oscilloscope_simulation.dart';
import '../../simulation/scope_signal.dart';
import 'scope_display.dart';

class OscilloscopeBlock extends StatefulWidget {
  final OscilloscopeLessonBlock block;
  final ValueChanged<bool> onAnswered;
  final VoidCallback onRetry;

  final QuizTaskController? quizTask;

  const OscilloscopeBlock({
    super.key,
    required this.block,
    required this.onAnswered,
    required this.onRetry,
    this.quizTask,
  });

  @override
  State<OscilloscopeBlock> createState() => _OscilloscopeBlockState();
}

class _OscilloscopeBlockState extends State<OscilloscopeBlock>
    with QuizTaskState<OscilloscopeBlock> {
  @override
  QuizTaskController? get quizTask => widget.quizTask;
  static const simulation = OscilloscopeSimulation();
  late ScopeScenario selected;
  late ScopeSettings settings;
  late ScopeCapture capture;
  bool? correct;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(covariant OscilloscopeBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block != widget.block) _initialize();
  }

  void _initialize() {
    selected = widget.block.scenario;
    settings = widget.block.initialSettings;
    correct = null;
    capture = simulation.capture(selected.signal, settings);
  }

  void change({ScopeSettings? next, ScopeScenario? scenario}) {
    final hadAnswer = correct != null;
    setState(() {
      settings = next ?? settings;
      selected = scenario ?? selected;
      correct = null;
      capture = simulation.capture(selected.signal, settings);
    });
    if (hadAnswer) widget.onRetry();
  }

  void reset() {
    setState(_initialize);
    widget.onRetry();
  }

  void check() {
    final result = simulation.evaluate(
      exercise: widget.block.exercise,
      target: widget.block.scenario,
      selected: selected,
      capture: capture,
    );
    setState(() => correct = result);
    widget.onAnswered(result);
  }

  String get status => switch (capture.status) {
    ScopeCaptureStatus.triggered =>
      settings.mode == ScopeTriggerMode.single
          ? 'Single: событие найдено, запись остановлена.'
          : 'Синхронизация: событие найдено.',
    ScopeCaptureStatus.freeRunning => 'Автозапуск без синхронизации.',
    ScopeCaptureStatus.waiting => 'Ожидание: пересечение уровня не найдено.',
    ScopeCaptureStatus.armed => 'Single: захвата нет. Нажмите «Захватить».',
  };

  @override
  Widget build(BuildContext context) {
    quizTask?.bind(submit: check, ready: () => quizTask!.interacted);
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.block.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Учебный осциллограф. Синтетические сигналы относительно N = 0 V. '
              'Тренажёр не подключается к автомобилю.',
            ),
            const SizedBox(height: 8),
            Text(widget.block.question),
            const SizedBox(height: 12),
            Semantics(
              label:
                  'Осциллограмма напряжения. $status '
                  '${settings.voltsPerDiv} V на деление, '
                  '${settings.millisecondsPerDiv} ms на деление.',
              child: ScopeDisplay(capture: capture),
            ),
            const SizedBox(height: 8),
            Text(status, key: const ValueKey('scope_status')),
            if (capture.clipped)
              const Text(
                'Сигнал обрезан границей экрана. Увеличьте V/div или измените центр.',
              ),
            const SizedBox(height: 12),
            _select<ScopeScenario>('signal', 'Учебный сигнал', selected, {
              for (final value in ScopeScenario.values)
                value: _scenarioName(value),
            }, (value) => change(scenario: value)),
            _select<double>(
              'volts',
              'Масштаб напряжения · V/div',
              settings.voltsPerDiv,
              {
                for (final value in ScopeSettings.voltageScales)
                  value: '$value V/div',
              },
              (value) => change(next: settings.copyWith(voltsPerDiv: value)),
            ),
            _select<double>(
              'time',
              'Масштаб времени · ms/div',
              settings.millisecondsPerDiv,
              {
                for (final value in ScopeSettings.timeScalesMs)
                  value: '$value ms/div',
              },
              (value) =>
                  change(next: settings.copyWith(millisecondsPerDiv: value)),
            ),
            _select<double>(
              'center',
              'Напряжение в центре экрана · V',
              settings.centerVoltage,
              {for (final value in ScopeSettings.centers) value: '$value V'},
              (value) => change(next: settings.copyWith(centerVoltage: value)),
            ),
            _select<double>(
              'level',
              'Уровень триггера · V',
              settings.triggerLevel,
              {
                for (final value in ScopeSettings.triggerLevels)
                  value: '$value V',
              },
              (value) => change(next: settings.copyWith(triggerLevel: value)),
            ),
            _select<ScopeEdge>('edge', 'Фронт триггера', settings.edge, const {
              ScopeEdge.rising: 'Положительный ↑',
              ScopeEdge.falling: 'Отрицательный ↓',
            }, (value) => change(next: settings.copyWith(edge: value))),
            _select<ScopeTriggerMode>(
              'mode',
              'Режим запуска',
              settings.mode,
              const {
                ScopeTriggerMode.normal: 'Normal · по событию',
                ScopeTriggerMode.auto:
                    'Auto · свободный при отсутствии события',
                ScopeTriggerMode.single: 'Single · одиночный захват',
              },
              (value) => change(next: settings.copyWith(mode: value)),
            ),
            if (settings.mode == ScopeTriggerMode.single)
              OutlinedButton(
                key: const ValueKey('scope_capture'),
                onPressed: () {
                  final hadAnswer = correct != null;
                  setState(() {
                    correct = null;
                    capture = simulation.capture(
                      selected.signal,
                      settings,
                      armSingle: true,
                    );
                  });
                  if (hadAnswer) widget.onRetry();
                },
                child: const Text('Захватить'),
              ),
            const Text(
              'Сетка 10 × 8 делений. Центр и масштабы меняют только отображение. '
              'Запись 0–200 ms; DC coupling. Триггер ищется в исходной модели, '
              '20% окна до события. T — момент запуска, L — уровень. '
              'Без пересечения Normal не рисует новую запись.',
            ),
            const SizedBox(height: 8),
            if (correct != null) ...[
              Row(
                children: [
                  Icon(
                    correct! ? Icons.check_circle_outline : Icons.error_outline,
                    color: correct! ? colorScheme.primary : colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      correct!
                          ? 'Настройка верна'
                          : 'Условия задания не выполнены',
                      style: TextStyle(
                        color: correct!
                            ? colorScheme.primary
                            : colorScheme.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(_feedback(widget.block.exercise)),
              const SizedBox(height: 8),
              Text(
                _parameters(selected.signal),
                key: const ValueKey('scope_parameters'),
              ),
            ] else
              const Text(
                'Параметры генератора модели показаны после проверки. '
                'Это не автоматические измерения по экрану.',
              ),
            const SizedBox(height: 12),
            if (quizTask == null)
              FilledButton(
                key: const ValueKey('scope_check'),
                onPressed: correct == null ? check : null,
                child: const Text('Проверить настройку'),
              ),
            OutlinedButton.icon(
              key: const ValueKey('scope_reset'),
              onPressed: reset,
              icon: const Icon(Icons.refresh),
              label: const Text('Сбросить / повторить'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _select<T>(
    String id,
    String label,
    T value,
    Map<T, String> options,
    ValueChanged<T> onChange,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label),
        const SizedBox(height: 4),
        DropdownButtonFormField<T>(
          key: ValueKey('scope_${id}_${value.toString()}'),
          initialValue: value,
          isExpanded: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: [
            for (final entry in options.entries)
              DropdownMenuItem(
                value: entry.key,
                child: Text(
                  entry.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (next) {
            if (next != null && next != value) onChange(next);
          },
        ),
      ],
    ),
  );
}

String _scenarioName(ScopeScenario scenario) => switch (scenario) {
  ScopeScenario.constant => 'Постоянное напряжение',
  ScopeScenario.sine => 'Синусоида',
  ScopeScenario.square => 'Прямоугольные импульсы',
  ScopeScenario.pwm30 => 'ШИМ A',
  ScopeScenario.pwm60 => 'ШИМ B',
  ScopeScenario.missingPulse => 'Пропадающий импульс',
};

String _feedback(ScopeExercise exercise) => switch (exercise) {
  ScopeExercise.voltageScale =>
    'Вернитесь к сигналу задания. Размах должен занимать '
        '50–90% высоты сетки, без обрезания; показание 0 V не доказывает исправную массу.',
  ScopeExercise.timeScale =>
    'Вернитесь к сигналу задания. Нужны 2–5 полных периодов '
        'в окне, без обрезания по напряжению. T = деления × ms/div; f = 1/T в секундах.',
  ScopeExercise.trigger =>
    'Вернитесь к сигналу задания. Нужны Normal, положительный '
        'фронт, найденное пересечение уровня и отсутствие обрезания. '
        'Ожидание триггера не доказывает отсутствие сигнала.',
};

String _parameters(ScopeSignal signal) {
  final range = '${signal.minimum}…${signal.maximum} V';
  final details = switch (signal) {
    ConstantScopeSignal() =>
      'Постоянное напряжение; период, частота и duty cycle не применимы.',
    SineScopeSignal(
      :final amplitude,
      :final offset,
      :final frequencyHz,
      :final periodSeconds,
    ) =>
      'A = $amplitude V; смещение = $offset V; '
          'T = ${(periodSeconds * 1000).toStringAsFixed(1)} ms; f = $frequencyHz Hz.',
    PulseScopeSignal(
      :final frequencyHz,
      :final periodSeconds,
      :final duty,
      :final highSeconds,
      :final averageVoltage,
    ) =>
      'T = ${(periodSeconds * 1000).toStringAsFixed(1)} ms; f = $frequencyHz Hz; '
          'DHigh = ${(100 * duty).toStringAsFixed(0)}%; '
          'tHigh = ${(highSeconds * 1000).toStringAsFixed(1)} ms; среднее = $averageVoltage V.',
    MissingPulseScopeSignal(:final eventStart, :final eventEnd) =>
      'Непериодическая запись: пропуск высокого импульса '
          '${(eventStart * 1000).toStringAsFixed(1)}–${(eventEnd * 1000).toStringAsFixed(1)} ms. '
          'Вне пропуска несущая 100 Hz, 0/5 V, DHigh 30%; общего периода записи нет.',
  };
  return 'Параметры генератора модели, не измерения по экрану: $range. $details';
}
