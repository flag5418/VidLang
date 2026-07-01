import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vidlang/models/ai_evaluation_log.dart';
import 'package:vidlang/services/ai_service.dart';
import 'package:vidlang/services/database_service.dart';
import 'package:vidlang/services/score_service.dart';
import 'package:vidlang/theme/theme.dart';

class AiEvaluationSheet extends StatefulWidget {
  final String videoCode;
  final String videoTitle;
  final String language;

  const AiEvaluationSheet({
    super.key,
    required this.videoCode,
    required this.videoTitle,
    this.language = 'en',
  });

  @override
  State<AiEvaluationSheet> createState() => _AiEvaluationSheetState();

  static void show(
    BuildContext context, {
    required String videoCode,
    required String videoTitle,
    String language = 'en',
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => AiEvaluationSheet(
        videoCode: videoCode,
        videoTitle: videoTitle,
        language: language,
      ),
    );
  }
}

class _AiEvaluationSheetState extends State<AiEvaluationSheet> {
  bool _loading = false;
  AiEvaluationLog? _evaluation;
  List<AiEvaluationLog> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final records = await DatabaseService.findByCondition(
      () => AiEvaluationLog(),
      where: 'resource_code = ? AND is_deleted = 0',
      whereArgs: [widget.videoCode],
      orderBy: 'evaluated_at DESC',
    );
    if (mounted) {
      setState(() {
        _history = records;
        if (records.isNotEmpty) _evaluation = records.first;
      });
    }
  }

  Future<void> _requestEvaluation() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      final breakdown = await ScoreService.getScoreBreakdown(widget.videoCode);

      if (breakdown.allRecords.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('暂无跟读记录，请先跟读后再请求AI点评')));
        }
        return;
      }

      final sentenceAvg = breakdown.sentenceAvg;
      final fullAvg = breakdown.fullAvg;
      final resourceScore = breakdown.resourceScore;

      final followSummary = <String>[];
      for (final r in breakdown.allRecords.take(10)) {
        followSummary.add(
          '${r.refText ?? ""}: ${r.overallScore?.round() ?? "?"}分',
        );
      }

      final result = await AiService.callAiProxy(
        ruleCode: 'ai_audio_evaluation',
        scene: 'audio_player',
        entry: 'ai_commentary',
        word: widget.videoTitle,
        sourceType: 'music',
        sourceCode: widget.videoCode,
        params: {
          'resource_title': widget.videoTitle,
          'language': widget.language,
          'sentence_follow_avg': sentenceAvg?.round(),
          'sentence_follow_count': breakdown.sentenceCount,
          'full_follow_avg': fullAvg?.round(),
          'full_follow_count': breakdown.fullCount,
          'resource_score': resourceScore?.round(),
          'follow_summary': followSummary.join('\n'),
        },
      );

      if (!mounted) return;

      final evaluationJson = result.success
          ? jsonEncode(result.toJson())
          : '{}';
      final summary = result.success
          ? (result.translation ??
                result.wordMeaningInContext ??
                result.mnemonic ??
                result.word)
          : null;

      final level = ScoreService.determineLevel(resourceScore);

      final log = AiEvaluationLog(
        resourceCode: widget.videoCode,
        resourceType: 'music',
        resourceTitle: widget.videoTitle,
        language: widget.language,
        sentenceFollowAvgScore: sentenceAvg,
        sentenceFollowCount: breakdown.sentenceCount,
        fullFollowAvgScore: fullAvg,
        fullFollowCount: breakdown.fullCount,
        resourceScore: resourceScore,
        evaluationJson: evaluationJson,
        summary: summary,
        overallLevel: level,
      );
      await DatabaseService.insert(log);

      if (mounted) {
        await _loadHistory();
        setState(() {});
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('AI点评请求失败')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _scoreColor(double score) => ScoreService.scoreColor(score);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  'AI 点评',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _loading ? null : _requestEvaluation,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: _loading ? null : AppColors.sunsetGradient,
                      color: _loading ? Colors.grey : null,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_loading)
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        else
                          Icon(
                            Icons.auto_awesome,
                            size: 14,
                            color: Colors.white,
                          ),
                        const SizedBox(width: 6),
                        Text(
                          _loading ? '分析中...' : '请求点评',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _evaluation != null
                ? _buildEvaluationContent(controller)
                : _buildEmptyState(controller),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ScrollController controller) {
    return ListView(
      controller: controller,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        SizedBox(height: 40),
        Icon(Icons.auto_awesome_outlined, size: 48, color: Colors.white24),
        SizedBox(height: 12),
        Text(
          '暂无AI点评\n跟读练习后点击"请求点评"',
          style: TextStyle(color: Colors.white54, fontSize: 13.sp),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildEvaluationContent(ScrollController controller) {
    final e = _evaluation!;
    final structured = _parseStructuredEvaluation(e.evaluationJson);
    return ListView(
      controller: controller,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        if (e.resourceScore != null)
          Center(
            child: Column(
              children: [
                Text(
                  '${e.resourceScore!.round()}',
                  style: TextStyle(
                    color: _scoreColor(e.resourceScore!),
                    fontSize: 48.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                if (e.overallLevel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _scoreColor(
                        e.resourceScore!,
                      ).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      e.overallLevel!,
                      style: TextStyle(
                        color: _scoreColor(e.resourceScore!),
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _statItem('单句均分', e.sentenceFollowAvgScore),
            _statItem('单句次数', e.sentenceFollowCount.toDouble(), showInt: true),
            _statItem('全文均分', e.fullFollowAvgScore),
            _statItem('全文次数', e.fullFollowCount.toDouble(), showInt: true),
          ],
        ),
        const SizedBox(height: 16),
        if (structured != null) ...[
          if (structured['encouragement'] != null)
            _evaluationSection(
              Icons.favorite,
              '鼓励',
              structured['encouragement']!,
            ),
          if (structured['pronunciation'] != null)
            _evaluationSection(
              Icons.record_voice_over,
              '发音',
              structured['pronunciation']!,
            ),
          if (structured['fluency'] != null)
            _evaluationSection(Icons.speed, '流畅度', structured['fluency']!),
          if (structured['suggestions'] != null)
            _suggestionsSection(structured['suggestions']),
          if (structured['nextStep'] != null)
            _evaluationSection(
              Icons.trending_up,
              '下一步',
              structured['nextStep']!,
            ),
        ] else if (e.summary != null && e.summary!.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              e.summary!,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13.sp,
                height: 1.6,
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        if (_history.length > 1) ...[
          Text(
            '历史点评',
            style: TextStyle(color: Colors.white70, fontSize: 12.sp),
          ),
          const SizedBox(height: 8),
          ..._history.skip(1).map((h) => _historyItem(h)),
        ],
      ],
    );
  }

  Map<String, dynamic>? _parseStructuredEvaluation(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map<String, dynamic>) {
        final eval = decoded['evaluation'];
        if (eval is Map<String, dynamic>) return eval;
        if (decoded.containsKey('encouragement')) return decoded;
      }
    } catch (_) {}
    return null;
  }

  Widget _evaluationSection(IconData icon, String title, String content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.white70),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(color: Colors.white, fontSize: 13.sp, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _suggestionsSection(dynamic suggestions) {
    if (suggestions is! List) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb, size: 16, color: Colors.white70),
              const SizedBox(width: 6),
              Text(
                '建议',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...suggestions.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: TextStyle(color: Colors.white54, fontSize: 13.sp),
                  ),
                  Expanded(
                    child: Text(
                      '$s',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.sp,
                        height: 1.5,
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

  Widget _statItem(String label, double? value, {bool showInt = false}) {
    return Column(
      children: [
        Text(
          value != null
              ? (showInt ? value.round().toString() : value.round().toString())
              : '-',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: Colors.white54, fontSize: 12.sp),
        ),
      ],
    );
  }

  Widget _historyItem(AiEvaluationLog h) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          if (h.resourceScore != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _scoreColor(h.resourceScore!).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${h.resourceScore!.round()}',
                style: TextStyle(
                  color: _scoreColor(h.resourceScore!),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              h.summary ?? '无点评内容',
              style: TextStyle(color: Colors.white70, fontSize: 13.sp),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            _fmtDate(h.evaluatedAt),
            style: TextStyle(color: Colors.white38, fontSize: 12.sp),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) {
    return '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
