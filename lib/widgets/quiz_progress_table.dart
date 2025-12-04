import 'package:flutter/material.dart';
import '../services/student_quiz_progress_service.dart';

class QuizProgressTable extends StatelessWidget {
  final List<QuizProgressData> quizData;

  const QuizProgressTable({
    super.key,
    required this.quizData,
  });

  double _calculateTotalGeneralAverage() {
    if (quizData.isEmpty) return 0;
    final averages = quizData.map((q) => q.generalAverage).where((a) => a > 0).toList();
    if (averages.isEmpty) return 0;
    return averages.reduce((a, b) => a + b) / averages.length;
  }

  @override
  Widget build(BuildContext context) {
    if (quizData.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            'No quiz data available for this operator.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    final totalGeneralAverage = _calculateTotalGeneralAverage();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Table(
            border: TableBorder.all(color: Colors.grey.shade300),
            columnWidths: const {
              0: FixedColumnWidth(200),
              1: FixedColumnWidth(150),
              2: FixedColumnWidth(100),
              3: FixedColumnWidth(120),
              4: FixedColumnWidth(150),
            },
            children: [

              TableRow(
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                children: [
                  _buildHeaderCell('Quiz'),
                  _buildHeaderCell('Attempts'),
                  _buildHeaderCell('Total'),
                  _buildHeaderCell('Highest Score'),
                  _buildHeaderCell('General Average'),
                ],
              ),

              ...quizData.map((quiz) {
                final attemptsText = _buildAttemptsText(quiz);
                final totalText = quiz.attemptsCount > 0
                    ? '${quiz.totalActualScore}/${quiz.totalPossible}'
                    : '-';
                final highestScore = quiz.attemptsCount > 0
                    ? '${quiz.highestScorePercentage}%'
                    : '-';
                final generalAvg = quiz.attemptsCount > 0
                    ? '${quiz.generalAverage.toStringAsFixed(1)}%'
                    : '-';

                return TableRow(
                  children: [
                    _buildDataCell(quiz.quizTitle, isLeftAligned: true),
                    _buildDataCell(attemptsText, isLeftAligned: true),
                    _buildDataCell(totalText),
                    _buildDataCell(highestScore),
                    _buildDataCell(generalAvg),
                  ],
                );
              }).toList(),

              TableRow(
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                children: [
                  _buildTotalCell('TOTAL GENERAL AVERAGE', isLeftAligned: true),
                  _buildTotalCell(''),
                  _buildTotalCell(''),
                  _buildTotalCell(''),
                  _buildTotalCell(
                    totalGeneralAverage > 0
                        ? '${totalGeneralAverage.toStringAsFixed(1)}%'
                        : '-',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildDataCell(String text, {bool isLeftAligned = false}) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13),
        textAlign: isLeftAligned ? TextAlign.left : TextAlign.center,
      ),
    );
  }

  Widget _buildTotalCell(String text, {bool isLeftAligned = false}) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.blue.shade900,
        ),
        textAlign: isLeftAligned ? TextAlign.left : TextAlign.center,
      ),
    );
  }

  String _buildAttemptsText(QuizProgressData quiz) {
    if (quiz.attemptsCount == 0) return 'No attempts';

    double _getActualScore(int? score) {
      if (score == null) return 0;
      if (quiz.isGame) {

        return score.toDouble();
      }

      return (score / 100.0 * quiz.totalQuestions).round().toDouble();
    }

    final parts = <String>[];
    if (quiz.try1Score != null) {
      final actualScore = _getActualScore(quiz.try1Score).round();
      parts.add('1 = $actualScore/${quiz.totalQuestions}');
    }
    if (quiz.try2Score != null) {
      final actualScore = _getActualScore(quiz.try2Score).round();
      parts.add('2 = $actualScore/${quiz.totalQuestions}');
    }
    if (quiz.try3Score != null) {
      final actualScore = _getActualScore(quiz.try3Score).round();
      parts.add('3 = $actualScore/${quiz.totalQuestions}');
    }

    return parts.join(' & ');
  }
}

