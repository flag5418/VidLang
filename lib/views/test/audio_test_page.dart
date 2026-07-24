import 'dart:async';
import 'package:vidlang/components/ui/ui_components.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'package:vidlang/services/tts/dashscope_tts_service.dart';
import 'package:vidlang/services/evaluation/shengtong_evaluator.dart';
// import 'package:vidlang/services/evaluation/shengtong_http_evaluator.dart'; // 已移除
import 'package:vidlang/theme/theme.dart';

/// DashScope TTS + 声通评测 联合测试页面
///
/// 使用说明：
/// 1. 确保已登录（AppKeysService 已加载密钥）
/// 2. 输入测试文本，点击"测试 TTS"进行流式合成
/// 3. 点击"测试声通"进行语音评测连接测试
class AudioTestPage extends StatefulWidget {
  const AudioTestPage({super.key});

  @override
  State<AudioTestPage> createState() => _AudioTestPageState();
}

class _AudioTestPageState extends State<AudioTestPage> {
  // ─── TTS 测试状态 ─────────────────────────
  final TextEditingController _ttsTextController = TextEditingController(
    text: 'Hello, this is a test of the DashScope TTS service.',
  );
  String _ttsVoice = 'Cherry';
  String _ttsFormat = 'mp3';
  bool _isTtsSynthesizing = false;
  String _ttsLog = '';
  final List<String> _ttsLogs = [];
  AudioPlayer? _audioPlayer;

  // ─── 声通测试状态 ─────────────────────────
  final TextEditingController _shengtongRefTextController =
      TextEditingController(text: 'Hello world');
  bool _isShengtongConnecting = false;
  bool _isShengtongHttpTesting = false;
  String _shengtongLog = '';
  final List<String> _shengtongLogs = [];
  ShengtongEvaluator? _shengtongEvaluator;

  // ─── 测试密钥（声通）───────────────────────
  /// ⚠️ 测试用密钥，仅用于调试
  static const String _testAppKey = '17827042090007b7';
  static const String _testSecretKey = '074713c03b62c75d1bee970dab2706ea';

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
  }

  @override
  void dispose() {
    _ttsTextController.dispose();
    _shengtongRefTextController.dispose();
    _audioPlayer?.dispose();
    _shengtongEvaluator?.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════
  // TTS 测试
  // ════════════════════════════════════════════

  void _addTtsLog(String msg) {
    final line = '[${DateTime.now().toString().substring(11, 19)}] $msg';
    debugPrint('🧪 [TTS-Test] $msg');
    setState(() {
      _ttsLogs.add(line);
      _ttsLog = _ttsLogs.join('\n');
    });
  }

  Future<void> _testTtsStream() async {
    if (_isTtsSynthesizing) return;

    setState(() => _isTtsSynthesizing = true);
    _ttsLogs.clear();

    final text = _ttsTextController.text.trim();
    if (text.isEmpty) {
      _addTtsLog('❌ 请输入测试文本');
      setState(() => _isTtsSynthesizing = false);
      return;
    }

    _addTtsLog('🚀 开始流式 TTS 测试（PCM 实时播放）');
    _addTtsLog('   文本: "$text"');
    _addTtsLog('   音色: $_ttsVoice');

    final sw = Stopwatch()..start();

    try {
      await DashScopeTtsService.instance.streamSynthesizeAndPlay(
        text: text,
        voice: _ttsVoice,
        onComplete: () {
          sw.stop();
          _addTtsLog('✅ 流式播放完成! 总耗时: ${sw.elapsedMilliseconds}ms');
          setState(() => _isTtsSynthesizing = false);
        },
        onError: (error) {
          _addTtsLog('❌ 播放错误: $error');
          setState(() => _isTtsSynthesizing = false);
        },
      );

      _addTtsLog('🎵 PCM 流式播放已启动');
    } catch (e, stack) {
      _addTtsLog('❌ 异常: $e');
      debugPrint('TTS 测试异常: $e\n$stack');
      setState(() => _isTtsSynthesizing = false);
    }
  }

  Future<void> _testTtsFile() async {
    if (_isTtsSynthesizing) return;

    setState(() => _isTtsSynthesizing = true);
    _ttsLogs.clear();

    final text = _ttsTextController.text.trim();
    if (text.isEmpty) {
      _addTtsLog('❌ 请输入测试文本');
      setState(() => _isTtsSynthesizing = false);
      return;
    }

    _addTtsLog('🚀 开始文件式 TTS 测试');

    try {
      final tempDir = await getTemporaryDirectory();
      final ext = _ttsFormat == 'pcm' ? 'wav' : _ttsFormat;
      final filePath =
          '${tempDir.path}/tts_file_test_${DateTime.now().millisecondsSinceEpoch}.$ext';

      final result = await DashScopeTtsService.instance.synthesize(
        text: text,
        outputPath: filePath,
        voice: _ttsVoice,
        format: _ttsFormat,
      );

      if (result != null) {
        _addTtsLog('✅ 合成成功: $result');
        final file = File(result);
        final size = await file.length();
        _addTtsLog('📦 文件大小: ${_formatBytes(size)}');

        // 播放
        await _audioPlayer?.stop();
        await _audioPlayer?.play(DeviceFileSource(result));
        _addTtsLog('▶️ 播放中...');
      } else {
        _addTtsLog('❌ 合成失败，返回 null');
      }
    } catch (e) {
      _addTtsLog('💥 异常: $e');
    } finally {
      setState(() => _isTtsSynthesizing = false);
    }
  }

  // ════════════════════════════════════════════
  // 声通测试
  // ════════════════════════════════════════════

  void _addShengtongLog(String msg) {
    final line = '[${DateTime.now().toString().substring(11, 19)}] $msg';
    debugPrint('🧪 [Shengtong-Test] $msg');
    setState(() {
      _shengtongLogs.add(line);
      _shengtongLog = _shengtongLogs.join('\n');
    });
  }

  Future<void> _testShengtongConnect({bool useWss = false}) async {
    if (_isShengtongConnecting) return;

    setState(() => _isShengtongConnecting = true);
    _shengtongLogs.clear();

    final protocol = useWss ? 'wss' : 'ws';
    final port = useWss ? '8443' : '8080';
    final baseUrl = '$protocol://api.stkouyu.com:$port';

    _addShengtongLog('🚀 开始声通连接测试');
    _addShengtongLog('   协议: $protocol');
    _addShengtongLog('   BaseUrl: $baseUrl');
    _addShengtongLog('   AppKey: $_testAppKey');
    _addShengtongLog('   SecretKey: ${_testSecretKey.substring(0, 8)}...');

    try {
      _shengtongEvaluator?.dispose();
      _shengtongEvaluator = ShengtongEvaluator(
        appKey: _testAppKey,
        secretKey: _testSecretKey,
        baseUrl: baseUrl,
        useSSL: useWss,
      );

      final connectCompleter = Completer<bool>();

      _shengtongEvaluator!.onConnectionStateChanged = (isConnected) {
        _addShengtongLog('📡 连接状态变化: $isConnected');
        if (isConnected && !connectCompleter.isCompleted) {
          connectCompleter.complete(true);
        }
      };

      _shengtongEvaluator!.onError = (error) {
        _addShengtongLog('❌ 错误: $error');
        if (!connectCompleter.isCompleted) {
          connectCompleter.complete(false);
        }
      };

      _shengtongEvaluator!.onResult = (result) {
        _addShengtongLog('📊 评测结果: $result');
      };

      final coreType = 'sent.eval';
      _addShengtongLog('🔗 准备评测: coreType=$coreType');

      // 直接调用 start，内部会自动连接
      final refText = _shengtongRefTextController.text.trim();
      final userId = 'test_user_${DateTime.now().millisecondsSinceEpoch}';
      _addShengtongLog('📝 发送 start 命令: refText="$refText"');

      final request = jsonEncode({
        'audio': {'audioType': 'wav', 'sampleRate': 16000},
        'params': {'userId': userId, 'coreType': coreType, 'refText': refText},
      });

      final started = await _shengtongEvaluator!.start(request);
      _addShengtongLog('📤 start 命令已发送, 结果: $started');

      if (!started) {
        _addShengtongLog('❌ start 命令发送失败');
        setState(() => _isShengtongConnecting = false);
        return;
      }

      // 等待连接确认（最多 10 秒）
      _addShengtongLog('⏳ 等待服务端响应...');
      final connected = await connectCompleter.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          _addShengtongLog('⏰ 等待连接响应超时');
          return false;
        },
      );

      if (connected) {
        _addShengtongLog('✅ 连接成功!');
      } else {
        _addShengtongLog('❌ 连接未建立');
      }
    } catch (e) {
      _addShengtongLog('💥 异常: $e');
    } finally {
      setState(() => _isShengtongConnecting = false);
    }
  }

  Future<void> _testShengtongSig() async {
    _shengtongLogs.clear();
    _addShengtongLog('🔐 声通 sig 算法验证');
    _addShengtongLog('   AppKey: $_testAppKey');
    _addShengtongLog('   SecretKey: ${_testSecretKey.substring(0, 8)}...');

    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    _addShengtongLog('   时间戳: $timestamp (${timestamp.length}位, 毫秒级)');

    // 模拟 connect sig 计算
    final connectRaw = '$_testAppKey$timestamp$_testSecretKey';
    _addShengtongLog('   connect raw: $connectRaw');

    // 注意：这里只是显示 raw，实际 sig 由 ShengtongEvaluator 内部计算
    _addShengtongLog('   ✅ 请查看上方日志中的实际 sig 值');
    _addShengtongLog('   💡 如果服务端返回 "invalid sig"，请检查:');
    _addShengtongLog('      1. AppKey 是否正确');
    _addShengtongLog('      2. SecretKey 是否正确');
    _addShengtongLog('      3. 时间戳是否为毫秒级（13位）');
    _addShengtongLog('      4. sig 算法: SHA1(appKey + timestamp + secretKey)');
  }

  Future<void> _testShengtongHttp() async {
    if (_isShengtongHttpTesting) return;

    setState(() => _isShengtongHttpTesting = true);
    _shengtongLogs.clear();

    _addShengtongLog('🚀 开始声通 HTTP 评测测试');
    _addShengtongLog('   AppKey: $_testAppKey');
    _addShengtongLog('   SecretKey: ${_testSecretKey.substring(0, 8)}...');

    // HTTP 评测器已移除，此测试代码暂时禁用
    _addShengtongLog('⚠️ HTTP 评测器已移除，测试暂停');
    setState(() => _isShengtongHttpTesting = false);
    return;
  }

  /// 创建测试 WAV 文件
  Future<void> _createTestWav(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }

    final header = _createWavHeader(16000, 1, 2, 16000 * 2);
    final data = Uint8List(16000 * 2);
    final wavData = BytesBuilder();
    wavData.add(header);
    wavData.add(data);

    await file.writeAsBytes(wavData.toBytes());
  }

  Uint8List _createWavHeader(
    int sampleRate,
    int channels,
    int bitsPerSample,
    int dataSize,
  ) {
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;
    final totalSize = dataSize + 36;

    final header = BytesBuilder();
    header.add(utf8.encode('RIFF'));
    header.add(_intToBytes(totalSize, 4));
    header.add(utf8.encode('WAVE'));
    header.add(utf8.encode('fmt '));
    header.add(_intToBytes(16, 4));
    header.add(_intToBytes(1, 2));
    header.add(_intToBytes(channels, 2));
    header.add(_intToBytes(sampleRate, 4));
    header.add(_intToBytes(byteRate, 4));
    header.add(_intToBytes(blockAlign, 2));
    header.add(_intToBytes(bitsPerSample, 2));
    header.add(utf8.encode('data'));
    header.add(_intToBytes(dataSize, 4));

    return Uint8List.fromList(header.toBytes());
  }

  Uint8List _intToBytes(int value, int length) {
    final result = Uint8List(length);
    for (var i = 0; i < length; i++) {
      result[i] = (value >> (i * 8)) & 0xFF;
    }
    return result;
  }

  // ════════════════════════════════════════════
  // UI
  // ════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
appBar: AppNavBar(
  title: '音频服务测试',
  backgroundColor: AppColors.primary,
),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(adaptive.Adaptive.w(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── DashScope TTS 测试 ────────────
            _buildSectionTitle('🔊 DashScope TTS 测试'),
            SizedBox(height: adaptive.Adaptive.h(8)),
            TextField(
              controller: _ttsTextController,
              decoration: const InputDecoration(
                labelText: '测试文本',
                border: OutlineInputBorder(),
                hintText: '输入要合成的文本',
              ),
              maxLines: 2,
            ),
            SizedBox(height: adaptive.Adaptive.h(12)),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _ttsVoice,
                    decoration: const InputDecoration(
                      labelText: '音色',
                      border: OutlineInputBorder(),
                    ),
                    items: DashScopeTtsService.englishVoices.keys
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (v) => setState(() => _ttsVoice = v!),
                  ),
                ),
                SizedBox(width: adaptive.Adaptive.w(12)),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _ttsFormat,
                    decoration: const InputDecoration(
                      labelText: '格式',
                      border: OutlineInputBorder(),
                    ),
                    items: ['mp3', 'pcm', 'wav']
                        .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                        .toList(),
                    onChanged: (v) => setState(() => _ttsFormat = v!),
                  ),
                ),
              ],
            ),
            SizedBox(height: adaptive.Adaptive.h(12)),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isTtsSynthesizing ? null : _testTtsStream,
                    icon: _isTtsSynthesizing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(AppIcons.play),
                    label: Text(_isTtsSynthesizing ? '合成中...' : '流式合成'),
                  ),
                ),
                SizedBox(width: adaptive.Adaptive.w(12)),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isTtsSynthesizing ? null : _testTtsFile,
                    icon: const Icon(AppIcons.save),
                    label: const Text('文件合成'),
                  ),
                ),
              ],
            ),
            SizedBox(height: adaptive.Adaptive.h(8)),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(adaptive.Adaptive.w(12)),
              decoration: BoxDecoration(
                color: AppColors.lightBackground,
                borderRadius: BorderRadius.circular(adaptive.Adaptive.r(8)),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: SelectableText(
                _ttsLog.isEmpty ? 'TTS 日志将显示在这里...' : _ttsLog,
                style: TextStyle(fontFamily: 'monospace', fontSize: adaptive.Adaptive.sp(12)),
              ),
            ),

            const Divider(height: 32),

            // ─── 声通评测测试 ──────────────────
            _buildSectionTitle('🎤 声通语音评测测试'),
            SizedBox(height: adaptive.Adaptive.h(8)),
            TextField(
              controller: _shengtongRefTextController,
              decoration: const InputDecoration(
                labelText: '参考文本',
                border: OutlineInputBorder(),
                hintText: '输入要评测的参考文本',
              ),
            ),
            SizedBox(height: adaptive.Adaptive.h(12)),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isShengtongConnecting
                        ? null
                        : () => _testShengtongConnect(useWss: false),
                    icon: _isShengtongConnecting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(AppIcons.mic),
                    label: Text(_isShengtongConnecting ? '连接中...' : '测试 WS'),
                  ),
                ),
                SizedBox(width: adaptive.Adaptive.w(12)),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isShengtongConnecting
                        ? null
                        : () => _testShengtongConnect(useWss: true),
                    icon: const Icon(AppIcons.lock),
                    label: const Text('测试 WSS'),
                  ),
                ),
              ],
            ),
            SizedBox(height: adaptive.Adaptive.h(8)),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isShengtongHttpTesting ? null : _testShengtongHttp,
                icon: _isShengtongHttpTesting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(AppIcons.http),
                label: Text(
                  _isShengtongHttpTesting ? 'HTTP 评测中...' : '测试 HTTP 评测',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: AppColors.surface,
                ),
              ),
            ),
            SizedBox(height: adaptive.Adaptive.h(8)),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _testShengtongSig,
                icon: const Icon(AppIcons.security),
                label: const Text('验证 sig 算法'),
              ),
            ),
            SizedBox(height: adaptive.Adaptive.h(8)),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(adaptive.Adaptive.w(12)),
              decoration: BoxDecoration(
                color: AppColors.lightBackground,
                borderRadius: BorderRadius.circular(adaptive.Adaptive.r(8)),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: SelectableText(
                _shengtongLog.isEmpty ? '声通日志将显示在这里...' : _shengtongLog,
                style: TextStyle(fontFamily: 'monospace', fontSize: adaptive.Adaptive.sp(12)),
              ),
            ),

            const Divider(height: 32),

            // ─── 使用说明 ──────────────────────
            _buildSectionTitle('📖 使用说明'),
            SizedBox(height: adaptive.Adaptive.h(8)),
            _buildInfoCard(
              'DashScope TTS',
              '• 使用 HTTP SSE 流式合成\n'
                  '• 模型: qwen3-tts-flash (标准模型)\n'
                  '• 支持流式播放和文件保存\n'
                  '• 需要配置 qwen_api_key',
            ),
            SizedBox(height: adaptive.Adaptive.h(8)),
            _buildInfoCard(
              '声通评测',
              '• 使用测试密钥连接\n'
                  '• 支持 sent.eval (句子评测)\n'
                  '• 验证 sig 算法是否正确\n'
                  '• 生产环境请使用 AppKeysService 加载密钥',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(fontSize: adaptive.Adaptive.sp(18), fontWeight: FontWeight.bold),
    );
  }

  Widget _buildInfoCard(String title, String content) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(adaptive.Adaptive.w(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: adaptive.Adaptive.h(4)),
            Text(content, style: TextStyle(fontSize: adaptive.Adaptive.sp(13))),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
