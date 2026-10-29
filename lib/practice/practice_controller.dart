import 'package:flutter/foundation.dart';

import 'attempt.dart';
import 'definition.dart';

/// Route-scoped Flutter adapter; the diagnostic engine remains pure Dart.
final class PracticeController extends ChangeNotifier {
  final PracticeSession _session;
  PracticeController(PracticeDefinition definition)
    : _session = PracticeSession(definition);
  PracticeAttempt get state => _session.state;
  void edit(void Function(PracticeSession session) change) {
    change(_session);
    notifyListeners();
  }
}
