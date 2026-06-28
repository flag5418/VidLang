import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vidlang/models/base_entity.dart';
import 'package:vidlang/models/subtitles.dart';
import 'package:vidlang/models/article_sentence.dart';

/// 翻译持久化测试
/// 验证 updateTranslationsByCode 的 SQL 逻辑能正确写入数据库
/// 验证第二次进入时能正确识别已翻译状态
void main() {
  late Database db;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    db = await databaseFactoryFfi.openDatabase(
      ':memory:',
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (Database db, int version) async {
          await db.execute('''
            CREATE TABLE subtitles (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              code TEXT UNIQUE NOT NULL,
              video_code TEXT NOT NULL,
              start_position INTEGER NOT NULL,
              end_position INTEGER NOT NULL,
              content TEXT NOT NULL DEFAULT '',
              content_translate TEXT,
              translate_source INTEGER NOT NULL DEFAULT -1,
              type TEXT NOT NULL DEFAULT 'subtitle',
              created_at TEXT,
              updated_at TEXT,
              is_deleted INTEGER NOT NULL DEFAULT 0
            )
          ''');

          await db.execute('''
            CREATE TABLE article_sentence (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              code TEXT UNIQUE NOT NULL,
              article_code TEXT NOT NULL,
              paragraph_index INTEGER NOT NULL,
              sentence_index INTEGER NOT NULL,
              content TEXT NOT NULL DEFAULT '',
              content_translate TEXT,
              translate_source INTEGER NOT NULL DEFAULT -1,
              created_at TEXT,
              updated_at TEXT,
              is_deleted INTEGER NOT NULL DEFAULT 0
            )
          ''');
        },
      ),
    );
  });

  tearDownAll(() async {
    await db.close();
  });

  setUp(() async {
    await db.delete('subtitles');
    await db.delete('article_sentence');
  });

  /// 模拟 DatabaseService._doUpdateTranslationsByCode 的核心逻辑
  /// 直接测试 SQL 写入是否正确
  Future<int> updateTranslationsByCode(List<BaseEntity> entities) async {
    if (entities.isEmpty) return 0;

    final subtitles = entities.whereType<Subtitles>().toList();
    final articleSentences = entities.whereType<ArticleSentence>().toList();

    int updatedCount = 0;

    for (final sub in subtitles) {
      if (sub.code == null || sub.code!.isEmpty) continue;
      if (sub.contentTranslate == null) continue;
      final now = DateTime.now().toIso8601String();
      updatedCount += await db.update(
        sub.tableName,
        {
          'content_translate': sub.contentTranslate,
          'translate_source': sub.translateSource,
          'updated_at': now,
        },
        where: 'code = ?',
        whereArgs: [sub.code],
      );
    }

    for (final sentence in articleSentences) {
      if (sentence.code == null || sentence.code!.isEmpty) continue;
      if (sentence.contentTranslate == null) continue;
      final now = DateTime.now().toIso8601String();
      updatedCount += await db.update(
        sentence.tableName,
        {
          'content_translate': sentence.contentTranslate,
          'translate_source': sentence.translateSource,
          'updated_at': now,
        },
        where: 'code = ?',
        whereArgs: [sentence.code],
      );
    }

    return updatedCount;
  }

  group('updateTranslationsByCode 翻译持久化测试', () {
    test('批量更新字幕翻译应成功写入数据库', () async {
      await db.insert('subtitles', {
        'code': 'sub-001',
        'video_code': 'test-video',
        'start_position': 0,
        'end_position': 1000,
        'content': 'We often think',
        'translate_source': -1,
      });
      await db.insert('subtitles', {
        'code': 'sub-002',
        'video_code': 'test-video',
        'start_position': 1000,
        'end_position': 2000,
        'content': 'that success comes',
        'translate_source': -1,
      });
      await db.insert('subtitles', {
        'code': 'sub-003',
        'video_code': 'test-video',
        'start_position': 2000,
        'end_position': 3000,
        'content': 'from one breakthrough',
        'translate_source': -1,
      });

      final subtitles = <Subtitles>[
        Subtitles(
          videoCode: 'test-video',
          content: 'We often think',
          contentTranslate: '我们经常认为',
          translateSource: 2,
        )..code = 'sub-001',
        Subtitles(
          videoCode: 'test-video',
          content: 'that success comes',
          contentTranslate: '成功来自于',
          translateSource: 2,
        )..code = 'sub-002',
        Subtitles(
          videoCode: 'test-video',
          content: 'from one breakthrough',
          contentTranslate: '一次突破',
          translateSource: 2,
        )..code = 'sub-003',
      ];

      final updatedCount = await updateTranslationsByCode(subtitles);
      expect(updatedCount, equals(3), reason: '应有 3 条记录被更新');

      final rows = await db.query('subtitles');
      expect(rows.length, equals(3));

      for (final row in rows) {
        expect(row['content_translate'], isNotNull, reason: '翻译内容不应为空');
        expect(row['translate_source'], equals(2), reason: '翻译来源应为 2');
      }

      final row1 = rows.firstWhere((r) => r['code'] == 'sub-001');
      expect(row1['content_translate'], equals('我们经常认为'));
      expect(row1['translate_source'], equals(2));

      final row2 = rows.firstWhere((r) => r['code'] == 'sub-002');
      expect(row2['content_translate'], equals('成功来自于'));
      expect(row2['translate_source'], equals(2));

      final row3 = rows.firstWhere((r) => r['code'] == 'sub-003');
      expect(row3['content_translate'], equals('一次突破'));
      expect(row3['translate_source'], equals(2));
    });

    test('部分翻译应只更新有翻译的记录', () async {
      await db.insert('subtitles', {
        'code': 'sub-101',
        'video_code': 'test-video',
        'start_position': 0,
        'end_position': 1000,
        'content': 'Hello',
        'translate_source': -1,
      });
      await db.insert('subtitles', {
        'code': 'sub-102',
        'video_code': 'test-video',
        'start_position': 1000,
        'end_position': 2000,
        'content': 'World',
        'translate_source': -1,
      });

      final subtitles = <Subtitles>[
        Subtitles(
          videoCode: 'test-video',
          content: 'Hello',
          contentTranslate: '你好',
          translateSource: 2,
        )..code = 'sub-101',
        Subtitles(
          videoCode: 'test-video',
          content: 'World',
        )..code = 'sub-102',
      ];

      final updatedCount = await updateTranslationsByCode(subtitles);
      expect(updatedCount, equals(1), reason: '只有 1 条记录应该有翻译');

      final rows = await db.query('subtitles');
      final row1 = rows.firstWhere((r) => r['code'] == 'sub-101');
      expect(row1['content_translate'], equals('你好'));
      expect(row1['translate_source'], equals(2));

      final row2 = rows.firstWhere((r) => r['code'] == 'sub-102');
      expect(row2['content_translate'], isNull);
      expect(row2['translate_source'], equals(-1));
    });

    test('空列表应返回 0', () async {
      final count = await updateTranslationsByCode([]);
      expect(count, equals(0));
    });

    test('重复更新应覆盖之前的值', () async {
      await db.insert('subtitles', {
        'code': 'sub-201',
        'video_code': 'test-video',
        'start_position': 0,
        'end_position': 1000,
        'content': 'Hello',
        'content_translate': '初始翻译',
        'translate_source': 1,
      });

      final subs1 = <Subtitles>[
        Subtitles(
          videoCode: 'test-video',
          content: 'Hello',
          contentTranslate: '第一次翻译',
          translateSource: 2,
        )..code = 'sub-201',
      ];
      await updateTranslationsByCode(subs1);

      var row = await db.query('subtitles', where: 'code = ?', whereArgs: ['sub-201']);
      expect(row.first['content_translate'], equals('第一次翻译'));
      expect(row.first['translate_source'], equals(2));

      final subs2 = <Subtitles>[
        Subtitles(
          videoCode: 'test-video',
          content: 'Hello',
          contentTranslate: '第二次翻译',
          translateSource: 2,
        )..code = 'sub-201',
      ];
      await updateTranslationsByCode(subs2);

      row = await db.query('subtitles', where: 'code = ?', whereArgs: ['sub-201']);
      expect(row.first['content_translate'], equals('第二次翻译'));
      expect(row.first['translate_source'], equals(2));
    });

    test('模拟第二次进入场景：已有翻译应跳过', () async {
      await db.insert('subtitles', {
        'code': 'sub-301',
        'video_code': 'test-video',
        'start_position': 0,
        'end_position': 1000,
        'content': 'Hello',
        'content_translate': '你好',
        'translate_source': 2,
      });

      final rows = await db.query('subtitles');
      final sub = Subtitles().fromMap(rows.first) as Subtitles;

      expect(sub.translateSource, equals(2));
      expect(sub.contentTranslate, equals('你好'));

      final needsTranslate = sub.translateSource == null ||
          sub.translateSource == -1 ||
          sub.translateSource == 0;

      expect(needsTranslate, isFalse, reason: '已有翻译的记录不应再次翻译');
    });

    test('无翻译的记录应标记为需要翻译', () async {
      await db.insert('subtitles', {
        'code': 'sub-401',
        'video_code': 'test-video',
        'start_position': 0,
        'end_position': 1000,
        'content': 'Hello',
        'content_translate': null,
        'translate_source': -1,
      });

      final rows = await db.query('subtitles');
      final sub = Subtitles().fromMap(rows.first) as Subtitles;

      expect(sub.translateSource, equals(-1));
      expect(sub.contentTranslate, isNull);

      final needsTranslate = sub.translateSource == null ||
          sub.translateSource == -1 ||
          sub.translateSource == 0;

      expect(needsTranslate, isTrue, reason: '无翻译的记录应标记为需要翻译');
    });

    test('大规模批量更新应保持稳定', () async {
      for (var i = 0; i < 50; i++) {
        await db.insert('subtitles', {
          'code': 'sub-batch-$i',
          'video_code': 'test-video',
          'start_position': i * 1000,
          'end_position': (i + 1) * 1000,
          'content': 'Content $i',
          'translate_source': -1,
        });
      }

      final subtitles = <Subtitles>[
        for (var i = 0; i < 50; i++)
          Subtitles(
            videoCode: 'test-video',
            content: 'Content $i',
            contentTranslate: '翻译 $i',
            translateSource: 2,
          )..code = 'sub-batch-$i',
      ];

      final updatedCount = await updateTranslationsByCode(subtitles);
      expect(updatedCount, equals(50));

      final rows = await db.query('subtitles');
      expect(rows.length, equals(50));

      for (var i = 0; i < 50; i++) {
        final row = rows.firstWhere((r) => r['code'] == 'sub-batch-$i');
        expect(row['content_translate'], equals('翻译 $i'));
        expect(row['translate_source'], equals(2));
      }
    });

    test('文章句子翻译应正确写入', () async {
      await db.insert('article_sentence', {
        'code': 'art-001',
        'article_code': 'test-article',
        'paragraph_index': 0,
        'sentence_index': 0,
        'content': 'The quiet power',
        'translate_source': -1,
      });
      await db.insert('article_sentence', {
        'code': 'art-002',
        'article_code': 'test-article',
        'paragraph_index': 0,
        'sentence_index': 1,
        'content': 'of small habits',
        'translate_source': -1,
      });

      final sentences = <ArticleSentence>[
        ArticleSentence(
          articleCode: 'test-article',
          paragraphIndex: 0,
          sentenceIndex: 0,
          content: 'The quiet power',
          contentTranslate: '安静的力量',
          translateSource: 2,
        )..code = 'art-001',
        ArticleSentence(
          articleCode: 'test-article',
          paragraphIndex: 0,
          sentenceIndex: 1,
          content: 'of small habits',
          contentTranslate: '小习惯的力量',
          translateSource: 2,
        )..code = 'art-002',
      ];

      final updatedCount = await updateTranslationsByCode(sentences);
      expect(updatedCount, equals(2));

      final rows = await db.query('article_sentence');
      for (final row in rows) {
        expect(row['content_translate'], isNotNull);
        expect(row['translate_source'], equals(2));
      }
    });

    test('混合更新：字幕和文章句子', () async {
      await db.insert('subtitles', {
        'code': 'mix-sub-001',
        'video_code': 'test-video',
        'start_position': 0,
        'end_position': 1000,
        'content': 'Hello',
        'translate_source': -1,
      });
      await db.insert('article_sentence', {
        'code': 'mix-art-001',
        'article_code': 'test-article',
        'paragraph_index': 0,
        'sentence_index': 0,
        'content': 'World',
        'translate_source': -1,
      });

      final entities = <BaseEntity>[
        Subtitles(
          videoCode: 'test-video',
          content: 'Hello',
          contentTranslate: '你好',
          translateSource: 2,
        )..code = 'mix-sub-001',
        ArticleSentence(
          articleCode: 'test-article',
          paragraphIndex: 0,
          sentenceIndex: 0,
          content: 'World',
          contentTranslate: '世界',
          translateSource: 2,
        )..code = 'mix-art-001',
      ];

      final updatedCount = await updateTranslationsByCode(entities);
      expect(updatedCount, equals(2));

      final subRows = await db.query('subtitles');
      expect(subRows.first['content_translate'], equals('你好'));
      expect(subRows.first['translate_source'], equals(2));

      final artRows = await db.query('article_sentence');
      expect(artRows.first['content_translate'], equals('世界'));
      expect(artRows.first['translate_source'], equals(2));
    });
  });
}
