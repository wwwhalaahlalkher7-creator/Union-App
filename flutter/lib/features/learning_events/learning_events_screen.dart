import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/errors/error_message.dart';
import '../../data/models/learning_event.dart';
import '../../data/repositories/learning_events_repository.dart';
import '../../core/di/app_dependencies.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/list_skeleton.dart';

class LearningEventsScreen extends StatefulWidget {
  const LearningEventsScreen({super.key});

  @override
  State<LearningEventsScreen> createState() => _LearningEventsScreenState();
}

class _LearningEventsScreenState extends State<LearningEventsScreen> {
  LearningEventsRepository? _repo;
  Future<List<LearningEvent>>? _future;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      _repo ??= AppDependencies.instance.learningEvents;
      setState(() => _future = _repo!.list());
    } catch (e) {
      if (mounted) setState(() => _future = Future.error(e));
    }
  }

  Future<void> _reload() async {
    final repo = _repo;
    if (repo == null) return;
    final future = repo.list();
    setState(() => _future = future);
    await future;
  }



  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('learningEvents'))),
      body: FutureBuilder<List<LearningEvent>>(
        future: _future,
        builder: (context, snapshot) {
          if (_future == null || snapshot.connectionState == ConnectionState.waiting) return const ListSkeleton(count: 4);
          if (snapshot.hasError) {
            return Center(child: FilledButton.icon(onPressed: _reload, icon: const Icon(Icons.refresh_rounded), label: Text(l10n.t('retry'))));
          }
          final events = snapshot.data ?? const <LearningEvent>[];
          if (events.isEmpty) return Center(child: Text(l10n.t('noLearningEvents')));
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: events.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _LearningEventCard(event: events[index]),
            ),
          );
        },
      ),
    );
  }
}

class _LearningEventCard extends StatelessWidget {
  const _LearningEventCard({required this.event});
  final LearningEvent event;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppCard(
      onTap: () => context.push('/learning-events/${event.id}'),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(width: 50, height: 50, decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(16)), child: Icon(event.completed ? Icons.check_circle_rounded : Icons.auto_awesome_rounded, color: cs.onPrimaryContainer)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(event.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
            if (event.description.isNotEmpty) ...[const SizedBox(height: 5), Text(event.description, maxLines: 2, overflow: TextOverflow.ellipsis)],
            const SizedBox(height: 8),
            Row(children: [Icon(Icons.bolt_rounded, size: 17, color: cs.primary), const SizedBox(width: 4), Text('${event.xpReward} XP', style: TextStyle(fontWeight: FontWeight.w900, color: cs.primary)), const Spacer(), Text(event.completed ? '✓' : '›', style: TextStyle(fontSize: 20, color: cs.onSurfaceVariant))]),
          ])),
        ],
      ),
    );
  }
}

class LearningEventRouteScreen extends StatefulWidget {
  const LearningEventRouteScreen({required this.eventId, super.key});
  final String eventId;

  @override
  State<LearningEventRouteScreen> createState() => _LearningEventRouteScreenState();
}

class _LearningEventRouteScreenState extends State<LearningEventRouteScreen> {
  Future<LearningEvent>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final event = await AppDependencies.instance.learningEvents.get(widget.eventId);
      if (mounted) setState(() => _future = Future.value(event));
    } catch (e) {
      if (mounted) setState(() => _future = Future.error(e));
    }
  }



  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LearningEvent>(
      future: _future,
      builder: (context, snapshot) {
        if (_future == null || snapshot.connectionState == ConnectionState.waiting) return const Scaffold(body: ListSkeleton(count: 4));
        if (snapshot.hasError || snapshot.data == null) return Scaffold(appBar: AppBar(), body: Center(child: FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: Text(AppLocalizations.of(context).t('retry')))));
        return LearningEventDetailScreen(event: snapshot.data!);
      },
    );
  }
}

class LearningEventDetailScreen extends StatefulWidget {
  const LearningEventDetailScreen({required this.event, super.key});
  final LearningEvent event;

  @override
  State<LearningEventDetailScreen> createState() => _LearningEventDetailScreenState();
}

class _LearningEventDetailScreenState extends State<LearningEventDetailScreen> {
  late LearningEvent _event = widget.event;
  bool _busy = false;
  String? _message;

  Future<void> _complete() async {
    if (_event.completed || _busy) return;
    setState(() { _busy = true; _message = null; });
    try {
      final repo = AppDependencies.instance.learningEvents;
      final xp = await repo.complete(_event.id);
        if (mounted) setState(() { _event = LearningEvent(id: _event.id, title: _event.title, description: _event.description, design: _event.design, xpReward: _event.xpReward, completed: true, config: _event.config, publishAt: _event.publishAt, expiresAt: _event.expiresAt); _message = xp > 0 ? '+$xp XP' : 'تم تسجيل الحدث.'; });
    } catch (e) {
      if (mounted) setState(() => _message = ErrorMessage.from(context, e, fallbackKey: 'eventCompleteFailed'));
    } finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final tasks = (_event.config['tasks'] is List) ? List<String>.from((_event.config['tasks'] as List).map((e) => '$e')) : const <String>[];
    return Scaffold(
      appBar: AppBar(title: Text(_event.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        AppCard(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(height: 110, decoration: BoxDecoration(gradient: LinearGradient(colors: [cs.primaryContainer, cs.surfaceContainerHighest]), borderRadius: BorderRadius.circular(22)), child: Icon(_event.design == 'challenge' ? Icons.flag_rounded : _event.design == 'checklist' ? Icons.checklist_rounded : Icons.auto_awesome_rounded, size: 54, color: cs.primary)),
          const SizedBox(height: 18),
          Text(_event.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          if (_event.description.isNotEmpty) ...[const SizedBox(height: 10), Text(_event.description, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6))],
          const SizedBox(height: 16),
          Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(16)), child: Row(children: [Icon(Icons.bolt_rounded, color: cs.onPrimaryContainer), const SizedBox(width: 8), Text('${_event.xpReward} XP', style: TextStyle(fontWeight: FontWeight.w900, color: cs.onPrimaryContainer, fontSize: 18))])),
          if (tasks.isNotEmpty) ...[const SizedBox(height: 18), for (final task in tasks) Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.check_circle_outline_rounded, size: 19, color: cs.primary), const SizedBox(width: 8), Expanded(child: Text(task))]))],
          const SizedBox(height: 20),
          if (_message != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_message!, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, color: cs.primary))),
          FilledButton.icon(onPressed: _event.completed || _busy ? null : _complete, icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(_event.completed ? Icons.check_rounded : Icons.bolt_rounded), label: Text(_event.completed ? l10n.t('eventCompleted') : l10n.t('completeEvent'))),
        ])),
      ]),
    );
  }
}
