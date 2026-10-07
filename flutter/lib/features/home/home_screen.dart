import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/errors/error_message.dart';
import '../../core/errors/app_error.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/models/content_item.dart';
import '../../data/models/student_profile.dart';
import '../../data/models/schedule_item.dart';
import '../../data/repositories/schedule_repository.dart';
import '../../core/di/app_dependencies.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/list_skeleton.dart';
import '../../features/eino/eino_face.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _homeNewsLimit = 3;
  Future<_HomeData>? _future;
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<_HomeData> _load() async {
    final newsFuture = AppDependencies.instance.content.news();

    final studentRepo = AppDependencies.instance.student;
    final profileFuture = studentRepo.profile();
    final scheduleFuture = AppDependencies.instance.schedule.getSchedule();

    final values = await Future.wait<dynamic>([
      newsFuture,
      profileFuture,
      scheduleFuture,
    ]);

    return _HomeData(
      values[0] as List<ContentItem>,
      values[1] as StudentProfile,
      values[2] as ScheduleData,
    );
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return RefreshIndicator(
      onRefresh: () async {
        final future = _load();
        setState(() => _future = future);
        await future;
      },
      child: FutureBuilder<_HomeData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ListSkeleton(count: 4);
          }

          if (snapshot.hasError) {
            final Object e = snapshot.error ?? Exception('Unknown error');
            return _StateMessage(
              message: ErrorMessage.from(context, e, fallbackKey: 'connectionFailed'),
              retry: e is ApiException && !e.retryable ? null : () => setState(() => _future = _load()),
            );
          }

          final data = snapshot.data!;

          return ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(
              DesignTokens.space16,
              DesignTokens.space16,
              DesignTokens.space16,
              96,
            ),
            children: [
              AppCard(
                padding: const EdgeInsets.all(DesignTokens.space20),
                borderColor: context.colors.primary.withValues(alpha: .28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      l10n.t('hello', {'name': data.profile.name.split(' ').first}),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.5,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      data.profile.departmentName ?? 'TRINEX',
                      style: TextStyle(
                        color: context.colors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Transform.translate(
                            offset: const Offset(0, -6),
                            child: _HomeScheduleCard(
                              schedule: data.schedule,
                              onTap: () => context.push('/schedule'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 92,
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 92),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                            decoration: BoxDecoration(
                              color: context.colors.surface,
                              borderRadius: BorderRadius.circular(DesignTokens.radius16),
                              border: Border.all(color: context.colors.outline),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.school_rounded, color: context.colors.tertiary, size: 22),
                                const SizedBox(height: 6),
                                Text(
                                  data.profile.semesterName ?? '—',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: context.colors.tertiary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  l10n.t('semesterShort'),
                                  style: TextStyle(
                                    color: context.colors.onSurfaceVariant,
                                    fontSize: 9.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DesignTokens.space24),
              Text(
                l10n.t('quickAccess'),
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: DesignTokens.space12),
              Row(
                children: [
                  Expanded(
                    child: _Tile(
                      l10n.t('materials'),
                      Icons.menu_book_rounded,
                      context.colors.secondary,
                      () => context.go('/materials'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Tile(
                      l10n.t('media'),
                      Icons.newspaper_rounded,
                      context.colors.primary,
                      () => context.go('/media'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Tile(
                      l10n.t('favorites'),
                      Icons.favorite_border_rounded,
                      context.colors.tertiary,
                      () => context.push('/favorites'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DesignTokens.space16),
              _EinoHomeCard(
                onTap: () => context.push('/eino?from=home'),
              ),
              const SizedBox(height: DesignTokens.space16),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    l10n.t('newsLatest'),
                    style: const TextStyle(
                      fontSize: 20.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.article_outlined,
                    color: context.colors.primary,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (data.news.isEmpty)
                AppCard(
                  child: Text(
                    l10n.t('noData'),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                for (final item in data.news.take(_HomeScreenState._homeNewsLimit))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: _NewsTile(
                      item: item,
                      onTap: () => context.push(
                        '/media/detail?type=news&id=${Uri.encodeQueryComponent(item.id)}',
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _HomeData {
  const _HomeData(
    this.news,
    this.profile,
    this.schedule,
  );

  final List<ContentItem> news;
  final StudentProfile profile;
  final ScheduleData schedule;
}

class _Tile extends StatelessWidget {
  const _Tile(
    this.title,
    this.icon,
    this.color,
    this.onTap,
  );

  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DesignTokens.radius16),
      child: Container(
        height: 92,
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(DesignTokens.radius16),
          border: Border.all(
            color: context.colors.outline,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(DesignTokens.radius12),
              ),
              child: Icon(icon, color: color, size: 23),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewsTile extends StatelessWidget {
  const _NewsTile({
    required this.item,
    required this.onTap,
  });

  final ContentItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      semanticLabel: item.title,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: context.colors.primary.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(DesignTokens.radius12),
            ),
            child: Icon(Icons.campaign_rounded, color: context.colors.primary, size: 23),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  if (item.summary?.isNotEmpty == true) ...[
                    const SizedBox(height: 3),
                    Text(
                      item.summary!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: TextStyle(color: context.colors.onSurfaceVariant, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.message,
    required this.retry,
  });

  final String message;
  final VoidCallback? retry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 50,
              color: context.colors.primary,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            if (retry != null) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: retry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(AppLocalizations.of(context).t('retry')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EinoHomeCard extends StatelessWidget {
  const _EinoHomeCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Material(
      color: cs.primaryContainer.withValues(alpha: .42),
      borderRadius: BorderRadius.circular(DesignTokens.radius20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesignTokens.radius20),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 12, 12),
          child: Row(
            children: [
              const EinoFace(size: 58, mood: EinoMood.happy, showAura: false),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.t('einoCardTitle'), style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(l10n.t('einoHomeSubtitle'), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5, height: 1.3)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 16, color: cs.primary),
            ],
          ),
        ),
      ),
    );
  }
}



class _HomeScheduleCard extends StatelessWidget {
  const _HomeScheduleCard({
    required this.schedule,
    required this.onTap,
  });

  final ScheduleData schedule;
  final VoidCallback onTap;

  static const _sudanOffset = Duration(hours: 2);

  DateTime _sudanNow() => DateTime.now().toUtc().add(_sudanOffset);

  int _minuteOfDay(String value) {
    final parts = value.split(':');
    final hour = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
    return (hour * 60 + minute).clamp(0, 1439);
  }

  DateTime _at(DateTime day, String time) {
    final minutes = _minuteOfDay(time);
    return DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60);
  }

  _ScheduleState _state() {
    final now = _sudanNow();
    final today = now.weekday % 7; // Database convention: Sunday = 0.
    final todayItems = schedule.items
        .where((item) => item.dayOfWeek == today)
        .toList()
      ..sort((a, b) => _minuteOfDay(a.startTime).compareTo(_minuteOfDay(b.startTime)));

    ScheduleItem? current;
    ScheduleItem? next;
    ScheduleItem? lastEnded;
    for (final item in todayItems) {
      final start = _at(now, item.startTime);
      var end = _at(now, item.endTime);
      // Be defensive with malformed overnight rows instead of producing a negative duration.
      if (!end.isAfter(start)) end = end.add(const Duration(days: 1));

      if (!now.isBefore(start) && now.isBefore(end)) {
        current = item;
        final index = todayItems.indexOf(item);
        if (index + 1 < todayItems.length) next = todayItems[index + 1];
        break;
      }
      if (!now.isBefore(end)) lastEnded = item;
      if (now.isBefore(start)) {
        next = item;
        break;
      }
    }

    return _ScheduleState(
      now: now,
      current: current,
      next: next,
      lastEnded: lastEnded,
      hasTodayClasses: todayItems.isNotEmpty,
    );
  }

  String _duration(Duration duration, AppLocalizations l10n) {
    final totalMinutes = duration.inMinutes.clamp(0, 24 * 60);
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (l10n.locale.languageCode == 'ar') {
      String arabicMinutes(int value) {
        if (value == 1) return 'دقيقة';
        if (value == 2) return 'دقيقتين';
        if (value >= 3 && value <= 10) return '$value دقائق';
        return '$value دقيقة';
      }

      String arabicHours(int value) {
        if (value == 1) return 'ساعة';
        if (value == 2) return 'ساعتين';
        if (value >= 3 && value <= 10) return '$value ساعات';
        return '$value ساعة';
      }

      if (hours == 0) return arabicMinutes(minutes);
      if (minutes == 0) return arabicHours(hours);
      return '${arabicHours(hours)} و${arabicMinutes(minutes)}';
    }

    if (hours == 0) {
      return l10n.t('scheduleMinutes', {'count': '$minutes'});
    }
    if (minutes == 0) {
      return l10n.t('scheduleHours', {'count': '$hours'});
    }
    return l10n.t('scheduleHoursMinutes', {
      'hours': '$hours',
      'minutes': '$minutes',
    });
  }

  String _clock(String value) => value.length >= 5 ? value.substring(0, 5) : value;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final state = _state();

    Color accent;
    IconData icon;
    String eyebrow;
    String title;
    String subtitle;
    String? secondary;

    if (state.current != null) {
      final item = state.current!;
      final end = _at(state.now, item.endTime);
      accent = AppColors.success;
      icon = Icons.play_circle_fill_rounded;
      eyebrow = l10n.t('scheduleNow');
      title = item.subjectName;
      subtitle = l10n.t('scheduleEndsIn', {
        'time': _duration(end.difference(state.now), l10n),
      });
      if (state.next != null) {
        final start = _at(state.now, state.next!.startTime);
        secondary = '${l10n.t('scheduleNext')} ${state.next!.subjectName} • '
            '${l10n.t('scheduleStartsIn', {'time': _duration(start.difference(state.now), l10n)})}';
      }
    } else if (state.next != null) {
      final item = state.next!;
      final start = _at(state.now, item.startTime);
      accent = cs.primary;
      icon = Icons.schedule_rounded;
      eyebrow = l10n.t('scheduleNext');
      title = item.subjectName;
      subtitle = l10n.t('scheduleStartsIn', {
        'time': _duration(start.difference(state.now), l10n),
      });
      secondary = '${_clock(item.startTime)} – ${_clock(item.endTime)}';
    } else if (state.lastEnded != null) {
      final item = state.lastEnded!;
      accent = cs.onSurfaceVariant;
      icon = Icons.check_circle_outline_rounded;
      eyebrow = l10n.t('scheduleEnded');
      title = item.subjectName;
      subtitle = l10n.t('scheduleNoMoreToday');
    } else if (!state.hasTodayClasses) {
      accent = cs.primary;
      icon = Icons.event_available_rounded;
      eyebrow = l10n.t('scheduleToday');
      title = l10n.t('scheduleNoClassesToday');
      subtitle = l10n.t('scheduleTapToView');
    } else {
      accent = cs.onSurfaceVariant;
      icon = Icons.event_busy_rounded;
      eyebrow = l10n.t('scheduleToday');
      title = l10n.t('scheduleNoMoreToday');
      subtitle = l10n.t('scheduleTapToView');
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesignTokens.radius16),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: .07),
            borderRadius: BorderRadius.circular(DesignTokens.radius16),
            border: Border.all(color: accent.withValues(alpha: .35)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(DesignTokens.radius12),
                ),
                child: Icon(icon, color: accent, size: 24),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      eyebrow,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color: accent,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (secondary != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        secondary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 9.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 7),
              Icon(Icons.chevron_left_rounded, color: accent, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
class _ScheduleState {
  const _ScheduleState({
    required this.now,
    required this.current,
    required this.next,
    required this.lastEnded,
    required this.hasTodayClasses,
  });

  final DateTime now;
  final ScheduleItem? current;
  final ScheduleItem? next;
  final ScheduleItem? lastEnded;
  final bool hasTodayClasses;
}
