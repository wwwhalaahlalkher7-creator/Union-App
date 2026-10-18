import 'package:flutter_test/flutter_test.dart';
import 'package:leo_association/core/app_version.dart';

void main() {
  test('app version is centralized and valid', () {
    expect(AppVersion.name, matches(RegExp(r'^\d+\.\d+\.\d+$')));
    expect(AppVersion.build, greaterThan(0));
    expect(AppVersion.full, '${AppVersion.name}+${AppVersion.build}');
  });
}
