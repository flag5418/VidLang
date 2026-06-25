import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:liquid_ai/liquid_ai.dart';
import 'package:vidlang/services/local_model_service.dart';

/// 本地 LLM 推理服务
/// 使用 liquid_ai 包运行本地大语言模型
class LocalLlmService {
  static LocalLlmService? _instance;
  static LocalLlmService get instance => _instance ??= LocalLlmService._();
  LocalLlmService._();

  LiquidAi? _liquidAi;
  ModelRunner? _runner;
  bool _isInitialized = false;
  bool _isLoading = false;
  
  // 模型路径
  String? _modelPath;
  
  /// 是否已初始化
  bool get isInitialized => _isInitialized;
  
  /// 是否正在加载模型
  bool get isLoading => _isLoading;

  /// 初始化 LLM 引擎
  Future<void> initialize() async {
    if (_isInitialized || _isLoading) return;
    
    _isLoading = true;
    
    try {
      // 获取模型路径
      _modelPath = await LocalModelService.instance.getLlmModelPath();
      
      if (_modelPath == null || !await File(_modelPath!).exists()) {
        debugPrint('LLM 模型文件不存在');
        _isLoading = false;
        return;
      }
      
      // 初始化 LEAP SDK
      _liquidAi = LiquidAi();
      
      // 加载模型
      await for (final event in _liquidAi!.loadModelFromPath(_modelPath!)) {
        if (event is LoadCompleteEvent) {
          _runner = event.runner;
          break;
        }
      }
      
      _isInitialized = true;
      debugPrint('LLM 引擎初始化成功');
    } catch (e) {
      debugPrint('LLM 引擎初始化失败: $e');
      _isInitialized = false;
    } finally {
      _isLoading = false;
    }
  }

  /// 生成文本
  Future<String> generate({
    required String prompt,
    String systemPrompt = '',
    int maxTokens = 512,
    double temperature = 0.7,
    double topP = 0.9,
  }) async {
    if (!_isInitialized || _runner == null) {
      await initialize();
      if (!_isInitialized) {
        return '模型未初始化，请先下载模型';
      }
    }
    
    try {
      // 创建对话
      final conversation = await _runner!.createConversation(
        systemPrompt: systemPrompt.isNotEmpty ? systemPrompt : '你是一个专业的翻译助手。',
      );
      
      // 生成响应
      final response = await conversation.generateText(prompt);
      
      // 释放对话资源
      await conversation.dispose();
      
      return response;
    } catch (e) {
      debugPrint('LLM 生成失败: $e');
      return '生成失败: $e';
    }
  }

  /// 翻译文本
  Future<String> translate({
    required String text,
    String sourceLanguage = 'English',
    String targetLanguage = 'Chinese',
  }) async {
    final prompt = '''请将以下$sourceLanguage文本翻译为$targetLanguage：

$text

翻译结果：''';
    
    return generate(
      prompt: prompt,
      systemPrompt: '你是一个专业的翻译助手。请只输出翻译结果，不要添加任何解释。',
      maxTokens: 1024,
    );
  }

  /// 生成单词释义
  Future<String> getDefinition({
    required String word,
    String? contextSentence,
  }) async {
    final prompt = contextSentence != null
        ? '''请为以下单词提供释义：

单词：$word
语境句子：$contextSentence

请提供：
1. 音标
2. 中文释义
3. 词性
4. 例句'''
        : '''请为以下单词提供释义：

单词：$word

请提供：
1. 音标
2. 中文释义
3. 词性
4. 例句''';
    
    return generate(
      prompt: prompt,
      systemPrompt: '你是一个英语词典助手。请提供准确、简洁的单词释义。',
      maxTokens: 512,
    );
  }

  /// 生成测验题目
  Future<String> generateQuiz({
    required List<String> words,
    int questionCount = 5,
  }) async {
    final wordList = words.join('、');
    final prompt = '''请根据以下单词生成$questionCount道选择题：

单词列表：$wordList

请生成：
1. 每道题4个选项（A、B、C、D）
2. 一个正确答案
3. 简短解析

格式要求：
题目1: ...
A. ...
B. ...
C. ...
D. ...
答案：...
解析：...''';
    
    return generate(
      prompt: prompt,
      systemPrompt: '你是一个英语出题老师。请生成高质量的选择题。',
      maxTokens: 2048,
    );
  }

  /// 对话模式
  Future<String> chat({
    required String message,
    List<Map<String, String>>? history,
  }) async {
    final systemPrompt = '''你是一个友好的英语学习助手。你可以：
1. 用英语和中文与用户对话
2. 帮助用户练习英语口语
3. 解答英语学习问题
4. 纠正用户的语法错误

请用简洁、友好的方式回复。''';
    
    return generate(
      prompt: message,
      systemPrompt: systemPrompt,
      maxTokens: 512,
    );
  }

  /// 释放资源
  void dispose() {
    _runner?.dispose();
    _runner = null;
    _liquidAi = null;
    _isInitialized = false;
  }
}
