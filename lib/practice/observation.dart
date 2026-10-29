import 'json_data.dart';

enum Quantity { voltage, current, resistance, power }

sealed class PracticeObservation {
  const PracticeObservation();

  String get display;

  factory PracticeObservation.fromJson(JsonData data) {
    switch (data.text('kind')) {
      case 'numeric':
        data.fields({'kind', 'quantity', 'value', 'unit', 'resolution'});
        final quantity = data.enumeration('quantity', Quantity.values);
        final unit = data.text('unit');
        final units = switch (quantity) {
          Quantity.voltage => {'V'},
          Quantity.current => {'A', 'mA'},
          Quantity.resistance => {'Ω', 'MΩ'},
          Quantity.power => {'W'},
        };
        if (!units.contains(unit) || data.number('resolution') <= 0) {
          data.fail('incompatible unit or resolution');
        }
        return NumericObservation(
          quantity,
          data.number('value'),
          unit,
          data.number('resolution'),
        );
      case 'packet':
        data.fields({'kind', 'text', 'source'});
        return PacketObservation(data.text('text'), data.text('source'));
      case 'openLoop':
        data.fields({'kind', 'limitOhm'});
        if (data.number('limitOhm') <= 0) data.fail('invalid range');
        return OpenLoopObservation(data.number('limitOhm'));
      case 'unavailable':
        data.fields({'kind', 'reason'});
        return UnavailableObservation(data.text('reason'));
      default:
        data.fail('unknown observation kind');
    }
  }
}

final class NumericObservation extends PracticeObservation {
  final Quantity quantity;
  final double value;
  final String unit;
  final double resolution;
  const NumericObservation(
    this.quantity,
    this.value,
    this.unit,
    this.resolution,
  );

  NumericObservation get reversed =>
      NumericObservation(quantity, -value, unit, resolution);

  @override
  String get display {
    var decimals = 0;
    var step = resolution;
    while (step < 1 && decimals < 6) {
      step *= 10;
      decimals++;
    }
    return '${value.toStringAsFixed(decimals).replaceAll('.', ',')} $unit';
  }
}

final class PacketObservation extends PracticeObservation {
  final String text;
  final String source;
  const PacketObservation(this.text, this.source);
  @override
  String get display => '$text\nИсточник: $source';
}

final class OpenLoopObservation extends PracticeObservation {
  final double limitOhm;
  const OpenLoopObservation(this.limitOhm);
  @override
  String get display =>
      'OL — выше диапазона ${limitOhm / 1000000} MΩ. '
      'Это не измеренное бесконечное сопротивление.';
}

final class UnavailableObservation extends PracticeObservation {
  final String reason;
  const UnavailableObservation(this.reason);
  @override
  String get display => 'Данных недостаточно: $reason';
}

final class BlockedObservation extends PracticeObservation {
  final String reason;
  const BlockedObservation(this.reason);
  @override
  String get display => 'Действие не выполнено: $reason';
}
