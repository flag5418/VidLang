import 'package:flutter/material.dart';
import '../views/evaluation_test_page.dart';
import 'package:vidlang/theme/theme.dart';

/// 评测功能演示组件 - 可直接在应用中使用
class EvaluationDemo extends StatelessWidget {
  const EvaluationDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('跟读评测演示'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(AppIcons.recordVoiceOver, size: 80, color: Colors.green),
            const SizedBox(height: 24),
            Text(
              'VidLang 跟读评测系统',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '多维度智能发音评测\n支持免费STT和付费精听模式',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // 开始测试按钮
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EvaluationTestPage(),
                  ),
                );
              },
              icon: const Icon(AppIcons.play),
              label: const Text('开始评测测试'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 功能特色
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    '功能特色',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildFeatureItem(AppIcons.micNone, '免费STT识别', '基础语音识别和对比'),
                  _buildFeatureItem(AppIcons.textFields, '单词精听', '音素级精准发音分析'),
                  _buildFeatureItem(
                    AppIcons.chatBubbleOutline,
                    '句子评测',
                    '流利度、准确度、完整度',
                  ),
                  _buildFeatureItem(AppIcons.article, '段落流畅度', '长文本连贯性分析'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade700,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 在播放器中集成评测功能的示例
class PlayerWithEvaluationDemo extends StatefulWidget {
  const PlayerWithEvaluationDemo({super.key});

  @override
  State<PlayerWithEvaluationDemo> createState() =>
      _PlayerWithEvaluationDemoState();
}

class _PlayerWithEvaluationDemoState extends State<PlayerWithEvaluationDemo> {
  // 模拟当前播放的字幕文本
  final String _currentSubtitle =
      'This is an example sentence for pronunciation practice.';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('视频播放器'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 模拟视频播放区域
          Container(
            height: 200,
            color: Colors.black,
            child: const Center(
              child: Text(
                '视频播放区域',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ),

          // 字幕显示区域
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  '当前字幕',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Text(
                  _currentSubtitle,
                  style: const TextStyle(fontSize: 16, height: 1.5),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const Spacer(),

          // 播放控制和评测按钮
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 播放控制
                IconButton(
                  onPressed: () {},
                  icon: const Icon(AppIcons.skipPrevious),
                  iconSize: 32,
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(AppIcons.play),
                  iconSize: 48,
                  color: Colors.blue,
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(AppIcons.skipNext),
                  iconSize: 32,
                ),

                // 评测功能按钮
                Container(
                  margin: const EdgeInsets.only(left: 20),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // 在实际应用中，这里应该调用:
                      // showPronunciationEvaluation(context, text: _currentSubtitle);

                      // 临时演示用测试页面
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EvaluationTestPage(),
                        ),
                      );
                    },
                    icon: const Icon(AppIcons.mic, size: 20),
                    label: const Text('跟读评测'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
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
}
