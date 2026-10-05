import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/network/authenticated_client.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/models/schedule_item.dart';
import '../../data/repositories/schedule_repository.dart';
import '../../shared/widgets/login_required_card.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() =>
      _ScheduleScreenState();
}

class _ScheduleScreenState
    extends State<ScheduleScreen> {
  ApiClient? _client;
  late Future<ScheduleData> _future;
  int? _selectedDay;
  bool _week = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<ScheduleData> _load() async {
    _client ??= await AuthenticatedClient.create();

    return ScheduleRepository(_client!).getSchedule();
  }

  Future<void> _reload() async {
    final future = _load();

    setState(() {
      _future = future;
    });

    await future;
  }

  @override
  void dispose() {
    _client?.dispose();
    super.dispose();
  }

  String _day(AppLocalizations l10n, int number) {
    return {
          0: l10n.t('daySunday'),
          1: l10n.t('dayMonday'),
          2: l10n.t('dayTuesday'),
          3: l10n.t('dayWednesday'),
          4: l10n.t('dayThursday'),
          5: l10n.t('dayFriday'),
          6: l10n.t('daySaturday'),
        }[number] ??
        l10n.t('today');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<ScheduleData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            final e = snapshot.error;
            if (e is ApiException && (e.kind == ApiErrorKind.auth || e.code == 'AUTH_REQUIRED')) return const LoginRequiredCard();
            return _Msg(message: e is ApiException ? e.message : AppLocalizations.of(context).t('connectionFailed'), retry: _reload);
          }

          final data = snapshot.data!;

          final days = data.days.isEmpty
              ? (data.items
                    .map((item) => item.dayOfWeek)
                    .toSet()
                    .toList()
                  ..sort())
              : data.days;

          if (_selectedDay == null && days.isNotEmpty) {
            _selectedDay = days.first;
          }

          final shown = _week
              ? data.items
              : data.items
                  .where(
                    (item) =>
                        item.dayOfWeek ==
                        _selectedDay,
                  )
                  .toList();

          return ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(
              14.72,
              12,
              14.72,
              92,
            ),
            children: [
              Text(
                l10n.t('scheduleTitle'),
                textAlign: TextAlign.end,
                style: const TextStyle(
                  fontSize: 20.2,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${data.department?['name_ar'] ?? ''} • '
                '${data.semester?['name_ar'] ?? ''}',
                textAlign: TextAlign.end,
                style: TextStyle(
                  color: context.colors.onSurfaceVariant,
                  fontSize: 11.5,
                ),
              ),
              const SizedBox(height: 10),
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: false,
                    label: Text(l10n.t('today')),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text(l10n.t('week')),
                  ),
                ],
                selected: {_week},
                onSelectionChanged: (values) {
                  setState(() {
                    _week = values.first;
                  });
                },
              ),
              const SizedBox(height: 10),
              if (days.isNotEmpty)
                SizedBox(
                  height: 62,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: days.length,
                    separatorBuilder: (
                      context,
                      index,
                    ) =>
                        const SizedBox(width: 6),
                    itemBuilder: (
                      context,
                      index,
                    ) {
                      final day = days[index];

                      return ChoiceChip(
                        label: Text(
                          _day(l10n, day),
                          style: const TextStyle(
                            fontSize: 10,
                          ),
                        ),
                        selected: !_week &&
                            day == _selectedDay,
                        onSelected: (_) {
                          setState(() {
                            _selectedDay = day;
                          });
                        },
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              if (shown.isEmpty)
                Container(
                  height: 180,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius:
                        BorderRadius.circular(15),
                    border: Border.all(
                      color: context.colors.outline,
                    ),
                  ),
                  child: Text(
                    l10n.t('noScheduledLectures'),
                    style: TextStyle(
                      color:
                          context.colors.onSurfaceVariant,
                    ),
                  ),
                )
              else
                for (final item in shown)
                  Padding(
                    padding:
                        const EdgeInsets.only(bottom: 8),
                    child: _Lecture(item: item),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _Lecture extends StatelessWidget {
  const _Lecture({
    required this.item,
  });

  final ScheduleItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.colors.outline,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: context.colors.primary.withValues(
                alpha: .12,
              ),
              borderRadius:
                  BorderRadius.circular(11),
            ),
            child: Icon(
              Icons.menu_book_rounded,
              color: context.colors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.end,
              children: [
                Text(
                  item.subjectName,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  [
                    if (item.room?.isNotEmpty == true)
                       '${AppLocalizations.of(context).t('room')} ${item.room}',
                    if (item.lecturer?.isNotEmpty == true)
                      item.lecturer!,
                  ].join(' • '),
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 9.5,
                    color:
                        context.colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${item.startTime}\n${item.endTime}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.colors.primary,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _Msg extends StatelessWidget {
  const _Msg({
    required this.message,
    required this.retry,
  });

  final String message;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: retry,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
            label: Text(
              AppLocalizations.of(context)
                  .t('retry'),
            ),
          ),
        ],
      ),
    );
  }
}