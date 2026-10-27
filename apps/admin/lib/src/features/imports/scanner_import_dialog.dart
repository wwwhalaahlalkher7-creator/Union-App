import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:pdfx/pdfx.dart';
import 'package:flutter/material.dart';

import '../../api_service.dart';

class ScannerImportDialog extends StatefulWidget {
  const ScannerImportDialog({super.key, required this.api, required this.type,
    required this.departments, required this.semesters, this.subjects = const []});
  final ApiService api;
  final String type; // students | schedule
  final List<Map<String, dynamic>> departments;
  final List<Map<String, dynamic>> semesters;
  final List<Map<String, dynamic>> subjects;

  @override
  State<ScannerImportDialog> createState() => _ScannerImportDialogState();
}

class _ScannerImportDialogState extends State<ScannerImportDialog> {
  String? _departmentId;
  String? _semesterId;
  String? _operationId;
  String? _expiresAt;
  String? _filename;
  String? _error;
  bool _working = false;
  bool _review = false;
  int _countdown = 10;
  Timer? _countdownTimer;
  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _existingSchedules = [];
  final List<String> _notes = [];

  bool get _students => widget.type == 'students';
  @override
  void dispose() { _countdownTimer?.cancel(); super.dispose(); }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() => _countdown = 10);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() { _countdown = (_countdown - 1).clamp(0, 10); });
      if (_countdown == 0) { timer.cancel(); }
    });
  }
  List<Map<String, dynamic>> get _availableSubjects => widget.subjects.where((s) =>
    '${s['department_id']}' == '$_departmentId' && '${s['semester_id']}' == '$_semesterId' && (s['active'] == 1 || s['active'] == true || s['active'] == null)).toList();

  String _name(Map<String, dynamic> row) => (row['name_ar'] ?? row['name'] ?? row['title'] ?? row['id'] ?? '').toString();
  String _firstName(Iterable<Map<String, dynamic>> rows) => rows.isEmpty ? '—' : _name(rows.first);
  String _digits(String value) {
    const ar = '٠١٢٣٤٥٦٧٨٩'; const fa = '۰۱۲۳۴۵۶۷۸۹';
    return value.replaceAllMapped(RegExp('[٠-٩]'), (m) => '${ar.indexOf(m[0]!)}')
      .replaceAllMapped(RegExp('[۰-۹]'), (m) => '${fa.indexOf(m[0]!)}');
  }
  String _time(dynamic value) {
    final raw = _digits('${value ?? ''}').trim();
    final m = RegExp(r'^(\d{1,2})(?::(\d{1,2}))?$').firstMatch(raw);
    if (m == null) { return raw; }
    final h = int.tryParse(m.group(1)!) ?? -1; final min = int.tryParse(m.group(2) ?? '0') ?? -1;
    if (h < 0 || h > 23 || min < 0 || min > 59) { return raw; }
    return '${h.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
  }
  String _header(String value) => _digits(value).toLowerCase().replaceAll(RegExp(r'[\s_\-ـ]+'), '').replaceAll(RegExp(r'[أإآ]'), 'ا').replaceAll('ة','ه');

  Future<void> _pickAndScan() async {
    if (_departmentId == null || _semesterId == null) { setState(() => _error = 'اختر القسم والفصل الدراسي قبل بدء المسح.'); return; }
    final picked = await FilePicker.platform.pickFiles(type: FileType.custom,
      allowedExtensions: const ['csv', 'xlsx', 'pdf', 'png', 'jpg', 'jpeg', 'webp', 'tif', 'tiff'], withData: true, allowMultiple: false);
    if (picked == null || picked.files.isEmpty) { return; }
    final file = picked.files.single;
    if (file.size <= 0) { setState(() => _error = 'الملف فارغ. اختر ملفًا يحتوي على بيانات ثم أعد المحاولة.'); return; }
    if (file.size > 100 * 1024 * 1024) { setState(() => _error = 'الملف كبير جدًا. اختر ملفًا أصغر ثم أعد المحاولة.'); return; }
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) { setState(() => _error = 'تعذر قراءة الملف من الجهاز. أعد اختياره وحاول مجددًا.'); return; }
    setState(() { _working = true; _error = null; _filename = file.name; _notes.clear(); });
    try {
      final created = await widget.api.post('/admin/imports', body: {
        'type': widget.type, 'departmentId': _departmentId, 'semesterId': _semesterId, 'records': <dynamic>[]
      });
      _operationId = created['id']?.toString();
      _expiresAt = created['expiresAt']?.toString();
      if (!_students) {
        final existing = await widget.api.get('/admin/schedule?limit=100');
        final rawExisting = existing['data'];
        _existingSchedules = rawExisting is List ? rawExisting.whereType<Map>().map((r) => Map<String, dynamic>.from(r)).where((r) => '${r['department_id']}' == _departmentId && '${r['semester_id']}' == _semesterId && (r['active'] == 1 || r['active'] == true || r['active'] == null)).toList() : [];
      }
      if (_operationId == null || _operationId!.isEmpty) { throw const ApiServiceException('لم يتم إنشاء عملية استيراد صالحة.'); }
      final ext = file.extension?.toLowerCase() ?? '';
      List<Map<String, dynamic>> parsed;
      if (ext == 'csv') {
        parsed = _parseGrid(CsvToListConverter(shouldParseNumbers: false).convert(utf8.decode(bytes, allowMalformed: true)));
      } else if (ext == 'xlsx') {
        final workbook = Excel.decodeBytes(bytes);
        if (workbook.tables.isEmpty || workbook.tables.values.every((sheet) => sheet.rows.isEmpty)) {
          throw const ApiServiceException('ملف Excel فارغ أو لا يحتوي على أوراق قابلة للقراءة.');
        }
        final sheet = workbook.tables.values.firstWhere((sheet) => sheet.rows.isNotEmpty);
        parsed = _parseGrid(sheet.rows.map((r) => r.map((c) => c?.value?.toString() ?? '').toList()).toList());
      } else if (['pdf','png','jpg','jpeg','webp','tif','tiff'].contains(ext)) {
        final mime = ext == 'pdf' ? 'application/pdf' : (ext == 'png' ? 'image/png' : (ext == 'webp' ? 'image/webp' : (ext == 'tif' || ext == 'tiff' ? 'image/tiff' : 'image/jpeg')));
        final compressed = await _prepareOcrUpload(bytes, file.name, mime);
        // First ask the vision model for only the fields the database needs.
        // OCR transcript parsing remains a fallback for providers that cannot
        // return a structured result. Raw document text is never shown as data.
        parsed = await _extractStructuredWithVision(compressed.bytes, compressed.contentType);
        if (parsed.isEmpty) {
          final result = await widget.api.uploadImportOcr(bytes: compressed.bytes, filename: compressed.filename, contentType: compressed.contentType);
          final text = result['text']?.toString() ?? '';
          parsed = _parseOcrText(text);
          if (parsed.isEmpty) {
            _notes.add('لم نستطع تحديد سجلات مكتملة من الملف. لم ننسخ محتوى المستند كاملًا؛ أضف السجلات المطلوبة فقط وتحقق من الحقول قبل الاعتماد.');
          }
        }
      } else {
        throw const ApiServiceException('نوع الملف غير مدعوم. استخدم CSV أو Excel أو PDF أو صورة واضحة.');
      }
      if (parsed.length > 2000) { throw const ApiServiceException('اكتُشف أكثر من 2000 سجل. قسّم الملف إلى ملفات أصغر ثم أعد المحاولة.'); }
      if (parsed.isEmpty) {
        _notes.add('لم يتم التعرف على سجلات قابلة للإضافة. لم تُنشأ صفوف وهمية؛ اضغط «إضافة صف» لإدخال سجل يدويًا أو جرّب ملفًا أوضح.');
      }
      if (!_students && _availableSubjects.isEmpty) { _notes.add('لا توجد مواد نشطة لهذا القسم والفصل الدراسي. تحقق من النطاق أو أضف المواد أولًا.'); }
      await widget.api.patch('/admin/imports/$_operationId', body: {'records': parsed});
      if (!mounted) { return; }
      setState(() { _rows = parsed; _review = true; _countdown = 10; });
      _countdownTimer?.cancel();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) { timer.cancel(); return; }
        setState(() { _countdown = (_countdown - 1).clamp(0, 10); });
        if (_countdown == 0) { timer.cancel(); }
      });
    } catch (e) {
      if (_operationId != null && !_review) { try { await widget.api.delete('/admin/imports/$_operationId'); } catch (_) {} _operationId = null; }
      if (mounted) { setState(() => _error = _friendlyError(e)); }
    } finally {
      // Source bytes are intentionally not retained in the review state.
      if (mounted) { setState(() => _working = false); }
    }
  }

  Future<_PreparedOcrUpload> _prepareOcrUpload(Uint8List source, String filename, String mime) async {
    const maxBytes = 1024 * 1024 - 1024; // leave a small multipart/provider margin
    final lower = filename.toLowerCase();
    Uint8List working = source;
    String outputName = filename;
    String outputMime = mime;

    if (mime == 'application/pdf' || lower.endsWith('.pdf')) {
      PdfDocument? document;
      PdfPage? page;
      try {
        document = await PdfDocument.openData(source);
        if (document.pagesCount > 1) {
          throw const ApiServiceException('IMPORT_MULTIPAGE_FILE: يجب أن يحتوي PDF على صفحة واحدة فقط.');
        }
        if (document.pagesCount < 1) { throw const ApiServiceException('ملف PDF لا يحتوي على صفحات قابلة للقراءة.'); }
        page = await document.getPage(1);
        final scale = (1800 / page.width).clamp(1.0, 2.0);
        final rendered = await page.render(
          width: page.width * scale,
          height: page.height * scale,
          format: PdfPageImageFormat.jpeg,
          quality: 82,
        );
        if (rendered == null || rendered.bytes.isEmpty) {
          throw const ApiServiceException('تعذر ضغط صفحة PDF. جرّب صورة JPG واضحة أو أدخل البيانات يدويًا.');
        }
        working = rendered.bytes;
        outputName = '${filename.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '')}.jpg';
        outputMime = 'image/jpeg';
      } finally {
        await page?.close();
        await document?.close();
      }
    }

    if (working.length <= maxBytes) { return _PreparedOcrUpload(working, outputName, outputMime); }

    final decoded = img.decodeImage(working);
    if (decoded == null) {
      throw const ApiServiceException('تعذر قراءة الصورة أو ضغطها. جرّب صورة JPG أو PNG واضحة.');
    }
    img.Image current = decoded;
    // Try high quality first. If the image is still too large, reduce its
    // longest edge gradually even when the source dimensions are below 900px.
    // This avoids repeatedly encoding the same small image and gives the
    // algorithm a predictable lower bound before we reject unreadable output.
    final outputFilename = '${outputName.replaceAll(RegExp(r'\.[^.]+$', caseSensitive: false), '')}.jpg';
    const qualities = <int>[90, 86, 82, 78, 74, 70, 66, 62];
    for (var pass = 0; pass < 7; pass++) {
      for (final quality in qualities) {
        final encoded = Uint8List.fromList(img.encodeJpg(current, quality: quality));
        if (encoded.length <= maxBytes) {
          return _PreparedOcrUpload(encoded, outputFilename, 'image/jpeg');
        }
      }
      final longestEdge = current.width > current.height ? current.width : current.height;
      if (longestEdge <= 1000) { break; }
      final targetEdge = (longestEdge * 0.82).round().clamp(1000, longestEdge - 1);
      final factor = targetEdge / longestEdge;
      final resized = img.copyResize(current,
        width: (current.width * factor).round().clamp(1, current.width),
        height: (current.height * factor).round().clamp(1, current.height),
        interpolation: img.Interpolation.average);
      current = resized;
    }
    // Final conservative attempt at the readability floor; do not degrade
    // indefinitely just to satisfy the provider size limit.
    for (final quality in <int>[72, 66, 60, 54]) {
      final encoded = Uint8List.fromList(img.encodeJpg(current, quality: quality));
      if (encoded.length <= maxBytes) { return _PreparedOcrUpload(encoded, outputFilename, 'image/jpeg'); }
    }
    throw const ApiServiceException('IMPORT_FILE_OVER_PROVIDER_LIMIT: تعذر تجهيز الملف لقراءة النص مع الحفاظ على وضوحه.');
  }

  String _friendlyError(Object error) {
    final value = error.toString();
    if (value.contains('IMPORT_MULTIPAGE_FILE')) { return 'يحتوي المستند على أكثر من صفحة. أدرج صفحة واحدة فقط ثم أعد المسح؛ يمكن أن تحتوي الصفحة الواحدة على أسطر كثيرة.'; }
    if (value.contains('IMPORT_OCR_NOT_CONFIGURED') || value.contains('IMPORT_OCR_AUTH_FAILED')) { return 'تعذّر الاتصال بخدمة قراءة النص. أبلغ مسؤول النظام.'; }
    if (value.contains('IMPORT_FILE_OVER_PROVIDER_LIMIT') || value.contains('IMPORT_OCR_PROVIDER_SIZE_LIMIT')) { return 'تعذّر إرسال الملف إلى خدمة قراءة النص. جرّب صورة أصغر مع الحفاظ على وضوح الجدول.'; }
    if (value.contains('IMPORT_OCR_QUOTA_EXCEEDED')) { return 'خدمة قراءة النص وصلت إلى حد الاستخدام الحالي. جرّب لاحقًا أو أدخل البيانات يدويًا.'; }
    if (value.contains('IMPORT_OCR_TIMEOUT')) { return 'استغرق استخراج النص وقتًا طويلًا. جرّب مرة أخرى أو أدخل البيانات يدويًا.'; }
    if (value.contains('IMPORT_OCR_UNAVAILABLE')) { return 'خدمة قراءة النص غير متاحة مؤقتًا. جرّب مرة أخرى بعد قليل.'; }
    if (value.contains('IMPORT_OCR_PROVIDER_REJECTED')) { return 'تعذّر على خدمة قراءة النص معالجة الملف. جرّب صورة JPG واضحة أو أدخل البيانات يدويًا.'; }
    if (value.contains('IMPORT_OCR_FAILED')) { return 'تعذّر استخراج النص. جرّب مرة أخرى، وإذا تكرر الخطأ فأبلغ مسؤول النظام.'; }
    if (value.contains('IMPORT_FILE_TYPE_UNSUPPORTED')) { return 'نوع الملف غير مدعوم. اختر ملف CSV أو Excel أو PDF أو صورة.'; }
    if (value.contains('IMPORT_FILE_TOO_LARGE')) { return 'تعذر معالجة الملف بسبب حجمه. جرّب نسخة أصغر.'; }
    if (value.contains('IMPORT_OCR_EMPTY')) { return 'لم يتمكن الماسح من قراءة نص واضح. جرّب صورة أوضح.'; }
    return value.replaceFirst('Exception: ', '');
  }

  Map<String, dynamic> _studentRow() => {'studentNumber': '', 'fullName': '', 'email': ''};
  Map<String, dynamic> _scheduleRow() => {'subjectId': '', 'subjectName': '', 'dayOfWeek': 0, 'startTime': '', 'endTime': '', 'room': '', 'lecturer': '', 'existingId': ''};


  String _extractionPrompt() {
    if (_students) {
      return '''استخرج فقط السجلات اللازمة لإضافة الطلاب إلى قاعدة بيانات جامعية من هذه الصورة. تجاهل الشعارات والعناوين والتواقيع والأختام والجامعة والقسم والفصل وأي نص لا يمثل سجل طالب. أخرج JSON فقط دون Markdown بالشكل {"records":[{"studentNumber":"...","fullName":"...","email":""}]}. لا تخمّن أي قيمة ولا تنشئ طالبًا من نص غير واضح. أدرج فقط الصفوف التي يظهر فيها رقم جامعي واسم طالب بوضوح. حافظ على الأرقام كنصوص.''';
    }
    return '''حلل صورة جدول محاضرات جامعي بهدف إدخال الحصص إلى قاعدة البيانات. استخرج الحصص فقط، ولا تنسخ عنوان الجامعة أو اسم الكلية أو القسم أو الدفعة أو الختم أو التوقيع أو أي نص خارج خلايا الجدول. اقرأ عناوين أعمدة الوقت وصفوف الأيام وحدد كل خلية مادة مرتبطة بيوم وفترة زمنية. إذا كانت خلية مادة ممتدة عبر عدة أعمدة أو صفوف، فأنشئ حصة واحدة فقط لكل فترة فعلية ظاهرة ولا تكرر المادة بلا دليل. أخرج JSON فقط دون Markdown بالشكل {"records":[{"subjectName":"اسم المادة كما يظهر","day":"الأحد","startTime":"08:00","endTime":"10:00","room":"","lecturer":""}]}. استخدم أيام الأسبوع العربية أو الإنجليزية. وحّد الوقت إلى 24 ساعة HH:mm. تجاهل الخلايا الفارغة والملاحظات الإدارية. لا تخمّن المواد أو الأيام أو الأوقات؛ إذا لم تكن قيمة أساسية واضحة، اتركها فارغة ولا تنشئ سجلًا ناقصًا.''';
  }

  Future<List<Map<String, dynamic>>> _extractStructuredWithVision(Uint8List bytes, String contentType) async {
    try {
      final dataUrl = 'data:$contentType;base64,${base64Encode(bytes)}';
      final result = await widget.api.post('/eino/vision', body: {
        'image': dataUrl,
        'mode': _extractionPrompt(),
      });
      final text = (result['text'] ?? result['answer'] ?? '').toString().trim();
      if (text.isEmpty) return [];
      final jsonText = text
          .replaceFirst(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '')
          .replaceFirst(RegExp(r'\s*```$'), '')
          .trim();
      final start = jsonText.indexOf('{');
      final end = jsonText.lastIndexOf('}');
      if (start < 0 || end <= start) return [];
      final decoded = jsonDecode(jsonText.substring(start, end + 1));
      final rawRecords = decoded is List ? decoded : (decoded is Map ? (decoded['records'] ?? decoded['students'] ?? decoded['schedule'] ?? decoded['lessons']) : null);
      if (rawRecords is! List) return [];
      final rows = <Map<String, dynamic>>[];
      for (final item in rawRecords) {
        if (item is! Map) continue;
        final record = Map<String, dynamic>.from(item);
        if (_students) {
          final number = _digits('${record['studentNumber'] ?? record['student_number'] ?? record['studentId'] ?? record['id'] ?? ''}').trim();
          final name = '${record['fullName'] ?? record['full_name'] ?? record['studentName'] ?? record['name'] ?? ''}'.trim();
          final email = '${record['email'] ?? ''}'.trim();
          if (number.isEmpty || name.isEmpty) continue;
          rows.add({'studentNumber': number, 'fullName': name, 'email': email});
        } else {
          final subjectName = '${record['subjectName'] ?? record['subject'] ?? record['course'] ?? record['name'] ?? ''}'.trim();
          final dayText = '${record['day'] ?? record['dayOfWeek'] ?? record['day_of_week'] ?? ''}'.trim();
          final startTime = _time(record['startTime'] ?? record['start_time'] ?? record['start'] ?? '');
          final endTime = _time(record['endTime'] ?? record['end_time'] ?? record['end'] ?? '');
          final dayValue = _dayNumber(dayText);
          if (subjectName.isEmpty || dayText.isEmpty || startTime.isEmpty || endTime.isEmpty || startTime.compareTo(endTime) >= 0) continue;
          final matches = _availableSubjects.where((subject) => _header(_name(subject)) == _header(subjectName) || _header(subject['name_en'] ?? '') == _header(subjectName)).toList();
          rows.add({
            'subjectId': matches.length == 1 ? '${matches.first['id']}' : '',
            'subjectName': subjectName,
            'dayOfWeek': dayValue,
            'dayLabel': _dayName(dayValue),
            'startTime': startTime,
            'endTime': endTime,
            'room': '${record['room'] ?? ''}'.trim(),
            'lecturer': '${record['lecturer'] ?? record['instructor'] ?? ''}'.trim(),
            'existingId': '',
          });
        }
      }
      // Deduplicate identical cells returned twice by a vision model.
      final unique = <String, Map<String, dynamic>>{};
      for (final row in rows) {
        final key = _students
            ? '${row['studentNumber']}|${_header('${row['fullName']}')}'
            : '${row['dayOfWeek']}|${row['startTime']}|${row['endTime']}|${_header('${row['subjectName']}')}';
        unique.putIfAbsent(key, () => row);
      }
      return unique.values.toList();
    } catch (_) {
      // A provider or response-format failure should not prevent OCR fallback.
      return [];
    }
  }

  List<Map<String, dynamic>> _parseGrid(List<List<dynamic>> grid) {
    final nonEmpty = grid.map((r) => r.map((c) => _digits('$c').trim()).toList()).where((r) => r.any((c) => c.isNotEmpty)).toList();
    if (nonEmpty.isEmpty) { throw const ApiServiceException('لم يعثر الملف على صفوف تحتوي بيانات.'); }
    final headers = nonEmpty.first.map(_header).toList();
    int find(List<String> names) => headers.indexWhere((h) => names.any((n) => h == _header(n) || h.contains(_header(n))));
    if (_students) {
      final n = find(['الرقم الجامعي','رقم الطالب','studentnumber','studentid','idnumber','number']);
      final f = find(['اسم الطالب','الاسم الكامل','الاسم','fullname','studentname','name']);
      final e = find(['البريد الالكتروني','البريد','email','emailaddress']);
      final hasHeader = n >= 0 || f >= 0 || e >= 0;
      final data = hasHeader ? nonEmpty.skip(1) : nonEmpty;
      final numberIndex = n >= 0 ? n : 0; final nameIndex = f >= 0 ? f : 1;
      return data.map((r) => {'studentNumber': _digits(_cell(r, numberIndex)).trim(), 'fullName': _cell(r, nameIndex), 'email': e >= 0 ? _cell(r,e) : ''})
        .where((r) => '${r['studentNumber']}'.isNotEmpty && RegExp(r'^\d+(?:-\d+)?$').hasMatch('${r['studentNumber']}') && '${r['fullName']}'.trim().isNotEmpty)
        .toList();
    }
    final sub = find(['المادة','اسم المادة','المقرر','subject','subjectname','course']);
    final day = find(['اليوم','day','dayofweek']);
    final start = find(['بداية','وقت البداية','من','start','starttime']);
    final end = find(['نهاية','وقت النهاية','الى','إلى','end','endtime']);
    if (sub < 0 && day < 0 && start < 0 && end < 0) {
      _notes.add('لم تُعرف أعمدة اليوم والمادة والوقت. لم تُنشأ سجلات تخمينية؛ أدخل الحصص المطلوبة يدويًا أو استخدم صورة أوضح.');
      return [];
    }
    final data = nonEmpty.skip(1);
    return data.map((r) {
      final subjectName = _cell(r, sub);
      final dayText = _cell(r, day);
      final startTime = _time(_cell(r, start));
      final endTime = _time(_cell(r, end));
      final matched = _availableSubjects.where((s) => _header(_name(s)) == _header(subjectName) || _header(s['name_en'] ?? '') == _header(subjectName)).toList();
      return {'subjectId': matched.length == 1 ? '${matched.first['id']}' : '', 'subjectName': subjectName,
        'dayOfWeek': _dayNumber(dayText), 'daySource': dayText, 'startTime': startTime, 'endTime': endTime, 'room': '', 'lecturer': ''};
    }).where((r) => '${r['subjectName']}'.trim().isNotEmpty && _isDayValue('${r['daySource']}') && RegExp(r'^\d{2}:\d{2}$').hasMatch('${r['startTime']}') && RegExp(r'^\d{2}:\d{2}$').hasMatch('${r['endTime']}') && '${r['startTime']}'.compareTo('${r['endTime']}') < 0).map((r) { r.remove('daySource'); return r; }).toList();
  }

  String _cell(List<String> row, int i) => i >= 0 && i < row.length ? row[i].trim() : '';
  String _dayName(dynamic value) { final day = int.tryParse('$value') ?? 0; return const ['الأحد','الاثنين','الثلاثاء','الأربعاء','الخميس','الجمعة','السبت'][day.clamp(0,6).toInt()]; }
  int _dayNumber(String value) {
    final v = _header(value);
    const names = {'الاحد':0,'sunday':0,'الاثنين':1,'monday':1,'الثلاثاء':2,'tuesday':2,'الاربعاء':3,'wednesday':3,'الخميس':4,'thursday':4,'الجمعة':5,'friday':5,'السبت':6,'saturday':6};
    return int.tryParse(v) != null ? int.parse(v).clamp(0,6).toInt() : (names[v] ?? 0);
  }

  bool _isDayValue(String value) {
    final v = _header(value);
    const names = {'الاحد','sunday','الاثنين','monday','الثلاثاء','tuesday','الاربعاء','wednesday','الخميس','thursday','الجمعة','friday','السبت','saturday'};
    final numeric = int.tryParse(v);
    return names.contains(v) || (numeric != null && numeric >= 0 && numeric <= 6);
  }



  List<Map<String, dynamic>> _parseTimetableMatrix(List<List<String>> grid) {
    if (_students || grid.length < 2) return [];
    final headerIndex = grid.indexWhere((row) => row.where((cell) => _parseTimeRange(cell) != null).length >= 2);
    if (headerIndex < 0) return [];
    final header = grid[headerIndex];
    final slots = <int, ({String start, String end})>{};
    for (var i = 0; i < header.length; i++) {
      final range = _parseTimeRange(header[i]);
      if (range != null) slots[i] = range;
    }
    if (slots.length < 2) return [];
    final output = <Map<String, dynamic>>[];
    for (final row in grid.skip(headerIndex + 1)) {
      var dayIndex = -1;
      var day = 0;
      for (var i = 0; i < row.length; i++) {
        final value = row[i].trim();
        final normalized = _header(value);
        const dayNames = ['الاحد','الاثنين','الثلاثاء','الاربعاء','الخميس','الجمعة','السبت'];
        if (dayNames.contains(normalized) || ['sunday','monday','tuesday','wednesday','thursday','friday','saturday'].contains(normalized)) {
          dayIndex = i;
          day = _dayNumber(value);
          break;
        }
      }
      if (dayIndex < 0) continue;
      final entries = <({int column, String subject, String start, String end})>[];
      for (final entry in slots.entries) {
        if (entry.key >= row.length || entry.key == dayIndex) continue;
        final subject = row[entry.key].trim();
        if (subject.isEmpty || _parseTimeRange(subject) != null || _header(subject).contains('اليوم')) continue;
        entries.add((column: entry.key, subject: subject, start: entry.value.start, end: entry.value.end));
      }
      // Merge adjacent cells with the same subject when OCR preserves the
      // table's cell positions (e.g. a lab spanning two periods).
      entries.sort((a,b) => a.start.compareTo(b.start));
      final merged = <({String subject, String start, String end})>[];
      for (final entry in entries) {
        if (merged.isNotEmpty && _header(merged.last.subject) == _header(entry.subject) && merged.last.end == entry.start) {
          final previous = merged.removeLast();
          merged.add((subject: previous.subject, start: previous.start, end: entry.end));
        } else {
          merged.add((subject: entry.subject, start: entry.start, end: entry.end));
        }
      }
      for (final item in merged) {
        final matches = _availableSubjects.where((subject) => _header(_name(subject)) == _header(item.subject) || _header(subject['name_en'] ?? '') == _header(item.subject)).toList();
        output.add({
          'subjectId': matches.length == 1 ? '${matches.first['id']}' : '',
          'subjectName': item.subject,
          'dayOfWeek': day,
          'dayLabel': _dayName(day),
          'startTime': item.start,
          'endTime': item.end,
          'room': '', 'lecturer': '', 'existingId': '',
        });
      }
    }
    return output;
  }

  ({String start, String end})? _parseTimeRange(String raw) {
    final value = _digits(raw).replaceAll('٫', ':').trim();
    final match = RegExp(r'(\d{1,2}(?::\d{1,2})?)\s*[-–—]\s*(\d{1,2}(?::\d{1,2})?)').firstMatch(value);
    if (match == null) return null;
    var first = _time(match.group(1));
    var second = _time(match.group(2));
    if (!RegExp(r'^\d{2}:\d{2}$').hasMatch(first) || !RegExp(r'^\d{2}:\d{2}$').hasMatch(second)) return null;
    // OCR for Arabic RTL timetables often reverses the two values and drops
    // the leading 1 in afternoon times (e.g. 4:00-2:00 means 14:00-16:00).
    var firstHour = int.parse(first.substring(0, 2));
    var secondHour = int.parse(second.substring(0, 2));
    if (firstHour <= 4 && secondHour <= 4 && (firstHour >= 1 || secondHour >= 1)) {
      firstHour += 12;
      secondHour += 12;
    } else if (firstHour <= 4 && secondHour >= 12) {
      firstHour += 12;
    } else if (secondHour <= 4 && firstHour >= 12) {
      secondHour += 12;
    }
    first = '${firstHour.toString().padLeft(2, '0')}${first.substring(2)}';
    second = '${secondHour.toString().padLeft(2, '0')}${second.substring(2)}';
    final start = first.compareTo(second) < 0 ? first : second;
    final end = first.compareTo(second) < 0 ? second : first;
    if (start == end) return null;
    return (start: start, end: end);
  }

  List<Map<String, dynamic>> _parseOcrText(String text) {
    final lines = text.split(RegExp(r'\r?\n')).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final tableRows = <List<String>>[];
    for (final line in lines) {
      if (!line.contains('|')) { continue; }
      final cells = line.split('|').map((c) => c.trim()).toList();
      if (cells.isNotEmpty && cells.first.isEmpty) { cells.removeAt(0); }
      if (cells.isNotEmpty && cells.last.isEmpty) { cells.removeLast(); }
      if (cells.isEmpty || cells.every((c) => c.isEmpty || RegExp(r'^:?-{2,}:?$').hasMatch(c))) { continue; }
      tableRows.add(cells);
    }
    if (tableRows.isNotEmpty) {
      if (!_students) {
        final timetable = _parseTimetableMatrix(tableRows);
        if (timetable.isNotEmpty) return timetable;
      }
      return _parseGrid(tableRows);
    }
    // A plain OCR transcript is intentionally not guessed into records. Return
    // empty so the reviewer gets editable blank rows and an explicit warning.
    return [];
  }

  void _addRow() { setState(() { _error = null; _rows.add(_students ? _studentRow() : _scheduleRow()); }); _startCountdown(); }
  void _removeRow(int index) { setState(() { _error = null; _rows.removeAt(index); }); _startCountdown(); }
  void _change(int i, String key, dynamic value) { setState(() { _error = null; _rows[i][key] = value; }); _startCountdown(); }
  Future<void> _closeDialog() async {
    final id = _operationId;
    if (id != null) { try { await widget.api.delete('/admin/imports/$id'); } catch (_) {} }
    if (mounted) { Navigator.of(context).pop(false); }
  }

  Future<void> _commit() async {
    if (_operationId == null) { return; }
    setState(() { _working = true; _error = null; });
    try {
      final validation = await widget.api.post('/admin/imports/$_operationId/validate', body: {'records': _rows});
      if (validation['valid'] != true) {
        final errors = validation['errors'] is List ? (validation['errors'] as List).whereType<Map>().toList() : <Map>[];
        final message = errors.take(12).map((e) => 'السجل ${(int.tryParse('${e['index']}') ?? -1) + 1}: ${e['message'] ?? 'تحقق من البيانات'}').join('\n');
        if (mounted) { setState(() => _error = 'لم يتم الحفظ. صحح الأخطاء التالية أو احذف السجلات غير المطلوبة ثم أعد الاعتماد:\n$message'); }
        return;
      }
      await widget.api.patch('/admin/imports/$_operationId', body: {'records': _rows});
      final result = await widget.api.post('/admin/imports/$_operationId/commit', body: {'records': _rows});
      if (!mounted) { return; }
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم اعتماد الاستيراد. السجلات المحفوظة: ${result['saved'] ?? 0}')));
    } catch (e) {
      if (mounted && e.toString().contains('IMPORT_EXPIRED')) {
        Navigator.of(context).pop(false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('انتهت مهلة عملية الاستيراد. ارجع إلى صفحة الطلاب أو الجداول وابدأ عملية جديدة.')));
      } else if (mounted) { setState(() => _error = _friendlyError(e)); }
    } finally { if (mounted) { setState(() => _working = false); } }
  }

  @override
  Widget build(BuildContext context) {
    final title = _students ? 'مسح واستيراد الطلاب' : 'مسح واستيراد الجدول';
    return Dialog.fullscreen(child: SafeArea(child: Column(children: [
      AppBar(title: Text(title), leading: IconButton(onPressed: _working ? null : _closeDialog, icon: const Icon(Icons.close)), automaticallyImplyLeading: false),
      Expanded(child: !_review ? _setupView() : _reviewView()),
    ])));
  }

  Widget _setupView() => ListView(padding: const EdgeInsets.all(20), children: [
    const Text('اختر القسم والفصل، ثم حدّد الملف لمراجعته قبل الحفظ.'), const SizedBox(height: 18),
    DropdownButtonFormField<String>(initialValue: _departmentId, decoration: const InputDecoration(labelText: 'القسم', border: OutlineInputBorder()), items: widget.departments.map((d) => DropdownMenuItem(value: '${d['id']}', child: Text(_name(d)))).toList(), onChanged: _working ? null : (v) => setState(() => _departmentId = v)),
    const SizedBox(height: 12),
    DropdownButtonFormField<String>(initialValue: _semesterId, decoration: const InputDecoration(labelText: 'الفصل الدراسي', border: OutlineInputBorder()), items: widget.semesters.map((s) => DropdownMenuItem(value: '${s['id']}', child: Text(_name(s)))).toList(), onChanged: _working ? null : (v) => setState(() => _semesterId = v)),
    if (_error != null) _errorBanner(_error!), if (_working) const LinearProgressIndicator(),
    const SizedBox(height: 16), FilledButton.icon(onPressed: _working ? null : _pickAndScan, icon: const Icon(Icons.document_scanner_outlined), label: const Text('اختيار الملف وبدء المسح')),
  ]);

  Widget _reviewView() => Column(children: [
    Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(_filename ?? 'ملف مستورد', style: Theme.of(context).textTheme.titleMedium),
      Text('القسم: ${_firstName(widget.departments.where((d) => '${d['id']}' == _departmentId))} • الفصل: ${_firstName(widget.semesters.where((s) => '${s['id']}' == _semesterId))}'),
      if (_expiresAt != null) Text('تنتهي مهلة العملية: $_expiresAt', style: Theme.of(context).textTheme.bodySmall),
      ..._notes.map((n) => Padding(padding: const EdgeInsets.only(top: 6), child: Text(n, style: TextStyle(color: Theme.of(context).colorScheme.tertiary)))),
      if (_error != null) _errorBanner(_error!),
    ])),
    const Divider(height: 1),
    Expanded(child: _rows.isEmpty ? const Center(child: Text('لا توجد سجلات. أضف سجلًا يدويًا أو ارجع واختر ملفًا آخر.')) : ListView.builder(itemCount: _rows.length, itemBuilder: (context, i) => _students ? _studentEditor(i) : _scheduleEditor(i))),
    Padding(padding: const EdgeInsets.all(12), child: Row(children: [OutlinedButton.icon(onPressed: _working ? null : _addRow, icon: const Icon(Icons.add), label: const Text('إضافة صف')), const Spacer(), if (_working) const SizedBox(width: 24,height:24,child:CircularProgressIndicator(strokeWidth:2)), const SizedBox(width: 10), FilledButton.icon(onPressed: _working || _rows.isEmpty || _countdown > 0 ? null : _commit, icon: const Icon(Icons.check), label: Text(_countdown > 0 ? 'اعتماد بعد $_countdown ثوانٍ' : 'اعتماد وإضافة'))])),
  ]);

  Widget _studentEditor(int i) {
    final row = _rows[i];
    return Card(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5), child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
      Row(children: [Text('الطالب ${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold)), const Spacer(), IconButton(tooltip: 'حذف الصف من الاستيراد', onPressed: () => _removeRow(i), icon: const Icon(Icons.delete_outline))]),
      TextFormField(initialValue: '${row['studentNumber'] ?? ''}', decoration: const InputDecoration(labelText: 'الرقم الجامعي'), onChanged: (v) => _change(i,'studentNumber',_digits(v).trim())),
      TextFormField(initialValue: '${row['fullName'] ?? ''}', decoration: const InputDecoration(labelText: 'اسم الطالب'), onChanged: (v) => _change(i,'fullName',v)),
      TextFormField(initialValue: '${row['email'] ?? ''}', decoration: const InputDecoration(labelText: 'البريد الإلكتروني (اختياري)'), onChanged: (v) => _change(i,'email',v)),
    ])));
  }

  Widget _scheduleEditor(int i) {
    final row = _rows[i]; final day = int.tryParse('${row['dayOfWeek']}') ?? 0;
    return Card(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5), child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
      Row(children: [Text('الحصة ${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold)), const Spacer(), IconButton(tooltip: 'حذف الحصة من الاستيراد', onPressed: () => _removeRow(i), icon: const Icon(Icons.delete_outline))]),
      DropdownButtonFormField<String>(initialValue: _existingSchedules.any((s) => '${s['id']}' == '${row['existingId']}') ? '${row['existingId']}' : '', decoration: const InputDecoration(labelText: 'الإجراء (اختياري: استبدال حصة موجودة)'), items: [const DropdownMenuItem<String>(value: '', child: Text('إضافة حصة جديدة')), ..._existingSchedules.map((s) => DropdownMenuItem<String>(value: '${s['id']}', child: Text('${_firstName(_availableSubjects.where((sub) => '${sub['id']}' == '${s['subject_id']}'))} • ${_dayName(s['day_of_week'])} • ${s['start_time']}–${s['end_time']}', overflow: TextOverflow.ellipsis)))], onChanged: (v) => _change(i, 'existingId', v ?? '')),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(initialValue: _availableSubjects.any((s) => '${s['id']}' == '${row['subjectId']}') ? '${row['subjectId']}' : null, decoration: const InputDecoration(labelText: 'المادة الجديدة'), items: _availableSubjects.map((s) => DropdownMenuItem(value: '${s['id']}', child: Text(_name(s)))).toList(), onChanged: (v) { setState(() { _error = null; _rows[i]['subjectId'] = v ?? ''; _rows[i]['subjectName'] = _firstName(_availableSubjects.where((s) => '${s['id']}' == v)); }); _startCountdown(); }),
      const SizedBox(height: 8), DropdownButtonFormField<int>(initialValue: day.clamp(0,6).toInt(), decoration: const InputDecoration(labelText: 'اليوم'), items: const [DropdownMenuItem(value:0,child:Text('الأحد')),DropdownMenuItem(value:1,child:Text('الاثنين')),DropdownMenuItem(value:2,child:Text('الثلاثاء')),DropdownMenuItem(value:3,child:Text('الأربعاء')),DropdownMenuItem(value:4,child:Text('الخميس')),DropdownMenuItem(value:5,child:Text('الجمعة')),DropdownMenuItem(value:6,child:Text('السبت'))], onChanged: (v) => _change(i,'dayOfWeek',v ?? 0)),
      Row(children: [Expanded(child: TextFormField(initialValue: '${row['startTime'] ?? ''}', decoration: const InputDecoration(labelText: 'وقت البداية', hintText: '08:00'), onChanged: (v) => _change(i,'startTime',_time(v)))), const SizedBox(width: 10), Expanded(child: TextFormField(initialValue: '${row['endTime'] ?? ''}', decoration: const InputDecoration(labelText: 'وقت النهاية', hintText: '10:00'), onChanged: (v) => _change(i,'endTime',_time(v))))]),
      Row(children: [Expanded(child: TextFormField(initialValue: '${row['room'] ?? ''}', decoration: const InputDecoration(labelText: 'القاعة (اختياري)'), onChanged: (v) => _change(i,'room',v))), const SizedBox(width: 10), Expanded(child: TextFormField(initialValue: '${row['lecturer'] ?? ''}', decoration: const InputDecoration(labelText: 'المدرّس (اختياري)'), onChanged: (v) => _change(i,'lecturer',v)))]),
    ])));
  }

  Widget _errorBanner(String message) => Container(margin: const EdgeInsets.symmetric(vertical: 8), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Theme.of(context).colorScheme.errorContainer, borderRadius: BorderRadius.circular(10)), child: Text(message, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)));
}

class _PreparedOcrUpload {
  const _PreparedOcrUpload(this.bytes, this.filename, this.contentType);
  final Uint8List bytes;
  final String filename;
  final String contentType;
}
