import '../models/lesson.dart';
import '../models/lesson_block.dart';

bool isScoredLessonBlock(LessonBlock block) => switch (block) {
  QuestionLessonBlock() ||
  CalculationLessonBlock() ||
  MeasurementLessonBlock() ||
  VoltageDropLessonBlock() ||
  CurrentMeasurementLessonBlock() ||
  DiagnosticCaseLessonBlock() ||
  DiagnosticChoiceLessonBlock() => true,
  _ => false,
};

/// A computed snapshot of the current attempt, never a persisted completion.
class LessonAttempt {
  final int totalTasks;
  final int answeredTasks;
  final int correctTasks;
  final bool isQuiz;
  final int passingScore;

  const LessonAttempt({
    required this.totalTasks,
    required this.answeredTasks,
    required this.correctTasks,
    required this.isQuiz,
    required this.passingScore,
  });

  bool get allAnswered => answeredTasks == totalTasks;
  bool get allCorrect => correctTasks == totalTasks;
  double get scoreFraction => totalTasks == 0 ? 0 : correctTasks / totalTasks;
  int get scorePercent => (scoreFraction * 100).round();
  bool get passedQuiz =>
      !isQuiz || (allAnswered && scorePercent >= passingScore);
  bool get canComplete => allAnswered && (isQuiz ? passedQuiz : allCorrect);
}

LessonAttempt evaluateLessonAttempt(
  Lesson lesson,
  Map<int, bool> answersByBlockIndex,
) {
  var total = 0;
  var answered = 0;
  var correct = 0;
  for (var index = 0; index < lesson.blocks.length; index++) {
    if (!isScoredLessonBlock(lesson.blocks[index])) continue;
    total++;
    final answer = answersByBlockIndex[index];
    if (answer != null) answered++;
    if (answer == true) correct++;
  }
  return LessonAttempt(
    totalTasks: total,
    answeredTasks: answered,
    correctTasks: correct,
    isQuiz: lesson.completion.isQuiz,
    passingScore: lesson.completion.passingScore ?? 0,
  );
}
