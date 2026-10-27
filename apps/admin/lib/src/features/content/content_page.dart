import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;

import '../../api_service.dart';
import '../../admin_permissions.dart';

enum _ContentKind { news, events, achievements, announcements }

// Keep these values aligned with the category maps in web/portal/news.html and
// web/portal/Injazat.html. The values (not just their labels) are sent to the API.
const Map<String, String> _newsCategoryOptions = {
  'statement': 'بيان رسمي',
  'coverage': 'تغطية إعلامية',
  'academic': 'نشاط أكاديمي',
  'إعلان هام': 'إعلان هام',
};
const Map<String, String> _achievementCategoryOptions = {
  'أكاديمي': 'إنجاز أكاديمي',
  'رياضي': 'إنجاز رياضي',
  'تكريم': 'تكريم',
  'قيادة': 'إنجاز قيادي',
  'تاريخي': 'إنجاز تاريخي',
  'مبادرة': 'مبادرة',
};

extension on _ContentKind {
  String get endpoint => switch (this) {
        _ContentKind.news => 'news',
        // The backend exposes the events table through the legacy 'activities' resource.
        _ContentKind.events => 'activities',
        _ContentKind.achievements => 'achievements',
        _ContentKind.announcements => 'announcements',
      };
  String get label => switch (this) {
        _ContentKind.news => 'الأخبار',
        _ContentKind.events => 'الأنشطة',
        _ContentKind.achievements => 'الإنجازات',
        _ContentKind.announcements => 'الإعلانات',
      };
  IconData get icon => switch (this) {
        _ContentKind.news => Icons.article_outlined,
        _ContentKind.events => Icons.event_outlined,
        _ContentKind.achievements => Icons.emoji_events_outlined,
        _ContentKind.announcements => Icons.campaign_outlined,
      };
}

class ContentPage extends StatefulWidget {
  const ContentPage({super.key, required this.api, required this.role});
  final ApiService api;
  final String role;

  @override
  State<ContentPage> createState() => _ContentPageState();
}

class _ContentPageState extends State<ContentPage> {
  late final List<_ContentKind> _kinds;
  _ContentKind _kind = _ContentKind.news;
  String _query = '';
  List<Map<String, dynamic>> _items = [];
  bool _loading = false;
  String? _error;
  int _loadRevision = 0;

  @override
  void initState() {
    super.initState();
    _kinds = [
      _ContentKind.news,
      _ContentKind.events,
      _ContentKind.achievements,
    ];
    _kind = _kinds.first;
    _load();
  }

  Future<void> _load() => _loadKind(_kind);

  Future<void> _loadKind(_ContentKind kind) async {
    // Ignore late responses from a previously selected tab. Otherwise a slow
    // request for News can overwrite the list after the user has selected Events.
    final revision = ++_loadRevision;
    setState(() { _loading = true; _error = null; });
    try {
      final response = await widget.api.get('/admin/${kind.endpoint}?limit=100');
      final raw = response['data'];
      final rows = raw is List
          ? raw.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList()
          : <Map<String, dynamic>>[];
      if (mounted && revision == _loadRevision && _kind == kind) {
        setState(() => _items = rows);
      }
    } catch (error) {
      if (mounted && revision == _loadRevision && _kind == kind) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted && revision == _loadRevision) {
        setState(() => _loading = false);
      }
    }
  }

  void _selectKind(_ContentKind kind) {
    if (_kind == kind) {
      // Tapping the active section is also a predictable way to retry/refresh it.
      _loadKind(kind);
      return;
    }
    setState(() {
      _kind = kind;
      _items = [];
      _query = '';
      _error = null;
    });
    _loadKind(kind);
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _query.trim().toLowerCase();
    return _items.where((item) {
      final text = '${item['title'] ?? ''} ${item['body'] ?? item['description'] ?? ''} ${item['category'] ?? ''}'.toLowerCase();
      return q.isEmpty || text.contains(q);
    }).toList();
  }

  DateTime? _date(dynamic value) => value == null ? null : DateTime.tryParse(value.toString());
  DateTime get _today => DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  String _eventStatus(Map<String, dynamic> item) {
    final start = _date(item['event_at']);
    final end = _date(item['end_at']);
    if (end != null && !_today.isBefore(DateTime(end.year, end.month, end.day).add(const Duration(days: 1)))) { return 'منتهي'; }
    if (start == null && end == null) { return 'جارٍ الآن'; }
    if (start == null) { return 'جارٍ الآن'; }
    final startDay = DateTime(start.year, start.month, start.day);
    if (_today.isBefore(startDay)) { return 'قريبًا'; }
    return 'جارٍ الآن';
  }

  String _newsStatus(Map<String, dynamic> item) {
    final date = _date(item['publish_at']);
    return date != null && DateTime(date.year, date.month, date.day).isAfter(_today) ? 'مجدول' : 'منشور';
  }

  String _achievementStatus(Map<String, dynamic> item) {
    final date = _date(item['achieved_at']);
    return date != null && DateTime(date.year, date.month, date.day).isAfter(_today) ? 'مجدول' : 'منشور';
  }

  Future<void> _edit([Map<String, dynamic>? item]) async {
    final isCreate = item == null;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _ContentEditor(api: widget.api, kind: _kind, initial: item),
    );
    if (result == null || !mounted) { return; }
    try {
      final id = item?['id']?.toString();
      if (id == null || id.isEmpty) {
        await widget.api.post('/admin/${_kind.endpoint}', body: result);
      } else {
        await widget.api.patch('/admin/${_kind.endpoint}/$id', body: result);
      }
      if (!mounted) { return; }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isCreate ? 'تم إنشاء السجل.' : 'تم حفظ التعديلات.')));
      await _load();
    } catch (error) {
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حفظ المحتوى: $error'))); }
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final id = item['id']?.toString() ?? '';
    if (id.isEmpty) { return; }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المحتوى؟'),
        content: Text('سيتم حذف «${item['title'] ?? 'هذا السجل'}» نهائيًا. قد تُحذف التفاعلات المرتبطة به أيضًا.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف نهائيًا')),
        ],
      ),
    );
    if (confirmed != true || !mounted) { return; }
    try {
      await widget.api.delete('/admin/${_kind.endpoint}/$id');
      if (!mounted) { return; }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف المحتوى.')));
      await _load();
    } catch (error) {
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر الحذف: $error'))); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canEdit = widget.role == AdminPermissions.superAdmin ||
        widget.role == AdminPermissions.contentManager;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
      children: [
        Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 12, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('إدارة المحتوى', style: theme.textTheme.headlineMedium?.copyWith(fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('إدارة السجلات المنشورة مباشرة عبر واجهة الخادم المعتمدة.', style: theme.textTheme.bodyMedium),
          ]),
          if (canEdit) FilledButton.icon(onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('إضافة محتوى')),
        ]),
        const SizedBox(height: 20),
        // Use real Material buttons rather than a custom tap surface, so the
        // selected section is accessible and reliably interactive on touch devices.
        LayoutBuilder(builder: (context, constraints) {
          final compact = constraints.maxWidth < 420;
          return Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7)),
            ),
            child: Row(
              children: [
                for (final kind in _kinds)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: SizedBox(
                        height: compact ? 68 : 48,
                        child: _kind == kind
                            ? FilledButton.tonal(
                                onPressed: () => _selectKind(kind),
                                style: FilledButton.styleFrom(
                                  padding: EdgeInsets.symmetric(horizontal: compact ? 2 : 8, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                                ),
                                child: compact
                                    ? Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                                        Icon(kind.icon, size: 20),
                                        const SizedBox(height: 4),
                                        Text(kind.label, maxLines: 1, overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700)),
                                      ])
                                    : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                        Icon(kind.icon, size: 19),
                                        const SizedBox(width: 6),
                                        Flexible(child: Text(kind.label, maxLines: 1, overflow: TextOverflow.ellipsis)),
                                      ]),
                              )
                            : OutlinedButton(
                                onPressed: () => _selectKind(kind),
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(horizontal: compact ? 2 : 8, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                                  side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.8)),
                                ),
                                child: compact
                                    ? Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                                        Icon(kind.icon, size: 20),
                                        const SizedBox(height: 4),
                                        Text(kind.label, maxLines: 1, overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700)),
                                      ])
                                    : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                        Icon(kind.icon, size: 19),
                                        const SizedBox(width: 6),
                                        Flexible(child: Text(kind.label, maxLines: 1, overflow: TextOverflow.ellipsis)),
                                      ]),
                              ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(width: 300, child: TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'البحث في العنوان والوصف', isDense: true),
            onChanged: (value) => setState(() => _query = value),
          )),
          OutlinedButton.icon(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh), label: const Text('تحديث')),
        ]),
        const SizedBox(height: 18),
        if (_loading && _items.isEmpty)
          const Padding(padding: EdgeInsets.all(36), child: Center(child: CircularProgressIndicator()))
        else if (_error != null && _items.isEmpty)
          Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.cloud_off_outlined, size: 32), const SizedBox(height: 8),
            const Text('تعذر تحميل المحتوى', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6), Text(_error!), const SizedBox(height: 12),
            FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة')),
          ])))
        else if (_filtered.isEmpty)
          Card(child: Padding(padding: const EdgeInsets.all(28), child: Column(children: [
            const Icon(Icons.inbox_outlined, size: 40), const SizedBox(height: 10),
            const Text('لا توجد سجلات مطابقة.', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4), Text('غيّر عوامل التصفية أو أضف سجلًا جديدًا.', style: theme.textTheme.bodyMedium),
          ])))
        else ...[
          Row(children: [Expanded(child: Text('${_kind.label} (${_filtered.length})', style: theme.textTheme.titleMedium)), if (_loading) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))]),
          const SizedBox(height: 10),
          for (final item in _filtered) Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(padding: const EdgeInsets.all(16), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)), child: Icon(_kind.icon, color: theme.colorScheme.primary)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item['title']?.toString() ?? 'بلا عنوان', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text((item['body'] ?? item['description'] ?? item['intro'] ?? '').toString(), maxLines: 3, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  if (_kind == _ContentKind.events) Chip(label: Text(_eventStatus(item)), visualDensity: VisualDensity.compact),
                  if (_kind == _ContentKind.news) Chip(label: Text(_newsStatus(item)), visualDensity: VisualDensity.compact),
                  if (_kind == _ContentKind.achievements) Chip(label: Text(_achievementStatus(item)), visualDensity: VisualDensity.compact),
                  if ((item['category'] ?? '').toString().isNotEmpty) Chip(label: Text(item['category'].toString()), visualDensity: VisualDensity.compact),
                  if ((item['created_at'] ?? '').toString().isNotEmpty) Text(item['created_at'].toString(), style: theme.textTheme.bodySmall),
                ]),
              ])),
              if (canEdit) PopupMenuButton<String>(
                tooltip: 'إجراءات السجل',
                onSelected: (value) { if (value == 'edit') { _edit(item); } if (value == 'delete') { _delete(item); } },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('تعديل'), contentPadding: EdgeInsets.zero)),
                  PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline), title: Text('حذف'), contentPadding: EdgeInsets.zero)),
                ],
              ),
            ])),
          ),
        ],
      ],
    );
  }
}

class _ContentEditor extends StatefulWidget {
  const _ContentEditor({required this.api, required this.kind, this.initial});
  final ApiService api;
  final _ContentKind kind;
  final Map<String, dynamic>? initial;
  @override
  State<_ContentEditor> createState() => _ContentEditorState();
}

class _ContentEditorState extends State<_ContentEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _imageUrl;
  late final TextEditingController _body;
  late final TextEditingController _category;
  late final TextEditingController _publisher;
  late final TextEditingController _location;
  late final TextEditingController _type;
  late final TextEditingController _eventAt;
  late final TextEditingController _endAt;
  late final TextEditingController _achievedAt;
  late final TextEditingController _publishAt;
  late final TextEditingController _expiresAt;
  late final TextEditingController _targetDepartment;
  late final TextEditingController _targetSemester;
  late final TextEditingController _highlightsTitle;
  late final TextEditingController _highlights;
  bool _busy = false;
  bool _uploadingImage = false;
  String? _imageError;
  final List<String> _achievementImages = <String>[];

  DateTime? _readDate(String value) {
    final raw = value.trim();
    final iso = DateTime.tryParse(raw); if (iso != null) { return iso; }
    final parts = raw.split('/');
    if (parts.length == 3) { final d = int.tryParse(parts[0]); final m = int.tryParse(parts[1]); final y = int.tryParse(parts[2]); if (d != null && m != null && y != null) { return DateTime(y,m,d); } }
    return null;
  }
  String _isoDate(String value) { final date = _readDate(value); return date == null ? '' : DateTime(date.year,date.month,date.day).toIso8601String(); }
  String _displayDate(String value) { final date = _readDate(value); return date == null ? '' : '${date.day.toString().padLeft(2,'0')}/${date.month.toString().padLeft(2,'0')}/${date.year}'; }
  Future<void> _pickDate(TextEditingController controller) async {
    final now = DateTime.now();
    final current = _readDate(controller.text);
    final picked = await showDatePicker(context: context, initialDate: current ?? now, firstDate: DateTime(2000), lastDate: DateTime(2100), helpText: 'اختر التاريخ');
    if (picked != null) { controller.text = '${picked.day.toString().padLeft(2,'0')}/${picked.month.toString().padLeft(2,'0')}/${picked.year}'; }
  }

  Future<Uint8List> _compressImage(Uint8List input) async {
    final decoded = img.decodeImage(input);
    if (decoded == null) throw const ApiServiceException('تعذر قراءة الصورة المختارة.');
    var image = decoded;
    const maxDimension = 2400;
    if (image.width > maxDimension || image.height > maxDimension) {
      image = img.copyResize(image, width: image.width >= image.height ? maxDimension : null,
          height: image.height > image.width ? maxDimension : null, interpolation: img.Interpolation.average);
    }
    // JPEG quality is reduced gradually only if needed; 90+ is visually high quality.
    for (final quality in <int>[92, 89, 86, 82, 78]) {
      final output = Uint8List.fromList(img.encodeJpg(image, quality: quality));
      if (output.length <= 2 * 1024 * 1024) return output;
    }
    final output = Uint8List.fromList(img.encodeJpg(image, quality: 75));
    if (output.length > 3 * 1024 * 1024) throw const ApiServiceException('تعذر ضغط الصورة إلى الحجم المسموح.');
    return output;
  }

  Future<void> _pickAndUploadImage() async {
    final isAchievement = widget.kind == _ContentKind.achievements;
    final remaining = isAchievement ? 10 - _achievementImages.length : 1;
    if (remaining <= 0) { setState(() => _imageError = 'يمكن إضافة 10 صور كحد أقصى للإنجاز.'); return; }
    final picked = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: isAchievement, withData: true);
    if (picked == null || picked.files.isEmpty || !mounted) return;
    final files = picked.files.take(remaining).toList();
    setState(() { _uploadingImage = true; _imageError = null; });
    try {
      final urls = <String>[];
      for (final file in files) {
        final bytes = file.bytes;
        if (bytes == null || bytes.isEmpty) throw ApiServiceException('تعذر قراءة الصورة ${file.name}.');
        final compressed = await _compressImage(bytes);
        final uploaded = await widget.api.uploadImage(bytes: compressed,
            filename: '${file.name.replaceAll(RegExp(r'\.[^.]+$'), '')}.jpg', contentType: 'image/jpeg');
        final url = uploaded['url']?.toString() ?? '';
        if (url.isEmpty) throw const ApiServiceException('لم يُرجع الخادم رابط الصورة.');
        urls.add(url);
      }
      if (mounted) setState(() {
        if (isAchievement) {
          _achievementImages.addAll(urls);
          _imageUrl.text = _achievementImages.isEmpty ? '' : _achievementImages.first;
        } else if (urls.isNotEmpty) { _imageUrl.text = urls.first; }
      });
    } catch (e) { if (mounted) setState(() => _imageError = e.toString()); }
    finally { if (mounted) setState(() => _uploadingImage = false); }
  }

  @override
  void initState() {
    super.initState();
    final item = widget.initial ?? {};
    _title = TextEditingController(text: item['title']?.toString() ?? '');
    _imageUrl = TextEditingController(text: item['image_url']?.toString() ?? '');
    final rawImages = item['images_json'] ?? item['images'];
    if (rawImages is List) { _achievementImages.addAll(rawImages.map((v) => v is Map ? '${v['url'] ?? ''}' : '$v').where((v) => v.trim().isNotEmpty).take(10)); }
    else if (rawImages is String && rawImages.trim().isNotEmpty) { try { final parsed = jsonDecode(rawImages); if (parsed is List) _achievementImages.addAll(parsed.map((v) => v is Map ? '${v['url'] ?? ''}' : '$v').where((v) => v.trim().isNotEmpty).take(10)); } catch (_) {} }
    if (_achievementImages.isEmpty && _imageUrl.text.trim().isNotEmpty && widget.kind == _ContentKind.achievements) _achievementImages.add(_imageUrl.text.trim());
    _body = TextEditingController(text: (item['body'] ?? item['description'] ?? item['intro'] ?? '').toString());
    final savedCategory = (widget.kind == _ContentKind.achievements
        ? item['badge']
        : item['category'])?.toString() ?? '';
    final knownCategories = widget.kind == _ContentKind.news
        ? _newsCategoryOptions.keys.toSet()
        : _achievementCategoryOptions.keys.toSet();
    // Events still use their existing free-text category. For news and
    // achievements, unknown legacy values remain unselected so the admin
    // explicitly chooses an approved value rather than silently rewriting it.
    _category = TextEditingController(
      text: widget.kind == _ContentKind.events || knownCategories.contains(savedCategory)
          ? savedCategory
          : '',
    );
    _publisher = TextEditingController(text: item['publisher']?.toString() ?? '');
    _location = TextEditingController(text: item['location']?.toString() ?? '');
    _type = TextEditingController(text: item['type']?.toString() ?? 'general');
    _eventAt = TextEditingController(text: item['event_at']?.toString() ?? '');
    _endAt = TextEditingController(text: item['end_at']?.toString() ?? '');
    _achievedAt = TextEditingController(text: item['achieved_at']?.toString() ?? '');
    _publishAt = TextEditingController(text: (item['publish_at'] ?? item['event_at'] ?? '').toString());
    _expiresAt = TextEditingController(text: item['expires_at']?.toString() ?? '');
    for (final controller in [_publishAt, _eventAt, _endAt, _achievedAt, _expiresAt]) { final formatted = _displayDate(controller.text); if (formatted.isNotEmpty) { controller.text = formatted; } }
    _targetDepartment = TextEditingController(text: item['target_department_id']?.toString() ?? '');
    _targetSemester = TextEditingController(text: item['target_semester_id']?.toString() ?? '');
    _highlightsTitle = TextEditingController(text: item['highlights_title']?.toString() ?? '');
    final rawHighlights = item['highlights'];
    var highlightsText = rawHighlights?.toString() ?? '';
    if (rawHighlights is List) {
      highlightsText = rawHighlights.join('\n');
    } else if (rawHighlights is String && rawHighlights.trim().startsWith('[')) {
      try { final parsed = jsonDecode(rawHighlights); if (parsed is List) { highlightsText = parsed.join('\n'); } } catch (_) { /* Keep the original value visible for manual correction. */ }
    }
    _highlights = TextEditingController(text: highlightsText);
  }

  @override
  void dispose() {
    _title.dispose(); _imageUrl.dispose(); _body.dispose(); _category.dispose(); _publisher.dispose(); _location.dispose(); _type.dispose(); _eventAt.dispose(); _endAt.dispose(); _achievedAt.dispose(); _publishAt.dispose(); _expiresAt.dispose(); _targetDepartment.dispose(); _targetSemester.dispose(); _highlightsTitle.dispose(); _highlights.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) { return; }
    final title = _title.text.trim();
    final body = _body.text.trim();
    final todayIso = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).toIso8601String();
    if (widget.kind == _ContentKind.news && _publishAt.text.trim().isEmpty) { _publishAt.text = _displayDate(todayIso); }
    if (widget.kind == _ContentKind.achievements && _achievedAt.text.trim().isEmpty) { _achievedAt.text = _displayDate(todayIso); }
    if (widget.kind == _ContentKind.events && _eventAt.text.trim().isEmpty && _endAt.text.trim().isEmpty) {
      // Both event dates are optional; absence of both means the event is ongoing.
    }
    final startDate = _readDate(_eventAt.text);
    final endDate = _readDate(_endAt.text);
    if (widget.kind == _ContentKind.events && startDate != null && endDate != null && DateTime(startDate.year, startDate.month, startDate.day).isAfter(DateTime(endDate.year, endDate.month, endDate.day))) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تاريخ بداية الفعالية لا يمكن أن يكون بعد تاريخ انتهائها.')));
      return;
    }
    final payload = <String, dynamic>{'title': title};
    switch (widget.kind) {
      case _ContentKind.news:
        payload.addAll({'body': body, 'category': _category.text.trim(), 'publisher': _publisher.text.trim(), 'image_url': _imageUrl.text.trim(), 'publish_at': _isoDate(_publishAt.text)});
        break;
      case _ContentKind.events:
        payload.addAll({'body': body, 'category': _category.text.trim(), 'publisher': _publisher.text.trim(), 'image_url': _imageUrl.text.trim(), 'location': _location.text.trim(), 'event_at': _isoDate(_eventAt.text), 'end_at': _isoDate(_endAt.text)});
        break;
      case _ContentKind.achievements:
        payload.addAll({'description': body, 'intro': body, 'publisher': _publisher.text.trim(), 'badge': _category.text.trim(), 'image_url': _achievementImages.isNotEmpty ? _achievementImages.first : _imageUrl.text.trim(), 'images_json': jsonEncode(_achievementImages.take(10).toList()), 'achieved_at': _isoDate(_achievedAt.text)});
        break;
      case _ContentKind.announcements:
        payload.addAll({'body': body, 'type': _type.text.trim().isEmpty ? 'general' : _type.text.trim(), 'target_department_id': _targetDepartment.text.trim().isEmpty ? null : _targetDepartment.text.trim(), 'target_semester_id': _targetSemester.text.trim().isEmpty ? null : _targetSemester.text.trim(), 'publish_at': _publishAt.text.trim().isEmpty ? null : _publishAt.text.trim(), 'expires_at': _expiresAt.text.trim().isEmpty ? null : _expiresAt.text.trim()});
        break;
    }
    setState(() => _busy = true);
    Navigator.of(context).pop(payload);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.kind == _ContentKind.achievements
        ? (widget.initial == null ? 'نشر إنجاز جديد' : 'تعديل الإنجاز')
        : (widget.initial == null ? 'إضافة ${widget.kind.label}' : 'تعديل ${widget.kind.label}')),
    content: SizedBox(width: 520, child: SingleChildScrollView(child: Form(key: _formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextFormField(controller: _title, decoration: const InputDecoration(labelText: 'العنوان'), validator: (v) => v == null || v.trim().isEmpty ? 'العنوان مطلوب' : null),
      const SizedBox(height: 12),
      TextFormField(controller: _body, minLines: 3, maxLines: 7, decoration: InputDecoration(labelText: widget.kind == _ContentKind.achievements ? 'الوصف' : 'المحتوى'), validator: (v) => v == null || v.trim().isEmpty ? 'المحتوى مطلوب' : null),
      if (widget.kind == _ContentKind.news || widget.kind == _ContentKind.events || widget.kind == _ContentKind.achievements) ...[
        const SizedBox(height: 12),
        if (widget.kind == _ContentKind.news || widget.kind == _ContentKind.achievements)
          DropdownButtonFormField<String>(
            value: _category.text.isNotEmpty ? _category.text : null,
            decoration: InputDecoration(
              labelText: widget.kind == _ContentKind.achievements ? 'تصنيف الإنجاز' : 'تصنيف الخبر',
            ),
            items: (widget.kind == _ContentKind.achievements
                    ? _achievementCategoryOptions
                    : _newsCategoryOptions)
                .entries
                .map((entry) => DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(entry.value),
                    ))
                .toList(),
            validator: (value) => value == null || value.isEmpty ? 'يرجى اختيار التصنيف' : null,
            onChanged: (value) => setState(() => _category.text = value ?? ''),
          )
        else
          TextFormField(controller: _category, decoration: const InputDecoration(labelText: 'تصنيف النشاط (اختياري)')),
        const SizedBox(height: 12),
        TextFormField(controller: _publisher, decoration: const InputDecoration(labelText: 'اسم الناشر (اختياري)')),
      ],
      if (widget.kind == _ContentKind.news) ...[
        const SizedBox(height: 12), TextFormField(controller: _publishAt, readOnly: true, onTap: () => _pickDate(_publishAt), decoration: const InputDecoration(labelText: 'تاريخ النشر (اختياري)', suffixIcon: Icon(Icons.calendar_month))),
      ],
      if (widget.kind == _ContentKind.events) ...[
        const SizedBox(height: 12), TextFormField(controller: _location, decoration: const InputDecoration(labelText: 'المكان (اختياري)')),
        const SizedBox(height: 12), TextFormField(controller: _eventAt, readOnly: true, onTap: () => _pickDate(_eventAt), decoration: const InputDecoration(labelText: 'تاريخ الفعالية (اختياري)', suffixIcon: Icon(Icons.calendar_month))),
        const SizedBox(height: 12), TextFormField(controller: _endAt, readOnly: true, onTap: () => _pickDate(_endAt), decoration: const InputDecoration(labelText: 'تاريخ نهاية الفعالية (اختياري)', suffixIcon: Icon(Icons.calendar_month))),
      ],
      if (widget.kind == _ContentKind.achievements) ...[
        const SizedBox(height: 12), TextFormField(controller: _achievedAt, readOnly: true, onTap: () => _pickDate(_achievedAt), decoration: const InputDecoration(labelText: 'تاريخ الإنجاز (اختياري)', suffixIcon: Icon(Icons.calendar_month))),
      ],
      if (widget.kind == _ContentKind.news || widget.kind == _ContentKind.events || widget.kind == _ContentKind.achievements) ...[
        const Divider(height: 28),
        Align(alignment: AlignmentDirectional.centerStart, child: Text('الصورة', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
        const SizedBox(height: 8),
        if (widget.kind == _ContentKind.achievements && _achievementImages.isNotEmpty)
          Wrap(spacing: 8, runSpacing: 8, children: [for (var i = 0; i < _achievementImages.length; i++)
            Stack(children: [ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(_achievementImages[i], height: 86, width: 86, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(height: 86, width: 86, color: Theme.of(context).colorScheme.surfaceContainerHighest, child: const Icon(Icons.broken_image_outlined))),),
              PositionedDirectional(top: 2, end: 2, child: IconButton.filledTonal(visualDensity: VisualDensity.compact, constraints: const BoxConstraints.tightFor(width: 28, height: 28), padding: EdgeInsets.zero, onPressed: _uploadingImage ? null : () => setState(() { _achievementImages.removeAt(i); _imageUrl.text = _achievementImages.isEmpty ? '' : _achievementImages.first; }), icon: const Icon(Icons.close, size: 16)))])]),
        if (widget.kind != _ContentKind.achievements && _imageUrl.text.trim().isNotEmpty) ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(_imageUrl.text, height: 150, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(height: 70, child: Center(child: Text('تعذر عرض معاينة الصورة'))))),
        Align(alignment: AlignmentDirectional.centerStart, child: OutlinedButton.icon(onPressed: _uploadingImage || (widget.kind == _ContentKind.achievements && _achievementImages.length >= 10) ? null : _pickAndUploadImage, icon: _uploadingImage ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.photo_library_outlined), label: Text(_uploadingImage ? 'جارٍ ضغط ورفع الصور…' : widget.kind == _ContentKind.achievements ? 'إضافة صور (${_achievementImages.length}/10)' : 'اختيار صورة من المعرض'))),
        if (_imageError != null) Align(alignment: AlignmentDirectional.centerStart, child: Text(_imageError!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
      ],
    ])))),
    actions: [
      TextButton(onPressed: (_busy || _uploadingImage) ? null : () => Navigator.pop(context), child: const Text('إلغاء')),
      FilledButton(
        onPressed: (_busy || _uploadingImage) ? null : _save,
        child: Text(widget.kind == _ContentKind.achievements
            ? (widget.initial == null ? 'نشر الإنجاز' : 'حفظ التعديلات')
            : 'حفظ'),
      ),
    ],
  );
}
