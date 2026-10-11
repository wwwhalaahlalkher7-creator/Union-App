/// Small, deterministic engineering calculations used by the specialty tools.
/// These helpers are educational estimators, not structural/electrical design approval.
class EngineeringCalculations {
  const EngineeringCalculations._();

  static double resistanceFromVoltageCurrent(double voltage, double current) {
    if (current == 0) {
      throw ArgumentError.value(current, 'current', 'Current cannot be zero.');
    }
    return voltage / current;
  }

  static double electricalPower(double voltage, double current) => voltage * current;

  static double seriesResistance(double first, double second) {
    _nonNegative(first, 'first');
    _nonNegative(second, 'second');
    return first + second;
  }

  static double parallelResistance(double first, double second) {
    _nonNegative(first, 'first');
    _nonNegative(second, 'second');
    final sum = first + second;
    if (sum == 0) {
      throw ArgumentError('Parallel resistance is undefined when both resistances are zero.');
    }
    return first * second / sum;
  }

  static double concreteVolume(double length, double width, double height) {
    _nonNegative(length, 'length');
    _nonNegative(width, 'width');
    _nonNegative(height, 'height');
    return length * width * height;
  }

  static ({double area, double perimeter}) rectangle(double length, double width) {
    _nonNegative(length, 'length');
    _nonNegative(width, 'width');
    return (area: length * width, perimeter: 2 * (length + width));
  }

  static double slopePercent(double rise, double horizontalDistance) {
    if (horizontalDistance == 0) {
      throw ArgumentError.value(horizontalDistance, 'horizontalDistance', 'Distance cannot be zero.');
    }
    return rise / horizontalDistance * 100;
  }

  static double scaledLength(double drawingLength, double scaleDenominator) {
    if (scaleDenominator <= 0) {
      throw ArgumentError.value(scaleDenominator, 'scaleDenominator', 'Scale denominator must be positive.');
    }
    return drawingLength * scaleDenominator;
  }

  static double aspectRatio(double width, double height) {
    if (height == 0) {
      throw ArgumentError.value(height, 'height', 'Height cannot be zero.');
    }
    return width / height;
  }

  static double convertStress(double value, String from, String to) {
    const factors = <String, double>{'Pa': 1, 'kPa': 1000, 'MPa': 1000000, 'psi': 6894.757293};
    return _convert(value, from, to, factors);
  }

  static double convertLength(double value, String from, String to) {
    const factors = <String, double>{'mm': .001, 'cm': .01, 'm': 1, 'km': 1000, 'in': .0254, 'ft': .3048};
    return _convert(value, from, to, factors);
  }

  static double convertCurrent(double value, String from, String to) {
    const factors = <String, double>{'mA': .001, 'A': 1, 'kA': 1000};
    return _convert(value, from, to, factors);
  }

  static double convertDataSize(double value, String from, String to) {
    // Decimal units (KB = 1000 bytes), matching SI storage-unit notation.
    const factors = <String, double>{'bit': 1, 'B': 8, 'KB': 8000, 'MB': 8000000, 'GB': 8000000000};
    return _convert(value, from, to, factors);
  }

  static double _convert(double value, String from, String to, Map<String, double> factors) {
    final source = factors[from];
    final target = factors[to];
    if (source == null || target == null) {
      throw ArgumentError('Unsupported unit conversion: $from to $to.');
    }
    return value * source / target;
  }

  static void _nonNegative(double value, String name) {
    if (value < 0 || !value.isFinite) {
      throw ArgumentError.value(value, name, 'Value must be finite and non-negative.');
    }
  }
}
