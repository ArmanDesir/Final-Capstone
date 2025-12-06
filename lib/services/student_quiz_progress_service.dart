import 'package:supabase_flutter/supabase_flutter.dart';

class QuizProgressData {
  final String quizId;
  final String quizTitle;
  final int totalQuestions;
  final int? try1Score;
  final int? try2Score;
  final int? try3Score;
  final int attemptsCount;
  final int highestScore;
  final bool isGame;
  final String? difficulty; 
  final String? lessonTitle;
  final String? operator; 

  QuizProgressData({
    required this.quizId,
    required this.quizTitle,
    required this.totalQuestions,
    this.try1Score,
    this.try2Score,
    this.try3Score,
    required this.attemptsCount,
    required this.highestScore,
    this.isGame = false,
    this.difficulty,
    this.lessonTitle,
    this.operator,
  });

  double? _getActualScore(int? score) {
    if (score == null) return null;
    if (isGame) {

      return score.toDouble();
    }

    return (score / 100.0 * totalQuestions);
  }

  int get totalActualScore {
    final scores = [try1Score, try2Score, try3Score]
        .map((p) => _getActualScore(p))
        .where((s) => s != null)
        .cast<double>()
        .toList();
    return scores.fold(0.0, (sum, score) => sum + score).round();
  }

  int get totalPossible {
    final actualAttempts = [try1Score, try2Score, try3Score]
        .where((s) => s != null)
        .length;
    final maxAttempts = isGame ? actualAttempts : (actualAttempts > 3 ? 3 : actualAttempts);
    return totalQuestions * maxAttempts;
  }
  
  int get totalScore {
    return totalActualScore;
  }
  
  double get passingRate {
    return generalAverage;
  }

  double get generalAverage {
    final scores = [try1Score, try2Score, try3Score].where((s) => s != null).cast<int>().toList();
    if (scores.isEmpty) return 0;

    if (isGame) {

      if (totalQuestions > 0) {
        final percentages = scores.map((score) => (score / totalQuestions) * 100).toList();
        return percentages.reduce((a, b) => a + b) / percentages.length;
      }

      return scores.reduce((a, b) => a + b) / scores.length;
    }

    return scores.reduce((a, b) => a + b) / scores.length;
  }

  int get highestScorePercentage {
    if (isGame) {

      if (totalQuestions > 0 && highestScore > 0) {
        return ((highestScore / totalQuestions) * 100).round();
      }
      return 0;
    }

    return highestScore;
  }
}

class StudentQuizProgressService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<QuizProgressData>> getStudentAllProgress({
    required String studentId,
    required String classroomId,
  }) async {
    final allProgress = <QuizProgressData>[];
    
    for (final op in ['addition', 'subtraction', 'multiplication', 'division']) {
      final progress = await getStudentQuizProgress(
        studentId: studentId,
        operator: op,
        classroomId: classroomId,
      );
      allProgress.addAll(progress);
    }
    
    return allProgress;
  }

  Future<List<QuizProgressData>> getStudentQuizProgress({
    required String studentId,
    required String operator,
    required String classroomId,
  }) async {
    try {
      final activityProgressResponse = await _supabase
          .from('activity_progress_by_classroom')
          .select('*')
          .eq('user_id', studentId)
          .eq('classroom_id', classroomId)
          .eq('entity_type', 'quiz')
          .order('created_at', ascending: false);

      final allActivityProgress = await _supabase
          .from('activity_progress_by_classroom')
          .select('*')
          .eq('user_id', studentId)
          .eq('classroom_id', classroomId)
          .order('created_at', ascending: false);

      List<Map<String, dynamic>> gameProgressList = [];
      try {
        final userClassrooms = await _supabase
            .from('user_classrooms')
            .select('classroom_id')
            .eq('user_id', studentId)
            .eq('status', 'accepted');
        
        final classroomIds = (userClassrooms as List)
            .map((c) => c['classroom_id']?.toString())
            .whereType<String>()
            .where((id) => id.isNotEmpty)
            .toList();
        
        final gameProgressResponse = await _supabase
            .from('game_progress')
            .select('*')
            .eq('user_id', studentId)
            .order('created_at', ascending: false);
        
        final seenGames = <String>{};
        
        for (final gameProgress in gameProgressResponse) {
          final gameName = gameProgress['game_name']?.toString() ?? '';
          final difficulty = gameProgress['difficulty']?.toString() ?? '';
          
          final gameNameLower = gameName.toLowerCase();
          final operatorLower = operator.toLowerCase();
          
          bool matchesOperator = false;
          if (gameNameLower.startsWith('${operatorLower}_')) {
            matchesOperator = true;
          } else if (gameNameLower.contains('_${operatorLower}_')) {
            matchesOperator = true;
          } else if (gameNameLower.contains(operatorLower) && 
                    (gameNameLower.contains('crossmath') || gameNameLower.contains('ninja'))) {
            matchesOperator = true;
          }
          
          if (matchesOperator) {            String entityTitle;
            if (gameNameLower.contains('crossmath')) {
              entityTitle = 'Crossword Math';
            } else if (gameNameLower.contains('ninja')) {
              entityTitle = 'Ninja Math';
            } else {
              entityTitle = gameName;
            }
            
            final uniqueKey = '${entityTitle}|${difficulty}|${gameProgress['id']}';
            if (seenGames.contains(uniqueKey)) {
              continue;
            }
            seenGames.add(uniqueKey);
            
            gameProgressList.add({
              'source': 'game_progress',
              'source_id': gameProgress['id']?.toString() ?? '',
              'user_id': studentId,
              'entity_type': 'game',
              'entity_id': gameProgress['id']?.toString() ?? '',
              'entity_title': entityTitle,
              'stage': difficulty,
              'score': gameProgress['score'],
              'attempt': gameProgress['tries'],
              'highest_score': gameProgress['score'], 
              'tries': gameProgress['tries'],
              'status': gameProgress['status']?.toString() ?? '',
              'classroom_id': classroomId, 
              'created_at': gameProgress['created_at']?.toString() ?? DateTime.now().toIso8601String(),
            });
          }
        }
      } catch (e) {
      }

      final Map<String, List<Map<String, dynamic>>> progressByQuiz = {};

      final progressList = [
        ...(allActivityProgress as List? ?? activityProgressResponse as List? ?? []),
        ...gameProgressList,
      ];
      for (final progress in progressList) {
        final progressMap = progress as Map<String, dynamic>;
        final entityType = progressMap['entity_type']?.toString() ?? '';
        final source = progressMap['source']?.toString() ?? '';

        if (entityType == 'quiz' || entityType == 'game' || source.contains('quiz') || source.contains('game')) {

          String quizId;
          if (entityType == 'game') {
            String title = progressMap['entity_title']?.toString() ?? '';
            String sourceTitle = progressMap['entity_title']?.toString() ?? '';
            final source = progressMap['source']?.toString() ?? '';
            
            if (source == 'game_progress') {

              if (title.contains('_') && !title.toLowerCase().contains('crossword math') && !title.toLowerCase().contains('ninja math')) {
                final parts = title.toLowerCase().split('_');
                if (parts.isNotEmpty && parts[0] != operator.toLowerCase()) {
                  continue;
                }
              }
              
              if (title.toLowerCase().contains('crossmath')) {
                title = 'Crossword Math';
              } else if (title.toLowerCase().contains('ninja')) {
                title = 'Ninja Math';
              }
            } else {
              final titleLower = title.toLowerCase();
              final operatorLower = operator.toLowerCase();
              
              if (!titleLower.startsWith('${operatorLower}_') && 
                  !titleLower.contains('_${operatorLower}_')) {
                continue;
              }

              if (titleLower.contains('crossmath')) {
                title = 'Crossword Math';
              } else if (titleLower.contains('ninja')) {
                title = 'Ninja Math';
              }
            }
            
            final stage = progressMap['stage']?.toString().toLowerCase() ?? '';
            quizId = '$title|$stage';
          } else {
            quizId = progressMap['entity_id']?.toString() ??
                     progressMap['entity_title']?.toString() ??
                     progressMap['source_id']?.toString() ?? '';
          }
          if (quizId.isNotEmpty) {
            progressByQuiz.putIfAbsent(quizId, () => []).add(progressMap);
          }
        }
      }

      final quizzesResponse = await _supabase
          .from('basic_operator_quizzes')
          .select('id, title, classroom_id, basic_operator_quiz_questions(id)')
          .eq('operator', operator);

      List<Map<String, dynamic>> quizzes = (quizzesResponse as List).cast<Map<String, dynamic>>();
      if (classroomId.isNotEmpty) {
        quizzes = quizzes.where((q) => q['classroom_id']?.toString() == classroomId).toList();
      }

      final quizIds = quizzes
          .map((q) => q['id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList();

      final Map<String, Map<String, dynamic>> directProgressMap = {};

      if (quizIds.isNotEmpty) {
        try {
          final progressResponse = await _supabase
              .from('basic_operator_quiz_progress')
              .select('*')
              .eq('user_id', studentId)
                  .inFilter('quiz_id', quizIds);

                for (final progressItem in progressResponse) {
            final progressMapEntry = Map<String, dynamic>.from(progressItem);
            final quizId = progressMapEntry['quiz_id']?.toString() ?? '';
            if (quizId.isNotEmpty) {
              directProgressMap[quizId] = progressMapEntry;
                  }
                }
              } catch (e) {
              }
            }

      final List<QuizProgressData> results = [];

      final sortedKeys = progressByQuiz.keys.toList()..sort((a, b) {

        final aNormalized = a.toLowerCase().contains('crossword math') ? 0 : 1;
        final bNormalized = b.toLowerCase().contains('crossword math') ? 0 : 1;
        return aNormalized.compareTo(bNormalized);
      });

      for (final quizKey in sortedKeys) {
        final activityProgressList = progressByQuiz[quizKey]!;
        if (activityProgressList.isEmpty) continue;

        Map<String, dynamic>? quizMetadata;
        int totalQuestions = 0;
        String quizTitle = 'Unknown Quiz';

        for (final quiz in quizzes) {
          final quizId = quiz['id']?.toString() ?? '';
          if (quizId == quizKey || quiz['title']?.toString() == quizKey) {
            quizMetadata = quiz;
            quizTitle = quiz['title']?.toString() ?? 'Untitled Quiz';
            final questions = quiz['basic_operator_quiz_questions'] as List? ?? [];
            totalQuestions = questions.length;
            break;
          }
        }

        if (quizMetadata == null && activityProgressList.isNotEmpty) {
          final firstProgress = activityProgressList.first;
          final entityType = firstProgress['entity_type']?.toString() ?? '';
          String title = firstProgress['entity_title']?.toString() ?? 'Unknown';

          if (entityType == 'game') {

            if (title.toLowerCase().contains('crossmath') ||
                title.toLowerCase().contains('${operator.toLowerCase()}_crossmath')) {
              title = 'Crossword Math';
            } else if (title.toLowerCase().contains('ninja')) {
              title = 'Ninja Math';
            }

            String stage = firstProgress['stage']?.toString() ?? '';
            if (stage.isNotEmpty) {

              stage = stage.substring(0, 1).toUpperCase() + stage.substring(1).toLowerCase();
              quizTitle = '$title ($stage)';
            } else {
              quizTitle = title;
            }
          } else {
            quizTitle = title;
          }
        }

        final entityType = activityProgressList.isNotEmpty
            ? activityProgressList.first['entity_type']?.toString() ?? ''
            : '';
        final isGame = entityType == 'game';

        List<Map<String, dynamic>> processedProgressList = List.from(activityProgressList);
        int attempts = processedProgressList.length;

        if (isGame && processedProgressList.length > 1) {

          processedProgressList.sort((a, b) {
            final aTime = a['created_at']?.toString() ?? '';
            final bTime = b['created_at']?.toString() ?? '';
            return aTime.compareTo(bTime);
          });

          final List<Map<String, dynamic>> uniqueAttempts = [];
          for (final progress in processedProgressList) {
            final score = progress['score'] as int? ?? 0;
            final createdAt = progress['created_at']?.toString() ?? '';

            bool isDuplicate = false;
            for (final existing in uniqueAttempts) {
              final existingScore = existing['score'] as int? ?? 0;
              final existingTime = existing['created_at']?.toString() ?? '';

              if (score == existingScore && createdAt.isNotEmpty && existingTime.isNotEmpty) {
                try {
                  final created = DateTime.parse(createdAt);
                  final existingCreated = DateTime.parse(existingTime);
                  final diff = created.difference(existingCreated).abs().inSeconds;

                  if (diff <= 5) {
                    isDuplicate = true;
                    break;
                  }
                } catch (e) {

                }
              }
            }

            if (!isDuplicate) {
              uniqueAttempts.add(progress);
            }
          }

          if (uniqueAttempts.length < processedProgressList.length) {
            processedProgressList = uniqueAttempts;
            attempts = uniqueAttempts.length;
          }
        }

        final rawScores = processedProgressList.map((p) {
          return p['score'] as int? ?? 0;
        }).where((s) => s > 0).toList();

        final highest = rawScores.isNotEmpty ? rawScores.reduce((a, b) => a > b ? a : b) : 0;

        int gameTotal = 0;
        if (isGame) {
          final firstProgress = processedProgressList.first;
          final gameTitle = quizTitle.toLowerCase();
          
          if (gameTitle.contains('crossword')) {
          try {
            final puzzleResponse = await _supabase
                .from('crossword_puzzles')
                .select('grid')
                .eq('operator', operator)
                  .eq('difficulty', firstProgress['stage']?.toString().toLowerCase() ?? 'easy')
                .order('created_at', ascending: false)
                .limit(1)
                .maybeSingle();

            if (puzzleResponse != null && puzzleResponse['grid'] != null) {
              final gridData = puzzleResponse['grid'] as List;
              int blankCount = 0;
              for (final row in gridData) {
                for (final cell in row as List) {
                  if (cell is Map && cell['type'] == 'blank') {
                    blankCount++;
                  }
                }
              }
              if (blankCount > 0) {
                gameTotal = blankCount;
              }
            }
          } catch (e) {
            }
          }
          
          if (gameTotal == 0 && gameTitle.contains('ninja')) {
            gameTotal = 10; 
          }

          if (gameTotal == 0) {
            final status = firstProgress['status']?.toString().toLowerCase() ?? '';
            if (status.contains('complete') && highest > 0) {
              gameTotal = highest;
            } else if (highest > 0) {
              gameTotal = highest;
            } else {
              gameTotal = 4; //
            }
          }
        }

        final quizId = processedProgressList.first['entity_id']?.toString() ??
                      processedProgressList.first['source_id']?.toString() ??
                      quizKey;

        final finalTotalQuestions = isGame
            ? (gameTotal > 0 ? gameTotal : (highest > 0 ? highest : 4))
            : (totalQuestions > 0 ? totalQuestions : 10);

        final scores = rawScores;
        final highestValue = highest;

        if (attempts > 0 || scores.isNotEmpty) {

          if (isGame) {

            String normalizedTitle = quizTitle;
            if (normalizedTitle.toLowerCase().contains('addition_crossmath')) {

              if (normalizedTitle.contains('(')) {
                final parts = normalizedTitle.split('(');
                final stage = parts.length > 1 ? parts[1].replaceAll(')', '').trim() : '';
                if (stage.isNotEmpty) {
                  normalizedTitle = 'Crossword Math ($stage)';
                } else {
                  normalizedTitle = 'Crossword Math';
                }
              } else {
                normalizedTitle = 'Crossword Math';
              }
            }

            String comparisonKey = normalizedTitle.toLowerCase();

            if (comparisonKey.contains('(')) {
              final parts = comparisonKey.split('(');
              final base = parts[0].trim();
              final stage = parts.length > 1 ? parts[1].replaceAll(')', '').trim() : '';
              comparisonKey = '$base|$stage';
            }

            final existingIndex = results.indexWhere((r) {
              if (!r.isGame) return false;
              String existingKey = r.quizTitle.toLowerCase();
              if (existingKey.contains('(')) {
                final parts = existingKey.split('(');
                final base = parts[0].trim();
                final stage = parts.length > 1 ? parts[1].replaceAll(')', '').trim() : '';
                existingKey = '$base|$stage';
              }
              return existingKey == comparisonKey;
            });

            if (existingIndex >= 0) {

              final existing = results[existingIndex];
              final allScores = [
                existing.try1Score,
                existing.try2Score,
                existing.try3Score,
                scores.length > 0 ? scores[0] : null,
                scores.length > 1 ? scores[1] : null,
                scores.length > 2 ? scores[2] : null,
              ].where((s) => s != null).cast<int>().toList();

              final difficulty = processedProgressList.first['stage']?.toString().toLowerCase() ?? existing.difficulty ?? 'easy';
              
              results[existingIndex] = QuizProgressData(
                quizId: existing.quizId,
                quizTitle: normalizedTitle,
                totalQuestions: existing.totalQuestions > 0 ? existing.totalQuestions : finalTotalQuestions,
                try1Score: allScores.length > 0 ? allScores[0] : null,
                try2Score: allScores.length > 1 ? allScores[1] : null,
                try3Score: allScores.length > 2 ? allScores[2] : null,
                attemptsCount: existing.attemptsCount + attempts,
                highestScore: allScores.isNotEmpty ? allScores.reduce((a, b) => a > b ? a : b) : 0,
                isGame: true,
                difficulty: difficulty,
                operator: operator,
              );
            } else {

              final difficulty = isGame ? (processedProgressList.first['stage']?.toString().toLowerCase() ?? 'easy') : null;
              
              results.add(QuizProgressData(
                quizId: quizId,
                quizTitle: normalizedTitle,
                totalQuestions: finalTotalQuestions > 0 ? finalTotalQuestions : (isGame ? (highest > 0 ? highest : 4) : 10),
                try1Score: scores.length > 0 ? scores[0] : null,
                try2Score: scores.length > 1 ? scores[1] : null,
                try3Score: scores.length > 2 ? scores[2] : null,
                attemptsCount: attempts,
                highestScore: highestValue,
                isGame: isGame,
                difficulty: difficulty,
                operator: operator,
              ));
            }
          } else {


            String? lessonTitle;
            try {
              if (quizMetadata != null && quizMetadata!['lesson_id'] != null) {
                final lessonId = quizMetadata!['lesson_id']?.toString();
                if (lessonId != null) {
                  final lessonResponse = await _supabase
                      .from('lessons')
                      .select('title')
                      .eq('id', lessonId)
                      .maybeSingle();
                  lessonTitle = lessonResponse?['title']?.toString();
                }
              }
            } catch (e) {
            }
            
            results.add(QuizProgressData(
              quizId: quizId,
              quizTitle: quizTitle,
              totalQuestions: finalTotalQuestions > 0 ? finalTotalQuestions : 10,
              try1Score: scores.length > 0 ? scores[0] : null,
              try2Score: scores.length > 1 ? scores[1] : null,
              try3Score: scores.length > 2 ? scores[2] : null,
              attemptsCount: attempts,
              highestScore: highestValue,
              isGame: false,
              lessonTitle: lessonTitle,
              operator: operator,
            ));
          }
        }
      }

      for (final quiz in quizzes) {
        final quizIdRaw = quiz['id'];
        if (quizIdRaw == null) continue;

        final quizId = quizIdRaw.toString();

        if (results.any((r) => r.quizId == quizId)) continue;

        final quizTitle = quiz['title']?.toString() ?? 'Untitled Quiz';
        final questions = quiz['basic_operator_quiz_questions'] as List? ?? [];
        final totalQuestions = questions.length;

        final progressData = directProgressMap[quizId];

        if (progressData != null) {
          final attemptsCount = progressData['attempts_count'] as int? ?? 0;
          if (attemptsCount > 0) {
            String? lessonTitle;
            try {
              if (quiz['lesson_id'] != null) {
                final lessonId = quiz['lesson_id']?.toString();
                if (lessonId != null) {
                  final lessonResponse = await _supabase
                      .from('lessons')
                      .select('title')
                      .eq('id', lessonId)
                      .maybeSingle();
                  lessonTitle = lessonResponse?['title']?.toString();
                }
              }
            } catch (e) {
            }
            
            results.add(QuizProgressData(
              quizId: quizId,
              quizTitle: quizTitle,
              totalQuestions: totalQuestions,
              try1Score: progressData['try1_score'] as int?,
              try2Score: progressData['try2_score'] as int?,
              try3Score: progressData['try3_score'] as int?,
              attemptsCount: attemptsCount,
              highestScore: progressData['highest_score'] as int? ?? 0,
              lessonTitle: lessonTitle,
              operator: operator,
            ));
          }
        }
      }

      final Map<String, QuizProgressData> deduplicated = {};
      for (final result in results) {
        if (result.isGame) {

          String normalizedTitle = result.quizTitle;

          String key;
          if (normalizedTitle.contains('(') && normalizedTitle.contains(')')) {
            final parts = normalizedTitle.split('(');
            final baseTitle = parts[0].trim();

            String normalizedBase = baseTitle;
            if (baseTitle.toLowerCase().contains('crossmath') ||
                baseTitle.toLowerCase().contains('addition_crossmath')) {
              normalizedBase = 'Crossword Math';
            }
            final stage = parts.length > 1 ? parts[1].replaceAll(')', '').trim().toLowerCase() : '';
            key = '$normalizedBase|$stage';
          } else {

            String normalizedBase = normalizedTitle;
            if (normalizedTitle.toLowerCase().contains('crossmath') ||
                normalizedTitle.toLowerCase().contains('addition_crossmath')) {
              normalizedBase = 'Crossword Math';
            }
            key = normalizedBase.toLowerCase();
          }

          if (!deduplicated.containsKey(key)) {
            deduplicated[key] = result;
          } else {
            final existing = deduplicated[key]!;

            final existingScores = [
              existing.try1Score,
              existing.try2Score,
              existing.try3Score,
            ].where((s) => s != null).cast<int>().toList();

            final newScores = [
              result.try1Score,
              result.try2Score,
              result.try3Score,
            ].where((s) => s != null).cast<int>().toList();

            final allScores = <int>[];
            allScores.addAll(existingScores);
            for (final score in newScores) {
              if (!allScores.contains(score)) {
                allScores.add(score);
              }
            }
            allScores.sort((a, b) => b.compareTo(a));

            String finalTitle = existing.quizTitle;
            if (existing.quizTitle.toLowerCase().contains('addition_crossmath') ||
                result.quizTitle.toLowerCase().contains('addition_crossmath')) {

              if (existing.quizTitle.contains('(')) {
                final parts = existing.quizTitle.split('(');
                final stage = parts.length > 1 ? parts[1].replaceAll(')', '').trim() : '';
                if (stage.isNotEmpty) {
                  finalTitle = 'Crossword Math ($stage)';
                } else {
                  finalTitle = 'Crossword Math';
                }
              } else if (result.quizTitle.contains('(')) {
                final parts = result.quizTitle.split('(');
                final stage = parts.length > 1 ? parts[1].replaceAll(')', '').trim() : '';
                if (stage.isNotEmpty) {
                  finalTitle = 'Crossword Math ($stage)';
                } else {
                  finalTitle = 'Crossword Math';
                }
              } else {
                finalTitle = 'Crossword Math';
              }
            }

            deduplicated[key] = QuizProgressData(
              quizId: existing.quizId,
              quizTitle: finalTitle,
              totalQuestions: existing.totalQuestions > 0 ? existing.totalQuestions : result.totalQuestions,
              try1Score: allScores.length > 0 ? allScores[0] : null,
              try2Score: allScores.length > 1 ? allScores[1] : null,
              try3Score: allScores.length > 2 ? allScores[2] : null,
              attemptsCount: existing.attemptsCount + result.attemptsCount,
              highestScore: allScores.isNotEmpty ? allScores.reduce((a, b) => a > b ? a : b) : 0,
              isGame: true,
              difficulty: existing.difficulty ?? result.difficulty,
              operator: existing.operator ?? result.operator,
            );
          }
        } else {

          if (!deduplicated.containsKey(result.quizId)) {
            deduplicated[result.quizId] = result;
          }
        }
      }

      final Map<String, QuizProgressData> finalDeduplicated = {};
      for (final result in deduplicated.values) {
        if (result.isGame) {

          String normalizedKey;
          if (result.quizTitle.contains('(') && result.quizTitle.contains(')')) {
            final parts = result.quizTitle.split('(');
            String baseTitle = parts[0].trim();

            if (baseTitle.toLowerCase().contains('crossmath') ||
                baseTitle.toLowerCase().contains('addition_crossmath')) {
              baseTitle = 'Crossword Math';
            }
            final stage = parts.length > 1 ? parts[1].replaceAll(')', '').trim().toLowerCase() : '';
            normalizedKey = '$baseTitle|$stage';
          } else {
            String baseTitle = result.quizTitle;
            if (baseTitle.toLowerCase().contains('crossmath') ||
                baseTitle.toLowerCase().contains('addition_crossmath')) {
              baseTitle = 'Crossword Math';
            }
            normalizedKey = baseTitle.toLowerCase();
          }

          if (!finalDeduplicated.containsKey(normalizedKey)) {

            String finalTitle = result.quizTitle;
            if (result.quizTitle.toLowerCase().contains('addition_crossmath')) {
              if (result.quizTitle.contains('(')) {
                final parts = result.quizTitle.split('(');
                final stage = parts.length > 1 ? parts[1].replaceAll(')', '').trim() : '';
                if (stage.isNotEmpty) {
                  finalTitle = 'Crossword Math ($stage)';
                } else {
                  finalTitle = 'Crossword Math';
                }
              } else {
                finalTitle = 'Crossword Math';
              }
            }

            finalDeduplicated[normalizedKey] = QuizProgressData(
              quizId: result.quizId,
              quizTitle: finalTitle,
              totalQuestions: result.totalQuestions,
              try1Score: result.try1Score,
              try2Score: result.try2Score,
              try3Score: result.try3Score,
              attemptsCount: result.attemptsCount,
              highestScore: result.highestScore,
              isGame: true,
              difficulty: result.difficulty,
              operator: result.operator,
            );
          } else {

            final existing = finalDeduplicated[normalizedKey]!;
            final allScores = [
              existing.try1Score,
              existing.try2Score,
              existing.try3Score,
              result.try1Score,
              result.try2Score,
              result.try3Score,
            ].where((s) => s != null).cast<int>().toList();

            finalDeduplicated[normalizedKey] = QuizProgressData(
              quizId: existing.quizId,
              quizTitle: existing.quizTitle,
              totalQuestions: existing.totalQuestions > 0 ? existing.totalQuestions : result.totalQuestions,
              try1Score: allScores.length > 0 ? allScores[0] : null,
              try2Score: allScores.length > 1 ? allScores[1] : null,
              try3Score: allScores.length > 2 ? allScores[2] : null,
              attemptsCount: existing.attemptsCount + result.attemptsCount,
              highestScore: allScores.isNotEmpty ? allScores.reduce((a, b) => a > b ? a : b) : 0,
              isGame: true,
              difficulty: existing.difficulty ?? result.difficulty,
              operator: existing.operator ?? result.operator,
            );
          }
        } else {

          if (!finalDeduplicated.containsKey(result.quizId)) {
            finalDeduplicated[result.quizId] = result;
          }
        }
      }

      final finalResults = finalDeduplicated.values.toList();
      
      return finalResults;
    } catch (e, stackTrace) {
      return [];
    }
  }
}

