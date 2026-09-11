import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/authenticated_client.dart';
import '../../data/models/material_progress.dart';
import '../../data/repositories/progress_repository.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_section.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  ApiClient? _client;
  ProgressRepository? _repo;
  ProgressSnapshot? _snapshot;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _client ??= await AuthenticatedClient.create();
      _repo ??= ProgressRepository(_client!);
      final snapshot = await _repo!.getProgress();
      if (mounted) setState(() => _snapshot = snapshot);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is ApiException ? e.message : 'تعذر تحميل تقدمك الدراسي.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _client?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final summary = snapshot?.summary ?? const <String, dynamic>{};
    final started = int.tryParse('${summary['started'] ?? 0}') ?? 0;
    final completed = int.tryParse('${summary['completed'] ?? 0}') ?? 0;
    final seconds = int.tryParse('${summary['active_seconds'] ?? 0}') ?? 0;

    Widget body;
    if (_loading && snapshot == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null && snapshot == null) {
      body = _ErrorView(message: _error!, retry: _load);
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            AppSection(
              title: 'ملخص التقدم',
              subtitle: 'تقدمك يُحتسب من نشاط دراسي حقيقي',
              child: Row(
                children: [
                  Expanded(child: _StatCard(label: 'ملفات بدأت', value: '$started', icon: Icons.play_circle_outline_rounded)),
                  const SizedBox(width: 8),
                  Expanded(child: _StatCard(label: 'مكتملة', value: '$completed', icon: Icons.check_circle_outline_rounded)),
                  const SizedBox(width: 8),
                  Expanded(child: _StatCard(label: 'دقائق نشطة', value: '${seconds ~/ 60}', icon: Icons.timer_outlined)),
                ],
              ),
            ),
            const SizedBox(height: 22),
            AppSection(
              title: 'ملفاتك الأخيرة',
              child: snapshot == null || snapshot.items.isEmpty
                  ? const AppCard(child: Text('لا يوجد تقدم مسجل بعد. ابدأ من المواد الدراسية.'))
                  : Column(
                      children: [
                        for (final item in snapshot.items)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ProgressTile(item: item),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('تقدمي الدراسي'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: body,
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      child: Column(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ProgressTile extends StatelessWidget {
  const _ProgressTile({required this.item});

  final MaterialProgress item;

  @override
  Widget build(BuildContext context) {
    final title = item.materialTitle?.isNotEmpty == true ? item.materialTitle! : 'ملف دراسي';
    final percent = item.percent.clamp(0, 100);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800))),
              Text('$percent%', style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          if (item.subjectName?.isNotEmpty == true) ...[
            const SizedBox(height: 3),
            Text(item.subjectName!, style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: percent.toDouble() / 100,
            minHeight: 7,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 8),
          Text(item.completed ? 'مكتمل' : 'قيد الدراسة', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.retry});

  final String message;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 56),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton.icon(onPressed: retry, icon: const Icon(Icons.refresh_rounded), label: const Text('إعادة المحاولة')),
          ],
        ),
      ),
    );
  }
}
