import 'package:flutter/material.dart';

import '../practice/definition.dart';
import '../practice/practice_service.dart';
import 'practice_screen.dart';

class PracticeCatalogScreen extends StatefulWidget {
  const PracticeCatalogScreen({super.key});
  @override
  State<PracticeCatalogScreen> createState() => _PracticeCatalogScreenState();
}

class _PracticeCatalogScreenState extends State<PracticeCatalogScreen> {
  late Future<List<PracticeDefinition>> catalog;
  @override
  void initState() {
    super.initState();
    catalog = PracticeService().loadCatalog();
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
                    catalog = PracticeService().loadCatalog();
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
                  'Три диагностических сценария',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Выберите проверки, соберите доказательства и обоснуйте вывод. '
                  'Все действия виртуальные. Простой выбор правильной детали не даёт зачёт.',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Пилот: попытка и результат живут только в открытом сценарии. '
                  'После выхода или перезапуска они не сохраняются. Прогресс 132 уроков не меняется.',
                ),
                const SizedBox(height: 16),
                for (final definition in snapshot.data!)
                  Card(
                    child: ListTile(
                      key: ValueKey('practice_case_${definition.id}'),
                      title: Text(definition.title),
                      subtitle: Text(definition.difficulty),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              PracticeScreen(definition: definition),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
