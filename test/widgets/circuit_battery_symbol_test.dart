import 'package:electrician/simulation/circuit_simulation.dart';
import 'package:electrician/widgets/lesson_blocks/circuit_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _LineCanvas implements Canvas {
  final lines = <(Offset, Offset)>[];

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) => lines.add((p1, p2));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final painters = <CustomPainter>[
    SimpleLampCircuitPainter(
      simulation: const SimpleLampSimulation(isClosed: true),
      activeColor: Colors.green,
      inactiveColor: Colors.grey,
      textColor: Colors.black,
    ),
    for (final topology in LampTopology.values)
      TwoLampCircuitPainter(
        simulation: TwoLampSimulation(topology: topology, lamp1Open: false),
        activeColor: Colors.green,
        wireColor: Colors.grey,
        textColor: Colors.black,
        errorColor: Colors.red,
      ),
  ];
  for (var index = 0; index < painters.length; index++) {
    test(
      'circuit painter $index draws positive plate longer than negative',
      () {
        const size = Size(400, 300);
        final canvas = _LineCanvas();
        painters[index].paint(canvas, size);
        // Both painters label the upper plate + and the lower plate −.
        // Find the two horizontal plates centred on the battery branch.
        final plates =
            canvas.lines
                .where(
                  (line) =>
                      line.$1.dy == line.$2.dy &&
                      line.$1.dx < size.width * 0.12 &&
                      line.$2.dx > size.width * 0.12,
                )
                .toList()
              ..sort((a, b) => a.$1.dy.compareTo(b.$1.dy));
        expect(plates, hasLength(2));
        final positiveLength = (plates[0].$2 - plates[0].$1).distance;
        final negativeLength = (plates[1].$2 - plates[1].$1).distance;
        expect(positiveLength, greaterThan(negativeLength));
      },
    );
  }
}
