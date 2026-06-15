import 'dart:ui';

import 'package:vidlang/models/recording_record.dart';
import 'package:vidlang/services/database_service.dart';

class ScoreService {
  static Future<double?> calculateResourceScore(String resourceCode) async {
    final records = await DatabaseService.findByCondition(
      () => RecordingRecord(),
      where: 'resource_code = ? AND is_deleted = 0',
      whereArgs: [resourceCode],
    );

    if (records.isEmpty) return null;

    final sentenceRecords = records.where((r) => r.scope == 'sentence' && r.overallScore != null).toList();
    final fullRecords = records.where((r) => r.scope == 'full' && r.overallScore != null).toList();

    final sentenceAvg = sentenceRecords.isNotEmpty
        ? sentenceRecords.map((r) => r.overallScore!).reduce((a, b) => a + b) / sentenceRecords.length
        : null;
    final fullAvg = fullRecords.isNotEmpty
        ? fullRecords.map((r) => r.overallScore!).reduce((a, b) => a + b) / fullRecords.length
        : null;

    if (sentenceAvg != null && fullAvg != null) {
      return (sentenceAvg + fullAvg) / 2;
    }
    return sentenceAvg ?? fullAvg;
  }

  static Future<ScoreBreakdown> getScoreBreakdown(String resourceCode) async {
    final records = await DatabaseService.findByCondition(
      () => RecordingRecord(),
      where: 'resource_code = ? AND is_deleted = 0',
      whereArgs: [resourceCode],
    );

    final sentenceRecords = records.where((r) => r.scope == 'sentence').toList();
    final fullRecords = records.where((r) => r.scope == 'full').toList();

    final scoredSentences = sentenceRecords.where((r) => r.overallScore != null).toList();
    final scoredFulls = fullRecords.where((r) => r.overallScore != null).toList();

    final sentenceAvg = scoredSentences.isNotEmpty
        ? scoredSentences.map((r) => r.overallScore!).reduce((a, b) => a + b) / scoredSentences.length
        : null;
    final fullAvg = scoredFulls.isNotEmpty
        ? scoredFulls.map((r) => r.overallScore!).reduce((a, b) => a + b) / scoredFulls.length
        : null;

    double? resourceScore;
    if (sentenceAvg != null && fullAvg != null) {
      resourceScore = (sentenceAvg + fullAvg) / 2;
    } else {
      resourceScore = sentenceAvg ?? fullAvg;
    }

    final bestRecord = scoredSentences.isNotEmpty
        ? (scoredSentences..sort((a, b) => (b.overallScore ?? 0).compareTo(a.overallScore ?? 0))).first
        : null;
    final worstRecord = scoredSentences.isNotEmpty
        ? (scoredSentences..sort((a, b) => (a.overallScore ?? 0).compareTo(b.overallScore ?? 0))).first
        : null;

    final uniqueSentences = sentenceRecords.map((r) => r.sentenceCode).toSet();

    return ScoreBreakdown(
      resourceScore: resourceScore,
      sentenceAvg: sentenceAvg,
      sentenceCount: sentenceRecords.length,
      fullAvg: fullAvg,
      fullCount: fullRecords.length,
      totalFollowCount: records.length,
      uniqueSentenceCount: uniqueSentences.length,
      bestRefText: bestRecord?.refText,
      bestScore: bestRecord?.overallScore,
      worstRefText: worstRecord?.refText,
      worstScore: worstRecord?.overallScore,
      allRecords: records,
    );
  }

  static String determineLevel(double? score) {
    if (score == null) return 'N/A';
    if (score >= 90) return 'A';
    if (score >= 80) return 'B';
    if (score >= 70) return 'C';
    if (score >= 60) return 'D';
    return 'F';
  }

  static Color scoreColor(double score) {
    if (score >= 90) return const Color(0xFF30D158);
    if (score >= 75) return const Color(0xFFFFCC00);
    if (score >= 60) return const Color(0xFFFF8A00);
    return const Color(0xFFFF453A);
  }
}

class ScoreBreakdown {
  final double? resourceScore;
  final double? sentenceAvg;
  final int sentenceCount;
  final double? fullAvg;
  final int fullCount;
  final int totalFollowCount;
  final int uniqueSentenceCount;
  final String? bestRefText;
  final double? bestScore;
  final String? worstRefText;
  final double? worstScore;
  final List<RecordingRecord> allRecords;

  const ScoreBreakdown({
    this.resourceScore,
    this.sentenceAvg,
    this.sentenceCount = 0,
    this.fullAvg,
    this.fullCount = 0,
    this.totalFollowCount = 0,
    this.uniqueSentenceCount = 0,
    this.bestRefText,
    this.bestScore,
    this.worstRefText,
    this.worstScore,
    this.allRecords = const [],
  });
}
