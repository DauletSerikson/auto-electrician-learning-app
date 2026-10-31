import 'package:electrician/practice/attempt.dart';
import 'package:electrician/practice/definition.dart';
import 'package:flutter_test/flutter_test.dart';

import 'practice_engine_test.dart'
    as engine
    show loadCase, perform, preparePass, routes;

void main() {
  for (final id in engine.routes.keys) {
    test(
      '$id irrelevant safe checks affect only the five-point route criterion',
      () {
        final s = PracticeSession(engine.loadCase(id));
        engine.preparePass(s, engine.routes[id]!);
        for (final a in s.definition.actions.values.where(
          (a) => a is! ForbiddenAction,
        )) {
          final choices = a.purposes.entries.where((e) => !e.value.justified);
          if (choices.isNotEmpty) {
            engine.perform(s, a.id, purpose: choices.first.key);
          }
        }
        final result = s.submit();
        expect(result.passed, isTrue);
        expect(result.score, inInclusiveRange(95, 100));
        expect(result.fractions[Criterion.evidence], 1);
        expect(result.fractions[Criterion.interpretation], 1);
      },
    );
    test(
      '$id extra safe justified checks do not penalize a proven diagnosis',
      () {
        final s = PracticeSession(engine.loadCase(id));
        engine.preparePass(s, engine.routes[id]!);
        for (final a in s.definition.actions.values.where(
          (a) => a is! ForbiddenAction,
        )) {
          final justified = a.purposes.values.firstWhere((p) => p.justified);
          engine.perform(s, a.id, purpose: justified.id);
        }
        final result = s.submit();
        expect(result.score, 100);
        expect(result.passed, isTrue);
      },
    );
    test(
      '$id correct answers and hypothesis labels cannot replace records',
      () {
        final s = PracticeSession(engine.loadCase(id));
        s.decideSafety(true);
        for (final h in s.definition.hypotheses.keys) {
          s.noteHypothesis(h, HypothesisStatus.confirmed, []);
        }
        for (final c in s.definition.claims.values) {
          s.answerClaim(c.id, c.correctOptionId);
        }
        s.chooseConclusion(
          s.definition.conclusions.values.firstWhere((c) => c.credit == 1).id,
        );
        final result = s.submit();
        expect(result.passed, isFalse);
        expect(result.fractions[Criterion.evidence], 0);
        expect(result.fractions[Criterion.interpretation], 0);
      },
    );
    test(
      '$id many duplicate checks cannot increase score or citations proof',
      () {
        final s = PracticeSession(engine.loadCase(id));
        engine.preparePass(s, engine.routes[id]!);
        final before = evaluatePractice(s.definition, s.state);
        for (var i = 0; i < 50; i++) {
          engine.perform(s, engine.routes[id]!.first);
        }
        final after = s.submit();
        expect(after.score, before.score);
        expect(after.groups, before.groups);
        expect(after.interpretations, before.interpretations);
      },
    );
  }
}
