import 'package:flutter_test/flutter_test.dart';
import 'package:leo_association/shared/utils/academic_labels.dart';

void main() {
  test('academic id formatter keeps only digits and one internal hyphen', () {
    const formatter = AcademicIdInputFormatter();
    final result = formatter.formatEditUpdate(
      const TextEditingValue(text: ''),
      const TextEditingValue(text: '20a--21-0045'),
    );
    expect(result.text, '20-210045');
  });

  test('academic id validation accepts the legacy digits-only form', () {
    expect(isValidAcademicId('20210045'), isTrue);
    expect(isValidAcademicId('20-210045'), isTrue);
    expect(isValidAcademicId('20/210045'), isFalse);
    expect(isValidAcademicId('20-21-0045'), isFalse);
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
