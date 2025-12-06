import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pracpro/models/activity_progress.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ActivityLogsScreen extends StatefulWidget {
  final String classroomId;
  const ActivityLogsScreen({super.key, required this.classroomId});

  @override
  State<ActivityLogsScreen> createState() => _ActivityLogsScreenState();
}

class _ActivityLogsScreenState extends State<ActivityLogsScreen> {
  final _searchCtl = TextEditingController();
  List<ActivityProgress> _allActivities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecentActivity();
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _refresh() => _loadRecentActivity();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Student Activity')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _allActivities.isEmpty
              ? const Center(child: Text('No activity yet.'))
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: _buildActivityList(),
                ),
    );
  }

  Future<void> _loadRecentActivity() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final List<ActivityProgress> allActivities = [];

      final studentsResponse = await supabase
          .from('user_classrooms')
          .select('user_id')
          .eq('classroom_id', widget.classroomId)
          .eq('status', 'accepted');

      final studentIds = (studentsResponse as List)
          .map((s) => s['user_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList();

      if (studentIds.isEmpty) {
        setState(() {
          _allActivities = [];
          _isLoading = false;
        });
        return;
      }

      try {
        final activityResponse = await supabase
            .from('activity_progress_by_classroom')
            .select()
            .eq('classroom_id', widget.classroomId)
            .inFilter('user_id', studentIds)
            .order('created_at', ascending: false)
            .limit(200);

        final activityData = (activityResponse as List).cast<Map<String, dynamic>>();
        
        for (var json in activityData) {
          final activity = ActivityProgress.fromJson(json);
          
          if (activity.entityType == 'game') {
            String formattedTitle = activity.entityTitle ?? '';
            final titleLower = formattedTitle.toLowerCase();
            if (titleLower.contains('crossmath') || titleLower.contains('division_crossmath') || 
                titleLower.contains('multiplication_crossmath') || titleLower.contains('subtraction_crossmath') ||
                titleLower.contains('addition_crossmath')) {
              formattedTitle = 'Crossword Math';
            } else if (titleLower.contains('ninja')) {
              formattedTitle = 'Ninja Math';
            }
            
            allActivities.add(ActivityProgress(
              source: activity.source,
              sourceId: activity.sourceId,
              userId: activity.userId,
              userName: activity.userName,
              entityType: activity.entityType,
              entityId: activity.entityId,
              entityTitle: formattedTitle,
              stage: activity.stage,
              score: activity.score,
              highestScore: activity.highestScore,
              tries: activity.tries,
              attempt: activity.attempt,
              classroomId: activity.classroomId,
              createdAt: activity.createdAt,
            ));
          } else {
            allActivities.add(activity);
          }
        }
      } catch (e) {
      }

      final quizTotalsMap = <String, int>{};

      try {
        final basicQuizProgressResponse = await supabase
            .from('basic_operator_quiz_progress')
            .select('*')
            .inFilter('user_id', studentIds)
            .order('updated_at', ascending: false)
            .limit(200);

        final basicQuizData = (basicQuizProgressResponse as List).cast<Map<String, dynamic>>();

        if (basicQuizData.isNotEmpty) {
          final quizIds = basicQuizData
              .map((p) => p['quiz_id']?.toString())
              .whereType<String>()
              .where((id) => id.isNotEmpty)
              .toSet()
              .toList();

          if (quizIds.isNotEmpty) {
            final quizzesResponse = await supabase
                .from('basic_operator_quizzes')
                .select('id, title, operator, classroom_id')
                .inFilter('id', quizIds)
                .eq('classroom_id', widget.classroomId);

            final quizzesMap = <String, Map<String, dynamic>>{};
            final quizzesData = (quizzesResponse as List).cast<Map<String, dynamic>>();

            try {
              final allQuestionsResponse = await supabase
                  .from('basic_operator_quiz_questions')
                  .select('quiz_id')
                  .inFilter('quiz_id', quizIds);

              final questionsList = (allQuestionsResponse as List).cast<Map<String, dynamic>>();
              for (final question in questionsList) {
                final qId = question['quiz_id']?.toString();
                if (qId != null) {
                  quizTotalsMap[qId] = (quizTotalsMap[qId] ?? 0) + 1;
                }
              }
            } catch (e) {
            }

            for (final quiz in quizzesData) {
              final quizId = quiz['id']?.toString();
              if (quizId != null) {
                quizzesMap[quizId] = quiz;
              }
            }

            for (final progress in basicQuizData) {
              final quizId = progress['quiz_id']?.toString();
              if (quizId != null && quizzesMap.containsKey(quizId)) {
                final quiz = quizzesMap[quizId]!;
                final totalQuestions = quizTotalsMap[quizId] ?? 0;
                final highestScorePercent = progress['highest_score'] as int? ?? 0;
                final actualScore = totalQuestions > 0
                    ? ((highestScorePercent / 100) * totalQuestions).round()
                    : 0;

                DateTime? completionTime;
                if (progress['created_at'] != null) {
                  try {
                    completionTime = DateTime.parse(progress['created_at']);
                  } catch (e) {
                  }
                }
                if (completionTime == null && progress['updated_at'] != null) {
                  try {
                    completionTime = DateTime.parse(progress['updated_at']);
                  } catch (e) {
                  }
                }
                completionTime ??= DateTime.now();

                allActivities.add(ActivityProgress(
                  source: 'basic_operator_quiz_progress',
                  sourceId: progress['id']?.toString() ?? '',
                  userId: progress['user_id']?.toString() ?? '',
                  entityType: 'quiz',
                  entityId: quizId,
                  entityTitle: quiz['title']?.toString() ?? 'Quiz',
                  stage: '${quiz['operator']?.toString() ?? ''}|$totalQuestions',
                  score: actualScore,
                  highestScore: actualScore,
                  tries: progress['attempts_count'] as int?,
                  attempt: totalQuestions,
                  classroomId: widget.classroomId,
                  createdAt: completionTime,
                ));
              }
            }
          }
        }
      } catch (e) {
      }

      try {
        final quizProgressResponse = await supabase
            .from('quiz_progress')
            .select('*')
            .inFilter('user_id', studentIds)
            .order('updated_at', ascending: false)
            .limit(200);

        final quizData = (quizProgressResponse as List).cast<Map<String, dynamic>>();

        if (quizData.isNotEmpty) {
          final quizIds = quizData
              .map((p) => p['quiz_id']?.toString())
              .whereType<String>()
              .where((id) => id.isNotEmpty)
              .toSet()
              .toList();

          if (quizIds.isNotEmpty) {
            final quizzesResponse = await supabase
                .from('quizzes')
                .select('id, title, lesson_id')
                .inFilter('id', quizIds);

            final quizzesData = (quizzesResponse as List).cast<Map<String, dynamic>>();

            final legacyQuizTotalsMap = <String, int>{};
            for (final quizId in quizIds) {
              try {
                final questionsResponse = await supabase
                    .from('quiz_questions')
                    .select('id')
                    .eq('quiz_id', quizId);
                legacyQuizTotalsMap[quizId] = (questionsResponse as List).length;
              } catch (e) {
                try {
                  final questionsResponse = await supabase
                      .from('questions')
                      .select('id')
                      .eq('quiz_id', quizId);
                  legacyQuizTotalsMap[quizId] = (questionsResponse as List).length;
                } catch (e2) {
                }
              }
            }

            final lessonIds = quizzesData
                .map((q) => q['lesson_id']?.toString())
                .whereType<String>()
                .where((id) => id.isNotEmpty)
                .toSet()
                .toList();

            if (lessonIds.isNotEmpty) {
              final lessonsResponse = await supabase
                  .from('lessons')
                  .select('id, classroom_id')
                  .inFilter('id', lessonIds)
                  .eq('classroom_id', widget.classroomId);

              final lessonsMap = <String, Map<String, dynamic>>{};
              final lessonsData = (lessonsResponse as List).cast<Map<String, dynamic>>();
              for (final lesson in lessonsData) {
                final lessonId = lesson['id']?.toString();
                if (lessonId != null) {
                  lessonsMap[lessonId] = lesson;
                }
              }

              final quizzesMap = <String, Map<String, dynamic>>{};
              for (final quiz in quizzesData) {
                final quizId = quiz['id']?.toString();
                final lessonId = quiz['lesson_id']?.toString();
                if (quizId != null && lessonId != null && lessonsMap.containsKey(lessonId)) {
                  final lesson = lessonsMap[lessonId]!;
                  quizzesMap[quizId] = {
                    ...quiz,
                    'classroom_id': lesson['classroom_id']?.toString(),
                  };
                }
              }

              for (final progress in quizData) {
                final quizId = progress['quiz_id']?.toString();
                if (quizId != null && quizzesMap.containsKey(quizId)) {
                  final quiz = quizzesMap[quizId]!;
                  final totalQuestions = legacyQuizTotalsMap[quizId] ?? 0;
                  final highestScorePercent = progress['highest_score'] as int? ?? 0;
                  final actualScore = totalQuestions > 0
                      ? ((highestScorePercent / 100) * totalQuestions).round()
                      : 0;

                  DateTime? completionTime;
                  if (progress['created_at'] != null) {
                    try {
                      completionTime = DateTime.parse(progress['created_at']);
                    } catch (e) {
                    }
                  }
                  if (completionTime == null && progress['updated_at'] != null) {
                    try {
                      completionTime = DateTime.parse(progress['updated_at']);
                    } catch (e) {
                    }
                  }
                  completionTime ??= DateTime.now();

                  allActivities.add(ActivityProgress(
                    source: 'quiz_progress',
                    sourceId: progress['id']?.toString() ?? '',
                    userId: progress['user_id']?.toString() ?? '',
                    entityType: 'quiz',
                    entityId: quizId,
                    entityTitle: quiz['title']?.toString() ?? 'Quiz',
                    stage: '|$totalQuestions',
                    score: actualScore,
                    highestScore: actualScore,
                    tries: progress['attempts_count'] as int?,
                    attempt: totalQuestions,
                    classroomId: widget.classroomId,
                    createdAt: completionTime,
                  ));
                }
              }
            }
          }
        }
      } catch (e) {
      }

      try {
        final gameProgressResponse = await supabase
            .from('game_progress')
            .select('*')
            .inFilter('user_id', studentIds)
            .order('created_at', ascending: false)
            .limit(200);

        final gameData = (gameProgressResponse as List).cast<Map<String, dynamic>>();

        final gameTotalsMap = <String, int>{};

        try {
          final crosswordPuzzles = await supabase
              .from('crossword_puzzles')
              .select('operator, difficulty, grid');

          for (final puzzle in crosswordPuzzles) {
            final operator = puzzle['operator']?.toString() ?? '';
            final difficulty = puzzle['difficulty']?.toString() ?? '';
            final gridData = puzzle['grid'] as List;
            int blankCount = 0;
            for (final row in gridData) {
              for (final cell in row as List) {
                if (cell is Map && cell['type'] == 'blank') {
                  blankCount++;
                }
              }
            }
            if (blankCount > 0) {
              gameTotalsMap['crossmath|$difficulty|$operator'] = blankCount;
            }
          }
        } catch (e) {
        }

        for (final progress in gameData) {
          final gameName = progress['game_name']?.toString() ?? '';
          final score = progress['score'] as int? ?? 0;
          final difficulty = progress['difficulty']?.toString() ?? 'easy';

          String gameTitle = gameName;
          final gameNameLower = gameName.toLowerCase();
          if (gameNameLower.contains('crossmath') || gameNameLower.contains('crossword math')) {
            gameTitle = 'Crossword Math';
          } else if (gameNameLower.contains('ninja')) {
            gameTitle = 'Ninja Math';
          }

          int finalTotalRounds = 0;
          if (gameNameLower.contains('crossmath')) {
            String? operator;
            if (gameNameLower.startsWith('addition_')) {
              operator = 'addition';
            } else if (gameNameLower.startsWith('subtraction_')) {
              operator = 'subtraction';
            } else if (gameNameLower.startsWith('multiplication_')) {
              operator = 'multiplication';
            } else if (gameNameLower.startsWith('division_')) {
              operator = 'division';
            }

            if (operator != null) {
              final key = 'crossmath|$difficulty|$operator';
              final totalFromPuzzle = gameTotalsMap[key];
              if (totalFromPuzzle != null && totalFromPuzzle > 0) {
                finalTotalRounds = totalFromPuzzle;
              } else {
                if (difficulty == 'easy') {
                  finalTotalRounds = score > 0 ? (score + 2) : 5;
                } else if (difficulty == 'medium') {
                  finalTotalRounds = score > 0 ? (score + 3) : 8;
                } else if (difficulty == 'hard') {
                  finalTotalRounds = score > 0 ? (score + 4) : 10;
                } else {
                  finalTotalRounds = score > 0 ? (score + 2) : 5;
                }
              }
            } else {
              finalTotalRounds = score > 0 ? (score + 2) : 5;
            }
          } else if (gameNameLower.contains('ninja')) {
            finalTotalRounds = 10;
          } else {
            finalTotalRounds = score > 0 ? score : 1;
          }

          allActivities.add(ActivityProgress(
            source: 'game_progress',
            sourceId: progress['id']?.toString() ?? '',
            userId: progress['user_id']?.toString() ?? '',
            entityType: 'game',
            entityId: progress['id']?.toString() ?? '',
            entityTitle: gameTitle,
            stage: difficulty,
            score: score,
            highestScore: score,
            tries: progress['tries'] as int? ?? 1,
            attempt: finalTotalRounds,
            classroomId: widget.classroomId,
            createdAt: progress['created_at'] != null
                ? DateTime.parse(progress['created_at'])
                : (progress['updated_at'] != null
                    ? DateTime.parse(progress['updated_at'])
                    : DateTime.now()),
          ));
        }
      } catch (e) {
      }

      final userIds = allActivities.map((a) => a.userId).toSet().toList();
      final usersMap = <String, String>{};
      if (userIds.isNotEmpty) {
        try {
          final usersResponse = await supabase
              .from('users')
              .select('id, name')
              .inFilter('id', userIds);

          for (final user in usersResponse as List) {
            final userId = user['id']?.toString();
            final userName = user['name']?.toString();
            if (userId != null && userName != null) {
              usersMap[userId] = userName;
            }
          }
        } catch (e) {
        }
      }

      for (var i = 0; i < allActivities.length; i++) {
        final activity = allActivities[i];
        if (usersMap.containsKey(activity.userId)) {
          allActivities[i] = ActivityProgress(
            source: activity.source,
            sourceId: activity.sourceId,
            userId: activity.userId,
            userName: usersMap[activity.userId],
            entityType: activity.entityType,
            entityId: activity.entityId,
            entityTitle: activity.entityTitle,
            stage: activity.stage,
            score: activity.score,
            highestScore: activity.highestScore,
            tries: activity.tries,
            attempt: activity.attempt,
            classroomId: activity.classroomId,
            createdAt: activity.createdAt,
          );
        }
      }

      final deduplicatedActivities = <String, ActivityProgress>{};

      for (var activity in allActivities) {
        String key;

        if (activity.entityType == 'game') {
          String gameTitle = activity.entityTitle ?? '';
          final titleLower = gameTitle.toLowerCase();
          if (titleLower.contains('crossmath') || titleLower.contains('division_crossmath') ||
              titleLower.contains('multiplication_crossmath') || titleLower.contains('subtraction_crossmath') ||
              titleLower.contains('addition_crossmath')) {
            gameTitle = 'Crossword Math';
          } else if (titleLower.contains('ninja')) {
            gameTitle = 'Ninja Math';
          }

          final difficulty = activity.stage?.toLowerCase() ?? 'easy';
          key = '${activity.entityType}|$gameTitle|$difficulty|${activity.userId}';
        } else {
          key = '${activity.entityType}|${activity.entityId}|${activity.userId}';
        }

        if (!deduplicatedActivities.containsKey(key)) {
          deduplicatedActivities[key] = activity;
        } else {
          final existing = deduplicatedActivities[key]!;
          final existingTotal = existing.attempt ?? 0;
          final newTotal = activity.attempt ?? 0;
          final existingScore = existing.score ?? 0;
          final newScore = activity.score ?? 0;

          if (existingScore > 1 && existingTotal == 1) {
            deduplicatedActivities[key] = activity;
          } else if (newScore > 1 && newTotal == 1) {
          } else if (activity.createdAt.isAfter(existing.createdAt)) {
            deduplicatedActivities[key] = activity;
          }
        }
      }

      final uniqueActivities = deduplicatedActivities.values.toList();
      uniqueActivities.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      setState(() {
        _allActivities = uniqueActivities;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildActivityList() {
    final filtered = _allActivities.where(_matchesSearch).toList();
          final sections = _groupByDay(filtered);

    return ListView.builder(
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
    final rel = _relative(item.createdAt);

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
                        if (item.userName != null && item.userName!.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.userName!,
                              style: TextStyle(
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
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

                    const SizedBox(height: 12),
                  if (item.score != null && item.attempt != null && item.attempt! > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${item.score}/${item.attempt}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: color,
                          fontSize: 13,
                        ),
                      ),
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
    return p.entityTitle ?? 'Untitled Activity';
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
    final now = DateTime.now().toUtc();
    final tUtc = t.isUtc ? t : t.toUtc();
    
    Duration diff = now.difference(tUtc);
    
    if (diff.isNegative) {
      return 'Just now';
    }
    
    if (diff.inSeconds < 60) {
      return diff.inSeconds < 1 ? 'Just now' : '${diff.inSeconds}s ago';
    }
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (diff.inDays < 30) {
      final weeks = (diff.inDays / 7).floor();
      return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
    }
    if (diff.inDays < 365) {
      final months = (diff.inDays / 30).floor();
      return months == 1 ? '1 month ago' : '$months months ago';
    }
    return DateFormat('MMM d, yyyy').format(t.toLocal());
  }
}
