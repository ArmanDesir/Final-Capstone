import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/basic_operator_quiz.dart';
import '../modules/basic_operators/addition/crossword_cell.dart';

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
    return totalQuestions * actualAttempts;
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

  Future<List<QuizProgressData>> getStudentQuizProgress({
    required String studentId,
    required String operator,
    required String classroomId,
  }) async {
    try {
      print('🔍 Fetching quiz progress for student: $studentId, operator: $operator, classroom: $classroomId');

      final activityProgressResponse = await _supabase
          .from('activity_progress_by_classroom')
          .select('*')
          .eq('user_id', studentId)
          .eq('classroom_id', classroomId)
          .eq('entity_type', 'quiz')
          .order('created_at', ascending: false);

      print('📊 Found ${activityProgressResponse.length} quiz progress records in activity_progress_by_classroom');

      final allActivityProgress = await _supabase
          .from('activity_progress_by_classroom')
          .select('*')
          .eq('user_id', studentId)
          .eq('classroom_id', classroomId)
          .order('created_at', ascending: false);

      print('📊 Found ${allActivityProgress.length} total activity records (quiz or quiz_progress source)');

      final Map<String, List<Map<String, dynamic>>> progressByQuiz = {};

      final progressList = (allActivityProgress as List? ?? activityProgressResponse as List? ?? []);
      for (final progress in progressList) {
        final progressMap = progress as Map<String, dynamic>;
        final entityType = progressMap['entity_type']?.toString() ?? '';
        final source = progressMap['source']?.toString() ?? '';

        if (entityType == 'quiz' || entityType == 'game' || source.contains('quiz') || source.contains('game')) {

          String quizId;
          if (entityType == 'game') {
            String title = progressMap['entity_title']?.toString() ?? '';

            if (title.toLowerCase().contains('crossmath') ||
                title.toLowerCase().contains('addition_crossmath') ||
                title.toLowerCase() == 'addition_crossmath') {
              title = 'Crossword Math';
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

      print('📊 Grouped into ${progressByQuiz.length} unique quizzes');

      final quizzesResponse = await _supabase
          .from('basic_operator_quizzes')
          .select('id, title, basic_operator_quiz_questions(id)')
          .eq('operator', operator);

      List<Map<String, dynamic>> quizzes = (quizzesResponse as List).cast<Map<String, dynamic>>();
      if (classroomId.isNotEmpty) {
        quizzes = quizzes.where((q) => q['classroom_id']?.toString() == classroomId).toList();
      }

      print('📝 Found ${quizzes.length} quizzes for operator $operator');

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

          print('📊 Found ${progressResponse.length} progress records in basic_operator_quiz_progress');

          if (progressResponse != null && progressResponse is List) {
            for (final progressItem in progressResponse) {
              final progressMapEntry = progressItem as Map<String, dynamic>;
              final quizId = progressMapEntry['quiz_id']?.toString() ?? '';
              if (quizId.isNotEmpty) {
                directProgressMap[quizId] = progressMapEntry;
              }
            }
          }
        } catch (e) {
          print('⚠️ Error fetching from basic_operator_quiz_progress: $e');
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
                title.toLowerCase().contains('addition_crossmath') ||
                title.toLowerCase() == 'addition_crossmath') {
              title = 'Crossword Math';
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
                    print('🔍 Detected duplicate game entry: score=$score, timeDiff=${diff}s');
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
            print('🔍 Deduplicated: ${processedProgressList.length} entries -> ${uniqueAttempts.length} unique attempts');
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
          try {

            final puzzleResponse = await _supabase
                .from('crossword_puzzles')
                .select('grid')
                .eq('operator', operator)
                .eq('difficulty', processedProgressList.first['stage']?.toString().toLowerCase() ?? 'easy')
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
            print('⚠️ Could not get puzzle total: $e');
          }

          if (gameTotal == 0) {
            final firstProgress = processedProgressList.first;
            final status = firstProgress['status']?.toString().toLowerCase() ?? '';
            if (status.contains('complete') && highest > 0) {
              gameTotal = highest;
              print('📊 Inferred total from completed status: $gameTotal');
            } else if (highest > 0) {
              gameTotal = highest;
            } else {
              gameTotal = 4;
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
              );
              print('🔀 Merged duplicate game during processing: $quizTitle -> $normalizedTitle');
            } else {

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
              ));
              print('✅ Added ${isGame ? 'game' : 'quiz'} progress: $normalizedTitle (${attempts} attempts, scores: $rawScores, total: $finalTotalQuestions)');
            }
          } else {

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
            ));
            print('✅ Added quiz progress: $quizTitle (${attempts} attempts)');
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
            results.add(QuizProgressData(
              quizId: quizId,
              quizTitle: quizTitle,
              totalQuestions: totalQuestions,
              try1Score: progressData['try1_score'] as int?,
              try2Score: progressData['try2_score'] as int?,
              try3Score: progressData['try3_score'] as int?,
              attemptsCount: attemptsCount,
              highestScore: progressData['highest_score'] as int? ?? 0,
            ));
            print('✅ Added quiz progress from basic_operator_quiz_progress: $quizTitle');
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
            print('✅ Added game to deduplication map: $key -> ${result.quizTitle}');
          } else {

            final existing = deduplicated[key]!;
            print('🔀 Found duplicate game entry: $key (existing: ${existing.quizTitle}, new: ${result.quizTitle})');

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
            );
            print('🔀 Merged duplicate game entries: ${existing.quizTitle} + ${result.quizTitle} -> $finalTitle');
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
            );
            print('🔀 Final merge: Combined duplicate game entries with key $normalizedKey');
          }
        } else {

          if (!finalDeduplicated.containsKey(result.quizId)) {
            finalDeduplicated[result.quizId] = result;
          }
        }
      }

      final finalResults = finalDeduplicated.values.toList();
      print('📊 Returning ${finalResults.length} quiz/game progress records (after final deduplication)');
      return finalResults;
    } catch (e, stackTrace) {
      print('❌ Error fetching quiz progress: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }
}

