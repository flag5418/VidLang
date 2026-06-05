import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:vidlang/services/deepseek_api.dart';
import 'package:vidlang/services/ios_native_features.dart';

class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _wordController = TextEditingController(text: 'apple');
  final TextEditingController _sentenceController = TextEditingController(text: 'I eat an apple every day.');
  final TextEditingController _translateController = TextEditingController(text: 'Hello World');
  final TextEditingController _speakController = TextEditingController(text: 'Hello, how are you?');
  String _deepseekResult = '';
  String _nativeTranslateResult = '';
  String _ocrResult = '';
  String _imageAnalysisResult = '';
  final String _subtitleResult = '';
  bool _isLoading = false;
  bool _isPhase1Done = false;
  bool _isPhase2Done = false;
  bool _isPhase3Done = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _wordController.dispose();
    _sentenceController.dispose();
    _translateController.dispose();
    _speakController.dispose();
    super.dispose();
  }

  Future<void> _testDeepseek() async {
    setState(() {
      _isLoading = true;
      _deepseekResult = '';
      _isPhase1Done = false;
      _isPhase2Done = false;
      _isPhase3Done = false;
    });

    try {
      final api = DeepSeekApi(config: DeepSeekConfig(
        apiKey: 'sk-4ba1162a5227487f88e5e6c963f89ff9',
        model: 'deepseek-chat',
        baseUrl: 'https://api.deepseek.com/v1',
      ));

      final stream = api.translateWordStream(
        word: _wordController.text,
        sentence: _sentenceController.text.isNotEmpty ? _sentenceController.text : null,
      );

      await for (final phase in stream) {
        setState(() {
          _deepseekResult += '=== Phase ${phase['phase']} ===\n';
          _deepseekResult += const JsonEncoder.withIndent('  ').convert(phase['data']);
          _deepseekResult += '\n\n';
          
          if (phase['phase'] == 1) _isPhase1Done = true;
          if (phase['phase'] == 2) _isPhase2Done = true;
          if (phase['phase'] == 3) _isPhase3Done = true;
        });
      }
    } catch (e) {
      setState(() {
        _deepseekResult = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testNativeTranslate() async {
    setState(() {
      _isLoading = true;
      _nativeTranslateResult = '';
    });

    try {
      final result = await IosNativeFeatures.translate(
        text: _translateController.text,
        sourceLanguage: 'en',
        targetLanguage: 'zh-Hans',
      );

      setState(() {
        _nativeTranslateResult = const JsonEncoder.withIndent('  ').convert({
          'success': result.success,
          'sourceText': result.sourceText,
          'translatedText': result.translatedText,
          'sourceLanguage': result.sourceLanguage,
          'targetLanguage': result.targetLanguage,
          'error': result.error,
        });
      });
    } catch (e) {
      setState(() {
        _nativeTranslateResult = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testNativeSpeak() async {
    try {
      await IosNativeFeatures.speak(
        text: _speakController.text,
        language: 'en-US',
        rate: 0.5,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _testOcrFromCamera() async {
    setState(() {
      _isLoading = true;
      _ocrResult = '';
    });

    try {
      final hasPermission = await IosNativeFeatures.hasCameraPermission();
      if (!hasPermission) {
        await IosNativeFeatures.requestCameraPermission();
      }

      final result = await IosNativeFeatures.extractTextFromCamera();
      setState(() {
        _ocrResult = const JsonEncoder.withIndent('  ').convert({
          'success': result.success,
          'text': result.text,
          'lines': result.lines.map((l) => {
            'text': l.text,
            'confidence': l.confidence,
            'words': l.words.map((w) => {'text': w.text, 'confidence': w.confidence}).toList(),
          }).toList(),
          'error': result.error,
        });
      });
    } catch (e) {
      setState(() {
        _ocrResult = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testImageAnalysis() async {
    setState(() {
      _isLoading = true;
      _imageAnalysisResult = '';
    });

    try {
      final hasPermission = await IosNativeFeatures.hasCameraPermission();
      if (!hasPermission) {
        await IosNativeFeatures.requestCameraPermission();
      }

      final result = await IosNativeFeatures.analyzeImageFromCamera();
      setState(() {
        _imageAnalysisResult = const JsonEncoder.withIndent('  ').convert({
          'success': result.success,
          'description': result.description,
          'chineseDescription': result.chineseDescription,
          'labels': result.labels,
          'chineseLabels': result.chineseLabels,
          'error': result.error,
        });
      });
    } catch (e) {
      setState(() {
        _imageAnalysisResult = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildLoadingIndicator() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildDeepseekTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _wordController,
            decoration: const InputDecoration(
              labelText: '输入单词',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _sentenceController,
            decoration: const InputDecoration(
              labelText: '输入句子（可选）',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isLoading ? null : _testDeepseek,
            child: const Text('调用 DeepSeek API'),
          ),
          const SizedBox(height: 16),
          if (_isPhase1Done || _isPhase2Done || _isPhase3Done)
            Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: _isPhase1Done ? Colors.green : Colors.grey,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _isPhase1Done ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                ),
                const SizedBox(width: 8),
                const Text('Phase 1: 发音数据'),
                const SizedBox(width: 16),
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: _isPhase2Done ? Colors.green : Colors.grey,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _isPhase2Done ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                ),
                const SizedBox(width: 8),
                const Text('Phase 2: 释义内容'),
                const SizedBox(width: 16),
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: _isPhase3Done ? Colors.green : Colors.grey,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _isPhase3Done ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                ),
                const SizedBox(width: 8),
                const Text('Phase 3: 词联网络'),
              ],
            ),
          const SizedBox(height: 16),
          if (_deepseekResult.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: Text(_deepseekResult),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNativeTranslateTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _translateController,
            decoration: const InputDecoration(
              labelText: '输入要翻译的文本',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isLoading ? null : _testNativeTranslate,
            child: const Text('调用系统翻译'),
          ),
          const SizedBox(height: 16),
          if (_nativeTranslateResult.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: Text(_nativeTranslateResult),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNativeSpeakTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _speakController,
            decoration: const InputDecoration(
              labelText: '输入要朗读的文本',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _testNativeSpeak,
            child: const Text('开始朗读'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => IosNativeFeatures.stopSpeaking(),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('停止朗读'),
          ),
        ],
      ),
    );
  }

  Widget _buildOcrTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          ElevatedButton(
            onPressed: _isLoading ? null : _testOcrFromCamera,
            child: const Text('拍照提取文字'),
          ),
          const SizedBox(height: 16),
          if (_ocrResult.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: Text(_ocrResult),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageAnalysisTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          ElevatedButton(
            onPressed: _isLoading ? null : _testImageAnalysis,
            child: const Text('拍照分析图片'),
          ),
          const SizedBox(height: 16),
          if (_imageAnalysisResult.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: Text(_imageAnalysisResult),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('功能测试'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'DeepSeek'),
            Tab(text: '系统翻译'),
            Tab(text: '系统发音'),
            Tab(text: 'OCR识别'),
            Tab(text: '图片分析'),
          ],
          isScrollable: true,
        ),
      ),
      body: _isLoading ? _buildLoadingIndicator() : TabBarView(
        controller: _tabController,
        children: [
          _buildDeepseekTab(),
          _buildNativeTranslateTab(),
          _buildNativeSpeakTab(),
          _buildOcrTab(),
          _buildImageAnalysisTab(),
        ],
      ),
    );
  }
}
