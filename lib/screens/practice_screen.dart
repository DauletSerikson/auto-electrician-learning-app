import 'package:flutter/material.dart';

import '../practice/attempt.dart';
import '../practice/definition.dart';
import '../practice/observation.dart';
import '../practice/practice_controller.dart';

class PracticeScreen extends StatefulWidget {
  final PracticeDefinition definition;
  final PracticeController? controller;
  const PracticeScreen({super.key, required this.definition, this.controller});
  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  late PracticeController controller;
  bool started = false;
  int tab = 0;
  PracticeDefinition get d => widget.definition;
  PracticeAttempt get state => controller.state;
  bool get frozen => state.submitted;

  @override
  void initState() {
    super.initState();
    controller = widget.controller ?? PracticeController(d);
  }

  @override
  void didUpdateWidget(covariant PracticeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.definition.id != d.id) {
      if (oldWidget.controller == null) controller.dispose();
      controller = widget.controller ?? PracticeController(d);
      started = false;
      tab = 0;
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) controller.dispose();
    super.dispose();
  }

  Widget panel(String title, List<Widget> children, {Key? key}) => Card(
    key: key,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          for (final child in children) ...[child, const SizedBox(height: 8)],
        ],
      ),
    ),
  );

  Future<void> showRecord(EvidenceRecord record) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Запись #${record.sequence}'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: recordDetails(record),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Закрыть запись'),
        ),
      ],
    ),
  );

  String pointsDescription(
    ReadingAction action,
    bool reverse,
  ) => switch (action.quantity) {
    Quantity.voltage =>
      reverse
          ? 'V DC: красный ${action.blackPoint}, чёрный ${action.redPoint}.'
          : 'V DC: красный ${action.redPoint}, чёрный ${action.blackPoint}.',
    Quantity.current =>
      'Готовый capture тока в направлении '
          '${action.redPoint} → ${action.blackPoint}. Подключение амперметра не моделируется.',
    Quantity.resistance =>
      'Готовый отчёт об изолированном участке '
          '${action.redPoint}–${action.blackPoint}.',
    Quantity.power =>
      'Готовая запись мощности участка '
          '${action.redPoint}–${action.blackPoint}, не режим V DC мультиметра.',
  };

  List<Widget> recordDetails(EvidenceRecord record) {
    final action = d.actions[record.actionId]!;
    return [
      Text(action.title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      if (action is ReadingAction)
        Text(pointsDescription(action, record.reversePolarity)),
      Text(record.observation.display),
      const SizedBox(height: 12),
      Text(record.conditions.description),
      if (record.purposeId.isNotEmpty)
        Text('Выбранная цель: ${action.purposes[record.purposeId]!.label}'),
      const SizedBox(height: 8),
      Text('Границы вывода: ${record.permittedScope}'),
      if (!record.isEvidence)
        const Text('Эта запись не подтверждает измерительный результат.'),
    ];
  }

  Future<void> citeRecords(
    String id, {
    bool hypothesis = false,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => SizedBox(
      height: MediaQuery.sizeOf(context).height * .8,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final selected = hypothesis
              ? state.hypotheses[id]?.recordIds ?? <int>{}
              : state.responses[id]?.recordIds ?? <int>{};
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Связать записи',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    if (state.journal.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'Сначала выполните диагностическую проверку.',
                        ),
                      ),
                    for (final r in state.journal)
                      CheckboxListTile(
                        key: ValueKey('cite_${id}_${r.sequence}'),
                        value: selected.contains(r.sequence),
                        title: Text(
                          '#${r.sequence} — ${d.actions[r.actionId]!.title}',
                        ),
                        subtitle: Text(
                          '${r.observation.display}\n${r.conditions.snapshotId}',
                        ),
                        onChanged: frozen || !r.isEvidence
                            ? null
                            : (value) {
                                final next = {...selected};
                                if (value == true) {
                                  next.add(r.sequence);
                                } else {
                                  next.remove(r.sequence);
                                }
                                controller.edit((s) {
                                  if (hypothesis) {
                                    s.noteHypothesis(
                                      id,
                                      state.hypotheses[id]?.status ??
                                          HypothesisStatus.untested,
                                      next,
                                    );
                                  } else {
                                    s.citeClaim(id, next);
                                  }
                                });
                              },
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton(
                  key: const ValueKey('close_citations'),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Готово'),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );

  Widget actionCard(PracticeAction action) {
    if (action case ForbiddenAction(:final reason)) {
      return panel(action.title, [
        Text(reason),
        const Text('Недоступно: метод запрещён.'),
      ], key: ValueKey('action_${action.id}'));
    }
    final profile = d.profiles[action.profileId]!;
    return panel(action.title, [
      Text('Условия: ${profile.label}'),
      if (action is ReadingAction) ...[
        Text(
          'Подготовленные данные. '
          '${pointsDescription(action, state.reversePolarity[action.id] ?? false)}',
        ),
        if (action.quantity == Quantity.voltage)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Обратная полярность'),
            value: state.reversePolarity[action.id] ?? false,
            onChanged: frozen
                ? null
                : (v) => controller.edit((s) => s.choosePolarity(action.id, v)),
          ),
      ],
      ExpansionTile(
        key: PageStorageKey('purpose_${d.id}_${state.id}_${action.id}'),
        tilePadding: EdgeInsets.zero,
        title: const Text('Цель проверки'),
        subtitle: Text(
          action.purposes[state.purposes[action.id]]?.label ??
              'Выберите до получения результата',
        ),
        children: [
          RadioGroup<String>(
            groupValue: state.purposes[action.id],
            onChanged: (v) {
              if (v != null && !frozen) {
                controller.edit((s) => s.choosePurpose(action.id, v));
              }
            },
            child: Column(
              children: [
                for (final purpose in action.purposes.values)
                  RadioListTile<String>(
                    key: ValueKey('purpose_${action.id}_${purpose.id}'),
                    enabled: !frozen,
                    value: purpose.id,
                    title: Text(purpose.label),
                  ),
              ],
            ),
          ),
        ],
      ),
      if (state.profileId != action.profileId) ...[
        const Text('Проверка недоступна в текущем профиле.'),
        OutlinedButton(
          key: ValueKey('profile_for_${action.id}'),
          onPressed: frozen
              ? null
              : () => controller.edit((s) => s.changeProfile(action.profileId)),
          child: Text('Выбрать: ${profile.label}'),
        ),
      ],
      FilledButton(
        key: ValueKey('perform_${action.id}'),
        onPressed:
            frozen ||
                state.profileId != action.profileId ||
                !state.purposes.containsKey(action.id)
            ? null
            : () {
                late EvidenceRecord record;
                controller.edit((s) {
                  record = s.perform(action.id);
                });
                showRecord(record);
              },
        child: const Text('Выполнить виртуальную проверку'),
      ),
      if (state.journal.any((r) => r.actionId == action.id))
        Text(
          'Записей: ${state.journal.where((r) => r.actionId == action.id).length}. См. журнал.',
        ),
    ], key: ValueKey('action_${action.id}'));
  }

  List<Widget> checks() => [
    panel('Текущие условия', [
      Text(d.profiles[state.profileId]!.description),
      ExpansionTile(
        key: PageStorageKey('profiles_${d.id}_${state.id}'),
        title: const Text('Выбрать другой профиль'),
        children: [
          RadioGroup<String>(
            groupValue: state.profileId,
            onChanged: (id) {
              if (id != null && !frozen) {
                controller.edit((s) => s.changeProfile(id));
              }
            },
            child: Column(
              children: [
                for (final p in d.profiles.values)
                  RadioListTile<String>(
                    value: p.id,
                    enabled: !frozen,
                    title: Text(p.label),
                  ),
              ],
            ),
          ),
        ],
      ),
    ]),
    ExpansionTile(
      key: PageStorageKey('schematic_${d.id}_${state.id}'),
      title: const Text('Симптомы и функциональная схема'),
      children: [
        panel(d.vehicle, [
          Text(d.symptoms),
          Text(d.topology),
          for (final p in d.points.values) Text(p.label),
        ]),
      ],
    ),
    const Padding(
      padding: EdgeInsets.all(8),
      child: Text(
        'Сначала выберите цель и условия. '
        'Результат не меняется при повторном чтении. Итоговый вывод вы формулируете сами.',
      ),
    ),
    for (final action in d.actions.values) actionCard(action),
  ];

  List<Widget> journal() => [
    if (state.journal.isEmpty)
      const Text('Журнал пуст. Выполните проверку во вкладке «Проверки».'),
    for (final r in state.journal)
      panel('Запись #${r.sequence}', [
        ...recordDetails(r),
        TextButton(
          onPressed: () => showRecord(r),
          child: const Text('Открыть запись'),
        ),
      ], key: ValueKey('record_${r.sequence}')),
  ];

  static const hypothesisLabels = {
    HypothesisStatus.untested: 'Не проверена',
    HypothesisStatus.supported: 'Поддерживается',
    HypothesisStatus.contradicted: 'Противоречит данным',
    HypothesisStatus.confirmed: 'Подтверждена в области проверки',
  };

  List<Widget> hypotheses() => [
    const Text(
      'Статусы — ваши рабочие предположения. Пометка «подтверждена» '
      'сама не создаёт доказательство и не означает правильный диагноз.',
    ),
    for (final h in d.hypotheses.values)
      panel(h.label, [
        RadioGroup<HypothesisStatus>(
          groupValue:
              state.hypotheses[h.id]?.status ?? HypothesisStatus.untested,
          onChanged: (v) {
            if (v != null && !frozen) {
              controller.edit(
                (s) => s.noteHypothesis(
                  h.id,
                  v,
                  state.hypotheses[h.id]?.recordIds ?? {},
                ),
              );
            }
          },
          child: Column(
            children: [
              for (final entry in hypothesisLabels.entries)
                RadioListTile<HypothesisStatus>(
                  key: ValueKey('hypothesis_${h.id}_${entry.key.name}'),
                  value: entry.key,
                  enabled: !frozen,
                  title: Text(entry.value),
                ),
            ],
          ),
        ),
        TextButton(
          onPressed: frozen ? null : () => citeRecords(h.id, hypothesis: true),
          child: Text(
            'Связать записи (${state.hypotheses[h.id]?.recordIds.length ?? 0})',
          ),
        ),
      ]),
  ];

  List<Widget> conclusion() => [
    panel('Безопасность', [
      Text(d.safety),
      CheckboxListTile(
        key: const ValueKey('practice_safety'),
        contentPadding: EdgeInsets.zero,
        title: const Text(
          'Принимаю границы: только виртуальные проверки, без обхода защит',
        ),
        value: state.safetyAccepted,
        onChanged: frozen
            ? null
            : (v) => controller.edit((s) {
                if (v == true) {
                  s.decideSafety(true);
                } else {
                  s.withdrawSafetyAcknowledgement();
                }
              }),
      ),
    ]),
    for (final claim in d.claims.values)
      panel(claim.prompt, [
        RadioGroup<String>(
          groupValue: state.responses[claim.id]?.optionId,
          onChanged: (v) {
            if (v != null && !frozen) {
              controller.edit((s) => s.answerClaim(claim.id, v));
            }
          },
          child: Column(
            children: [
              for (final option in claim.options.values)
                RadioListTile<String>(
                  key: ValueKey('claim_${claim.id}_${option.id}'),
                  value: option.id,
                  enabled: !frozen,
                  title: Text(option.label),
                ),
            ],
          ),
        ),
        TextButton(
          key: ValueKey('link_${claim.id}'),
          onPressed: frozen ? null : () => citeRecords(claim.id),
          child: Text(
            'Связать записи (${state.responses[claim.id]?.recordIds.length ?? 0})',
          ),
        ),
      ], key: ValueKey('claim_${claim.id}')),
    panel('Итоговый вывод', [
      RadioGroup<String>(
        groupValue: state.conclusionId,
        onChanged: (v) {
          if (v != null && !frozen) {
            controller.edit((s) => s.chooseConclusion(v));
          }
        },
        child: Column(
          children: [
            for (final c in d.conclusions.values)
              RadioListTile<String>(
                key: ValueKey('conclusion_${c.id}'),
                value: c.id,
                enabled: !frozen,
                title: Text(c.label),
              ),
          ],
        ),
      ),
      if (d.conclusions[state.conclusionId]?.kind ==
          ConclusionKind.insufficient)
        ExpansionTile(
          key: PageStorageKey('follow_up_${d.id}_${state.id}'),
          title: const Text('Следующая безопасная проверка'),
          subtitle: Text(
            d.actions[state.followUpActionId]?.title ??
                'Укажите, каких данных не хватает',
          ),
          children: [
            RadioGroup<String>(
              groupValue: state.followUpActionId,
              onChanged: (v) {
                if (v != null && !frozen) {
                  controller.edit((s) => s.chooseFollowUp(v));
                }
              },
              child: Column(
                children: [
                  for (final a in d.actions.values.where(
                    (a) => a is! ForbiddenAction,
                  ))
                    RadioListTile<String>(
                      key: ValueKey('follow_up_choice_${a.id}'),
                      value: a.id,
                      enabled: !frozen,
                      title: Text(a.title),
                    ),
                ],
              ),
            ),
          ],
        ),
      const Text(
        'Оценка учитывает вывод, доказательства, интерпретацию, безопасность и цель проверок. '
        'Можно отправить преждевременный вывод, но без доказательств зачёта не будет.',
      ),
      FilledButton(
        key: const ValueKey('practice_submit'),
        onPressed: frozen || state.conclusionId == null
            ? null
            : () {
                FocusScope.of(context).unfocus();
                controller.edit((s) => s.submit());
                setState(() {
                  tab = 4;
                });
              },
        child: const Text('Оценить заключение'),
      ),
    ]),
  ];

  static const criterionLabels = {
    Criterion.diagnosis: 'Диагностический вывод',
    Criterion.evidence: 'Достаточность доказательств',
    Criterion.interpretation: 'Интерпретация измерений',
    Criterion.safety: 'Безопасность',
    Criterion.route: 'Обоснованность маршрута',
  };

  List<Widget> evaluation() {
    final result = state.evaluation!;
    return [
      panel(
        result.passed
            ? 'PASS — обоснованный вывод'
            : result.needsMoreEvidence
            ? 'Нужна дополнительная проверка'
            : 'FAIL — вывод не подтверждён',
        [
          Text(
            '${result.score.toStringAsFixed(1)} / 100',
            key: const ValueKey('practice_score'),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          for (final c in Criterion.values)
            Text(
              '${criterionLabels[c]}: '
              '${(result.fractions[c]! * d.weights[c]!).toStringAsFixed(1)} / ${d.weights[c]!.toInt()}',
            ),
          const Text(
            'PASS: обоснованный вывод, все обязательные доказательства, верная интерпретация ключевых измерений, '
            'безопасность и минимум 80 баллов до округления. Правильного угадывания недостаточно.',
          ),
          for (final message in result.feedback) Text(message),
          if (result.passed) Text(d.explanation),
          Text(
            controller.saving
                ? 'Сохранение результата…'
                : controller.saveError != null
                ? 'Не удалось сохранить результат. Попытка остаётся открытой; повторите сохранение. Прогресс курса не изменён.'
                : controller.resultSaved
                ? 'Результат сохранён на устройстве. Прогресс курса не изменён.'
                : 'Прогресс курса не изменён.',
          ),
          if (controller.saveError != null)
            TextButton(
              key: const ValueKey('practice_save_retry'),
              onPressed: controller.saveResult,
              child: const Text('Повторить сохранение'),
            ),
          OutlinedButton(
            key: const ValueKey('practice_retry'),
            onPressed: controller.saving || controller.saveError != null
                ? null
                : () {
                    controller.edit((s) => s.retry());
                    setState(() {
                      tab = 0;
                    });
                  },
            child: const Text('Повторить попытку'),
          ),
        ],
      ),
    ];
  }

  bool get hasDraft =>
      state.journal.isNotEmpty ||
      state.purposes.isNotEmpty ||
      state.responses.isNotEmpty ||
      state.hypotheses.isNotEmpty ||
      state.conclusionId != null;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => PopScope(
      canPop:
          (frozen && !controller.saving && controller.saveError == null) ||
          !hasDraft,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Выйти из попытки?'),
            content: Text(
              controller.saving || controller.saveError != null
                  ? 'Сохранение результата ещё не подтверждено. При выходе он может быть потерян. Прогресс курса останется.'
                  : 'Черновик и журнал текущего сценария не сохранятся. Прогресс курса останется.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Остаться'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Выйти'),
              ),
            ],
          ),
        );
        if (leave == true && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(d.title)),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: !started
                ? ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(
                        d.title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text('Сложность: ${d.difficulty}'),
                      Text(d.vehicle),
                      panel('Исходные симптомы', [Text(d.symptoms)]),
                      panel('Функциональная схема', [Text(d.topology)]),
                      Text(
                        'Предзнания: модули ${d.prerequisites.map((id) => int.parse(id.split('_').last) + 1).join(', ')}.',
                      ),
                      Text(d.safety),
                      const Text(
                        'Итог завершённой попытки сохраняется на устройстве. Черновик и журнал после выхода не сохраняются.',
                      ),
                      FilledButton(
                        key: const ValueKey('practice_start'),
                        onPressed: () => setState(() {
                          started = true;
                        }),
                        child: const Text('Начать попытку'),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Wrap(
                          spacing: 6,
                          children: [
                            for (final (index, label) in [
                              'Проверки',
                              'Журнал',
                              'Гипотезы',
                              'Заключение',
                              if (frozen) 'Оценка',
                            ].indexed)
                              ChoiceChip(
                                key: ValueKey('practice_tab_$index'),
                                label: Text(label),
                                selected: tab == index,
                                onSelected: (_) => setState(() {
                                  tab = index;
                                }),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ExcludeFocus(
                          excluding: frozen && tab != 4 && tab != 1,
                          child: ListView(
                            key: PageStorageKey(
                              'practice_${d.id}_${state.id}_$tab',
                            ),
                            padding: const EdgeInsets.all(16),
                            children: switch (tab) {
                              0 => checks(),
                              1 => journal(),
                              2 => hypotheses(),
                              3 => conclusion(),
                              _ => evaluation(),
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    ),
  );
}
