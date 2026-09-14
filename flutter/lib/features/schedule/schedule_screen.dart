import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/network/api_client.dart';
import '../../core/network/authenticated_client.dart';
import '../../data/models/schedule_item.dart';
import '../../data/repositories/schedule_repository.dart';
import '../../shared/widgets/list_skeleton.dart';
import '../../shared/widgets/responsive_content.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  ApiClient? _client;
  ScheduleRepository? _repository;
  Future<ScheduleData>? _future;
  Future<List<Map<String, dynamic>>>? _semestersFuture;
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
      _semestersFuture = _repository!.semesters();
      final future = _repository!.getSchedule(semesterId: _semesterId);
      if (mounted) setState(() => _future = future);
    } catch (_) {}
  }

  Future<ScheduleData> _load() {
    final repository = _repository;
    if (repository == null) {
      return Future.error(ApiException(AppLocalizations.of(context).t('sessionInitializing')));
    }
    return repository.getSchedule(semesterId: _semesterId);
  }

  @override
  void dispose() {
    _client?.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final future = _load();
    if (mounted) setState(() => _future = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('schedule'))),
      body: ResponsiveContent(
        padding: EdgeInsets.zero,
        child: FutureBuilder<ScheduleData>(
        future: _future ?? Future.error(ApiException(AppLocalizations.of(context).t('sessionInitializing'))),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ListSkeleton();
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
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                _HeaderCard(data: data, locale: locale),
                const SizedBox(height: 14),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _semestersFuture ??= _repository?.semesters() ?? Future.value(const <Map<String, dynamic>>[]),
                  builder: (context, semestersSnapshot) {
                    final semesters = semestersSnapshot.data ?? const <Map<String, dynamic>>[];
                    if (semesters.isEmpty) return const SizedBox.shrink();
                    return DropdownButtonFormField<String>(
                      initialValue: _semesterId ?? data.semester?['id']?.toString(),
                      decoration: InputDecoration(labelText: l10n.t('semester'), border: const OutlineInputBorder()),
                      items: semesters.map((semester) {
                        final id = semester['id']?.toString();
                        final name = _localizedName(locale, semester['name_fr'], semester['name_en'], semester['name_ar']);
                        return DropdownMenuItem(value: id, child: Text(name.isNotEmpty ? name : (id ?? '')));
                      }).toList(),
                      onChanged: (value) { _semesterId = value; _selectedDay = null; _reload(); },
                    );
                  },
                ),
                const SizedBox(height: 14),
                if (days.isNotEmpty) _DayPicker(days: days, selected: selected, onChanged: (day) => setState(() => _selectedDay = day)),
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

String _localizedName(Locale locale, dynamic fr, dynamic en, dynamic ar) {
  final candidates = locale.languageCode == 'fr' ? [fr, en, ar] : locale.languageCode == 'en' ? [en, ar, fr] : [ar, en, fr];
  for (final value in candidates) {
    if (value != null && value.toString().trim().isNotEmpty) return value.toString();
  }
  return '—';
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.data, required this.locale});
  final ScheduleData data;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    final semesterName = _localizedName(locale, data.semester?['name_fr'], data.semester?['name_en'], data.semester?['name_ar']);
    final departmentName = _localizedName(locale, data.department?['name_fr'], data.department?['name_en'], data.department?['name_ar']);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(15)), child: Icon(Icons.calendar_month_rounded, color: Theme.of(context).colorScheme.onPrimaryContainer)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(departmentName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(semesterName, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ])),
        ]),
      ),
    );
  }
}

class _DayPicker extends StatelessWidget {
  const _DayPicker({required this.days, required this.selected, required this.onChanged});
  final List<int> days;
  final int? selected;
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
            return ChoiceChip(label: Text(_dayName(context, day)), selected: day == selected, onSelected: (_) => onChanged(day));
          },
        ),
      );

  String _dayName(BuildContext context, int day) {
    final keys = ['daySunday', 'dayMonday', 'dayTuesday', 'dayWednesday', 'dayThursday', 'dayFriday', 'daySaturday'];
    if (day < 0 || day >= keys.length) return AppLocalizations.of(context).t('dayUnknown', {'day': '$day'});
    return AppLocalizations.of(context).t(keys[day]);
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
            Container(
              width: 76,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .10), borderRadius: BorderRadius.circular(14)),
              child: Column(children: [
                Icon(Icons.schedule_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 5),
                Text(item.startTime, textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
                Text(item.endTime, textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall),
              ]),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(subject.isEmpty ? '—' : subject, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              if (item.subjectCode?.isNotEmpty == true) ...[const SizedBox(height: 3), Text(item.subjectCode!, style: Theme.of(context).textTheme.labelMedium)],
              const SizedBox(height: 9),
              Wrap(spacing: 10, runSpacing: 6, children: [
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
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 56), const SizedBox(height: 14), Text(text, textAlign: TextAlign.center), if (retry != null) ...[const SizedBox(height: 14), OutlinedButton(onPressed: retry, child: Text(AppLocalizations.of(context).t('retry')))]])));
}
