import 'definition.dart';
import 'observation.dart';

enum HypothesisStatus { untested, supported, contradicted, confirmed }

final class HypothesisNote {
  final HypothesisStatus status;
  final Set<int> recordIds;
  HypothesisNote(this.status, Iterable<int> records)
    : recordIds = Set.unmodifiable(records);
}

final class ClaimResponse {
  final String? optionId;
  final Set<int> recordIds;
  ClaimResponse(this.optionId, Iterable<int> records)
    : recordIds = Set.unmodifiable(records);
}

/// A captured result, never recomputed from the current profile or UI state.
final class EvidenceRecord {
  final int attemptId, sequence, contentRevision;
  final String actionId, variantId, purposeId, permittedScope;
  final ConditionProfile conditions;
  final bool reversePolarity;
  final PracticeObservation observation;
  EvidenceRecord({
    required this.attemptId,
    required this.sequence,
    required this.contentRevision,
    required this.actionId,
    required this.variantId,
    required this.purposeId,
    required this.conditions,
    required this.observation,
    required this.reversePolarity,
    required this.permittedScope,
  });

  bool get isEvidence =>
      observation is! BlockedObservation &&
      observation is! UnavailableObservation;
}

final class PracticeEvaluation {
  final Map<Criterion, double> fractions;
  final Map<String, bool> groups, interpretations;
  final double score;
  final bool passed, needsMoreEvidence;
  final List<String> feedback;
  PracticeEvaluation({
    required Map<Criterion, double> fractions,
    required Map<String, bool> groups,
    required Map<String, bool> interpretations,
    required this.score,
    required this.passed,
    required this.needsMoreEvidence,
    required Iterable<String> feedback,
  }) : fractions = Map.unmodifiable(fractions),
       groups = Map.unmodifiable(groups),
       interpretations = Map.unmodifiable(interpretations),
       feedback = List.unmodifiable(feedback);
}

final class PracticeAttempt {
  final int id;
  final String profileId;
  final Map<String, String> purposes;
  final Map<String, bool> reversePolarity;
  final Map<String, HypothesisNote> hypotheses;
  final Map<String, ClaimResponse> responses;
  final List<EvidenceRecord> journal;
  final bool safetyAccepted, unsafeDecision;
  final String? conclusionId, followUpActionId;
  final PracticeEvaluation? evaluation;

  PracticeAttempt({
    required this.id,
    required this.profileId,
    Map<String, String> purposes = const {},
    Map<String, bool> reversePolarity = const {},
    Map<String, HypothesisNote> hypotheses = const {},
    Map<String, ClaimResponse> responses = const {},
    Iterable<EvidenceRecord> journal = const [],
    this.safetyAccepted = false,
    this.unsafeDecision = false,
    this.conclusionId,
    this.followUpActionId,
    this.evaluation,
  }) : purposes = Map.unmodifiable(purposes),
       reversePolarity = Map.unmodifiable(reversePolarity),
       hypotheses = Map.unmodifiable(hypotheses),
       responses = Map.unmodifiable(responses),
       journal = List.unmodifiable(journal);

  bool get submitted => evaluation != null;

  PracticeAttempt copyWith({
    String? profileId,
    Map<String, String>? purposes,
    Map<String, bool>? reversePolarity,
    Map<String, HypothesisNote>? hypotheses,
    Map<String, ClaimResponse>? responses,
    Iterable<EvidenceRecord>? journal,
    bool? safetyAccepted,
    bool? unsafeDecision,
    String? conclusionId,
    String? followUpActionId,
    PracticeEvaluation? evaluation,
  }) => PracticeAttempt(
    id: id,
    profileId: profileId ?? this.profileId,
    purposes: purposes ?? this.purposes,
    reversePolarity: reversePolarity ?? this.reversePolarity,
    hypotheses: hypotheses ?? this.hypotheses,
    responses: responses ?? this.responses,
    journal: journal ?? this.journal,
    safetyAccepted: safetyAccepted ?? this.safetyAccepted,
    unsafeDecision: unsafeDecision ?? this.unsafeDecision,
    conclusionId: conclusionId ?? this.conclusionId,
    followUpActionId: followUpActionId ?? this.followUpActionId,
    evaluation: evaluation ?? this.evaluation,
  );
}

/// Finite, deterministic scenario engine. A route owner holds this session.
/// All mutable controls are projected from [state], including offscreen drafts.
final class PracticeSession {
  final PracticeDefinition definition;
  late PracticeAttempt _state;
  PracticeSession(this.definition) {
    _state = PracticeAttempt(id: 1, profileId: definition.initialProfileId);
  }
  PracticeAttempt get state => _state;
  void _editable() {
    if (_state.submitted) throw StateError('Attempt is frozen until retry');
  }

  PracticeAction _action(String id) =>
      definition.actions[id] ?? (throw ArgumentError.value(id, 'actionId'));
  void _recordIds(Iterable<int> ids) {
    if (ids.any((id) => !_state.journal.any((r) => r.sequence == id))) {
      throw ArgumentError('Unknown evidence record');
    }
  }

  void changeProfile(String id) {
    _editable();
    if (id != _state.profileId &&
        !(definition.transitions[_state.profileId] ?? {}).contains(id)) {
      throw ArgumentError('Unavailable profile transition');
    }
    _state = _state.copyWith(profileId: id);
  }

  void choosePurpose(String actionId, String purposeId) {
    _editable();
    if (!_action(actionId).purposes.containsKey(purposeId)) {
      throw ArgumentError('Unknown purpose');
    }
    _state = _state.copyWith(
      purposes: {..._state.purposes, actionId: purposeId},
    );
  }

  void choosePolarity(String actionId, bool reverse) {
    _editable();
    final action = _action(actionId);
    if (action is! ReadingAction || action.quantity != Quantity.voltage) {
      throw ArgumentError('Only voltage readings support reversed probes');
    }
    _state = _state.copyWith(
      reversePolarity: {..._state.reversePolarity, actionId: reverse},
    );
  }

  void decideSafety(bool accepted) {
    _editable();
    _state = _state.copyWith(
      safetyAccepted: accepted,
      unsafeDecision: _state.unsafeDecision || !accepted,
    );
  }

  void withdrawSafetyAcknowledgement() {
    _editable();
    _state = _state.copyWith(safetyAccepted: false);
  }

  EvidenceRecord perform(String actionId, {bool confirmUnsafe = false}) {
    _editable();
    final action = _action(actionId);
    final profile = definition.profiles[_state.profileId]!;
    final purposeId = _state.purposes[actionId] ?? '';
    final reverse = _state.reversePolarity[actionId] ?? false;
    PracticeObservation result;
    if (action case ForbiddenAction(:final reason)) {
      result = BlockedObservation(reason);
      if (confirmUnsafe) _state = _state.copyWith(unsafeDecision: true);
    } else if (action.profileId != profile.id) {
      result = BlockedObservation(
        'Нужен профиль «${definition.profiles[action.profileId]!.label}».',
      );
    } else if (purposeId.isEmpty) {
      result = const BlockedObservation('Сначала выберите цель проверки.');
    } else {
      result = definition.observationFor(
        definition.selectedVariantId,
        actionId,
      );
      if (reverse && result is NumericObservation) result = result.reversed;
    }
    final record = EvidenceRecord(
      attemptId: _state.id,
      sequence: _state.journal.length + 1,
      contentRevision: definition.contentRevision,
      actionId: actionId,
      variantId: definition.selectedVariantId,
      purposeId: purposeId,
      conditions: profile,
      observation: result,
      reversePolarity: reverse,
      permittedScope: action.scope,
    );
    _state = _state.copyWith(journal: [..._state.journal, record]);
    return record;
  }

  void noteHypothesis(
    String id,
    HypothesisStatus status,
    Iterable<int> records,
  ) {
    _editable();
    if (!definition.hypotheses.containsKey(id)) {
      throw ArgumentError('Unknown hypothesis');
    }
    _recordIds(records);
    _state = _state.copyWith(
      hypotheses: {..._state.hypotheses, id: HypothesisNote(status, records)},
    );
  }

  void answerClaim(String id, String optionId) {
    _editable();
    if (!(definition.claims[id]?.options.containsKey(optionId) ?? false)) {
      throw ArgumentError('Unknown claim option');
    }
    _state = _state.copyWith(
      responses: {
        ..._state.responses,
        id: ClaimResponse(optionId, _state.responses[id]?.recordIds ?? {}),
      },
    );
  }

  void citeClaim(String id, Iterable<int> recordIds) {
    _editable();
    if (!definition.claims.containsKey(id)) {
      throw ArgumentError('Unknown claim');
    }
    _recordIds(recordIds);
    _state = _state.copyWith(
      responses: {
        ..._state.responses,
        id: ClaimResponse(_state.responses[id]?.optionId, recordIds),
      },
    );
  }

  void chooseConclusion(String id) {
    _editable();
    if (!definition.conclusions.containsKey(id)) {
      throw ArgumentError('Unknown conclusion');
    }
    _state = _state.copyWith(conclusionId: id);
  }

  void chooseFollowUp(String id) {
    _editable();
    if (_action(id) is ForbiddenAction) throw ArgumentError('Unsafe follow-up');
    _state = _state.copyWith(followUpActionId: id);
  }

  PracticeEvaluation submit() {
    _editable();
    if (_state.conclusionId == null) throw StateError('Select a conclusion');
    final result = evaluatePractice(definition, _state);
    _state = _state.copyWith(evaluation: result);
    return result;
  }

  void retry() {
    _state = PracticeAttempt(
      id: _state.id + 1,
      profileId: definition.initialProfileId,
    );
  }
}

bool satisfiesEvidence(
  EvidenceRequirement proof,
  Iterable<EvidenceRecord> records,
) {
  final valid = records.where((x) => x.isEvidence).toList();
  for (final route in proof.alternatives) {
    if (!proof.sameSnapshot) {
      if (valid.map((x) => x.actionId).toSet().containsAll(route)) return true;
    } else {
      for (final snapshot
          in valid.map((x) => x.conditions.snapshotId).toSet()) {
        if (valid
            .where((r) => r.conditions.snapshotId == snapshot)
            .map((r) => r.actionId)
            .toSet()
            .containsAll(route)) {
          return true;
        }
      }
    }
  }
  return false;
}

PracticeEvaluation evaluatePractice(
  PracticeDefinition d,
  PracticeAttempt state,
) {
  final records = state.journal
      .where(
        (r) =>
            r.attemptId == state.id &&
            r.variantId == d.selectedVariantId &&
            r.contentRevision == d.contentRevision,
      )
      .toList();
  final groups = {
    for (final g in d.evidenceGroups.values)
      g.id: satisfiesEvidence(g.requirement, records),
  };
  final claimEvidence = {
    for (final c in d.claims.values)
      c.id: satisfiesEvidence(
        c.requirement,
        records.where(
          (r) => state.responses[c.id]?.recordIds.contains(r.sequence) ?? false,
        ),
      ),
  };
  final interpretations = {
    for (final c in d.claims.values)
      c.id:
          state.responses[c.id]?.optionId == c.correctOptionId &&
          claimEvidence[c.id]!,
  };
  final unique = <String, EvidenceRecord>{};
  for (final record in records.where((r) => r.isEvidence)) {
    unique.putIfAbsent(record.actionId, () => record);
  }
  final conclusion = d.conclusions[state.conclusionId];
  var diagnosis = conclusion?.credit ?? 0;
  final completeEvidence = groups.values.every((x) => x);
  if (conclusion?.kind == ConclusionKind.insufficient &&
      d.assessmentGoal == AssessmentGoal.confirmable) {
    final next = state.followUpActionId;
    final useful =
        next != null &&
        !unique.containsKey(next) &&
        d.evidenceGroups.values
            .where((g) => !groups[g.id]!)
            .any(
              (g) => g.requirement.alternatives.any(
                (route) => route.contains(next),
              ),
            );
    if (completeEvidence || !useful) diagnosis = 0;
  }
  final fractions = <Criterion, double>{
    Criterion.diagnosis: diagnosis,
    Criterion.evidence: groups.values.where((x) => x).length / groups.length,
    Criterion.interpretation:
        interpretations.values.where((x) => x).length / interpretations.length,
    Criterion.safety: state.safetyAccepted && !state.unsafeDecision ? 1 : 0,
    Criterion.route: unique.isEmpty
        ? 0
        : unique.values
                  .where(
                    (r) =>
                        d
                            .actions[r.actionId]!
                            .purposes[r.purposeId]
                            ?.justified ??
                        false,
                  )
                  .length /
              unique.length,
  };
  final score = fractions.entries.fold(
    0.0,
    (sum, e) => sum + d.weights[e.key]! * e.value,
  );
  final criticalInterpreted = d.claims.values
      .where((c) => c.critical)
      .every((c) => interpretations[c.id]!);
  final passed =
      diagnosis == 1 &&
      completeEvidence &&
      criticalInterpreted &&
      fractions[Criterion.safety] == 1 &&
      score >= d.passingScore;
  final feedback = <String>[
    if (!completeEvidence)
      'Не подтверждены: ${d.evidenceGroups.values.where((g) => !groups[g.id]!).map((g) => g.label).join('; ')}.',
    for (final c in d.claims.values.where((c) => !interpretations[c.id]!))
      claimEvidence[c.id]!
          ? '${c.prompt}: ${c.explanation}'
          : '${c.prompt}: не хватает связанных доказательств. Выполните нужные проверки и свяжите их записи с интерпретацией. Правильный ответ без измерений не подтверждает вывод.',
    if (fractions[Criterion.safety] != 1) 'Безопасность: примите безопасную границу. Подтверждённое опасное решение требует новой попытки.',
    if (conclusion != null)
      (completeEvidence && criticalInterpreted) ||
              (conclusion.kind == ConclusionKind.insufficient &&
                  diagnosis == .5)
          ? conclusion.explanation
          : 'Выбранный вывод не подтверждён собранными и интерпретированными данными.',
    if (fractions[Criterion.route]! < 1) 'Не все проверки имеют обоснованную цель. Повтор одной записи не увеличивает баллы.',
  ];
  return PracticeEvaluation(
    fractions: fractions,
    groups: groups,
    interpretations: interpretations,
    score: score,
    passed: passed,
    needsMoreEvidence:
        conclusion?.kind == ConclusionKind.insufficient && !completeEvidence,
    feedback: feedback,
  );
}
