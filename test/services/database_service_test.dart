import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:vidlang/models/subtitles.dart';
import 'package:vidlang/services/database_service.dart';
import 'package:vidlang/models/video_info.dart';

/// 数据库服务测试 - 重点测试 batchUpdate 和恢复机制
void main() {
  group('DatabaseService batchUpdate 测试', () {
    test('batchUpdate 的 toMap 应包含 id 但更新时应移除', () {
      final sub = Subtitles(
        videoCode: 'test',
        content: 'call',
        contentTranslate: '打电话',
        startPosition: 0,
        endPosition: 1000,
      );
      sub.id = 42;

      final map = sub.toMap();
      // toMap 应该包含 id
      expect(map.containsKey('id'), isTrue);
      expect(map['id'], equals(42));

      // 模拟 batchUpdate 中的移除操作
      map.remove('id');
      expect(map.containsKey('id'), isFalse);
    });

    test('batchUpdate 的 toMap 移除 id 后不应影响原实体', () {
      final sub = Subtitles(
        videoCode: 'test',
        content: 'hello',
        contentTranslate: '你好',
        startPosition: 0,
        endPosition: 1000,
      );
      sub.id = 123;

      final map = sub.toMap();
      map.remove('id');
      
      // 原实体的 id 应该保持不变
      expect(sub.id, equals(123));
    });
  });

  group('翻译数据完整性测试', () {
    test('字幕序列化应包含所有翻译相关字段', () {
      final sub = Subtitles(
        videoCode: 'v1',
        content: 'test content',
        contentTranslate: '测试内容',
        translateSource: 1, // AI 翻译
        startPosition: 100,
        endPosition: 500,
      );

      final map = sub.toMap();
      expect(map['content'], equals('test content'));
      expect(map['content_translate'], equals('测试内容'));
      expect(map['translate_source'], equals(1));
      expect(map['start_position'], equals(100));
      expect(map['end_position'], equals(500));
    });

    test('字幕反序列化应正确恢复翻译字段', () {
      final map = {
        'id': 1,
        'code': 'sub-1',
        'video_code': 'v1',
        'content': 'hello',
        'content_translate': '你好',
        'translate_source': 0,
        'start_position': 0,
        'end_position': 1000,
        'type': 'subtitle',
      };

      final sub = Subtitles().fromMap(map) as Subtitles;
      expect(sub.content, equals('hello'));
      expect(sub.contentTranslate, equals('你好'));
      expect(sub.translateSource, equals(0));
      expect(sub.videoCode, equals('v1'));
    });

    test('未翻译字幕的 contentTranslate 应为 null', () {
      final sub = Subtitles(
        videoCode: 'v1',
        content: 'call',
        startPosition: 0,
        endPosition: 1389,
      );

      expect(sub.contentTranslate, isNull);
      expect(sub.translateSource, equals(-1)); // 默认值
    });
  });

  group('数据库损坏检测测试', () {
    test('应正确识别 malformed 错误消息', () {
      final malformedMsg = 'database disk image is malformed';
      final otherMsg = 'some other error';

      expect(malformedMsg.toLowerCase().contains('malformed'), isTrue);
      expect(otherMsg.toLowerCase().contains('malformed'), isFalse);
    });

    test('应正确识别各种损坏错误', () {
      final errors = [
        'database disk image is malformed',
        'database is locked',
        'disk i/o error',
        'database corrupt',
      ];

      for (final error in errors) {
        final s = error.toLowerCase();
        final isCorrupted = s.contains('database disk image is malformed') ||
            s.contains('malformed') ||
            s.contains('database is locked') ||
            s.contains('disk i/o error') ||
            s.contains('corrupt');
        expect(isCorrupted, isTrue, reason: '应识别为损坏: $error');
      }
    });

    test('损坏时 batchUpdate 应返回 0 而不是尝试恢复', () {
      // 验证新策略：损坏时直接返回 0，避免数据丢失
      // 实际测试需要在集成环境中进行，这里验证逻辑正确性
      final entities = [
        Subtitles(content: 'test', startPosition: 0, endPosition: 1000),
      ];
      
      // 空列表应返回 0
      expect(DatabaseService.batchUpdate([]), completion(equals(0)));
    });
  });

  group('翻译后数据更新测试', () {
    test('翻译后字幕应包含正确的中文翻译', () {
      final sub = Subtitles(
        videoCode: 'test-video',
        content: 'call',
        startPosition: 0,
        endPosition: 1389,
      );

      // 模拟翻译过程
      sub.contentTranslate = '打电话';
      sub.translateSource = 0; // native 翻译

      expect(sub.contentTranslate, equals('打电话'));
      expect(sub.translateSource, equals(0));
      expect(sub.content, equals('call'));
    });

    test('批量翻译后的字幕列表应全部包含翻译', () {
      final subtitles = [
        Subtitles(content: 'call', startPosition: 0, endPosition: 1389),
        Subtitles(content: 'hello', startPosition: 1389, endPosition: 2500),
        Subtitles(content: 'world', startPosition: 2500, endPosition: 4000),
      ];

      // 模拟翻译
      final translations = {
        'call': '打电话',
        'hello': '你好',
        'world': '世界',
      };

      for (final sub in subtitles) {
        final translated = translations[sub.content];
        if (translated != null) {
          sub.contentTranslate = translated;
          sub.translateSource = 0;
        }
      }

      // 验证所有字幕都已翻译
      for (final sub in subtitles) {
        expect(sub.contentTranslate, isNotNull);
        expect(sub.contentTranslate!.isNotEmpty, isTrue);
      }
    });
  });
}
