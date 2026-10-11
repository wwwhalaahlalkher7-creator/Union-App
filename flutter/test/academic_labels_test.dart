import 'package:flutter_test/flutter_test.dart';
import 'package:leo_association/shared/utils/academic_labels.dart';

void main() {
  test('academic id formatter normalizes input to the required ten digits', () {
    const formatter = AcademicIdInputFormatter();
    final result = formatter.formatEditUpdate(
      const TextEditingValue(text: ''),
      const TextEditingValue(text: '24a--12-34567899'),
    );
    expect(result.text, '24-12345678');
  });

  test('academic id validation requires two digits, a hyphen, and eight digits', () {
    expect(isValidAcademicId('24-12345678'), isTrue);
    expect(isValidAcademicId('2412345678'), isFalse);
    expect(isValidAcademicId('24-1234567'), isFalse);
    expect(isValidAcademicId('24/12345678'), isFalse);
    expect(isValidAcademicId('24-12-345678'), isFalse);
  });

  test('department labels follow the selected language', () {
    final value = {'id': 'ee', 'code': 'EE', 'name_ar': 'هندسة كهرباء إلكترونية'};
    expect(AcademicLabels.department(value, 'ar'), 'هندسة كهرباء إلكترونية');
    expect(AcademicLabels.department(value, 'en'), 'Electrical & Electronic Engineering');
    expect(AcademicLabels.department(value, 'fr'), 'Génie électrique et électronique');
  });

  test('semester labels are localized', () {
    final value = {'id': 'sem_1', 'number': 1, 'name_ar': 'الفصل الأول'};
    expect(AcademicLabels.semester(value, 'ar'), 'الفصل الأول');
    expect(AcademicLabels.semester(value, 'en'), 'Semester 1');
    expect(AcademicLabels.semester(value, 'fr'), 'Semestre 1');
  });
}
