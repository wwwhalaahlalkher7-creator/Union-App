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
    var text = newValue.text.replaceAll(RegExp(r'[^0-9-]'), '');
    text = text.replaceFirst(RegExp(r'^-+'), '');

    final dash = text.indexOf('-');
    if (dash >= 0) {
      text = text.substring(0, dash + 1) +
          text.substring(dash + 1).replaceAll('-', '');
    }

    final offset = newValue.selection.baseOffset.clamp(0, newValue.text.length).toInt();
    final beforeCursor = newValue.text.substring(0, offset);
    var cleanBeforeCursor = beforeCursor.replaceAll(RegExp(r'[^0-9-]'), '');
    cleanBeforeCursor = cleanBeforeCursor.replaceFirst(RegExp(r'^-+'), '');
    final beforeDash = cleanBeforeCursor.indexOf('-');
    if (beforeDash >= 0) {
      cleanBeforeCursor = cleanBeforeCursor.substring(0, beforeDash + 1) +
          cleanBeforeCursor.substring(beforeDash + 1).replaceAll('-', '');
    }
    final selectionOffset = cleanBeforeCursor.length.clamp(0, text.length).toInt();

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: selectionOffset),
      composing: TextRange.empty,
    );
  }
}

bool isValidAcademicId(String value) =>
    RegExp(r'^[0-9]+(?:-[0-9]+)?$').hasMatch(value.trim());

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
