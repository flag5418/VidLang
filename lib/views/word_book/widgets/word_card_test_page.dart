import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/material.dart';
import 'package:vidlang/models/word_detail.dart';
import 'package:vidlang/providers/subscription_provider.dart';
import 'package:vidlang/services/ai/ai_service.dart';
import 'package:vidlang/services/ai/unified_translation_service.dart';
import 'package:vidlang/services/tts/local_tts_service.dart';
import 'package:vidlang/services/tts/unified_tts_service.dart';
import 'package:vidlang/views/word_book/widgets/word_detail_panel.dart';
import 'package:vidlang/views/word_book/providers/display_config_provider.dart';

/// WordCard 测试页面
/// 
/// 用于独立测试查词弹窗功能，隔离 Player 和其他组件的干扰
class WordCardTestPage extends StatefulWidget {
  const WordCardTestPage({super.key});

  @override
  State<WordCardTestPage> createState() => _WordCardTestPageState();
}

class _WordCardTestPageState extends State<WordCardTestPage> {
  final TextEditingController _wordController = TextEditingController(text: 'one');
  bool _isLoading = false;
  String? _resultText;
  String? _errorText;
  WordDetail? _detail;
  
  // 独立音频播放器
  final ap.AudioPlayer _audioPlayer = ap.AudioPlayer();
  bool _isSpeaking = false;

  @override
  void dispose() {
    _wordController.dispose();
    _stopSpeaking();
    _audioPlayer.dispose();
    super.dispose();
  }

  /// 测试翻译（纯逻辑，无 UI 干扰）
  Future<void> _testTranslation() async {
    final word = _wordController.text.trim();
    if (word.isEmpty) return;

    setState(() {
      _isLoading = true;
      _resultText = null;
      _errorText = null;
      _detail = null;
    });

    try {
      // 模拟 WordCard 的查询逻辑
      final isPremium = false; // 先测试免费模式
      final mode = isPremium ? SubscriptionMode.premium : SubscriptionMode.free;
      
      WordDetail detail;
      
      if (isPremium) {
        detail = await AiService.getDefinition(
          word: word,
          contextSentence: null,
          sourceType: 'test',
          sourceCode: '',
          billing: {'mode': 'premium'},
        );
      } else {
        detail = await UnifiedTranslationService.instance.translate(
          text: word,
          mode: mode,
          contextSentence: null,
          sourceType: 'test',
          sourceCode: '',
        );
      }

      if (!mounted) return;

      debugPrint('✅ [TestPage] 查询成功:');
      debugPrint('   - success: ${detail.success}');
      debugPrint('   - word: ${detail.word}');
      debugPrint('   - translation: ${detail.translation}');
      debugPrint('   - error: ${detail.error}');
      debugPrint('   - source: ${detail.source}');

      setState(() {
        _detail = detail;
        _isLoading = false;
        
        if (detail.success) {
          _resultText = '✅ 查询成功\n'
              'word: ${detail.word}\n'
              'translation: ${detail.translation ?? "空"}\n'
              'source: ${detail.source}';
        } else {
          _errorText = '❌ 查询失败: ${detail.error ?? "未知错误"}';
        }
      });
    } catch (e, stackTrace) {
      debugPrint('💥 [TestPage] 异常: $e');
      debugPrint(stackTrace.toString());
      
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorText = '💥 异常: $e';
      });
    }
  }

  /// 测试发音（使用独立播放器）
  Future<void> _testSpeak() async {
    final word = _wordController.text.trim();
    if (word.isEmpty || _isSpeaking) return;

    await _stopSpeaking();
    _isSpeaking = true;
    setState(() {});

    try {
      debugPrint('🔊 [TestPage] 开始发音: "$word"');
      
      final result = await UnifiedTtsService.instance.synthesize(
        text: word,
        mode: SubscriptionMode.free,
        onWord: null,
      );

      if (!mounted) return;

      if (result.success && result.audioPath.isNotEmpty && result.format != 'direct') {
        // 文件模式：用独立播放器播放
        await _audioPlayer.play(ap.DeviceFileSource(result.audioPath));
        await _audioPlayer.onPlayerComplete.first;
      } else if (result.success) {
        // 直接播放模式：等待估算时长
        final wordCount = word.trim().split(RegExp(r'\s+')).length;
        final estimatedMs = (wordCount * 400).clamp(500, 30000);
        debugPrint('🔊 [TestPage] 直接播放模式，等待 ${estimatedMs}ms');
        await Future.delayed(Duration(milliseconds: estimatedMs));
      } else {
        debugPrint('❌ [TestPage] TTS 合成失败: ${result.error}');
      }
    } catch (e) {
      debugPrint('💥 [TestPage] 发音异常: $e');
    } finally {
      _isSpeaking = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _stopSpeaking() async {
    try {
      await _audioPlayer.stop();
      await LocalTtsService.instance.stop();
    } catch (_) {}
    _isSpeaking = false;
  }

  /// 测试完整 WordCard 流程
  Future<void> _testFullFlow() async {
    // 1. 先停止之前的操作
    await _stopSpeaking();
    
    // 2. 查询翻译
    await _testTranslation();
    
    // 3. 如果成功，自动发音
    if (_detail != null && _detail!.success && mounted) {
      await Future.delayed(const Duration(milliseconds: 500));
      await _testSpeak();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WordCard 测试页面')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 输入区域
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('输入要查询的单词:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _wordController,
                      decoration: const InputDecoration(
                        hintText: '输入英文单词',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _testTranslation,
                          icon: const Icon(Icons.search),
                          label: const Text('测试翻译'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _isSpeaking ? null : _testSpeak,
                          icon: Icon(_isSpeaking ? Icons.stop : Icons.volume_up),
                          label: Text(_isSpeaking ? '停止' : '测试发音'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _testFullFlow,
                          icon: const Icon(Icons.play_circle_outline),
                          label: const Text('完整流程'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 结果显示
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_errorText != null)
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_errorText!, style: const TextStyle(color: Colors.red)),
                ),
              )
            else if (_resultText != null)
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_resultText!),
                ),
              )
            else if (_detail != null)
              // 使用真实的 WordDetailPanel 展示
              Card(
                child: WordDetailPanel(
                  data: _detail!,
                  config: const WordDetailDisplayConfig(sections: WordDetailSection.values),
                  onSpeak: () => _testSpeak(),
                  onClose: () {},
                  isSaved: false,
                  saving: false,
                  onSaveWord: null,
                  isSentenceMode: false,
                ),
              )
            else
              const Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text('点击按钮开始测试', style: TextStyle(color: Colors.grey)),
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // 说明文档
            const Text(
              '测试说明:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('• 测试翻译：只调用翻译 API，验证数据返回是否正常'),
            const Text('• 测试发音：使用独立 AudioPlayer，不影响全局 TtsService'),
            const Text('• 完整流程：翻译 + 自动发音，模拟真实 WordCard 行为'),
            const Text('• 观察日志中的 [TestPage] 标签，确认每步执行情况'),
          ],
        ),
      ),
    );
  }
}
