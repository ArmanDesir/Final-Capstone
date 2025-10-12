import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:offline_first_app/models/activity_progress.dart';
import 'package:offline_first_app/providers/activity_provider.dart';
import 'package:provider/provider.dart';

class ActivityLogsScreen extends StatefulWidget {
  final String classroomId;
  const ActivityLogsScreen({super.key, required this.classroomId});

  @override
  State<ActivityLogsScreen> createState() => _ActivityLogsScreenState();
}

class _ActivityLogsScreenState extends State<ActivityLogsScreen> {
  final _searchCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ActivityProvider>().loadActivity(widget.classroomId);
    });
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _refresh() =>
      context.read<ActivityProvider>().loadActivity(widget.classroomId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Student Activity')),
      body: Consumer<ActivityProvider>(
        builder: (_, provider, __) {
          if (provider.isLoading) return const Center(child: CircularProgressIndicator());
          if (provider.error != null) return Center(child: Text(provider.error!));
          if (provider.items.isEmpty) return const Center(child: Text('No activity yet.'));

          final filtered = provider.items.where(_matchesSearch).toList();
          final sections = _groupByDay(filtered);

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: sections.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) return _searchHeader();

                final s = sections[i - 1];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 8),
                      child: Text(
                        _dayLabel(s.date),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    ...s.items.map((e) => _ActivityCardV2(item: e)),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _searchHeader() {
    return Column(children: [
      TextField(
        controller: _searchCtl,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Search by student or title…',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchCtl.text.isEmpty
              ? null
              : IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () { _searchCtl.clear(); setState(() {}); },
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      const SizedBox(height: 8),
    ]);
  }

  bool _matchesSearch(ActivityProgress p) {
    final q = _searchCtl.text.trim().toLowerCase();
    if (q.isEmpty) return true;
    return (p.userName ?? '').toLowerCase().contains(q) ||
        (p.entityTitle ?? '').toLowerCase().contains(q) ||
        p.stage.toLowerCase().contains(q);
  }

  List<_DaySection> _groupByDay(List<ActivityProgress> items) {
    final sorted = [...items]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final map = <String, List<ActivityProgress>>{};
    for (final it in sorted) {
      final key = DateFormat('yyyy-MM-dd').format(it.createdAt.toLocal());
      (map[key] ??= []).add(it);
    }
    final out = map.entries
        .map((e) => _DaySection(DateTime.parse('${e.key}T00:00:00'), e.value))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return out;
  }

  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final dd = DateTime(d.year, d.month, d.day);
    final today = DateTime(now.year, now.month, now.day);
    final yest = today.subtract(const Duration(days: 1));
    if (dd == today) return 'Today';
    if (dd == yest) return 'Yesterday';
    return DateFormat('MMM d, yyyy').format(d);
  }
}

class _DaySection {
  final DateTime date;
  final List<ActivityProgress> items;
  _DaySection(this.date, this.items);
}

class _ActivityCardV2 extends StatelessWidget {
  final ActivityProgress item;
  const _ActivityCardV2({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _accentFor(item.entityType, item.stage);
    final tLocal = item.createdAt.toLocal();
    final time = DateFormat('HH:mm').format(tLocal);
    final rel = _relative(tLocal);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 6,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(color: color.withOpacity(.95), borderRadius: BorderRadius.circular(12)),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _typeIcon(item.entityType, item.stage, color),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                          _title(item),
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(rel, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600], height: 1.2)),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(10)),
                      child: Text(time,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: color,
                            letterSpacing: .2,
                          )),
                    ),
                  ]),

                  if ((item.entityTitle ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(item.entityTitle!, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[800])),
                    ),

                  if (item.entityType == 'quiz' && item.score != null) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: (item.score!.clamp(0, 100)) / 100.0,
                        minHeight: 8,
                        backgroundColor: Colors.grey.withOpacity(.14),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      if (item.attempt != null) _chip('Attempt ${item.attempt}'),
                      if (item.score != null) _chip('Score ${item.score}'),
                      if (item.highestScore != null) _chip('Best ${item.highestScore}'),
                      if (item.tries != null) _chip('Tries ${item.tries}'),
                      if ((item.status ?? '').isNotEmpty) _chip(item.status!),
                      if ((item.entityId ?? '').isNotEmpty) _chip('ref ${_shortRef(item.entityId!)}'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _title(ActivityProgress p) {
    final who = (p.userName == null || p.userName!.isEmpty) ? 'Student' : p.userName!;
    switch (p.entityType) {
      case 'lesson':   return '$who viewed a lesson';
      case 'exercise': return '$who opened an exercise';
      case 'content':  return '$who opened content';
      case 'quiz':     return '$who attempted a quiz';
      case 'game':     return '$who played a game';
      default:         return '$who activity';
    }
  }

  Widget _typeIcon(String entityType, String stage, Color color) {
    IconData icon;
    switch (entityType) {
      case 'lesson':   icon = Icons.menu_book_outlined; break;
      case 'exercise': icon = Icons.task_alt_outlined;  break;
      case 'content':  icon = Icons.insert_drive_file_outlined; break;
      case 'quiz':     icon = Icons.quiz_outlined;      break;
      case 'game':     icon = Icons.videogame_asset_outlined; break;
      default:         icon = Icons.history;
    }
    return Container(
      width: 38, height: 38,
      decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: color, size: 22),
    );
  }

  Widget _chip(String text) => Chip(
    label: Text(text),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
    labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
  );

  String _shortRef(String id) => id.length <= 6 ? id : id.substring(id.length - 6);

  Color _accentFor(String entityType, String stage) {
    switch (entityType) {
      case 'lesson':   return Colors.blue;
      case 'content':  return Colors.teal;
      case 'exercise': return Colors.indigo;
      case 'quiz':     return Colors.deepPurple;
      case 'game':     return Colors.orange;
      default:         return Colors.grey;
    }
  }

  String _relative(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return '${d.inSeconds}s ago';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays == 1) return '1 day ago';
    return '${d.inDays} days ago';
  }
}
