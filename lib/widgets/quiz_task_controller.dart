import 'package:flutter/material.dart';

/// Route-local draft and submission adapter. No scores or persisted progress.
/// Existing task widgets remain responsible for their own evaluation rules.
class QuizTaskController {
  final VoidCallback onChanged;
  int? selectedAnswer;
  String calculationText = '';
  bool interacted = false;
  VoidCallback? _submit;
  bool Function()? _ready;

  QuizTaskController({required this.onChanged});

  void bind({required VoidCallback submit, required bool Function() ready}) {
    _submit = submit;
    _ready = ready;
  }

  bool get ready => _ready?.call() ?? false;

  void changed() {
    interacted = true;
    onChanged();
  }

  void submit() => _submit!();
}

/// Reports local simulator edits without changing its domain calculations.
mixin QuizTaskState<T extends StatefulWidget> on State<T> {
  QuizTaskController? get quizTask;

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    quizTask?.changed();
  }
}
