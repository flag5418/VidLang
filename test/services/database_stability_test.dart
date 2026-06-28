import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:synchronized/synchronized.dart';
import 'package:vidlang/models/base_entity.dart';
import 'package:vidlang/models/subtitles.dart';
import 'package:vidlang/models/article_sentence.dart';

/// ============================================================
/// 数据库稳定性对比测试
///
/// 对比 deepenglish（成熟稳定）和 vidlang（当前）的数据库操作模式
/// 找出 vidlang 数据库损坏的根本原因
/// ============================================================
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  /// deepenglish 模式：使用 getDatabasesPath(), 无 PRAGMA, 无 Lock
  group('deepenglish 模式（无损坏风险）', () {
    late Database db;

    setUp(() async {
      final dbPath = await getDatabasesPath();
      final fullPath = p.join(dbPath, 'deep_test.db');
      try {
        await deleteDatabase(fullPath);
      } catch (_) {}

      // deepenglish 的做法：无任何 PRAGMA 设置
      db = await openDatabase(
        fullPath,
        version: 1,
        onCreate: (db, version) async {
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
        },
      );
    });

    tearDown(() async {
      await db.close();
      final dbPath = await getDatabasesPath();
      try {
        await deleteDatabase(p.join(dbPath, 'deep_test.db'));
      } catch (_) {}
    });

    test('单线程批量插入 500 条应稳定', () async {
      for (var i = 0; i < 500; i++) {
        await db.insert('subtitles', {
          'code': 'sub-$i',
          'video_code': 'test-video',
          'start_position': i * 1000,
          'end_position': (i + 1) * 1000,
          'content': 'Content $i',
          'translate_source': -1,
        });
      }

      final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM subtitles'),
      );
      expect(count, equals(500));

      // 写入翻译
      for (var i = 0; i < 500; i++) {
        await db.update(
          'subtitles',
          {
            'content_translate': '翻译 $i',
            'translate_source': 2,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'code = ?',
          whereArgs: ['sub-$i'],
        );
      }

      final count2 = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM subtitles WHERE content_translate IS NOT NULL'),
      );
      expect(count2, equals(500));
    });

    test('无 Lock 并发写入不应损坏', () async {
      final errors = <Object>[];

      // 模拟 deepenglish 的模式：直接写入，无 Lock
      Future<void> writeBatch(int start, int count) async {
        for (var i = start; i < start + count; i++) {
          try {
            await db.insert('subtitles', {
              'code': 'sub-$i',
              'video_code': 'test-video',
              'start_position': i * 1000,
              'end_position': (i + 1) * 1000,
              'content': 'Content $i',
              'translate_source': -1,
            });
          } catch (e) {
            errors.add(e);
          }
        }
      }

      // 同时发起多个写入任务（模拟并发场景）
      await Future.wait([
        writeBatch(0, 100),
        writeBatch(100, 100),
        writeBatch(200, 100),
      ]);

      // 检查数据库是否损坏
      try {
        final rows = await db.rawQuery('PRAGMA quick_check(1)');
        final result = rows.first.values.first;
        expect(result, equals('ok'), reason: '数据库应保持完整');
      } catch (e) {
        fail('数据库已损坏: $e');
      }
    });

    test('并发读写不应损坏', () async {
      // 先插入数据
      for (var i = 0; i < 100; i++) {
        await db.insert('subtitles', {
          'code': 'sub-$i',
          'video_code': 'test-video',
          'start_position': i * 1000,
          'end_position': (i + 1) * 1000,
          'content': 'Content $i',
          'translate_source': -1,
        });
      }

      final errors = <Object>[];

      // 读任务
      Future<void> reader() async {
        for (var i = 0; i < 50; i++) {
          try {
            await db.query('subtitles', limit: 10);
          } catch (e) {
            errors.add(e);
          }
        }
      }

      // 写任务（更新翻译）
      Future<void> writer(int start, int count) async {
        for (var i = start; i < start + count; i++) {
          try {
            await db.update(
              'subtitles',
              {
                'content_translate': '翻译 $i',
                'translate_source': 2,
              },
              where: 'code = ?',
              whereArgs: ['sub-$i'],
            );
          } catch (e) {
            errors.add(e);
          }
        }
      }

      // 同时读写
      await Future.wait([
        reader(),
        writer(0, 50),
        writer(50, 50),
      ]);

      try {
        final rows = await db.rawQuery('PRAGMA quick_check(1)');
        expect(rows.first.values.first, equals('ok'));
      } catch (e) {
        fail('数据库已损坏: $e');
      }
    });
  });

  /// vidlang 模式：使用 Lock + PRAGMA + Batch
  group('vidlang 模式（带 Lock）', () {
    late Database db;
    final writeLock = Lock();

    setUp(() async {
      final dbPath = await getDatabasesPath();
      final fullPath = p.join(dbPath, 'vidlang_test.db');
      try {
        await deleteDatabase(fullPath);
      } catch (_) {}

      db = await openDatabase(
        fullPath,
        version: 1,
        onConfigure: (db) async {
          // vidlang 的 PRAGMA 设置
          try {
            await db.execute('PRAGMA journal_mode = DELETE');
          } catch (_) {}
          try {
            await db.execute('PRAGMA synchronous = FULL');
          } catch (_) {}
          try {
            await db.execute('PRAGMA busy_timeout = 15000');
          } catch (_) {}
        },
        onCreate: (db, version) async {
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
        },
      );
    });

    tearDown(() async {
      await db.close();
      final dbPath = await getDatabasesPath();
      try {
        await deleteDatabase(p.join(dbPath, 'vidlang_test.db'));
      } catch (_) {}
    });

    test('有 Lock 的并发写入应稳定', () async {
      Future<void> writeBatch(int start, int count) async {
        await writeLock.synchronized(() async {
          for (var i = start; i < start + count; i++) {
            await db.insert('subtitles', {
              'code': 'sub-$i',
              'video_code': 'test-video',
              'start_position': i * 1000,
              'end_position': (i + 1) * 1000,
              'content': 'Content $i',
              'translate_source': -1,
            });
          }
        });
      }

      await Future.wait([
        writeBatch(0, 100),
        writeBatch(100, 100),
        writeBatch(200, 100),
      ]);

      try {
        final rows = await db.rawQuery('PRAGMA quick_check(1)');
        expect(rows.first.values.first, equals('ok'));
      } catch (e) {
        fail('数据库已损坏: $e');
      }
    });

    test('模拟 updateTranslationsByCode 无 Lock 并发写入', () async {
      // 先插入数据
      for (var i = 0; i < 200; i++) {
        await db.insert('subtitles', {
          'code': 'sub-$i',
          'video_code': 'test-video',
          'start_position': i * 1000,
          'end_position': (i + 1) * 1000,
          'content': 'Content $i',
          'translate_source': -1,
        });
      }

      final errors = <Object>[];

      // 模拟 vidlang 的 updateTranslationsByCode（无 Lock 直接写入）
      Future<void> updateTranslationsByCode(int start, int count) async {
        for (var i = start; i < start + count; i++) {
          try {
            // 这里模拟 vidlang 的 bug：直接 db.update 无 Lock
            await db.update(
              'subtitles',
              {
                'content_translate': '翻译 $i',
                'translate_source': 2,
                'updated_at': DateTime.now().toIso8601String(),
              },
              where: 'code = ?',
              whereArgs: ['sub-$i'],
            );
          } catch (e) {
            errors.add(e);
          }
        }
      }

      // 同时模拟：一个正常写入（有 Lock），一个翻译写入（无 Lock）
      Future<void> normalInsert() async {
        await writeLock.synchronized(() async {
          for (var i = 200; i < 300; i++) {
            try {
              await db.insert('subtitles', {
                'code': 'sub-$i',
                'video_code': 'test-video',
                'start_position': i * 1000,
                'end_position': (i + 1) * 1000,
                'content': 'New Content $i',
                'translate_source': -1,
              });
            } catch (e) {
              errors.add(e);
            }
          }
        });
      }

      // 三个并发操作：有 Lock 写入 + 无 Lock 翻译写入 x2
      await Future.wait([
        normalInsert(),
        updateTranslationsByCode(0, 100),
        updateTranslationsByCode(100, 100),
      ]);

      try {
        final rows = await db.rawQuery('PRAGMA quick_check(1)');
        final result = rows.first.values.first;
        expect(result, equals('ok'), reason: '即使并发，数据库也应保持完整');
      } catch (e) {
        fail('数据库已损坏: $e');
      }
    });

    test('模拟真实场景：翻译写入 + 用户操作并发', () async {
      // 先插入 300 条字幕
      for (var i = 0; i < 300; i++) {
        await db.insert('subtitles', {
          'code': 'sub-$i',
          'video_code': 'test-video',
          'start_position': i * 1000,
          'end_position': (i + 1) * 1000,
          'content': 'Content $i',
          'translate_source': -1,
        });
      }

      final errors = <String>[];

      // 场景1：翻译服务写入（无 Lock - vidlang bug）
      Future<void> translationService() async {
        for (var i = 0; i < 300; i++) {
          try {
            await db.update(
              'subtitles',
              {
                'content_translate': '翻译 $i',
                'translate_source': 2,
                'updated_at': DateTime.now().toIso8601String(),
              },
              where: 'code = ?',
              whereArgs: ['sub-$i'],
            );
          } catch (e) {
            errors.add('translation: $e');
          }
        }
      }

      // 场景2：用户设置保存（有 Lock）
      Future<void> settingsService() async {
        await writeLock.synchronized(() async {
          for (var i = 0; i < 50; i++) {
            try {
              await db.update(
                'subtitles',
                {
                  'updated_at': DateTime.now().toIso8601String(),
                },
                where: 'code = ?',
                whereArgs: ['sub-$i'],
              );
            } catch (e) {
              errors.add('settings: $e');
            }
          }
        });
      }

      // 场景3：字幕保存（有 Lock）
      Future<void> subtitleService() async {
        await writeLock.synchronized(() async {
          for (var i = 300; i < 350; i++) {
            try {
              await db.insert('subtitles', {
                'code': 'sub-$i',
                'video_code': 'test-video',
                'start_position': i * 1000,
                'end_position': (i + 1) * 1000,
                'content': 'New $i',
                'translate_source': -1,
              });
            } catch (e) {
              errors.add('subtitle: $e');
            }
          }
        });
      }

      // 场景4：播放记录读取（并发读）
      Future<void> playbackService() async {
        for (var i = 0; i < 50; i++) {
          try {
            await db.query('subtitles', limit: 10);
          } catch (e) {
            errors.add('playback: $e');
          }
        }
      }

      // 四个服务同时运行
      await Future.wait([
        translationService(),
        settingsService(),
        subtitleService(),
        playbackService(),
      ]);

      if (errors.isNotEmpty) {
        print('错误: ${errors.length} 个');
        for (final e in errors.take(5)) {
          print('  - $e');
        }
      }

      try {
        final rows = await db.rawQuery('PRAGMA quick_check(1)');
        final result = rows.first.values.first;
        expect(result, equals('ok'), reason: '数据库应保持完整');
      } catch (e) {
        fail('数据库已损坏: $e');
      }
    });
  });

  /// 对比测试：两种 PRAGMA 模式
  group('PRAGMA 模式对比', () {
    test('DELETE journal + FULL synchronous vs 默认', () async {
      // 测试两种模式都能正常工作
      for (final mode in ['DELETE', 'WAL', 'TRUNCATE']) {
        final dbPath = await getDatabasesPath();
        final fullPath = p.join(dbPath, 'pragma_test_$mode.db');
        try {
          await deleteDatabase(fullPath);
        } catch (_) {}

        final db = await openDatabase(
          fullPath,
          version: 1,
          onConfigure: (db) async {
            await db.execute("PRAGMA journal_mode = $mode");
            await db.execute('PRAGMA synchronous = FULL');
          },
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE test_table (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                code TEXT UNIQUE NOT NULL,
                content TEXT
              )
            ''');
          },
        );

        // 写入 100 条
        for (var i = 0; i < 100; i++) {
          await db.insert('test_table', {
            'code': 'test-$i',
            'content': 'Content $i',
          });
        }

        // 验证 journal_mode
        final journalMode = await db.rawQuery('PRAGMA journal_mode');
        print('journal_mode=$mode: 实际=${journalMode.first.values.first}');

        // 检查完整性
        final check = await db.rawQuery('PRAGMA quick_check(1)');
        expect(check.first.values.first, equals('ok'), reason: 'mode=$mode 应保持完整');

        await db.close();
        try {
          await deleteDatabase(fullPath);
        } catch (_) {}
      }
    });
  });
}
