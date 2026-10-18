import 'package:flutter/services.dart';

/// Restricts academic IDs to ASCII digits plus a single internal hyphen.
/// The field itself is rendered LTR so RTL locales cannot visually reorder it.
class AcademicIdInputFormatter extends TextInputFormatter {
  const AcademicIdInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Accept digits only, format after the first two, and cap at ten digits.
    // This also normalizes pasted values such as "24-12345678" without
    // duplicating the separator or showing a warning for excess input.
    var allDigits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    // Backspace immediately after the auto-inserted separator should delete
    // the preceding digit instead of making the separator impossible to erase.
    final deletingAutoSeparator = oldValue.text.endsWith('-') &&
        oldValue.selection.isCollapsed &&
        oldValue.selection.baseOffset == oldValue.text.length &&
        newValue.text == oldValue.text.substring(0, oldValue.text.length - 1);
    if (deletingAutoSeparator && allDigits.length == 2) {
      allDigits = allDigits.substring(0, 1);
    }
    final digits = allDigits.length > 10 ? allDigits.substring(0, 10) : allDigits;
    final formatted = digits.length <= 2
        ? (digits.length == 2 ? '$digits-' : digits)
        : '${digits.substring(0, 2)}-${digits.substring(2)}';

    final oldOffset = newValue.selection.baseOffset.clamp(0, newValue.text.length).toInt();
    final digitsBeforeCursor = newValue.text
        .substring(0, oldOffset)
        .replaceAll(RegExp(r'[^0-9]'), '')
        .length
        .clamp(0, digits.length)
        .toInt();
    var selectionOffset = digitsBeforeCursor;
    if (digitsBeforeCursor >= 2) selectionOffset++;
    selectionOffset = selectionOffset.clamp(0, formatted.length).toInt();

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: selectionOffset),
      composing: TextRange.empty,
    );
  }
}

bool isValidAcademicId(String value) =>
    RegExp(r'^[0-9]{2}-[0-9]{8}$').hasMatch(value.trim());

/// Converts department/semester records from the API into the selected UI
/// language. The API currently stores Arabic/English names; French is supplied
/// here for the known academic departments so the UI is not Arabic-only.
class AcademicLabels {
  const AcademicLabels._();

  static String department(Map<String, dynamic> value, String languageCode) {
    final code = _normalize(value['code'] ?? value['id']);
    final arabic = _text(value['name_ar'] ?? value['name']);
    final english = _text(value['name_en'] ?? value['name']);

    if (languageCode == 'fr') {
      if (code == 'ee' || code == 'electrical' || code == 'electricalengineering') {
        return 'Génie électrique et électronique';
      }
      if (code == 'civil' || code == 'civilengineering') {
        return 'Génie civil';
      }
      if (code == 'architecture' || code == 'arch' || code == 'architecturalengineering') {
        return 'Architecture';
      }
      if (english.isNotEmpty) return english;
      return arabic.isNotEmpty ? arabic : _fallback(value);
    }

    if (languageCode == 'en') {
      if (english.isNotEmpty) return english;
      if (code == 'ee' || code == 'electrical' || code == 'electricalengineering') {
        return 'Electrical & Electronic Engineering';
      }
      if (code == 'civil' || code == 'civilengineering') return 'Civil Engineering';
      if (code == 'architecture' || code == 'arch' || code == 'architecturalengineering') {
        return 'Architecture';
      }
      return arabic.isNotEmpty ? arabic : _fallback(value);
    }

    if (arabic.isNotEmpty) return arabic;
    if (code == 'ee' || code == 'electrical' || code == 'electricalengineering') {
      return 'الهندسة الكهربائية والإلكترونية';
    }
    if (code == 'civil' || code == 'civilengineering') return 'الهندسة المدنية';
    if (code == 'architecture' || code == 'arch' || code == 'architecturalengineering') {
      return 'هندسة العمارة';
    }
    return english.isNotEmpty ? english : _fallback(value);
  }

  static String semester(Map<String, dynamic> value, String languageCode) {
    final number = int.tryParse('${value['number'] ?? ''}');
    if (number != null) {
      if (languageCode == 'fr') return 'Semestre $number';
      if (languageCode == 'en') return 'Semester $number';
      return 'الفصل ${_arabicOrdinal(number)}';
    }

    final arabic = _text(value['name_ar'] ?? value['name']);
    final english = _text(value['name_en'] ?? value['name']);
    if (languageCode == 'fr') return english.isNotEmpty ? english : arabic;
    if (languageCode == 'en') return english.isNotEmpty ? english : arabic;
    return arabic.isNotEmpty ? arabic : english;
  }

  static String _normalize(Object? value) =>
      _text(value).toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');

  static String _text(Object? value) =>
      value == null ? '' : value.toString().trim();

  static String _fallback(Map<String, dynamic> value) =>
      _text(value['code'] ?? value['id']);

  static String _arabicOrdinal(int number) {
    const values = <int, String>{
      1: 'الأول',
      2: 'الثاني',
      3: 'الثالث',
      4: 'الرابع',
      5: 'الخامس',
      6: 'السادس',
      7: 'السابع',
      8: 'الثامن',
      9: 'التاسع',
      10: 'العاشر',
      11: 'الحادي عشر',
      12: 'الثاني عشر',
    };
    return values[number] ?? '$number';
  }
}
