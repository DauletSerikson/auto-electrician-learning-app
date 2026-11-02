import 'dart:convert';
import 'dart:io';

import 'package:electrician/practice/practice_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final class MemoryBundle extends CachingAssetBundle {
  final Map<String, String> files;
  MemoryBundle(this.files);
  @override
  Future<ByteData> load(String key) async {
    final text = files[key];
    if (text == null) throw StateError('Asset unavailable: $key');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(text)));
  }
}

Map<String, String> files() => {
  for (final name in [
    'catalog.json',
    'cases/dp01.json',
    'cases/dp13.json',
    'cases/dp05.json',
    for (var i = 1; i <= 18; i++)
      if (![1, 13, 5].contains(i))
        'cases/dp${i.toString().padLeft(2, '0')}.json',
  ])
    'assets/practice/$name': File('assets/practice/$name').readAsStringSync(),
};

void main() {
  test('catalog loads all eighteen definitions and retains pilot order, separate from course', () async {
    final items = await PracticeService(bundle: MemoryBundle(files()))
        .loadCatalog();
    expect(items.take(3).map((d) => d.id), ['dp01', 'dp13', 'dp05']);
    expect(items.map((d) => d.id).toSet(), {
      for (var i = 1; i <= 18; i++) 'dp${i.toString().padLeft(2, '0')}',
    });
    expect(items, hasLength(18));
    expect(
      items.every((d) => d.claims.isNotEmpty && d.evidenceGroups.isNotEmpty),
      isTrue,
    );
    expect(
      items.map((d) => d.weights.values.reduce((a, b) => a + b)),
      everyElement(100),
    );
  });
  for (final ids in <List<String>>[
    [],
    ['dp01', 'dp01'],
    ['../course'],
    ['missing'],
  ]) {
    test('catalog rejects invalid IDs $ids', () async {
      final data = files();
      data['assets/practice/catalog.json'] = jsonEncode({
        'schemaVersion': 1,
        'caseIds': ids,
      });
      await expectLater(
        PracticeService(bundle: MemoryBundle(data)).loadCatalog(),
        throwsFormatException,
      );
    });
  }
  test(
    'case ID mismatch fails instead of presenting a partial catalog',
    () async {
      final data = files();
      final definition = jsonDecode(
        data['assets/practice/cases/dp01.json']!,
      ) as Map<String, dynamic>;
      definition['id'] = 'dp05';
      data['assets/practice/cases/dp01.json'] = jsonEncode(definition);
      await expectLater(
        PracticeService(bundle: MemoryBundle(data)).loadCatalog(),
        throwsFormatException,
      );
    },
  );
  test('load failure remains an error, not empty success', () async {
    final data = files()..remove('assets/practice/cases/dp13.json');
    await expectLater(
      PracticeService(bundle: MemoryBundle(data)).loadCatalog(),
      throwsStateError,
    );
  });
}
