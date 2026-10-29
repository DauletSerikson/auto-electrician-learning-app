import 'dart:convert';

import 'package:flutter/services.dart';

import 'definition.dart';
import 'json_data.dart';

/// Bundled practice content is separate from course assets and user progress.
final class PracticeService {
  final AssetBundle bundle;
  PracticeService({AssetBundle? bundle}) : bundle = bundle ?? rootBundle;

  Future<List<PracticeDefinition>> loadCatalog() async {
    final catalog = JsonData(
      jsonDecode(await bundle.loadString('assets/practice/catalog.json')),
      'practiceCatalog',
    );
    catalog.fields({'schemaVersion', 'caseIds'});
    final ids = catalog.texts('caseIds');
    if (catalog.integer('schemaVersion') != 1 ||
        ids.isEmpty ||
        ids.toSet().length != ids.length ||
        ids.any((id) => !RegExp(r'^dp[0-9]{2}$').hasMatch(id))) {
      catalog.fail('invalid catalog');
    }
    final result = <PracticeDefinition>[];
    for (final id in ids) {
      final definition = PracticeDefinition.fromJson(
        jsonDecode(await bundle.loadString('assets/practice/cases/$id.json')),
      );
      if (definition.id != id) catalog.fail('case ID mismatch');
      result.add(definition);
    }
    return List.unmodifiable(result);
  }
}
