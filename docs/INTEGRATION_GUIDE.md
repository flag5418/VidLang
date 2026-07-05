# VidLang 跟读评测功能集成指南 📘

## 🎯 快速开始指南

### 1. 一行代码集成

```dart
// 在任意页面添加评测按钮
ElevatedButton(
  onPressed: () {
    showPronunciationEvaluation(
      context,
      text: 'Hello World!',
    );
  },
  child: Text('开始跟读评测'),
)
```

### 2. 在视频播放器中集成

```dart
class VideoPlayerPage extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // 视频播放器
          VideoPlayerWidget(video: currentVideo),
          
          // 字幕显示区域
          Container(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  '当前字幕',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                SizedBox(height: 8),
                
                // 可点击的字幕文本
                GestureDetector(
                  onTap: () {
                    showPronunciationEvaluation(
                      context,
                      text: currentSubtitle,
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      currentSubtitle,
                      style: TextStyle(
                        fontSize: 16,
                        decoration: TextDecoration.underline,
                        color: Colors.blue.shade700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 固定评测按钮
          Container(
            padding: EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: () {
                showPronunciationEvaluation(
                  context,
                  text: currentSubtitle,
                  onComplete: (result) {
                    // 处理评测结果
                    _showEvaluationResult(result);
                  },
                );
              },
              icon: Icon(Icons.mic),
              label: Text('跟读评测'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEvaluationResult(EvaluationResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('🎯 评测结果'),
        content: Text(
          '综合得分: ${result.overallScore.toInt()}%\n'
          '下次继续加油！'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('确定'),
          ),
        ],
      ),
    );
  }
}
```

### 3. 在文章阅读器中集成

```dart
class ArticleReaderPage extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('文章阅读'),
        actions: [
          // 阅读器顶部评测按钮
          IconButton(
            onPressed: () {
              showPronunciationEvaluation(
                context,
                text: selectedText, // 当前选中文本
                mode: EvaluationMode.sentence,
              );
            },
            icon: Icon(Icons.record_voice_over),
            tooltip: '跟读评测',
          ),
        ],
      ),
      body: Column(
        children: [
          // 文章内容
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: SelectableText(
                articleContent,
                style: TextStyle(fontSize: 16, height: 1.6),
                onSelectionChanged: (selection, cause) {
                  if (selection.isValid && !selection.isCollapsed) {
                    selectedText = articleContent.substring(
                      selection.start,
                      selection.end,
                    );
                  }
                },
              ),
            ),
          ),
          
          // 底部悬浮评测按钮
          if (selectedText.isNotEmpty)
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '选中文本: ${selectedText.length > 30 ? selectedText.substring(0, 30) + "..." : selectedText}',
                      style: TextStyle(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      showPronunciationEvaluation(
                        context,
                        text: selectedText,
                      );
                    },
                    child: Text('开始评测'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
```

## 🎨 UI/UX 最佳实践

### 1. 评测按钮设计规范

```dart
// ✅ 推荐的评测按钮样式
ElevatedButton.icon(
  onPressed: onPressed,
  icon: Icon(Icons.mic, size: 20),
  label: Text('跟读评测'),
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.green,
    foregroundColor: Colors.white,
    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  ),
)

// ❌ 不推荐的样式
ElevatedButton(
  onPressed: onPressed,
  child: Text('测试'), // 太简单，用户不理解功能
)
```

### 2. 评测触发时机

#### ✅ **推荐的触发方式**
- **字幕点击**: 用户点击视频字幕时
- **文本选择**: 用户选择文章文本后
- **专用按钮**: 固定位置的"跟读评测"按钮
- **长按触发**: 长按单词/句子显示评测选项

#### ⚠️ **注意避免**
- 自动触发评测（可能会打扰用户）
- 覆盖默认文本操作（如复制、翻译）
- 在用户编辑文本时触发

### 3. 评测结果反馈

```dart
void _handleEvaluationComplete(EvaluationResult result) {
  // 1. 显示成绩弹窗
  _showScoreDialog(result);
  
  // 2. 播放音效反馈
  _playScoreSound(result.overallScore);
  
  // 3. 保存学习记录
  _saveLearningRecord(result);
  
  // 4. 显示改进建议
  if (result.overallScore < 80) {
    _showImprovementTips(result);
  }
}

void _showScoreDialog(EvaluationResult result) {
  final color = result.scoreColor;
  final emoji = result.overallScore >= 90 ? '🎉' : 
                result.overallScore >= 80 ? '👍' :
                result.overallScore >= 70 ? '💪' : '🔄';

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Text(emoji),
          SizedBox(width: 8),
          Text('评测完成！'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${result.overallScore.toInt()}%',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 8),
          Text(result.gradeLabel),
          SizedBox(height: 16),
          LinearProgressIndicator(
            value: result.overallScore / 100,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('再来一次'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: Text('确定'),
        ),
      ],
    ),
  );
}
```

## 🔧 高级集成技巧

### 1. 自定义评测配置

```dart
class CustomEvaluationConfig {
  final bool autoStartRecording;
  final bool showDetailedResults;
  final int maxRecordingDuration;
  final bool enableHints;
  
  const CustomEvaluationConfig({
    this.autoStartRecording = false,
    this.showDetailedResults = true,
    this.maxRecordingDuration = 30,
    this.enableHints = true,
  });
}

// 使用自定义配置
void showCustomEvaluation(
  BuildContext context, {
  required String text,
  required CustomEvaluationConfig config,
}) {
  showDialog(
    context: context,
    builder: (context) => PronunciationEvaluationModal(
      referenceText: text,
      mode: EvaluationModeDetector.detectMode(text),
      theme: Theme.of(context),
      dismissible: !config.autoStartRecording,
    ),
  );
}
```

### 2. 批量评测功能

```dart
class BatchEvaluationPage extends StatefulWidget {
  final List<String> sentences;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('批量评测'),
        actions: [
          IconButton(
            onPressed: _evaluateAll,
            icon: Icon(Icons.play_circle_outline),
            tooltip: '全部评测',
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: sentences.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(sentences[index]),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 单个评测按钮
                IconButton(
                  onPressed: () => _evaluateSingle(index),
                  icon: Icon(Icons.mic),
                ),
                // 评测结果指示器
                if (evalResults.containsKey(index))
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: evalResults[index]!.scoreColor,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _evaluateSingle(int index) {
    showPronunciationEvaluation(
      context,
      text: sentences[index],
      mode: EvaluationMode.sentence,
      onComplete: (result) {
        setState(() {
          evalResults[index] = result;
        });
      },
    );
  }

  void _evaluateAll() async {
    for (int i = 0; i < sentences.length; i++) {
      await Future.delayed(Duration(milliseconds: 500));
      await _evaluateSingleAsync(i);
    }
    _showBatchResults();
  }

  Future<void> _evaluateSingleAsync(int index) async {
    final service = EvaluationService();
    final result = await service.evaluateRecording(
      referenceText: sentences[index],
      mode: EvaluationMode.sentence,
    );
    
    if (mounted) {
      setState(() {
        evalResults[index] = result;
      });
    }
  }
}
```

### 3. 学习进度追踪

```dart
class LearningProgressTracker {
  static const String _storageKey = 'evaluation_progress';
  
  // 保存评测记录
  static Future<void> saveEvaluation(EvaluationResult result) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getEvaluationHistory();
    
    history.add(result);
    
    // 只保留最近100条记录
    if (history.length > 100) {
      history.removeRange(0, history.length - 100);
    }
    
    final jsonList = history.map((e) => jsonEncode(e.toMap())).toList();
    await prefs.setStringList(_storageKey, jsonList);
  }
  
  // 获取学习统计
  static Future<LearningStats> getStats() async {
    final history = await getEvaluationHistory();
    
    if (history.isEmpty) {
      return const LearningStats();
    }
    
    final totalEvaluations = history.length;
    final avgScore = history.map((e) => e.overallScore).reduce((a, b) => a + b) / totalEvaluations;
    
    // 计算最近7天的进步趋势
    final now = DateTime.now();
    final weekAgo = now.subtract(Duration(days: 7));
    final recentEvaluations = history.where((e) => e.createdAt.isAfter(weekAgo)).toList();
    
    double trend = 0.0;
    if (recentEvaluations.length >= 2) {
      final firstScore = recentEvaluations.first.overallScore;
      final lastScore = recentEvaluations.last.overallScore;
      trend = lastScore - firstScore;
    }
    
    return LearningStats(
      totalEvaluations: totalEvaluations,
      averageScore: avgScore,
      improvementTrend: trend,
      lastEvaluated: history.last.createdAt,
      masteredWordsCount: _countMasteredWords(history),
    );
  }
  
  static int _countMasteredWords(List<EvaluationResult> history) {
    final masteredWords = <String>{};
    
    for (final result in history) {
      for (final wordEval in result.wordEvaluations) {
        if (wordEval.score >= 90) {
          masteredWords.add(wordEval.word.toLowerCase());
        }
      }
    }
    
    return masteredWords.length;
  }
}

class LearningStats {
  final int totalEvaluations;
  final double averageScore;
  final double improvementTrend;
  final DateTime lastEvaluated;
  final int masteredWordsCount;
  
  const LearningStats({
    this.totalEvaluations = 0,
    this.averageScore = 0.0,
    this.improvementTrend = 0.0,
    DateTime? lastEvaluated,
    this.masteredWordsCount = 0,
  }) : lastEvaluated = lastEvaluated ?? DateTime.now();
  
  String get trendText {
    if (improvementTrend >= 5) return '显著进步';
    if (improvementTrend >= 2) return '稳定提升';
    if (improvementTrend >= -2) return '保持稳定';
    return '有待加强';
  }
  
  String get encouragementMessage {
    if (averageScore >= 85) return '发音很棒，继续保持！';
    if (averageScore >= 75) return '不错的进步，再接再厉！';
    if (averageScore >= 65) return '继续练习，会有更大提升！';
    return '多练习就会越来越好！';
  }
}
```

## 🎯 集成检查清单

### ✅ **必须完成的步骤**
- [ ] 在应用中添加`showPronunciationEvaluation`调用
- [ ] 处理评测完成回调
- [ ] 添加合适的UI触发按钮
- [ ] 测试四种评测模式

### 🎨 **用户体验优化**
- [ ] 添加评测结果弹窗
- [ ] 实现学习进度追踪
- [ ] 添加音效反馈
- [ ] 创建学习统计页面

### 📱 **平台适配**
- [ ] 测试iOS/Android适配
- [ ] 验证Pad设备UI
- [ ] 检查暗色模式适配
- [ ] 测试屏幕阅读器支持

### 🐞 **质量保证**
- [ ] 编写单元测试
- [ ] 进行集成测试
- [ ] 收集用户反馈
- [ ] 监控使用数据

## 🚨 常见问题和解决方案

### Q1: 评测弹窗显示异常
**问题**: 在部分设备上弹窗位置不正确
**解决方案**: 
```dart
showDialog(
  context: context,
  useSafeArea: true, // 添加安全区域支持
  builder: (context) => PronunciationEvaluationModal(...),
);
```

### Q2: 长时间评测卡顿
**问题**: 长文本评测时应用卡顿
**解决方案**: 
```dart
// 在后台线程执行评测
Future.microtask(() async {
  final result = await evaluationService.evaluateRecording(...);
  if (mounted) {
    setState(() {
      _currentResult = result;
    });
  }
});
```

### Q3: 内存占用过高
**问题**: 连续评测时内存增长
**解决方案**:
```dart
// 定期清理录音缓存
@override
void dispose() {
  evaluationService.reset();
  super.dispose();
}
```

## 📞 技术支持

### 获取帮助
- 🎯 **产品问题**: 查看[EVALUATION_IMPLEMENTATION.md]()
- 💻 **技术问题**: 查看源码注释
- 🐛 **Bug报告**: 联系开发团队

### 性能监控
- 监控评测平均响应时间
- 跟踪用户完成率
- 收集设备兼容性信息

---

**🎉 集成完成后，你的应用就拥有了专业的发音评测功能！**

**最后更新**: 2026年7月4日
**版本**: 1.0 (核心功能)
**支持**: 四种评测模式 + 智能模式检测 + 完整的错误处理