import 'package:flutter_test/flutter_test.dart';
import 'package:leo_association/shared/utils/engineering_calculations.dart';

void main() {
  group('EngineeringCalculations', () {
    test('calculates Ohm resistance and electrical power', () {
      expect(EngineeringCalculations.resistanceFromVoltageCurrent(12, 2), 6);
      expect(EngineeringCalculations.electricalPower(12, 2), 24);
      expect(() => EngineeringCalculations.resistanceFromVoltageCurrent(12, 0), throwsArgumentError);
    });

    test('calculates series and parallel resistance', () {
      expect(EngineeringCalculations.seriesResistance(6, 3), 9);
      expect(EngineeringCalculations.parallelResistance(6, 3), 2);
    });

    test('calculates concrete volume and rectangular area/perimeter', () {
      expect(EngineeringCalculations.concreteVolume(2, 3, 0.5), 3);
      final shape = EngineeringCalculations.rectangle(4, 3);
      expect(shape.area, 12);
      expect(shape.perimeter, 14);
    });

    test('calculates slope, scale, and aspect ratio', () {
      expect(EngineeringCalculations.slopePercent(2, 10), 20);
      expect(EngineeringCalculations.scaledLength(3.5, 100), 350);
      expect(EngineeringCalculations.aspectRatio(16, 9), closeTo(1.777777, 0.00001));
    });

    test('converts stress, length, current, and data size units', () {
      expect(EngineeringCalculations.convertStress(1, 'MPa', 'kPa'), 1000);
      expect(EngineeringCalculations.convertLength(1, 'm', 'cm'), 100);
      expect(EngineeringCalculations.convertCurrent(1000, 'mA', 'A'), 1);
      expect(EngineeringCalculations.convertDataSize(1, 'MB', 'KB'), 1000);
    });
  });
}
