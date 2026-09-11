import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/authenticated_client.dart';
import '../../data/models/xp_snapshot.dart';
import '../../data/repositories/xp_repository.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_section.dart';

class XpScreen extends StatefulWidget {
  const XpScreen({super.key});

  @override
  State<XpScreen> createState() => _XpScreenState();
}

class _XpScreenState extends State<XpScreen> {
  ApiClient? _client;
  XpRepository? _repo;
  XpSnapshot? _snapshot;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _client ??= await AuthenticatedClient.create();
      _repo ??= XpRepository(_client!);
      final snapshot = await _repo!.getXp();
      if (mounted) setState(() { _snapshot = snapshot; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : 'تعذر تحميل نقاط XP.');
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
    final progress = snapshot == null || snapshot.nextLevelXp <= 0
        ? 0.0
        : (snapshot.levelXp / snapshot.nextLevelXp).clamp(0.0, 1.0).toDouble();

    Widget body;
    if (_loading && snapshot == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null && snapshot == null) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('إعادة المحاولة')),
          ],
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            AppCard(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(Icons.bolt_rounded, size: 32, color: Theme.of(context).colorScheme.onPrimaryContainer),
                  ),
                  const SizedBox(height: 10),
                  Text('${snapshot!.totalXp} XP', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
                  Text('المستوى ${snapshot.level}', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(value: progress, minHeight: 8, borderRadius: BorderRadius.circular(8)),
                  const SizedBox(height: 8),
                  Text('${snapshot.levelXp} / ${snapshot.nextLevelXp} XP للمستوى التالي', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(height: 22),
            AppSection(
              title: 'سجل XP',
              subtitle: 'تُمنح النقاط من تقدم دراسي موثّق',
              child: snapshot.events.isEmpty
                  ? const AppCard(child: Text('لم تحصل على XP بعد. ابدأ التقدم في ملفاتك الدراسية.'))
                  : Column(
                      children: [
                        for (final event in snapshot.events)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: AppCard(
                              child: Row(
                                children: [
                                  Icon(Icons.add_circle_rounded, color: Theme.of(context).colorScheme.primary),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('+${event.xp} XP', style: const TextStyle(fontWeight: FontWeight.w900)),
                                        Text(_label(event.type), style: Theme.of(context).textTheme.bodySmall),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
        title: const Text('XP والمستوى'),
        actions: [IconButton(tooltip: 'تحديث', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: body,
    );
  }

  String _label(String type) {
    switch (type) {
      case 'material_progress_25':
        return 'إكمال 25٪ من ملف دراسي';
      case 'material_progress_50':
        return 'إكمال 50٪ من ملف دراسي';
      case 'material_progress_75':
        return 'إكمال 75٪ من ملف دراسي';
      case 'material_complete':
        return 'إكمال ملف دراسي';
      default:
        return 'نشاط دراسي';
    }
  }
}
