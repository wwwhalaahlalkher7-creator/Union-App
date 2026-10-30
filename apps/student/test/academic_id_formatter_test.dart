import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leo_association/shared/utils/academic_labels.dart';

void main() {
  const formatter = AcademicIdInputFormatter();

  TextEditingValue edit(String text, {int? cursor}) => TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: cursor ?? text.length),
      );

  group('AcademicIdInputFormatter', () {
    test('adds separator after first two digits', () {
      final result = formatter.formatEditUpdate(edit('2'), edit('24'));
      expect(result.text, '24-');
      expect(result.selection.baseOffset, 3);
    });

    test('formats a pasted academic ID without duplicating the separator', () {
      final result = formatter.formatEditUpdate(
        edit(''),
        edit('24-12345678'),
      );
      expect(result.text, '24-12345678');
    });

    test('silently ignores digits beyond the allowed ten', () {
      final result = formatter.formatEditUpdate(
        edit('24-12345678'),
        edit('24-12345678999'),
      );
      expect(result.text, '24-12345678');
    });

    test('backspace after the inserted separator removes a digit', () {
      final result = formatter.formatEditUpdate(
        edit('24-', cursor: 3),
        edit('24', cursor: 2),
      );
      expect(result.text, '2');
    });
  });

  group('isValidAcademicId', () {
    test('accepts exactly two digits, hyphen, and eight digits', () {
      expect(isValidAcademicId('24-12345678'), isTrue);
    });

    test('rejects missing separator, wrong lengths, and extra input', () {
      expect(isValidAcademicId('2412345678'), isFalse);
      expect(isValidAcademicId('24-1234567'), isFalse);
      expect(isValidAcademicId('24-123456789'), isFalse);
      expect(isValidAcademicId('2-12345678'), isFalse);
    });
  });
}
