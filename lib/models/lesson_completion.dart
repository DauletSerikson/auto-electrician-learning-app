class LessonCompletion {
  final String type;
  final int? passingScore;

  LessonCompletion({required this.type, this.passingScore}) {
    if (type != 'lesson' && type != 'quiz') {
      throw FormatException('Unsupported completion type: $type');
    }
    if (isQuiz && passingScore == null) {
      throw const FormatException('Quiz completion requires passingScore');
    }
    final score = passingScore;
    if (score != null && (score < 1 || score > 100)) {
      throw const FormatException(
        'Completion passingScore must be between 1 and 100',
      );
    }
  }

  factory LessonCompletion.fromJson(Object? json) {
    if (json == null) {
      return LessonCompletion(type: 'lesson');
    }
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Lesson completion must be a JSON object');
    }
    final type = json['type'] ?? 'lesson';
    if (type is! String) {
      throw const FormatException('Completion type must be a string');
    }
    final passingScore = json['passingScore'];
    if (passingScore != null && passingScore is! int) {
      throw const FormatException('Completion passingScore must be an integer');
    }

    return LessonCompletion(type: type, passingScore: passingScore as int?);
  }

  bool get isQuiz => type == 'quiz';
}
