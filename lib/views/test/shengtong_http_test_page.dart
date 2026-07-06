import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'package:vidlang/services/shengtong_http_evaluator.dart';
import 'package:vidlang/theme/theme.dart';

/// 声通 HTTP 评测测试页面
class ShengtongHttpTestPage extends StatefulWidget {
  const ShengtongHttpTestPage({super.key});

  @override
  State<ShengtongHttpTestPage> createState() => _ShengtongHttpTestPageState();
}

class _ShengtongHttpTestPageState extends State<ShengtongHttpTestPage> {
  // 测试密钥
  static const String _testAppKey = '17827042090007b7';
  static const String _testSecretKey = '074713c03b62c75d1bee970dab2706ea';

  final TextEditingController _refTextController =
      TextEditingController(text: 'Hello world');
  final TextEditingController _coreTypeController =
      TextEditingController(text: 'sent.eval');

  String _log = '';
  bool _isLoading = false;
  String? _result;

  void _addLog(String msg) {
    final line = '[$_now] $msg';
    debugPrint('🧪 [HTTP-Test] $msg');
    setState(() {
      _log += '$line\n';
    });
  }

  String get _now {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
  }

  Future<void> _testEvaluate() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _log = '';
      _result = null;
    });

    try {
      _addLog('🚀 开始 HTTP 评测测试');
      _addLog('   AppKey: $_testAppKey');
      _addLog('   SecretKey: ${_testSecretKey.substring(0, 8)}...');

      final evaluator = ShengtongHttpEvaluator(
        appKey: _testAppKey,
        secretKey: _testSecretKey,
      );

      // 创建一个简单的测试音频文件（静音 WAV）
      _addLog('📝 准备测试音频...');
      final tempDir = await getTemporaryDirectory();
      final audioPath = '${tempDir.path}/test_audio.wav';
      await _createTestWav(audioPath);
      _addLog('✅ 测试音频已创建: $audioPath');

      _addLog('📝 发送评测请求...');
      _addLog('   coreType: ${_coreTypeController.text}');
      _addLog('   refText: ${_refTextController.text}');

      final result = await evaluator.evaluate(
        coreType: _coreTypeController.text.trim(),
        refText: _refTextController.text.trim(),
        audioPath: audioPath,
        userId: 'test_user_${DateTime.now().millisecondsSinceEpoch}',
      );

      _addLog('✅ 评测成功!');
      _result = const JsonEncoder.withIndent('  ').convert(result);
      _addLog('📊 结果:\n$_result');
    } catch (e, stackTrace) {
      _addLog('❌ 评测失败: $e');
      _addLog('📋 堆栈:\n$stackTrace');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 创建一个简单的测试 WAV 文件（1秒静音）
  Future<void> _createTestWav(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }

    // WAV 文件头 + 1秒静音数据 (16000Hz, 16bit, 单声道)
    final header = _createWavHeader(16000, 1, 2, 16000 * 2);
    final data = Uint8List(16000 * 2); // 1秒静音
    final wavData = BytesBuilder();
    wavData.add(header);
    wavData.add(data);

    await file.writeAsBytes(wavData.toBytes());
  }

  /// 创建 WAV 文件头
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

    // RIFF chunk
    header.add(utf8.encode('RIFF'));
    header.add(_intToBytes(totalSize, 4));
    header.add(utf8.encode('WAVE'));

    // fmt sub-chunk
    header.add(utf8.encode('fmt '));
    header.add(_intToBytes(16, 4)); // Subchunk1Size
    header.add(_intToBytes(1, 2)); // AudioFormat (PCM)
    header.add(_intToBytes(channels, 2));
    header.add(_intToBytes(sampleRate, 4));
    header.add(_intToBytes(byteRate, 4));
    header.add(_intToBytes(blockAlign, 2));
    header.add(_intToBytes(bitsPerSample, 2));

    // data sub-chunk
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

  @override
  void dispose() {
    _refTextController.dispose();
    _coreTypeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('声通 HTTP 评测测试'),
        backgroundColor: AppColors.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 配置输入
            TextField(
              controller: _coreTypeController,
              decoration: const InputDecoration(
                labelText: 'coreType',
                border: OutlineInputBorder(),
                hintText: '如: sent.eval, word.eval',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _refTextController,
              decoration: const InputDecoration(
                labelText: '参考文本 (refText)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // 测试按钮
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testEvaluate,
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(_isLoading ? '评测中...' : '发送 HTTP 评测请求'),
            ),
            const SizedBox(height: 16),

            // 日志显示
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.lightBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderLight!),
              ),
              child: SelectableText(
                _log.isEmpty ? '日志将显示在这里...' : _log,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
