import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/network/authenticated_client.dart';
import '../../data/models/schedule_item.dart';
import '../../data/repositories/schedule_repository.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  ApiClient? _client;
  ScheduleRepository? _repository;
  Future<ScheduleData>? _future;
  String? _semesterId;
  int? _selectedDay;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      _client = await AuthenticatedClient.create();
      _repository = ScheduleRepository(_client!);
      final future = _repository!.getSchedule(semesterId: _semesterId);
      if (mounted) setState(() => _future = future);
    } catch (_) {}
  }

  Future<ScheduleData> _load() {
    final repository = _repository;
    if (repository == null) {
      return Future.error(const ApiException('جارٍ تهيئة جلسة الطالب.'));
    }
    return repository.getSchedule(semesterId: _semesterId);
  }

  @override
  void dispose() {
    _client?.dispose();
    super.dispose();
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('schedule'))),
      body: FutureBuilder<ScheduleData>(
        future: _future ?? Future.error(const ApiException('جارٍ تهيئة جلسة الطالب.')),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ScheduleMessage(
              icon: Icons.cloud_off_outlined,
              text: snapshot.error is ApiException
                  ? (snapshot.error! as ApiException).message
                  : l10n.t('connectionFailed'),
              retry: _reload,
            );
          }
          final data = snapshot.data!;
          final days = data.days.isNotEmpty ? data.days : _groupByDay(data.items).keys.toList()..sort();
          final selected = _selectedDay != null && days.contains(_selectedDay) ? _selectedDay! : (days.isNotEmpty ? days.first : null);
          if (_selectedDay != selected && mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _selectedDay = selected);
            });
          }
          final items = selected == null ? const <ScheduleItem>[] : data.items.where((e) => e.dayOfWeek == selected).toList();
          return RefreshIndicator(
            onRefresh: () async { _reload(); await _future; },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                _HeaderCard(data: data, locale: locale),
                const SizedBox(height: 14),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _repository?.semesters() ?? Future.value(const <Map<String, dynamic>>[]),
                  builder: (context, semestersSnapshot) {
                    final semesters = semestersSnapshot.data ?? const <Map<String, dynamic>>[];
                    if (semesters.isEmpty) return const SizedBox.shrink();
                    return DropdownButtonFormField<String>(
                      value: _semesterId ?? data.semester?['id']?.toString(),
                      decoration: InputDecoration(labelText: l10n.t('semester'), border: const OutlineInputBorder()),
                      items: semesters.map((semester) {
                        final id = semester['id']?.toString();
                        final name = locale.languageCode == 'en' ? (semester['name_en'] ?? semester['name_ar']) : semester['name_ar'];
                        return DropdownMenuItem(value: id, child: Text(name?.toString() ?? id ?? ''));
                      }).toList(),
                      onChanged: (value) { _semesterId = value; _selectedDay = null; _reload(); },
                    );
                  },
                ),
                const SizedBox(height: 14),
                if (days.isNotEmpty) _DayPicker(days: days, selected: selected, locale: locale, onChanged: (day) => setState(() => _selectedDay = day)),
                const SizedBox(height: 16),
                if (items.isEmpty)
                  _ScheduleMessage(icon: Icons.event_busy_outlined, text: l10n.t('scheduleEmpty'))
                else
                  ...items.map((item) => _ClassCard(item: item, locale: locale)),
              ],
            ),
          );
        },
      ),
    );
  }

  Map<int, List<ScheduleItem>> _groupByDay(List<ScheduleItem> items) {
    final grouped = <int, List<ScheduleItem>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.dayOfWeek, () => []).add(item);
    }
    return grouped;
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.data, required this.locale});
  final ScheduleData data;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    final semesterName = locale.languageCode == 'en'
        ? (data.semester?['name_en'] ?? data.semester?['name_ar'])
        : data.semester?['name_ar'];
    final departmentName = locale.languageCode == 'en'
        ? (data.department?['name_en'] ?? data.department?['name_ar'])
        : data.department?['name_ar'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(15)), child: Icon(Icons.calendar_month_rounded, color: Theme.of(context).colorScheme.onPrimaryContainer)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(departmentName?.toString() ?? '—', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(semesterName?.toString() ?? '—', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ])),
        ]),
      ),
    );
  }
}

class _DayPicker extends StatelessWidget {
  const _DayPicker({required this.days, required this.selected, required this.locale, required this.onChanged});
  final List<int> days;
  final int? selected;
  final Locale locale;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 52,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: days.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, index) {
            final day = days[index];
            return ChoiceChip(label: Text(_dayName(day, locale)), selected: day == selected, onSelected: (_) => onChanged(day));
          },
        ),
      );

  String _dayName(int day, Locale locale) {
    const ar = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
    const en = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    const fr = ['Dimanche', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];
    final values = switch (locale.languageCode) { 'en' => en, 'fr' => fr, _ => ar };
    return day >= 0 && day < values.length ? values[day] : 'Day $day';
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.item, required this.locale});
  final ScheduleItem item;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    final subject = locale.languageCode == 'en' && (item.subjectNameEn?.isNotEmpty ?? false) ? item.subjectNameEn! : item.subjectName;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 4, height: 64, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(4))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(subject.isEmpty ? '—' : subject, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              if (item.subjectCode?.isNotEmpty == true) ...[const SizedBox(height: 3), Text(item.subjectCode!, style: Theme.of(context).textTheme.labelMedium)],
              const SizedBox(height: 9),
              Wrap(spacing: 10, runSpacing: 6, children: [
                _Meta(icon: Icons.schedule_rounded, text: '${item.startTime} – ${item.endTime}'),
                if (item.room?.isNotEmpty == true) _Meta(icon: Icons.location_on_outlined, text: item.room!),
                if (item.lecturer?.isNotEmpty == true) _Meta(icon: Icons.person_outline_rounded, text: item.lecturer!),
              ]),
            ])),
          ]),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant), const SizedBox(width: 5), Text(text, style: Theme.of(context).textTheme.bodySmall)]);
}

class _ScheduleMessage extends StatelessWidget {
  const _ScheduleMessage({required this.icon, required this.text, this.retry});
  final IconData icon;
  final String text;
  final VoidCallback? retry;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 56), const SizedBox(height: 14), Text(text, textAlign: TextAlign.center), if (retry != null) ...[const SizedBox(height: 14), OutlinedButton(onPressed: retry, child: const Text('إعادة المحاولة'))]])));
}
