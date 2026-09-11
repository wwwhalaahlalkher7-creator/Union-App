import 'package:flutter_test/flutter_test.dart';
import 'package:leo_association/core/update/update_info.dart';

void main() {
  group('VersionComparator', () {
    test('compares semantic versions numerically', () {
      expect(VersionComparator.compare('2.10.0', '2.9.9'), greaterThan(0));
      expect(VersionComparator.compare('2.3.0', '2.3.0'), 0);
      expect(VersionComparator.compare('2.2.9', '2.3.0'), lessThan(0));
    });

    test('ignores build metadata and optional v prefix', () {
      expect(VersionComparator.compare('v2.3.0+99', '2.3.0+1'), 0);
    });
  });
}
