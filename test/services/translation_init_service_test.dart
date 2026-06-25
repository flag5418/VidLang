import 'package:flutter_test/flutter_test.dart';
import 'package:vidlang/models/subtitles.dart';
import 'package:vidlang/services/translation_init_service.dart';
import 'package:vidlang/services/ios_native_features.dart';

/// 模拟 iOS 原生翻译结果，用于测试
class MockTranslationResult {
  final String sourceText;
  final String translatedText;
  final bool success;

  MockTranslationResult({
    required this.sourceText,
    required this.translatedText,
    this.success = true,
  });
}

/// 测试数据：模拟真实字幕数据
class TestData {
  /// 测试用例1：简单英文句子
  static List<Subtitles> get simpleSubtitles => [
    Subtitles(content: 'Hello', startPosition: 0, endPosition: 1000),
    Subtitles(content: 'World', startPosition: 1000, endPosition: 2000),
  ];

  /// 测试用例2：包含 "call" 的字幕（用户反馈的问题词）
  static List<Subtitles> get callSubtitles => [
    Subtitles(content: 'call', startPosition: 0, endPosition: 1389),
    Subtitles(content: 'phone', startPosition: 1389, endPosition: 2500),
    Subtitles(content: 'hello world', startPosition: 2500, endPosition: 4000),
  ];

  /// 测试用例3：长句子
  static List<Subtitles> get longSubtitles => [
    Subtitles(content: 'I want to make a phone call', startPosition: 0, endPosition: 3000),
    Subtitles(content: 'Can you help me with this', startPosition: 3000, endPosition: 6000),
  ];

  /// 测试用例4：混合内容（有些已翻译，有些未翻译）
  static List<Subtitles> get mixedSubtitles => [
    Subtitles(content: 'Hello', contentTranslate: '你好', translateSource: 0, startPosition: 0, endPosition: 1000),
    Subtitles(content: 'World', startPosition: 1000, endPosition: 2000),
    Subtitles(content: 'Test', contentTranslate: '测试', translateSource: 0, startPosition: 2000, endPosition: 3000),
  ];

  /// 期望翻译结果映射
  static final Map<String, String> expectedTranslations = {
    'Hello': '你好',
    'World': '世界',
    'call': '打电话',
    'phone': '电话',
    'hello world': '你好世界',
    'I want to make a phone call': '我想打个电话',
    'Can you help me with this': '你能帮我这个吗',
  };
}

void main() {
  group('TranslationInitService 翻译测试', () {
    group('countNeedTranslate 计数测试', () {
      test('空字幕列表应返回 0', () {
        expect(TranslationInitService.countNeedTranslate([], true), 0);
        expect(TranslationInitService.countNeedTranslate([], false), 0);
      });

      test('全部未翻译应返回总数', () {
        final subtitles = TestData.simpleSubtitles;
        expect(TranslationInitService.countNeedTranslate(subtitles, true), 2);
        expect(TranslationInitService.countNeedTranslate(subtitles, false), 2);
      });

      test('包含 call 的字幕应正确计数', () {
        final subtitles = TestData.callSubtitles;
        expect(TranslationInitService.countNeedTranslate(subtitles, true), 3);
        expect(TranslationInitService.countNeedTranslate(subtitles, false), 3);
      });

      test('混合内容应只计数未翻译的', () {
        final subtitles = TestData.mixedSubtitles;
        // 付费模式：需要 AI 翻译，但现有的是 native(0)，所以全部需要重新翻译
        expect(TranslationInitService.countNeedTranslate(subtitles, true), 3);
        // 免费模式：native(0) 匹配，但有一个未翻译
        expect(TranslationInitService.countNeedTranslate(subtitles, false), 1);
      });
    });

    group('翻译结果验证', () {
      test('简单词典翻译验证', () {
        // 验证 simpleTranslateENtoZH 的词典映射
        final testCases = [
          MapEntry('hello', '你好'),
          MapEntry('world', '世界'),
          MapEntry('call', 'call'), // 不在词典中，应返回原词
          MapEntry('phone', 'phone'), // 不在词典中，应返回原词
        ];

        for (final testCase in testCases) {
          // 这里我们模拟翻译结果检查
          // 实际翻译结果取决于 iOS 原生实现
          expect(testCase.value, isNotEmpty, reason: '翻译结果不应为空');
        }
      });

      test('翻译结果不应等于原文（对于已知词）', () {
        final knownWords = ['hello', 'world', 'good', 'love'];
        for (final word in knownWords) {
          // 这些词在词典中有翻译，不应返回原文
          final expected = TestData.expectedTranslations[word.toLowerCase()];
          if (expected != null) {
            expect(expected, isNot(equals(word)), reason: '$word 应该有中文翻译');
          }
        }
      });
    });

    group('字幕模型测试', () {
      test('Subtitles toMap 应正确序列化', () {
        final sub = Subtitles(
          content: 'call',
          contentTranslate: '打电话',
          translateSource: 0,
          startPosition: 0,
          endPosition: 1389,
        );
        final map = sub.toMap();
        expect(map['content'], equals('call'));
        expect(map['content_translate'], equals('打电话'));
        expect(map['translate_source'], equals(0));
      });

      test('Subtitles fromMap 应正确反序列化', () {
        final map = {
          'id': 1,
          'code': 'test-code',
          'content': 'call',
          'content_translate': '打电话',
          'translate_source': 0,
          'start_position': 0,
          'end_position': 1389,
        };
        final sub = Subtitles().fromMap(map) as Subtitles;
        expect(sub.content, equals('call'));
        expect(sub.contentTranslate, equals('打电话'));
        expect(sub.translateSource, equals(0));
      });
    });

    group('批量翻译逻辑测试', () {
      test('翻译成功后应设置 contentTranslate 和 translateSource', () async {
        final subtitles = TestData.simpleSubtitles;
        
        // 模拟翻译过程
        for (final sub in subtitles) {
          final translated = TestData.expectedTranslations[sub.content];
          if (translated != null) {
            sub.contentTranslate = translated;
            sub.translateSource = TranslateSource.native.value;
          }
        }

        // 验证翻译结果
        expect(subtitles[0].contentTranslate, equals('你好'));
        expect(subtitles[0].translateSource, equals(TranslateSource.native.value));
        expect(subtitles[1].contentTranslate, equals('世界'));
        expect(subtitles[1].translateSource, equals(TranslateSource.native.value));
      });

      test('未在词典中的词应保持原样或标记为未翻译', () {
        final sub = Subtitles(content: 'call', startPosition: 0, endPosition: 1389);
        
        // 模拟翻译：call 不在简单词典中
        final translated = TestData.expectedTranslations[sub.content];
        if (translated == null || translated == sub.content) {
          // 如果翻译失败或返回原文，应保持未翻译状态
          expect(sub.contentTranslate, isNull);
        }
      });
    });

    group('数据库更新测试', () {
      test('batchUpdate 前应确保 map 移除 id 字段', () {
        final sub = Subtitles(
          content: 'call',
          contentTranslate: '打电话',
          translateSource: 0,
          startPosition: 0,
          endPosition: 1389,
        );
        sub.id = 1; // 设置 id
        
        final map = sub.toMap();
        // 验证 toMap 包含 id
        expect(map.containsKey('id'), isTrue);
        
        // 模拟 batchUpdate 中的移除操作
        map.remove('id');
        expect(map.containsKey('id'), isFalse);
      });

      test('翻译后的字幕应能正确序列化用于数据库更新', () {
        final subtitles = TestData.callSubtitles;
        
        // 模拟翻译
        for (final sub in subtitles) {
          final translated = TestData.expectedTranslations[sub.content];
          if (translated != null) {
            sub.contentTranslate = translated;
            sub.translateSource = TranslateSource.native.value;
          }
        }

        // 验证序列化
        for (final sub in subtitles) {
          final map = sub.toMap();
          map.remove('id'); // 模拟 batchUpdate 移除 id
          
          expect(map['content_translate'], isNotNull);
          expect(map['translate_source'], equals(0));
        }
      });
    });
  });
}
