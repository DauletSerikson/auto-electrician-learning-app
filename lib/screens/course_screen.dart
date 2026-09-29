import 'package:flutter/material.dart';

import '../models/course_module.dart';
import '../services/course_service.dart';
import 'module_screen.dart';

class CourseScreen extends StatefulWidget {
  const CourseScreen({super.key});

  @override
  State<CourseScreen> createState() => _CourseScreenState();
}

class _CourseScreenState extends State<CourseScreen> {
  final CourseService courseService = CourseService();

  late Future<List<CourseModule>> modulesFuture;

  @override
  void initState() {
    super.initState();
    modulesFuture = courseService.loadModules();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Курс')),
      body: FutureBuilder<List<CourseModule>>(
        future: modulesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Ошибка загрузки:\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          final modules = snapshot.data ?? [];

          if (modules.isEmpty) {
            return const Center(child: Text('Модули не найдены'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: modules.length,
            itemBuilder: (context, index) {
              final module = modules[index];

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: module.order == 0
                        ? const Icon(Icons.health_and_safety_outlined)
                        : Text('${module.order}'),
                  ),
                  title: Text(module.title),
                  subtitle: Text(module.description),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ModuleScreen(module: module),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
