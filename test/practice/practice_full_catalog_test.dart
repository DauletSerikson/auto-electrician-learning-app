import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:electrician/practice/attempt.dart';
import 'package:electrician/practice/definition.dart';
import 'package:electrician/practice/observation.dart';
import 'package:electrician/practice/practice_result_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'full_catalog_routes.dart';
import 'practice_engine_test.dart'
    as engine
    show loadCase, perform, preparePass, interpretAll;

double numeric(PracticeDefinition d, String action) =>
    (d.observationFor(d.selectedVariantId, action) as NumericObservation).value;
String packet(PracticeDefinition d, String action) =>
    (d.observationFor(d.selectedVariantId, action) as PacketObservation).text;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'completed_lessons': ['sentinel'],
    }),
  );
  test('exactly eighteen unique catalog, files, routes and prerequisite references', () {
    final catalog = jsonDecode(
      File('assets/practice/catalog.json').readAsStringSync(),
    ) as Map;
    final ids = (catalog['caseIds'] as List).cast<String>();
    expect(ids, hasLength(18));
    expect(ids.toSet(), fullRoutes.keys.toSet());
    expect(fullAlternateRoutes.keys.toSet(), ids.toSet());
    expect(ids.take(3), ['dp01', 'dp13', 'dp05']);
    final files = Directory('assets/practice/cases')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'));
    expect(files, hasLength(18));
    for (final id in ids) {
      final d = engine.loadCase(id);
      expect(d.id, id);
      for (final prerequisite in d.prerequisites) {
        expect(RegExp(r'^stage_(\d+)$').hasMatch(prerequisite), isTrue);
        expect(
          int.parse(prerequisite.split('_').last),
          inInclusiveRange(0, 13),
        );
      }
    }
  });
  for (final id in fullRoutes.keys) {
    final d = engine.loadCase(id);
    PracticeSession session() => PracticeSession(d);
    test(
      '$id schema references outcomes and safe proof routes are reachable',
      () {
        expect(d.hypotheses.length, greaterThanOrEqualTo(2));
        expect(d.actions.keys.toSet().containsAll(fullRoutes[id]!), isTrue);
        expect(
          d.actions.keys.toSet().containsAll(fullAlternateRoutes[id]!),
          isTrue,
        );
        for (final action in d.actions.values.where(
          (a) => a is! ForbiddenAction,
        )) {
          expect(
            d.observationFor(d.selectedVariantId, action.id),
            isA<PracticeObservation>(),
          );
        }
        for (final proof in [
          ...d.evidenceGroups.values.map((g) => g.requirement),
          ...d.claims.values.map((c) => c.requirement),
        ]) {
          for (final route in proof.alternatives) {
            final s = session();
            for (final action in route) {
              engine.perform(s, action);
            }
            expect(satisfiesEvidence(proof, s.state.journal), isTrue);
          }
        }
      },
    );
    test('$id correct conclusion and answers without evidence FAIL', () {
      final s = session();
      s.decideSafety(true);
      engine.interpretAll(s);
      s.chooseConclusion(
        d.conclusions.values.firstWhere((c) => c.credit == 1).id,
      );
      final result = s.submit();
      expect(result.passed, isFalse);
      expect(result.fractions[Criterion.evidence], 0);
      expect(result.fractions[Criterion.interpretation], 0);
    });
    test('$id primary and independent alternative routes both 100 PASS', () {
      for (final route in [fullRoutes[id]!, fullAlternateRoutes[id]!]) {
        final s = session();
        engine.preparePass(s, route);
        final r = s.submit();
        expect(r.score, 100);
        expect(r.passed, isTrue);
        expect(r.groups.values, everyElement(true));
        expect(r.interpretations.values, everyElement(true));
      }
    });
    test('$id full evidence cannot rescue wrong diagnosis', () {
      final s = session();
      engine.preparePass(s, fullRoutes[id]!);
      s.chooseConclusion(
        d.conclusions.values.firstWhere((c) => c.credit == 0).id,
      );
      expect(s.submit().passed, isFalse);
    });
    test('$id collecting everything without interpretation FAIL', () {
      final s = session();
      s.decideSafety(true);
      for (final a in d.actions.values.where((a) => a is! ForbiddenAction)) {
        engine.perform(s, a.id);
      }
      s.chooseConclusion(
        d.conclusions.values.firstWhere((c) => c.credit == 1).id,
      );
      expect(s.submit().passed, isFalse);
    });
    test(
      '$id insufficient citations and contradicted critical interpretation FAIL',
      () {
        for (final incorrect in [false, true]) {
          final s = session();
          engine.preparePass(s, fullRoutes[id]!);
          final c = d.claims.values.firstWhere((c) => c.critical);
          if (incorrect) {
            s.answerClaim(
              c.id,
              c.options.keys.firstWhere((x) => x != c.correctOptionId),
            );
          } else {
            s.citeClaim(c.id, []);
          }
          expect(s.submit().passed, isFalse);
        }
      },
    );
    test(
      '$id missing one primary proof action cannot claim complete evidence',
      () {
        final route = fullRoutes[id]!;
        // Every primary action must serve evidence; no ornamental mandatory steps.
        for (final omitted in route) {
          final s = session();
          engine.preparePass(s, route.where((x) => x != omitted).toList());
          expect(s.submit().passed, isFalse, reason: '$id without $omitted');
        }
      },
    );
    test(
      '$id deterministic observations and immutable captured conditions',
      () {
        final s = session();
        final first = engine.perform(s, fullRoutes[id]!.first);
        final again = engine.perform(s, fullRoutes[id]!.first);
        expect(first.observation.display, again.observation.display);
        engine.perform(s, fullRoutes[id]!.last);
        expect(
          first.conditions.snapshotId,
          d.profiles[d.actions[first.actionId]!.profileId]!.snapshotId,
        );
        expect(s.state.journal.first, same(first));
      },
    );
    test(
      '$id duplicate and extra justified safe checks do not farm or punish',
      () {
        final s = session();
        engine.preparePass(s, fullRoutes[id]!);
        for (var i = 0; i < 20; i++) {
          engine.perform(s, fullRoutes[id]!.first);
        }
        for (final a in d.actions.values.where((a) => a is! ForbiddenAction)) {
          engine.perform(
            s,
            a.id,
            purpose: a.purposes.entries
                .firstWhere((e) => e.value.justified)
                .key,
          );
        }
        final r = s.submit();
        expect(r.passed, isTrue);
        expect(r.score, 100);
      },
    );
    test('$id wrong condition or missing goal cannot create evidence', () {
      final s = session();
      final a = d.actions.values.firstWhere((a) => a is! ForbiddenAction);
      s.changeProfile(a.profileId);
      final missingGoal = s.perform(a.id);
      expect(missingGoal.isEvidence, isFalse);
      final wrong = d.actions.values.where(
        (a) => a is! ForbiddenAction && a.profileId != s.state.profileId,
      );
      if (wrong.isNotEmpty) {
        s.choosePurpose(wrong.first.id, wrong.first.purposes.keys.first);
        expect(s.perform(wrong.first.id).isEvidence, isFalse);
      }
    });
    test('$id unsafe action produces no advantage and safety blocks PASS', () {
      final s = session();
      final forbidden = d.actions.values.firstWhere(
        (a) => a is ForbiddenAction,
      );
      final record = s.perform(forbidden.id, confirmUnsafe: true);
      expect(record.observation, isA<BlockedObservation>());
      expect(record.isEvidence, isFalse);
      engine.preparePass(s, fullRoutes[id]!);
      expect(s.submit().passed, isFalse);
    });
    test(
      '$id retry clears attempt, remains deterministic and submitted state is frozen',
      () {
        final s = session();
        engine.preparePass(s, fullRoutes[id]!);
        s.noteHypothesis(d.hypotheses.keys.first, HypothesisStatus.supported, [
          1,
        ]);
        s.submit();
        expect(() => s.perform(fullRoutes[id]!.first), throwsStateError);
        final oldId = s.state.id;
        s.retry();
        expect(s.state.id, oldId + 1);
        expect(s.state.profileId, d.initialProfileId);
        expect(s.state.journal, isEmpty);
        expect(s.state.hypotheses, isEmpty);
        expect(s.state.responses, isEmpty);
        expect(s.state.purposes, isEmpty);
        expect(s.state.reversePolarity, isEmpty);
        expect(s.state.conclusionId, isNull);
        expect(s.state.safetyAccepted, isFalse);
        engine.preparePass(s, fullRoutes[id]!);
        expect(s.submit().score, 100);
      },
    );
    test(
      '$id persistent best and receipt survive worse repeat and repository recreation',
      () async {
        final r = PreferencesPracticeResultRepository();
        final s = session();
        engine.preparePass(s, fullRoutes[id]!);
        final pass = s.submit();
        Future<void> save(String token, PracticeEvaluation result) async {
          await r.complete(
            scenarioId: id,
            submissionId: token,
            evaluation: result,
            completedAt: DateTime.utc(2026, 11, 2),
          );
        }

        await save('pass', pass);
        await save('pass', pass);
        s.retry();
        s.chooseConclusion(
          d.conclusions.values.firstWhere((c) => c.credit == 0).id,
        );
        await save('fail', s.submit());
        final read = await PreferencesPracticeResultRepository().read(id);
        expect(read!.passed, isTrue);
        expect(read.bestScore, 100);
        expect(read.completedAttempts, 2);
        expect(
          (await SharedPreferences.getInstance()).getStringList(
            'completed_lessons',
          ),
          ['sentinel'],
        );
      },
    );
  }
  test(
    'eighteen persisted scenarios remain isolated when one record is corrupted',
    () async {
      final r = PreferencesPracticeResultRepository();
      for (final id in fullRoutes.keys) {
        final s = PracticeSession(engine.loadCase(id));
        engine.preparePass(s, fullRoutes[id]!);
        await r.complete(
          scenarioId: id,
          submissionId: id,
          evaluation: s.submit(),
          completedAt: DateTime.utc(2026, 11, 2),
        );
      }
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), hasLength(19));
      await prefs.setString(
        PreferencesPracticeResultRepository.keyFor('dp08'),
        '{broken',
      );
      for (final id in fullRoutes.keys) {
        if (id == 'dp08') {
          await expectLater(r.read(id), throwsFormatException);
        } else {
          final summary = await r.read(id);
          expect(summary!.passed, isTrue);
          expect(summary.completedAttempts, 1);
          expect(summary.bestScore, 100);
        }
      }
      expect(prefs.getStringList('completed_lessons'), ['sentinel']);
    },
  );
  test('SRS is bounded referral: hidden component cannot be proved even with all available data', () {
    final d = engine.loadCase('dp18');
    expect(d.assessmentGoal, AssessmentGoal.boundedDisposition);
    expect(d.actions.values.whereType<ReadingAction>(), isEmpty);
    expect(
      d.conclusions.values.where((c) => c.credit == 1).single.kind,
      ConclusionKind.referral,
    );
    final s = PracticeSession(d);
    engine.preparePass(s, fullRoutes['dp18']!);
    for (final c in d.conclusions.values.where(
      (c) => c.kind == ConclusionKind.replacement,
    )) {
      s.chooseConclusion(c.id);
      expect(evaluatePractice(d, s.state).passed, isFalse);
    }
    expect(d.hypotheses, hasLength(4));
  });
  test('ABS, SRS and HV provide analysis packets only, not physical measurement actions', () {
    for (final id in ['dp14', 'dp17', 'dp18']) {
      final d = engine.loadCase(id);
      expect(d.actions.values.whereType<ReadingAction>(), isEmpty);
      expect(
        d.actions.values.where(
          (a) => a.safetyClass == SafetyClass.qualifiedProcedureOnly,
        ),
        isEmpty,
      );
      for (final a in d.actions.values.whereType<DocumentAction>()) {
        expect(
          d.observationFor(d.selectedVariantId, a.id),
          isA<PacketObservation>(),
        );
      }
    }
  });
  test('electrical audit CKP source, isolated path and reference load are consistent', () {
    final d = engine.loadCase('dp02');
    expect(numeric(d, 'C1'), 5);
    expect(numeric(d, 'C2'), 0);
    expect(d.observationFor('fault', 'C4'), isA<OpenLoopObservation>());
    expect(packet(d, 'C3'), contains('G–N=0.004 V'));
    expect(.2 * .020, .004);
  });
  test('sleep current, lamp power and added overnight charge balance', () {
    final d = engine.loadCase('dp03');
    final p = d.variants['fault']!.parameters;
    expect(numeric(d, 'S1') - numeric(d, 'S2'), closeTo(.40, 1e-12));
    expect(p['lampW'], closeTo(p['supplyV']! * p['lampA']!, 1e-12));
    expect(p['lampOhm'], p['supplyV']! / p['lampA']!);
    expect(p['extraAh'], p['lampA']! * p['windowHours']!);
    expect(packet(d, 'S5'), contains('Awake'));
  });
  test(
    'generator target, positive drop, branch current and loss conserve power',
    () {
      final d = engine.loadCase('dp04');
      final p = d.variants['fault']!.parameters;
      expect(
        numeric(d, 'G1') - numeric(d, 'G2'),
        closeTo(numeric(d, 'G3'), 1e-12),
      );
      expect(numeric(d, 'G3'), numeric(d, 'G4') * p['contactOhm']!);
      expect(p['lossW'], numeric(d, 'G3') * numeric(d, 'G4'));
      expect(numeric(d, 'G5'), 0);
      expect(numeric(d, 'G6'), 0);
    },
  );
  test('fuse localization uses isolated sections and no powered short-circuit experiment', () {
    final d = engine.loadCase('dp06');
    expect(numeric(d, 'F1'), .2);
    for (final id in ['F2', 'F3']) {
      expect(d.observationFor('fault', id), isA<OpenLoopObservation>());
    }
    for (final a in d.actions.values.whereType<ReadingAction>()) {
      expect(d.profiles[a.profileId]!.isolated, isTrue);
    }
  });
  test('return loss is loaded potential, not proof from OFF zero', () {
    final d = engine.loadCase('dp07');
    expect(numeric(d, 'M1'), numeric(d, 'M2') + numeric(d, 'M3'));
    expect(numeric(d, 'M2') / numeric(d, 'M4'), 1);
    expect(numeric(d, 'M3') / numeric(d, 'M4'), 5);
    expect(numeric(d, 'M5'), 0);
  });
  test(
    'intermittent records preserve simultaneous failure and good windows',
    () {
      final d = engine.loadCase('dp08');
      expect(numeric(d, 'I2'), 2.5);
      expect(numeric(d, 'I3'), 0);
      expect(
        d.profiles[d.actions['I2']!.profileId]!.snapshotId,
        d.profiles[d.actions['I3']!.profileId]!.snapshotId,
      );
      expect(packet(d, 'I1'), contains('S–N=2.5 V, E–N=2.5 V'));
      expect(packet(d, 'I4'), contains('1200…1210 ms'));
      expect(packet(d, 'I4'), contains('не режим омметра'));
    },
  );
  test('door bridge and motor voltages are differential and open conductor is isolated', () {
    final d = engine.loadCase('dp09');
    expect(numeric(d, 'L1'), 12);
    expect(numeric(d, 'L2'), 0);
    expect(d.observationFor('fault', 'L4'), isA<OpenLoopObservation>());
    expect(packet(d, 'L3'), contains('a=b=0 V, ток=0 A'));
  });
  test(
    'window input pull-up, pressed contact and intact wire are distinguished',
    () {
      final d = engine.loadCase('dp10');
      expect(numeric(d, 'W1'), 5);
      expect(numeric(d, 'W2'), .2);
      expect(d.observationFor('fault', 'W3'), isA<OpenLoopObservation>());
      expect(packet(d, 'W0'), contains('software_request=false'));
    },
  );
  test('wiper stand capture is separated from stationary complaint', () {
    final d = engine.loadCase('dp11');
    expect(packet(d, 'K1'), contains('[0,5,0,5] V'));
    expect(packet(d, 'K2'), contains('[5,5,5,5] V'));
    expect(d.observationFor('fault', 'K3'), isA<OpenLoopObservation>());
    expect(packet(d, 'K0'), contains('motor_command=withheld'));
  });
  test('heater open protection explains low path but does not establish overheating cause', () {
    final d = engine.loadCase('dp12');
    expect(numeric(d, 'H1'), 12);
    expect(numeric(d, 'H2'), 0);
    expect(d.observationFor('fault', 'H3'), isA<OpenLoopObservation>());
    expect(packet(d, 'H4'), contains('не предоставлены'));
    expect(packet(d, 'H0'), contains('HIGH идёт по другой'));
  });
  test(
    'ABS pole-pair, frequency and revolution time match prepared captures',
    () {
      final d = engine.loadCase('dp14');
      final p = d.variants['fault']!.parameters;
      expect(p['polePairs']! * p['rpm']! / 60, p['frequencyHz']);
      expect(60 / p['rpm']!, p['revolutionS']);
      expect(1000 / p['frequencyHz']!, p['periodMs']);
      final times = RegExp(r'0\.\d{3}')
          .allMatches(packet(d, 'A1'))
          .map((m) => double.parse(m.group(0)!))
          .toList();
      expect(times, [.120, .360, .600, .240]);
      expect(times[1] - times[0], closeTo(p['revolutionS']!, 1e-12));
      expect(times[2] - times[1], closeTo(p['revolutionS']!, 1e-12));
    },
  );
  test(
    'missing ECU power is not floating and ground proof is separately loaded',
    () {
      final d = engine.loadCase('dp15');
      expect(numeric(d, 'N1'), 12);
      expect(numeric(d, 'N2'), 0);
      expect(d.variants['fault']!.parameters['inputLoadOhm'], 100000);
      expect(d.observationFor('fault', 'N4'), isA<OpenLoopObservation>());
      expect(packet(d, 'N3'), contains('0.10 A'));
    },
  );
  test(
    'AC samples obey periodic high-pass step and exponential decay, unlike DC',
    () {
      final d = engine.loadCase('dp16');
      final p = d.variants['fault']!.parameters;
      final a = 5 / (1 + math.exp(-5 / 20));
      final b = a * math.exp(-5 / 20);
      expect(a + b, closeTo(5, 1e-12));
      expect(p['acPeakV'], closeTo(a, 1e-12));
      expect(p['acEndV'], closeTo(b, 1e-12));
      final values = RegExp(r'([+−])([0-9]+\.[0-9]+) V')
          .allMatches(packet(d, 'T1'))
          .map((m) => (m.group(1) == '−' ? -1 : 1) * double.parse(m.group(2)!))
          .toList();
      final mid = a * math.exp(-2.5 / 20);
      final expected = [a, mid, b, -a, -mid, -b, a];
      expect(values, hasLength(expected.length));
      for (var i = 0; i < values.length; i++) {
        expect(values[i], closeTo(expected[i], .000001));
      }
      expect(packet(d, 'T2'), contains('среднее 2.5 V'));
    },
  );
  test(
    'EV session authorization is linked and not_run is not a passing HV test',
    () {
      final d = engine.loadCase('dp17');
      expect(packet(d, 'E1'), contains('EV17, t=10 s'));
      expect(packet(d, 'E2'), contains('EV17, t=10 s'));
      expect(packet(d, 'E1'), contains('not_run'));
      expect(packet(d, 'E2'), contains('authorization=rejected'));
      expect(packet(d, 'E4'), contains('нет диагностических данных OBC'));
    },
  );
}
