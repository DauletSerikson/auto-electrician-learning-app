import 'json_data.dart';
import 'observation.dart';

enum SafetyClass { safeAnalysis, qualifiedProcedureOnly, forbidden }

enum ConclusionKind { confirmed, insufficient, referral, replacement }

enum AssessmentGoal { confirmable, boundedDisposition }

enum Criterion { diagnosis, evidence, interpretation, safety, route }

final class PracticeOption {
  final String id;
  final String label;
  const PracticeOption(this.id, this.label);
  factory PracticeOption.parse(JsonData data) {
    data.fields({'id', 'label'});
    return PracticeOption(data.text('id'), data.text('label'));
  }
}

final class DiagnosticPurpose {
  final String id;
  final String label;
  final bool justified;
  DiagnosticPurpose(JsonData data)
    : id = data.text('id'),
      label = data.text('label'),
      justified = data.flag('justified') {
    data.fields({'id', 'label', 'justified'});
  }
}

final class ConditionProfile {
  final String id, label, load, command, snapshotId;
  final bool powered, isolated;
  final double temperatureC;
  ConditionProfile(JsonData data)
    : id = data.text('id'),
      label = data.text('label'),
      load = data.text('load'),
      command = data.text('command'),
      snapshotId = data.text('snapshotId'),
      powered = data.flag('powered'),
      isolated = data.flag('isolated'),
      temperatureC = data.number('temperatureC') {
    data.fields({
      'id',
      'label',
      'load',
      'command',
      'snapshotId',
      'powered',
      'isolated',
      'temperatureC',
    });
    if (isolated && powered) data.fail('isolated profile cannot be powered');
  }
  String get description =>
      '$label • $load • $command • $temperatureC °C\n'
      'Снимок: $snapshotId. ${isolated ? 'Изоляция подтверждена в отчёте.' : 'Цепь не изолирована.'}';
}

sealed class PracticeAction {
  final String id, title, profileId, scope;
  final SafetyClass safetyClass;
  final Map<String, DiagnosticPurpose> purposes;
  PracticeAction(JsonData data)
    : id = data.text('id'),
      title = data.text('title'),
      profileId = data.text('profileId'),
      scope = data.text('kind') == 'forbidden'
          ? data.text('reason')
          : data.text('scope'),
      safetyClass = data.enumeration('safetyClass', SafetyClass.values),
      purposes = data.text('kind') == 'forbidden'
          ? const {}
          : indexedById(
              data.objects('purposes').map(DiagnosticPurpose.new),
              (x) => x.id,
              '${data.path}.purposes',
            );

  factory PracticeAction.parse(JsonData data) => switch (data.text('kind')) {
    'reading' => ReadingAction(data),
    'document' => DocumentAction(data),
    'forbidden' => ForbiddenAction(data),
    _ => data.fail('unsupported action kind'),
  };
}

const _actionFields = {'id', 'title', 'kind', 'profileId', 'safetyClass'};

final class ReadingAction extends PracticeAction {
  final String redPoint, blackPoint;
  final Quantity quantity;
  ReadingAction(JsonData data)
    : redPoint = data.text('redPoint'),
      blackPoint = data.text('blackPoint'),
      quantity = data.enumeration('quantity', Quantity.values),
      super(data) {
    data.fields({
      ..._actionFields,
      'redPoint',
      'blackPoint',
      'quantity',
      'purposes',
      'scope',
    });
    if (safetyClass != SafetyClass.qualifiedProcedureOnly) {
      data.fail('measurements require a prepared specialist record');
    }
  }
}

final class DocumentAction extends PracticeAction {
  DocumentAction(JsonData data) : super(data) {
    data.fields({..._actionFields, 'purposes', 'scope'});
    if (safetyClass != SafetyClass.safeAnalysis) data.fail('unsafe document');
  }
}

final class ForbiddenAction extends PracticeAction {
  final String reason;
  ForbiddenAction(JsonData data) : reason = data.text('reason'), super(data) {
    data.fields({..._actionFields, 'reason'});
    if (safetyClass != SafetyClass.forbidden) data.fail('invalid safety class');
  }
}

final class EvidenceRequirement {
  final List<Set<String>> alternatives;
  final bool sameSnapshot;
  EvidenceRequirement(JsonData data)
    : sameSnapshot = data.flag('sameSnapshot'),
      alternatives = List.unmodifiable(
        data.list('anyOf').map((value) {
          if (value is! List<Object?> ||
              value.isEmpty ||
              value.any((x) => x is! String || x.trim().isEmpty)) {
            data.fail('anyOf requires nonempty lists of action IDs');
          }
          final ids = value.cast<String>().toSet();
          if (ids.length != value.length) data.fail('duplicate proof action');
          return Set<String>.unmodifiable(ids);
        }),
      ) {
    data.fields({'anyOf', 'sameSnapshot'});
    if (alternatives.isEmpty) data.fail('empty proof');
  }
}

final class EvidenceGroup {
  final String id, label;
  final EvidenceRequirement requirement;
  EvidenceGroup(JsonData data)
    : id = data.text('id'),
      label = data.text('label'),
      requirement = EvidenceRequirement(data.child('proof')) {
    data.fields({'id', 'label', 'proof'});
  }
}

final class InterpretationClaim {
  final String id, prompt, correctOptionId, explanation;
  final bool critical;
  final Map<String, PracticeOption> options;
  final EvidenceRequirement requirement;
  InterpretationClaim(JsonData data)
    : id = data.text('id'),
      prompt = data.text('prompt'),
      correctOptionId = data.text('correctOptionId'),
      explanation = data.text('explanation'),
      critical = data.flag('critical'),
      options = indexedById(
        data.objects('options').map(PracticeOption.parse),
        (x) => x.id,
        '${data.path}.options',
      ),
      requirement = EvidenceRequirement(data.child('proof')) {
    data.fields({
      'id',
      'prompt',
      'correctOptionId',
      'explanation',
      'critical',
      'options',
      'proof',
    });
    if (!options.containsKey(correctOptionId) || options.length < 2) {
      data.fail('invalid interpretation choices');
    }
  }
}

final class DiagnosticConclusion {
  final String id, label, explanation;
  final ConclusionKind kind;
  final double credit;
  DiagnosticConclusion(JsonData data)
    : id = data.text('id'),
      label = data.text('label'),
      explanation = data.text('explanation'),
      kind = data.enumeration('kind', ConclusionKind.values),
      credit = data.number('credit') {
    data.fields({'id', 'label', 'explanation', 'kind', 'credit'});
    if (![0.0, 0.5, 1.0].contains(credit)) {
      data.fail('invalid diagnosis credit');
    }
  }
}

final class FaultState {
  final String id, description;
  final Map<String, double> parameters;
  FaultState(JsonData data)
    : id = data.text('id'),
      description = data.text('description'),
      parameters = Map.unmodifiable({
        for (final key in data.child('parameters').value.keys)
          key: data.child('parameters').number(key),
      }) {
    data.fields({'id', 'description', 'parameters'});
  }
}

final class ActionOutcome {
  final String variantId, actionId;
  final PracticeObservation observation;
  ActionOutcome(JsonData data)
    : variantId = data.text('variantId'),
      actionId = data.text('actionId'),
      observation = PracticeObservation.fromJson(data.child('result')) {
    data.fields({'variantId', 'actionId', 'result'});
  }
}

final class PracticeDefinition {
  final String id,
      title,
      difficulty,
      vehicle,
      symptoms,
      topology,
      safety,
      explanation,
      selectedVariantId,
      initialProfileId;
  final int contentRevision, rubricVersion;
  final AssessmentGoal assessmentGoal;
  final List<String> prerequisites;
  final Map<String, PracticeOption> points, hypotheses;
  final Map<String, ConditionProfile> profiles;
  final Map<String, Set<String>> transitions;
  final Map<String, FaultState> variants;
  final Map<String, PracticeAction> actions;
  final Map<String, EvidenceGroup> evidenceGroups;
  final Map<String, InterpretationClaim> claims;
  final Map<String, DiagnosticConclusion> conclusions;
  final Map<Criterion, double> weights;
  final double passingScore;
  final Map<(String, String), PracticeObservation> _outcomes;

  PracticeDefinition._(JsonData data)
    : id = data.text('id'),
      title = data.text('title'),
      difficulty = data.text('difficulty'),
      vehicle = data.text('vehicle'),
      symptoms = data.text('symptoms'),
      topology = data.text('topology'),
      safety = data.text('safety'),
      explanation = data.text('explanation'),
      selectedVariantId = data.text('selectedVariantId'),
      initialProfileId = data.text('initialProfileId'),
      contentRevision = data.integer('contentRevision'),
      rubricVersion = data.integer('rubricVersion'),
      assessmentGoal = data.enumeration(
        'assessmentGoal',
        AssessmentGoal.values,
      ),
      prerequisites = data.texts('prerequisites'),
      points = indexedById(
        data.objects('points').map(PracticeOption.parse),
        (x) => x.id,
        'points',
      ),
      hypotheses = indexedById(
        data.objects('hypotheses').map(PracticeOption.parse),
        (x) => x.id,
        'hypotheses',
      ),
      profiles = indexedById(
        data.objects('profiles').map(ConditionProfile.new),
        (x) => x.id,
        'profiles',
      ),
      variants = indexedById(
        data.objects('faultVariants').map(FaultState.new),
        (x) => x.id,
        'faultVariants',
      ),
      actions = indexedById(
        data.objects('actions').map(PracticeAction.parse),
        (x) => x.id,
        'actions',
      ),
      evidenceGroups = indexedById(
        data.objects('evidenceGroups').map(EvidenceGroup.new),
        (x) => x.id,
        'evidenceGroups',
      ),
      claims = indexedById(
        data.objects('claims').map(InterpretationClaim.new),
        (x) => x.id,
        'claims',
      ),
      conclusions = indexedById(
        data.objects('conclusions').map(DiagnosticConclusion.new),
        (x) => x.id,
        'conclusions',
      ),
      transitions = _transitions(data),
      weights = _weights(data.child('rubric')),
      passingScore = data.child('rubric').number('passingScore'),
      _outcomes = _readOutcomes(data) {
    data.fields({
      'schemaVersion',
      'id',
      'title',
      'difficulty',
      'vehicle',
      'symptoms',
      'topology',
      'safety',
      'explanation',
      'selectedVariantId',
      'initialProfileId',
      'contentRevision',
      'rubricVersion',
      'assessmentGoal',
      'prerequisites',
      'points',
      'hypotheses',
      'profiles',
      'faultVariants',
      'actions',
      'evidenceGroups',
      'claims',
      'conclusions',
      'transitions',
      'rubric',
      'outcomes',
    });
    if (data.integer('schemaVersion') != 1) {
      data.fail('unsupported schemaVersion');
    }
    _validate(data);
  }

  factory PracticeDefinition.fromJson(Object? value) =>
      PracticeDefinition._(JsonData(value, 'practice'));

  static Map<String, Set<String>> _transitions(JsonData data) {
    final result = <String, Set<String>>{};
    for (final row in data.objects('transitions')) {
      row.fields({'from', 'to'});
      final from = row.text('from'), to = row.text('to');
      if (!(result[from] ??= {}).add(to)) row.fail('duplicate transition');
    }
    return Map.unmodifiable({
      for (final e in result.entries) e.key: Set<String>.unmodifiable(e.value),
    });
  }

  static Map<Criterion, double> _weights(JsonData data) {
    data.fields({'passingScore', 'weights'});
    final w = data.child('weights');
    w.fields(Criterion.values.map((x) => x.name).toSet());
    final result = {for (final c in Criterion.values) c: w.number(c.name)};
    if (result.values.any((x) => x <= 0) ||
        (result.values.fold(0.0, (a, b) => a + b) - 100).abs() > 1e-9 ||
        data.number('passingScore') <= 0 ||
        data.number('passingScore') > 100) {
      data.fail('invalid rubric');
    }
    return Map.unmodifiable(result);
  }

  static Map<(String, String), PracticeObservation> _readOutcomes(
    JsonData data,
  ) {
    final result = <(String, String), PracticeObservation>{};
    for (final row in data.objects('outcomes').map(ActionOutcome.new)) {
      final key = (row.variantId, row.actionId);
      if (result.containsKey(key)) data.fail('duplicate outcome $key');
      result[key] = row.observation;
    }
    return Map.unmodifiable(result);
  }

  PracticeObservation observationFor(String variant, String action) =>
      _outcomes[(variant, action)] ??
      (throw StateError('Missing validated outcome'));

  void _validate(JsonData data) {
    if (!variants.containsKey(selectedVariantId) ||
        !profiles.containsKey(initialProfileId) ||
        hypotheses.length < 2 ||
        prerequisites.isEmpty ||
        !conclusions.values.any((x) => x.credit == 1) ||
        !conclusions.values.any((x) => x.kind == ConclusionKind.insufficient) ||
        !claims.values.any((x) => x.critical)) {
      data.fail('incomplete scenario');
    }
    for (final e in transitions.entries) {
      if (!profiles.containsKey(e.key) ||
          e.value.any((x) => !profiles.containsKey(x))) {
        data.fail('unknown transition profile');
      }
    }
    final reached = {initialProfileId};
    var previous = -1;
    while (previous != reached.length) {
      previous = reached.length;
      for (final id in reached.toList()) {
        reached.addAll(transitions[id] ?? {});
      }
    }
    if (reached.length != profiles.length) data.fail('unreachable profile');
    for (final action in actions.values) {
      if (!profiles.containsKey(action.profileId)) {
        data.fail('unknown action profile');
      }
      if (action is ReadingAction) {
        if (!points.containsKey(action.redPoint) ||
            !points.containsKey(action.blackPoint) ||
            action.redPoint == action.blackPoint) {
          data.fail('unknown/identical points');
        }
        if (action.quantity == Quantity.resistance &&
            (!profiles[action.profileId]!.isolated ||
                profiles[action.profileId]!.powered)) {
          data.fail('resistance requires confirmed isolation');
        }
      }
      if (action is! ForbiddenAction &&
          !action.purposes.values.any((x) => x.justified)) {
        data.fail('no valid purpose');
      }
      for (final variant in variants.keys) {
        final result = _outcomes[(variant, action.id)];
        if (action is ForbiddenAction) {
          if (result != null) {
            data.fail('forbidden action cannot yield evidence');
          }
        } else {
          if (result == null) {
            data.fail('missing outcome $variant/${action.id}');
          }
          if (action is ReadingAction &&
              !((result is NumericObservation &&
                      result.quantity == action.quantity) ||
                  (result is OpenLoopObservation &&
                      action.quantity == Quantity.resistance) ||
                  result is UnavailableObservation)) {
            data.fail('incompatible reading');
          }
          if (action is DocumentAction &&
              result is! PacketObservation &&
              result is! UnavailableObservation) {
            data.fail('incompatible document result');
          }
        }
      }
    }
    for (final key in _outcomes.keys) {
      if (!variants.containsKey(key.$1) || !actions.containsKey(key.$2)) {
        data.fail('orphan outcome');
      }
    }
    for (final proof in [
      ...evidenceGroups.values.map((x) => x.requirement),
      ...claims.values.map((x) => x.requirement),
    ]) {
      for (final route in proof.alternatives) {
        for (final action in route) {
          if (!actions.containsKey(action) ||
              actions[action] is ForbiddenAction ||
              observationFor(selectedVariantId, action)
                  is UnavailableObservation) {
            data.fail('invalid/unreachable proof reference $action');
          }
        }
        if (proof.sameSnapshot &&
            route
                    .map((a) => profiles[actions[a]!.profileId]!.snapshotId)
                    .toSet()
                    .length !=
                1) {
          data.fail('incompatible proof snapshots');
        }
      }
    }
  }
}
