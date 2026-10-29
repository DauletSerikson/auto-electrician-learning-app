import 'dart:convert';
import 'dart:io';

import 'package:electrician/practice/attempt.dart';
import 'package:electrician/practice/definition.dart';
import 'package:electrician/practice/observation.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> rawCase(String id) =>
    (jsonDecode(File('assets/practice/cases/$id.json').readAsStringSync())
        as Map<String, Object?>);
PracticeDefinition loadCase(String id) =>
    PracticeDefinition.fromJson(rawCase(id));

EvidenceRecord perform(
  PracticeSession session,
  String id, {
  String purpose = 'p1',
}) {
  final action = session.definition.actions[id]!;
  session.changeProfile(action.profileId);
  session.choosePurpose(id, purpose);
  return session.perform(id);
}

void interpretAll(PracticeSession session) {
  for (final claim in session.definition.claims.values) {
    session.answerClaim(claim.id, claim.correctOptionId);
    session.citeClaim(
      claim.id,
      session.state.journal.where((r) => r.isEvidence).map((r) => r.sequence),
    );
  }
}

void preparePass(PracticeSession session, List<String> route) {
  session.decideSafety(true);
  for (final id in route) {
    perform(session, id);
  }
  interpretAll(session);
  session.chooseConclusion(
    session.definition.conclusions.values.firstWhere((c) => c.credit == 1).id,
  );
}

const routes = {
  'dp01': ['ST0', 'ST1', 'ST4', 'ST5', 'ST6', 'ST7'],
  'dp13': ['MF0', 'MF1', 'MF2', 'MF3', 'MF4', 'MF6', 'MF7'],
  'dp05': ['LP0', 'LP1', 'LP3', 'LP4', 'LP5', 'LP6', 'LP9', 'LP10'],
};
const alternateRoutes = {
  'dp01': ['ST7', 'ST3', 'ST2', 'ST5', 'ST4', 'ST1', 'ST0'],
  'dp13': ['MF8', 'MF4', 'MF3', 'MF2', 'MF1', 'MF0'],
  'dp05': [
    'LP10',
    'LP9',
    'LP6',
    'LP3',
    'LP2',
    'LP1',
    'LP4',
    'LP7',
    'LP8',
    'LP0',
  ],
};

void main() {
  for (final id in routes.keys) {
    test('$id full evidence cannot compensate an incorrect diagnosis', () {
      final s = PracticeSession(loadCase(id));
      preparePass(s, routes[id]!);
      s.chooseConclusion(
        s.definition.conclusions.values.firstWhere((c) => c.credit == 0).id,
      );
      final result = s.submit();
      expect(result.fractions[Criterion.evidence], 1);
      expect(result.fractions[Criterion.interpretation], 1);
      expect(result.fractions[Criterion.diagnosis], 0);
      expect(result.passed, isFalse);
    });
    test('$id strict real definition, determinism and frozen results', () {
      final d = loadCase(id);
      final session = PracticeSession(d);
      final first = perform(session, routes[id]!.first);
      final second = session.perform(first.actionId);
      expect(second.observation.display, first.observation.display);
      session.changeProfile('briefing');
      expect(first.conditions.id, d.actions[first.actionId]!.profileId);
      expect(() => session.state.journal.clear(), throwsUnsupportedError);
      expect(() => d.actions.clear(), throwsUnsupportedError);
    });
    test(
      '$id correct diagnosis alone fails; all action enumeration alone fails',
      () {
        final s = PracticeSession(loadCase(id));
        s.decideSafety(true);
        s.chooseConclusion(
          s.definition.conclusions.values.firstWhere((c) => c.credit == 1).id,
        );
        expect(s.submit().passed, isFalse);
        s.retry();
        s.decideSafety(true);
        for (final a in s.definition.actions.values.where(
          (a) => a is! ForbiddenAction,
        )) {
          perform(s, a.id);
        }
        s.chooseConclusion(
          s.definition.conclusions.values.firstWhere((c) => c.credit == 1).id,
        );
        final result = s.submit();
        expect(result.passed, isFalse);
        expect(result.fractions[Criterion.interpretation], 0);
        expect(result.score, lessThan(100));
      },
    );
    test('$id supported route passes, wrong interpretation blocks mastery', () {
      final s = PracticeSession(loadCase(id));
      preparePass(s, routes[id]!);
      final result = s.submit();
      expect(result.passed, isTrue);
      expect(result.score, closeTo(100, 1e-9));
      expect(() => s.changeProfile('briefing'), throwsStateError);
      expect(() => s.perform(routes[id]!.first), throwsStateError);
      expect(() => s.chooseConclusion('more'), throwsStateError);
      s.retry();
      preparePass(s, routes[id]!);
      final claim = s.definition.claims.values.first;
      s.answerClaim(
        claim.id,
        claim.options.keys.firstWhere((x) => x != claim.correctOptionId),
      );
      expect(s.submit().passed, isFalse);
    });
    test(
      '$id equivalent route and arbitrary safe ordering have equal scores',
      () {
        final a = PracticeSession(loadCase(id)),
            b = PracticeSession(loadCase(id));
        preparePass(a, routes[id]!.reversed.toList());
        preparePass(b, alternateRoutes[id]!);
        expect(a.submit().score, closeTo(100, 1e-9));
        expect(b.submit().score, closeTo(100, 1e-9));
        expect(b.state.evaluation!.passed, isTrue);
      },
    );
    test('$id no evidence for blocked, unavailable or unperformed checks', () {
      final s = PracticeSession(loadCase(id));
      final a = s.definition.actions[routes[id]![1]]!;
      s.choosePurpose(a.id, 'p1');
      expect(s.perform(a.id).observation, isA<BlockedObservation>());
      expect(s.state.journal.single.isEvidence, isFalse);
      for (final c in s.definition.claims.values) {
        s.answerClaim(c.id, c.correctOptionId);
        s.citeClaim(c.id, [1]);
      }
      expect(
        () => s.citeClaim(s.definition.claims.keys.first, [999]),
        throwsArgumentError,
      );
      s.chooseConclusion(
        s.definition.conclusions.values.firstWhere((c) => c.credit == 1).id,
      );
      final result = s.submit();
      expect(result.fractions[Criterion.evidence], 0);
      expect(result.fractions[Criterion.interpretation], 0);
    });
    test('$id repeated checks do not farm scores or repair first intent', () {
      final s = PracticeSession(loadCase(id));
      perform(s, routes[id]!.first, purpose: 'p2');
      preparePass(s, routes[id]!);
      final score = evaluatePractice(s.definition, s.state).score;
      for (var i = 0; i < 5; i++) {
        perform(s, routes[id]!.first);
      }
      interpretAll(s);
      expect(s.submit().score, closeTo(score, 1e-9));
      expect(score, lessThan(100));
    });
    test(
      '$id unsafe intent cannot gain evidence or be erased without retry',
      () {
        final s = PracticeSession(loadCase(id));
        expect(
          s.perform('unsafe', confirmUnsafe: true).observation,
          isA<BlockedObservation>(),
        );
        preparePass(s, routes[id]!);
        expect(s.submit().passed, isFalse);
        expect(s.state.evaluation!.fractions[Criterion.safety], 0);
        final frozen = s.state;
        s.retry();
        expect(s.state.id, frozen.id + 1);
        expect(s.state.journal, isEmpty);
        expect(s.state.responses, isEmpty);
        expect(s.state.hypotheses, isEmpty);
        expect(s.state.conclusionId, isNull);
        expect(s.state.unsafeDecision, isFalse);
        expect(frozen.journal, isNotEmpty);
        preparePass(s, routes[id]!);
        expect(s.submit().passed, isTrue);
      },
    );
    test('$id insufficient conclusion identifies useful next safe check', () {
      final s = PracticeSession(loadCase(id));
      s.decideSafety(true);
      s.chooseConclusion('more');
      s.chooseFollowUp(routes[id]!.first);
      final result = s.submit();
      expect(result.needsMoreEvidence, isTrue);
      expect(result.passed, isFalse);
      expect(result.fractions[Criterion.diagnosis], .5);
      s.retry();
      s.chooseConclusion('more');
      expect(s.submit().fractions[Criterion.diagnosis], 0);
    });
    test('$id hypotheses preserve cited snapshots through profile changes', () {
      final s = PracticeSession(loadCase(id));
      final r = perform(s, routes[id]!.first);
      s.noteHypothesis(
        s.definition.hypotheses.keys.first,
        HypothesisStatus.supported,
        [r.sequence],
      );
      s.changeProfile('briefing');
      expect(s.state.hypotheses.values.single.recordIds, {r.sequence});
      expect(
        () => s.noteHypothesis('missing', HypothesisStatus.confirmed, []),
        throwsArgumentError,
      );
    });
  }

  test('electrical audit: starter uses coil current, headlamp conserves power, MAF has a defined bias', () {
    final st = PracticeSession(loadCase('dp01'));
    final p = st.definition.variants['fault']!.parameters;
    final current = p['sourceV']! / (p['coilOhm']! + p['contactOhm']!);
    expect(
      (perform(st, 'ST5').observation as NumericObservation).value,
      closeTo(current * 1000, 1e-9),
    );
    expect(
      (perform(st, 'ST6').observation as NumericObservation).value,
      closeTo(current * p['contactOhm']!, 1e-9),
    );
    expect((perform(st, 'ST9').observation as NumericObservation).value, 180);
    st.changeProfile('start');
    st.choosePolarity('ST6', true);
    expect((st.perform('ST6').observation as NumericObservation).value, -7.56);
    final lp = PracticeSession(loadCase('dp05'));
    final m = lp.definition.variants['fault']!.parameters;
    final i =
        m['sourceV']! / (m['lampOhm']! + m['positiveOhm']! + m['groundOhm']!);
    expect((perform(lp, 'LP6').observation as NumericObservation).value, i);
    expect(
      (perform(lp, 'LP7').observation as NumericObservation).value,
      i * i * m['lampOhm']!,
    );
    expect(
      (perform(lp, 'LP8').observation as NumericObservation).value,
      i * i * m['positiveOhm']!,
    );
    expect(i * m['sourceV']!, 24);
    final mf = PracticeSession(loadCase('dp13'));
    expect((perform(mf, 'MF3').observation as NumericObservation).value, 1.6);
    expect((perform(mf, 'MF4').observation as NumericObservation).value, 0);
    expect(perform(mf, 'MF6').observation, isA<OpenLoopObservation>());
    expect(perform(mf, 'MF9').isEvidence, isFalse);
  });

  final corruptions = <String, void Function(Map<String, Object?>)>{
    'unknown schema': (d) => d['schemaVersion'] = 2,
    'unknown field': (d) => d['fallBack'] = true,
    'missing metadata': (d) => d.remove('vehicle'),
    'missing variant': (d) => d['selectedVariantId'] = 'missing',
    'missing outcome': (d) => (d['outcomes'] as List).removeLast(),
    'duplicate outcome': (d) =>
        (d['outcomes'] as List).add((d['outcomes'] as List).first),
    'unknown hypothesis structure': (d) =>
        ((d['hypotheses'] as List).first as Map)['id'] = '',
    'unknown points': (d) =>
        ((d['actions'] as List)[1] as Map)['redPoint'] = 'nowhere',
    'orphan proof': (d) =>
        (((d['evidenceGroups'] as List).first as Map)['proof']
            as Map)['anyOf'] = [
          ['phantom'],
        ],
    'unreachable profile': (d) => d['transitions'] = [],
    'powered isolation': (d) =>
        ((d['profiles'] as List).last as Map)['powered'] = true,
    'invalid conclusion': (d) =>
        ((d['conclusions'] as List).first as Map)['kind'] = 'anything',
    'invalid claim answer': (d) =>
        ((d['claims'] as List).first as Map)['correctOptionId'] = 'missing',
    'unknown result': (d) =>
        (((d['outcomes'] as List).first as Map)['result'] as Map)['kind'] =
            'unknown',
    'invalid units': (d) =>
        (((d['outcomes'] as List)[1] as Map)['result'] as Map)['unit'] = 'A',
    'nonfinite': (d) =>
        (((d['outcomes'] as List)[1] as Map)['result'] as Map)['value'] =
            double.nan,
    'incompatible snapshot': (d) =>
        (((d['evidenceGroups'] as List).first as Map)['proof']
                as Map)['sameSnapshot'] =
            true,
  };
  for (final entry in corruptions.entries) {
    test('strict validation rejects ${entry.key}', () {
      final data = rawCase('dp01');
      entry.value(data);
      expect(() => PracticeDefinition.fromJson(data), throwsFormatException);
    });
  }
}
