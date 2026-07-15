import 'dart:math';import 'package:vidlang/utils/adaptive.dart' as adaptive;

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:vidlang/models/ai_evaluation_log.dart';
import 'package:vidlang/models/recording_record.dart';
import 'package:vidlang/services/database_service.dart';
import 'package:vidlang/services/evaluation/score_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/views/audio_player/ai_evaluation_sheet.dart';


class LearningRecordPage extends StatefulWidget {
  final String videoCode;
  final String videoTitle;

  const LearningRecordPage({
    super.key,
    required this.videoCode,
    required this.videoTitle,
  });

  @override
  State<LearningRecordPage> createState() => _LearningRecordPageState();
}

class _LearningRecordPageState extends State<LearningRecordPage> {
  List<RecordingRecord> _records = [];
  List<AiEvaluationLog> _evaluations = [];
  bool _loading = true;

  double? _sentenceAvg;
  double? _fullAvg;
  double? _resourceScore;
  int _totalFollowCount = 0;
  int _uniqueSentenceCount = 0;
  String? _bestRefText;
  double? _bestScore;
  String? _worstRefText;
  double? _worstScore;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final breakdown = await ScoreService.getScoreBreakdown(widget.videoCode);

    final evaluations = await DatabaseService.findByCondition(
      () => AiEvaluationLog(),
      where: 'resource_code = ? AND is_deleted = 0',
      whereArgs: [widget.videoCode],
      orderBy: 'evaluated_at DESC',
    );

    if (mounted) {
      setState(() {
        _records = breakdown.allRecords;
        _evaluations = evaluations;
        _sentenceAvg = breakdown.sentenceAvg;
        _fullAvg = breakdown.fullAvg;
        _resourceScore = breakdown.resourceScore;
        _totalFollowCount = breakdown.totalFollowCount;
        _uniqueSentenceCount = breakdown.uniqueSentenceCount;
        _bestRefText = breakdown.bestRefText;
        _bestScore = breakdown.bestScore;
        _worstRefText = breakdown.worstRefText;
        _worstScore = breakdown.worstScore;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('学习记录', style: TextStyle(color: AppColors.onSurface, fontSize: adaptive.Adaptive.sp(16))),
        backgroundColor: AppColors.surface,
        iconTheme: const IconThemeData(color: AppColors.onSurface),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _loadData,
              child: ListView(
                padding: EdgeInsets.all(adaptive.Adaptive.w(16)),
                children: [
                  _buildScoreOverview(),
                  SizedBox(height: adaptive.Adaptive.h(16)),
                  _buildStatsGrid(),
                  SizedBox(height: adaptive.Adaptive.h(16)),
                  if (_bestRefText != null || _worstRefText != null)
                    _buildBestWorst(),
                  SizedBox(height: adaptive.Adaptive.h(16)),
                  if (_records.where((r) => r.overallScore != null).length >= 3)
                    _buildScoreTrendChart(),
                  if (_records.where((r) => r.overallScore != null).length >= 3)
                    SizedBox(height: adaptive.Adaptive.h(16)),
                  _buildWeakSentences(),
                  SizedBox(height: adaptive.Adaptive.h(16)),
                  _buildEvaluationHistory(),
                  SizedBox(height: adaptive.Adaptive.h(16)),
                  _buildFollowHistory(),
                ],
              ),
            ),
    );
  }

  Widget _buildScoreOverview() {
    return Container(
      padding: EdgeInsets.all(adaptive.Adaptive.w(20)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary.withValues(alpha: 0.2), AppColors.secondary.withValues(alpha: 0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(adaptive.Adaptive.r(16)),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(widget.videoTitle, style: TextStyle(color: AppColors.onSurface.withValues(alpha: 0.7), fontSize: adaptive.Adaptive.sp(12)), maxLines: 1, overflow: TextOverflow.ellipsis),
          SizedBox(height: adaptive.Adaptive.h(12)),
          if (_resourceScore != null) ...[
            Text(
              '${_resourceScore!.round()}',
              style: TextStyle(
                color: _scoreColor(_resourceScore!),
                fontSize: adaptive.Adaptive.sp(56),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: adaptive.Adaptive.h(4)),
            Text('综合评分', style: TextStyle(color: AppColors.onSurface.withValues(alpha: 0.54), fontSize: adaptive.Adaptive.sp(12))),
          ] else
            Column(
              children: [
                Icon(AppIcons.micNone, size: adaptive.Adaptive.icon(48), color: AppColors.onSurface.withValues(alpha: 0.24)),
                SizedBox(height: adaptive.Adaptive.h(8)),
                Text('暂无跟读评分', style: TextStyle(color: AppColors.onSurface.withValues(alpha: 0.38), fontSize: adaptive.Adaptive.sp(13))),
              ],
            ),
          if (_sentenceAvg != null || _fullAvg != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_sentenceAvg != null) _miniScore('单句', _sentenceAvg!),
                  if (_sentenceAvg != null && _fullAvg != null)
                    Container(width: 1, height: 16, color: AppColors.onSurface.withValues(alpha: 0.12), margin: const EdgeInsets.symmetric(horizontal: 16)),
                  if (_fullAvg != null) _miniScore('全文', _fullAvg!),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _miniScore(String label, double score) {
    return Column(
      children: [
        Text('${score.round()}', style: TextStyle(color: _scoreColor(score), fontSize: adaptive.Adaptive.sp(18), fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: AppColors.onSurface.withValues(alpha: 0.54), fontSize: adaptive.Adaptive.sp(12))),
      ],
    );
  }

  Widget _buildStatsGrid() {
    return Container(
      padding: EdgeInsets.all(adaptive.Adaptive.w(16)),
      decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(adaptive.Adaptive.r(12))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem(AppIcons.micRounded, '跟读次数', '$_totalFollowCount'),
          _statItem(AppIcons.textFields, '覆盖句数', '$_uniqueSentenceCount'),
          _statItem(AppIcons.autoAwesome, 'AI点评', '${_evaluations.length}'),
        ],
      ),
    );
  }

  Widget _statItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: adaptive.Adaptive.icon(20)),
        SizedBox(height: adaptive.Adaptive.h(4)),
        Text(value, style: TextStyle(color: AppColors.onSurface, fontSize: adaptive.Adaptive.sp(16), fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: AppColors.onSurface.withValues(alpha: 0.54), fontSize: adaptive.Adaptive.sp(12))),
      ],
    );
  }

  Widget _buildBestWorst() {
    return Container(
      padding: EdgeInsets.all(adaptive.Adaptive.w(16)),
      decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(adaptive.Adaptive.r(12))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('表现分析', style: TextStyle(color: AppColors.onSurface, fontSize: adaptive.Adaptive.sp(14), fontWeight: FontWeight.w600)),
          SizedBox(height: adaptive.Adaptive.h(12)),
          if (_bestRefText != null)
            _analysisRow(AppIcons.thumbUp, '最佳', _bestRefText ?? '', _bestScore!, AppColors.success),
          if (_bestRefText != null && _worstRefText != null) SizedBox(height: adaptive.Adaptive.h(8)),
          if (_worstRefText != null)
            _analysisRow(AppIcons.thumbDown, '待提升', _worstRefText ?? '', _worstScore!, AppColors.warning),
        ],
      ),
    );
  }

  Widget _analysisRow(IconData icon, String label, String text, double score, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: adaptive.Adaptive.icon(16)),
        SizedBox(width: adaptive.Adaptive.w(8)),
        Expanded(
          child: Text(text, style: TextStyle(color: AppColors.onSurface.withValues(alpha: 0.7), fontSize: adaptive.Adaptive.sp(12)), maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: adaptive.Adaptive.w(8), vertical: adaptive.Adaptive.h(2)),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(adaptive.Adaptive.r(8))),
          child: Text('${score.round()}', style: TextStyle(color: color, fontSize: adaptive.Adaptive.sp(13), fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildScoreTrendChart() {
    final scored = _records.where((r) => r.overallScore != null).toList();
    if (scored.length < 3) return const SizedBox.shrink();
    final last20 = scored.length > 20 ? scored.sublist(scored.length - 20) : scored;
    return Container(
      padding: EdgeInsets.all(adaptive.Adaptive.w(16)),
      decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(adaptive.Adaptive.r(12))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('分数趋势', style: TextStyle(color: AppColors.onSurface, fontSize: adaptive.Adaptive.sp(14), fontWeight: FontWeight.w600)),
          SizedBox(height: adaptive.Adaptive.h(12)),
          SizedBox(
            height: 120,
            child: CustomPaint(
              painter: _ScoreTrendPainter(last20.map((r) => r.overallScore!).toList()),
              size: Size.infinite,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeakSentences() {
    final sentenceRecords = _records.where((r) => r.scope == 'sentence' && r.overallScore != null).toList();
    if (sentenceRecords.isEmpty) return const SizedBox.shrink();
    final bySentence = <String, List<RecordingRecord>>{};
    for (final r in sentenceRecords) {
      final key = r.sentenceCode ?? '';
      if (key.isEmpty) continue;
      bySentence.putIfAbsent(key, () => []).add(r);
    }
    final avgBySentence = <String, double>{};
    for (final e in bySentence.entries) {
      avgBySentence[e.key] = e.value.map((r) => r.overallScore!).reduce((a, b) => a + b) / e.value.length;
    }
    final weak = avgBySentence.entries.where((e) => e.value < 70).toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    if (weak.isEmpty) return const SizedBox.shrink();
    final weakWithText = <MapEntry<String, double>>[];
    for (final e in weak.take(5)) {
      weakWithText.add(e);
    }
    final codeToText = <String, String>{};
    for (final r in sentenceRecords) {
      final sc = r.sentenceCode ?? '';
      if (sc.isNotEmpty && !codeToText.containsKey(sc) && r.refText != null && r.refText!.isNotEmpty) {
        codeToText[sc] = r.refText!;
      }
    }
    return Container(
      padding: EdgeInsets.all(adaptive.Adaptive.w(16)),
      decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(adaptive.Adaptive.r(12))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('薄弱句型', style: TextStyle(color: AppColors.onSurface, fontSize: adaptive.Adaptive.sp(14), fontWeight: FontWeight.w600)),
          SizedBox(height: adaptive.Adaptive.h(8)),
          ...weakWithText.map((e) {
            final text = codeToText[e.key] ?? e.key;
            final score = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: GestureDetector(
                onTap: () => Navigator.pop(context, e.key),
                child: Row(
                  children: [
                    Icon(AppIcons.refresh, size: adaptive.Adaptive.icon(14), color: AppColors.primary),
                    SizedBox(width: adaptive.Adaptive.w(6)),
                    Expanded(
                      child: Text(text, style: TextStyle(color: AppColors.onSurface.withValues(alpha: 0.7), fontSize: adaptive.Adaptive.sp(13)), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: adaptive.Adaptive.w(6), vertical: adaptive.Adaptive.h(1)),
                      decoration: BoxDecoration(color: ScoreService.scoreColor(score).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(adaptive.Adaptive.r(6))),
                      child: Text('${score.round()}', style: TextStyle(color: ScoreService.scoreColor(score), fontSize: adaptive.Adaptive.sp(12), fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEvaluationHistory() {
    if (_evaluations.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('AI 点评历史', style: TextStyle(color: AppColors.onSurface, fontSize: adaptive.Adaptive.sp(14), fontWeight: FontWeight.w600)),
            const Spacer(),
            GestureDetector(
              onTap: () => AiEvaluationSheet.show(
                context,
                videoCode: widget.videoCode,
                videoTitle: widget.videoTitle,
              ),
              child: Text('查看详情', style: TextStyle(color: AppColors.primary, fontSize: adaptive.Adaptive.sp(13))),
            ),
          ],
        ),
        SizedBox(height: adaptive.Adaptive.h(8)),
        ..._evaluations.take(3).map((e) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: EdgeInsets.all(adaptive.Adaptive.w(12)),
          decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(adaptive.Adaptive.r(8))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (e.resourceScore != null)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: adaptive.Adaptive.w(6), vertical: adaptive.Adaptive.h(1)),
                      decoration: BoxDecoration(
                        color: _scoreColor(e.resourceScore!).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(adaptive.Adaptive.r(6)),
                      ),
                      child: Text('${e.resourceScore!.round()}', style: TextStyle(color: _scoreColor(e.resourceScore!), fontSize: adaptive.Adaptive.sp(13), fontWeight: FontWeight.bold)),
                    ),
                  SizedBox(width: adaptive.Adaptive.w(8)),
                  if (e.overallLevel != null)
                    Text(e.overallLevel!, style: TextStyle(color: AppColors.onSurface.withValues(alpha: 0.54), fontSize: adaptive.Adaptive.sp(13))),
                  const Spacer(),
                  Text(_fmtDate(e.evaluatedAt), style: TextStyle(color: AppColors.onSurface.withValues(alpha: 0.38), fontSize: adaptive.Adaptive.sp(12))),
                ],
              ),
              if (e.summary != null && e.summary!.isNotEmpty) ...[
                SizedBox(height: adaptive.Adaptive.h(6)),
                Text(e.summary!, style: TextStyle(color: AppColors.onSurface.withValues(alpha: 0.7), fontSize: adaptive.Adaptive.sp(13), height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildFollowHistory() {
    if (_records.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('跟读记录', style: TextStyle(color: AppColors.onSurface, fontSize: adaptive.Adaptive.sp(14), fontWeight: FontWeight.w600)),
        SizedBox(height: adaptive.Adaptive.h(8)),
        ..._records.take(20).map((r) => Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: EdgeInsets.symmetric(horizontal: adaptive.Adaptive.w(12), vertical: adaptive.Adaptive.h(8)),
          decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(adaptive.Adaptive.r(8))),
          child: Row(
            children: [
              if (r.overallScore != null)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: adaptive.Adaptive.w(6), vertical: adaptive.Adaptive.h(1)),
                  decoration: BoxDecoration(
                    color: _scoreColor(r.overallScore!).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(adaptive.Adaptive.r(6)),
                  ),
                  child: Text('${r.overallScore!.round()}', style: TextStyle(color: _scoreColor(r.overallScore!), fontSize: adaptive.Adaptive.sp(13), fontWeight: FontWeight.bold)),
                )
              else
                Container(
                  padding: EdgeInsets.symmetric(horizontal: adaptive.Adaptive.w(6), vertical: adaptive.Adaptive.h(1)),
                  decoration: BoxDecoration(color: AppColors.onSurface.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(adaptive.Adaptive.r(6))),
                  child: Text('--', style: TextStyle(color: AppColors.onSurface.withValues(alpha: 0.38), fontSize: adaptive.Adaptive.sp(13))),
                ),
              SizedBox(width: adaptive.Adaptive.w(10)),
              Expanded(
                child: Text(
                  r.refText ?? '',
                  style: TextStyle(color: AppColors.onSurface.withValues(alpha: 0.7), fontSize: adaptive.Adaptive.sp(12)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                r.scope == 'sentence' ? '单句' : '全文',
                style: TextStyle(color: AppColors.onSurface.withValues(alpha: 0.38), fontSize: adaptive.Adaptive.sp(12)),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Color _scoreColor(double score) => ScoreService.scoreColor(score);

  String _fmtDate(DateTime d) {
    return '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

class _ScoreTrendPainter extends CustomPainter {
  final List<double> scores;
  _ScoreTrendPainter(this.scores);

  @override
  void paint(Canvas canvas, Size size) {
    if (scores.isEmpty) return;
    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    const pad = 8.0;
    final w = size.width - pad * 2;
    final h = size.height - pad * 2;
    final n = scores.length;
    final minScore = scores.reduce(min);
    final maxScore = scores.reduce(max);
    final range = maxScore - minScore;
    final yScale = range > 0 ? h / range : h / 100.0;

    final points = <Offset>[];
    for (var i = 0; i < n; i++) {
      final x = pad + (n > 1 ? w * i / (n - 1) : w / 2);
      final y = pad + h - (scores[i] - (range > 0 ? minScore : 0)) * yScale;
      points.add(Offset(x, y));
    }

    if (points.length > 1) {
      final path = Path()..moveTo(points.first.dx, size.height);
      for (final p in points) {
        path.lineTo(p.dx, p.dy);
      }
      path.lineTo(points.last.dx, size.height);
      path.close();
      canvas.drawPath(path, fillPaint);
      canvas.drawPoints(PointMode.polygon, points, paint);
    }

    final dotPaint = Paint()..color = AppColors.primary..style = PaintingStyle.fill;
    for (final p in points) {
      canvas.drawCircle(p, 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScoreTrendPainter old) => old.scores != scores;
}
