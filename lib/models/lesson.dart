import 'lesson_block.dart';
import 'lesson_completion.dart';

class Lesson {
  final String id;
  final String moduleId;
  final int order;
  final String title;
  final String description;
  final int estimatedMinutes;
  final LessonCompletion completion;
  final List<LessonBlock> blocks;

  Lesson({
    required this.id,
    required this.moduleId,
    required this.order,
    required this.title,
    required this.description,
    required this.estimatedMinutes,
    required this.completion,
    required this.blocks,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'],
      moduleId: json['moduleId'],
      order: json['order'],
      title: json['title'],
      description: json['description'],
      estimatedMinutes: json['estimatedMinutes'],

      completion: LessonCompletion.fromJson(json['completion']),

      blocks: (json['blocks'] as List)
          .map((block) => LessonBlock.fromJson(block))
          .toList(),
    );
  }
}
