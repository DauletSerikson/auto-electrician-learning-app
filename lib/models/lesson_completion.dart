class LessonCompletion {
  final String type;
  final int? passingScore;

  LessonCompletion({required this.type, this.passingScore});

  factory LessonCompletion.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return LessonCompletion(type: 'lesson');
    }

    return LessonCompletion(
      type: json['type'] ?? 'lesson',
      passingScore: json['passingScore'],
    );
  }

  bool get isQuiz => type == 'quiz';
}
