import 'package:flutter/material.dart';

import '../practice/definition.dart';
import '../practice/practice_service.dart';
import '../practice/practice_controller.dart';
import '../practice/practice_result_repository.dart';
import 'practice_screen.dart';

class PracticeCatalogScreen extends StatefulWidget {
  final PracticeResultRepository? repository;
  const PracticeCatalogScreen({super.key, this.repository});
  @override
  State<PracticeCatalogScreen> createState() => _PracticeCatalogScreenState();
}

class _PracticeCatalogScreenState extends State<PracticeCatalogScreen> {
  late Future<List<PracticeDefinition>> catalog;
  late final PracticeResultRepository repository;
  final Map<String, PracticeResult?> results = {};
  final Set<String> readErrors = {};
  Future<List<PracticeDefinition>> load() async {
    final definitions = await PracticeService().loadCatalog();
    results.clear();
    readErrors.clear();
    for (final d in definitions) {
      try {
        results[d.id] = await repository.read(d.id);
      } catch (_) {
        readErrors.add(d.id);
      }
    }
    return definitions;
  }

  @override
  void initState() {
    super.initState();
    repository = widget.repository ?? PreferencesPracticeResultRepository();
    catalog = load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Практика диагноста')),
    body: FutureBuilder<List<PracticeDefinition>>(
      future: catalog,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Не удалось загрузить практикум'),
                TextButton(
                  onPressed: () => setState(() {
                    catalog = load();
                  }),
                  child: const Text('Повторить загрузку'),
                ),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Диагностические сценарии: ${snapshot.data!.length}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Выберите проверки, соберите доказательства и обоснуйте вывод. '
                  'Все действия виртуальные. Простой выбор правильной детали не даёт зачёт.',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Итоги завершённых попыток сохраняются на устройстве. '
                  'Черновик и журнал после выхода не сохраняются. Прогресс 132 уроков не меняется.',
                ),
                const SizedBox(height: 16),
                if (readErrors.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() {
                      catalog = load();
                    }),
                    child: const Text('Повторить чтение результатов'),
                  ),
                for (final definition in snapshot.data!)
                  Card(
                    child: ListTile(
                      key: ValueKey('practice_case_${definition.id}'),
                      title: Text(definition.title),
                      subtitle: Text(
                        '${definition.difficulty}\n${status(definition.id)}',
                        key: ValueKey('practice_status_${definition.id}'),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final controller = PracticeController(
                          definition,
                          repository: repository,
                        );
                        try {
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => PracticeScreen(
                                definition: definition,
                                controller: controller,
                              ),
                            ),
                          );
                        } finally {
                          // A user may explicitly leave while storage is pending.
                          // Refresh only after that write has settled.
                          await controller.pendingSave;
                          controller.dispose();
                        }
                        if (mounted) {
                          setState(() {
                            catalog = load();
                          });
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );

  String status(String id) {
    if (readErrors.contains(id)) {
      return 'Не удалось прочитать сохранённый результат. Данные не изменены.';
    }
    final result = results[id];
    if (result == null) return 'Не пройден · лучший результат: —';
    return '${result.passed ? 'Пройден' : 'Не пройден'} · '
        'лучший результат: ${result.bestScore.toStringAsFixed(1)} / 100';
  }
}
