class LessonSummary {
  final String id;
  final int order;
  final String title;
  final String description;
  final int estimatedMinutes;
  final String file;

  LessonSummary({
    required this.id,
    required this.order,
    required this.title,
    required this.description,
    required this.estimatedMinutes,
    required this.file,
  });

  factory LessonSummary.fromJson(Map<String, dynamic> json) {
    return LessonSummary(
      id: json['id'],
      order: json['order'],
      title: json['title'],
      description: json['description'],
      estimatedMinutes: json['estimatedMinutes'],
      file: json['file'],
    );
  }
}
