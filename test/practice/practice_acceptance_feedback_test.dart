import 'package:electrician/practice/attempt.dart';
import 'package:electrician/practice/definition.dart';
import 'package:flutter_test/flutter_test.dart';

import 'full_catalog_routes.dart';
import 'practice_engine_test.dart' as engine show loadCase, preparePass;

void main() {
  for (final id in fullRoutes.keys) {
    final d = engine.loadCase(id);
    test(
      '$id guessed conclusion feedback cannot affirm unseen measurements',
      () {
        final s = PracticeSession(d);
        s.decideSafety(true);
        final correct = d.conclusions.values.firstWhere((c) => c.credit == 1);
        s.chooseConclusion(correct.id);
        final r = s.submit();
        expect(r.passed, isFalse);
        expect(r.feedback, isNot(contains(correct.explanation)));
        for (final claim in d.claims.values) {
          expect(
            r.feedback,
            isNot(contains('${claim.prompt}: ${claim.explanation}')),
          );
        }
        expect(r.feedback.join('\n'), contains('Не подтверждены:'));
      },
    );
    test('$id wrong guess feedback does not invent measurements either', () {
      final s = PracticeSession(d);
      final wrong = d.conclusions.values.firstWhere((c) => c.credit == 0);
      s.chooseConclusion(wrong.id);
      expect(s.submit().feedback, isNot(contains(wrong.explanation)));
    });
    test(
      '$id supported wrong interpretation explains the cited result specifically',
      () {
        final s = PracticeSession(d);
        engine.preparePass(s, fullRoutes[id]!);
        final claim = d.claims.values.firstWhere((c) => c.critical);
        s.answerClaim(
          claim.id,
          claim.options.keys.firstWhere((x) => x != claim.correctOptionId),
        );
        final r = s.submit();
        expect(r.passed, isFalse);
        expect(r.feedback, contains('${claim.prompt}: ${claim.explanation}'));
      },
    );
    test(
      '$id proven conclusion retains its explanation with both admissible routes',
      () {
        for (final route in [fullRoutes[id]!, fullAlternateRoutes[id]!]) {
          final s = PracticeSession(d);
          engine.preparePass(s, route);
          final r = s.submit();
          expect(r.passed, isTrue);
          expect(
            r.feedback,
            contains(d.conclusions[s.state.conclusionId]!.explanation),
          );
          expect(r.fractions.values, everyElement(1));
        }
      },
    );
  }
  test('insufficient without useful next action must not claim a useful action was chosen', () {
    final d = engine.loadCase('dp01');
    final s = PracticeSession(d);
    final more = d.conclusions.values.firstWhere(
      (c) => c.kind == ConclusionKind.insufficient,
    );
    s.chooseConclusion(more.id);
    final r = s.submit();
    expect(r.fractions[Criterion.diagnosis], 0);
    expect(r.feedback, isNot(contains(more.explanation)));
  });
}
