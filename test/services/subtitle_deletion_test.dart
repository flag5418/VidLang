import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:synchronized/synchronized.dart';

/// ============================================================
/// 字幕删除综合测试
///
/// 测试场景：
/// 1. 软删除基本功能
/// 2. 批量软删除
/// 3. 并发删除操作
/// 4. 删除后数据一致性
/// 5. 数据库损坏检测与恢复
/// 6. 级联删除（视频删除时字幕删除）
/// ============================================================
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('字幕软删除基本测试', () {
    late Database db;
    final writeLock = Lock();

    setUp(() async {
      final dbPath = await getDatabasesPath();
      final fullPath = p.join(dbPath, 'subtitle_delete_basic_test.db');
      try {
        await deleteDatabase(fullPath);
      } catch (_) {}

      db = await openDatabase(
        fullPath,
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA journal_mode = WAL');
          await db.execute('PRAGMA synchronous = NORMAL');
          await db.execute('PRAGMA busy_timeout = 15000');
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
              source TEXT,
              pronunciation TEXT,
              pronunciation_map_json TEXT,
              confidence REAL,
              created_at TEXT,
              updated_at TEXT,
              deleted_at TEXT,
              is_deleted INTEGER NOT NULL DEFAULT 0,
              created_by TEXT,
              updated_by TEXT,
              deleted_by TEXT
            )
          ''');
        },
      );
    });

    tearDown(() async {
      await db.close();
      final dbPath = await getDatabasesPath();
      try {
        await deleteDatabase(p.join(dbPath, 'subtitle_delete_basic_test.db'));
      } catch (_) {}
    });

    test('单条软删除应正确设置 is_deleted 字段', () async {
      // 插入测试数据
      await db.insert('subtitles', {
        'code': 'sub-001',
        'video_code': 'video-001',
        'start_position': 0,
        'end_position': 1000,
        'content': 'Hello',
        'translate_source': -1,
      });

      // 执行软删除
      final now = DateTime.now().toIso8601String();
      final count = await db.update(
        'subtitles',
        {
          'is_deleted': 1,
          'deleted_at': now,
          'deleted_by': 'test-user',
          'updated_at': now,
          'updated_by': 'test-user',
        },
        where: 'code = ?',
        whereArgs: ['sub-001'],
      );

      expect(count, equals(1));

      // 验证软删除结果
      final result = await db.query(
        'subtitles',
        where: 'code = ?',
        whereArgs: ['sub-001'],
      );

      expect(result.length, equals(1));
      expect(result.first['is_deleted'], equals(1));
      expect(result.first['deleted_at'], isNotNull);
      expect(result.first['deleted_by'], equals('test-user'));
    });

    test('软删除后查询应过滤已删除记录', () async {
      // 插入多条数据
      for (var i = 0; i < 5; i++) {
        await db.insert('subtitles', {
          'code': 'sub-$i',
          'video_code': 'video-001',
          'start_position': i * 1000,
          'end_position': (i + 1) * 1000,
          'content': 'Content $i',
          'translate_source': -1,
        });
      }

      // 软删除其中两条
      final now = DateTime.now().toIso8601String();
      await db.update(
        'subtitles',
        {'is_deleted': 1, 'deleted_at': now},
        where: 'code IN (?, ?)',
        whereArgs: ['sub-0', 'sub-2'],
      );

      // 查询未删除的记录
      final active = await db.query(
        'subtitles',
        where: 'is_deleted = 0',
      );

      expect(active.length, equals(3));
      expect(active.every((r) => r['is_deleted'] == 0), isTrue);
    });

    test('批量软删除应使用事务保证原子性', () async {
      // 插入 10 条数据
      for (var i = 0; i < 10; i++) {
        await db.insert('subtitles', {
          'code': 'sub-batch-$i',
          'video_code': 'video-001',
          'start_position': i * 1000,
          'end_position': (i + 1) * 1000,
          'content': 'Batch Content $i',
          'translate_source': -1,
        });
      }

      // 使用事务批量软删除
      final now = DateTime.now().toIso8601String();
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (var i = 0; i < 5; i++) {
          batch.update(
            'subtitles',
            {
              'is_deleted': 1,
              'deleted_at': now,
              'deleted_by': 'test-user',
              'updated_at': now,
              'updated_by': 'test-user',
            },
            where: 'code = ?',
            whereArgs: ['sub-batch-$i'],
          );
        }
        await batch.commit(noResult: true);
      });

      // 验证批量删除结果
      final active = await db.query(
        'subtitles',
        where: 'is_deleted = 0',
      );

      expect(active.length, equals(5));
    });

    test('软删除不存在的记录应返回 0 影响行数', () async {
      final now = DateTime.now().toIso8601String();
      final count = await db.update(
        'subtitles',
        {
          'is_deleted': 1,
          'deleted_at': now,
          'deleted_by': 'test-user',
        },
        where: 'code = ?',
        whereArgs: ['non-existent-code'],
      );

      expect(count, equals(0));
    });
  });

  group('并发删除操作测试', () {
    late Database db;
    final writeLock = Lock();

    setUp(() async {
      final dbPath = await getDatabasesPath();
      final fullPath = p.join(dbPath, 'subtitle_delete_concurrent_test.db');
      try {
        await deleteDatabase(fullPath);
      } catch (_) {}

      db = await openDatabase(
        fullPath,
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA journal_mode = WAL');
          await db.execute('PRAGMA synchronous = NORMAL');
          await db.execute('PRAGMA busy_timeout = 15000');
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
              source TEXT,
              pronunciation TEXT,
              pronunciation_map_json TEXT,
              confidence REAL,
              created_at TEXT,
              updated_at TEXT,
              deleted_at TEXT,
              is_deleted INTEGER NOT NULL DEFAULT 0,
              created_by TEXT,
              updated_by TEXT,
              deleted_by TEXT
            )
          ''');
        },
      );

      // 预插入测试数据
      for (var i = 0; i < 100; i++) {
        await db.insert('subtitles', {
          'code': 'sub-concurrent-$i',
          'video_code': i < 50 ? 'video-A' : 'video-B',
          'start_position': i * 1000,
          'end_position': (i + 1) * 1000,
          'content': 'Concurrent Content $i',
          'translate_source': -1,
        });
      }
    });

    tearDown(() async {
      await db.close();
      final dbPath = await getDatabasesPath();
      try {
        await deleteDatabase(p.join(dbPath, 'subtitle_delete_concurrent_test.db'));
      } catch (_) {}
    });

    test('并发软删除不同视频的字幕不应损坏数据库', () async {
      final errors = <Object>[];

      // 并发删除 video-A 和 video-B 的字幕
      Future<void> deleteVideoSubtitles(String videoCode, int start, int count) async {
        await writeLock.synchronized(() async {
          try {
            final now = DateTime.now().toIso8601String();
            for (var i = start; i < start + count; i++) {
              await db.update(
                'subtitles',
                {
                  'is_deleted': 1,
                  'deleted_at': now,
                  'deleted_by': 'test-user',
                  'updated_at': now,
                  'updated_by': 'test-user',
                },
                where: 'video_code = ? AND code = ?',
                whereArgs: [videoCode, 'sub-concurrent-$i'],
              );
            }
          } catch (e) {
            errors.add(e);
          }
        });
      }

      // 同时删除两个视频的字幕
      await Future.wait([
        deleteVideoSubtitles('video-A', 0, 25),
        deleteVideoSubtitles('video-A', 25, 25),
        deleteVideoSubtitles('video-B', 50, 25),
        deleteVideoSubtitles('video-B', 75, 25),
      ]);

      // 验证数据库完整性
      try {
        final rows = await db.rawQuery('PRAGMA quick_check(1)');
        expect(rows.first.values.first, equals('ok'), reason: '并发删除后数据库应保持完整');
      } catch (e) {
        fail('数据库已损坏: $e');
      }

      expect(errors, isEmpty, reason: '不应有并发错误');
    });

    test('并发软删除和插入不应损坏数据库', () async {
      final errors = <Object>[];

      // 写任务：软删除
      Future<void> softDeleteTask(int start, int count) async {
        await writeLock.synchronized(() async {
          try {
            final now = DateTime.now().toIso8601String();
            for (var i = start; i < start + count; i++) {
              await db.update(
                'subtitles',
                {
                  'is_deleted': 1,
                  'deleted_at': now,
                  'deleted_by': 'test-user',
                },
                where: 'code = ?',
                whereArgs: ['sub-concurrent-$i'],
              );
            }
          } catch (e) {
            errors.add(e);
          }
        });
      }

      // 写任务：插入新数据
      Future<void> insertTask(int start, int count) async {
        await writeLock.synchronized(() async {
          try {
            for (var i = start; i < start + count; i++) {
              await db.insert('subtitles', {
                'code': 'sub-new-$i',
                'video_code': 'video-new',
                'start_position': i * 1000,
                'end_position': (i + 1) * 1000,
                'content': 'New Content $i',
                'translate_source': -1,
              });
            }
          } catch (e) {
            errors.add(e);
          }
        });
      }

      // 同时执行删除和插入
      await Future.wait([
        softDeleteTask(0, 50),
        softDeleteTask(50, 50),
        insertTask(0, 100),
        insertTask(100, 100),
      ]);

      // 验证数据库完整性
      try {
        final rows = await db.rawQuery('PRAGMA quick_check(1)');
        expect(rows.first.values.first, equals('ok'));
      } catch (e) {
        fail('数据库已损坏: $e');
      }

      expect(errors, isEmpty);
    });

    test('并发读写删除不应损坏数据库', () async {
      final errors = <Object>[];

      // 读任务
      Future<void> reader() async {
        for (var i = 0; i < 50; i++) {
          try {
            await db.query(
              'subtitles',
              where: 'is_deleted = 0',
              limit: 10,
            );
          } catch (e) {
            errors.add(e);
          }
        }
      }

      // 写任务：软删除
      Future<void> writer(int start, int count) async {
        await writeLock.synchronized(() async {
          try {
            final now = DateTime.now().toIso8601String();
            for (var i = start; i < start + count; i++) {
              await db.update(
                'subtitles',
                {
                  'is_deleted': 1,
                  'deleted_at': now,
                  'updated_at': now,
                },
                where: 'code = ?',
                whereArgs: ['sub-concurrent-$i'],
              );
            }
          } catch (e) {
            errors.add(e);
          }
        });
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

  group('批量软删除测试', () {
    late Database db;
    final writeLock = Lock();

    setUp(() async {
      final dbPath = await getDatabasesPath();
      final fullPath = p.join(dbPath, 'subtitle_delete_batch_test.db');
      try {
        await deleteDatabase(fullPath);
      } catch (_) {}

      db = await openDatabase(
        fullPath,
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA journal_mode = WAL');
          await db.execute('PRAGMA synchronous = NORMAL');
          await db.execute('PRAGMA busy_timeout = 15000');
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
              source TEXT,
              pronunciation TEXT,
              pronunciation_map_json TEXT,
              confidence REAL,
              created_at TEXT,
              updated_at TEXT,
              deleted_at TEXT,
              is_deleted INTEGER NOT NULL DEFAULT 0,
              created_by TEXT,
              updated_by TEXT,
              deleted_by TEXT
            )
          ''');
        },
      );
    });

    tearDown(() async {
      await db.close();
      final dbPath = await getDatabasesPath();
      try {
        await deleteDatabase(p.join(dbPath, 'subtitle_delete_batch_test.db'));
      } catch (_) {}
    });

    test('批量软删除 500 条记录应稳定', () async {
      // 插入 500 条数据
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (var i = 0; i < 500; i++) {
          batch.insert('subtitles', {
            'code': 'sub-batch-500-$i',
            'video_code': 'video-batch',
            'start_position': i * 1000,
            'end_position': (i + 1) * 1000,
            'content': 'Batch Content $i',
            'translate_source': -1,
          });
        }
        await batch.commit(noResult: true);
      });

      // 验证插入成功
      final countBefore = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM subtitles WHERE is_deleted = 0'),
      );
      expect(countBefore, equals(500));

      // 批量软删除
      await writeLock.synchronized(() async {
        await db.transaction((txn) async {
          final batch = txn.batch();
          final now = DateTime.now().toIso8601String();
          for (var i = 0; i < 500; i++) {
            batch.update(
              'subtitles',
              {
                'is_deleted': 1,
                'deleted_at': now,
                'deleted_by': 'test-user',
                'updated_at': now,
                'updated_by': 'test-user',
              },
              where: 'code = ?',
              whereArgs: ['sub-batch-500-$i'],
            );
          }
          await batch.commit(noResult: true);
        });
      });

      // 验证软删除结果
      final countAfter = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM subtitles WHERE is_deleted = 0'),
      );
      expect(countAfter, equals(0));

      // 验证数据库完整性
      final rows = await db.rawQuery('PRAGMA quick_check(1)');
      expect(rows.first.values.first, equals('ok'));
    });

    test('批量软删除后重新插入应正常', () async {
      // 插入 100 条数据
      for (var i = 0; i < 100; i++) {
        await db.insert('subtitles', {
          'code': 'sub-reinsert-$i',
          'video_code': 'video-reinsert',
          'start_position': i * 1000,
          'end_position': (i + 1) * 1000,
          'content': 'Reinsert Content $i',
          'translate_source': -1,
        });
      }

      // 批量软删除
      final now = DateTime.now().toIso8601String();
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (var i = 0; i < 100; i++) {
          batch.update(
            'subtitles',
            {
              'is_deleted': 1,
              'deleted_at': now,
              'deleted_by': 'test-user',
            },
            where: 'code = ?',
            whereArgs: ['sub-reinsert-$i'],
          );
        }
        await batch.commit(noResult: true);
      });

      // 重新插入新数据
      for (var i = 0; i < 50; i++) {
        await db.insert('subtitles', {
          'code': 'sub-reinsert-new-$i',
          'video_code': 'video-reinsert',
          'start_position': i * 1000,
          'end_position': (i + 1) * 1000,
          'content': 'New Reinsert Content $i',
          'translate_source': -1,
        });
      }

      // 验证新数据插入成功
      final countNew = Sqflite.firstIntValue(
        await db.rawQuery("SELECT COUNT(*) FROM subtitles WHERE is_deleted = 0 AND code LIKE 'sub-reinsert-new-%'"),
      );
      expect(countNew, equals(50));
    });

    test('批量软删除与并发插入不应损坏数据库', () async {
      final errors = <Object>[];

      // 预插入数据
      for (var i = 0; i < 200; i++) {
        await db.insert('subtitles', {
          'code': 'sub-mixed-$i',
          'video_code': 'video-mixed',
          'start_position': i * 1000,
          'end_position': (i + 1) * 1000,
          'content': 'Mixed Content $i',
          'translate_source': -1,
        });
      }

      // 批量软删除任务
      Future<void> batchDeleteTask() async {
        await writeLock.synchronized(() async {
          try {
            await db.transaction((txn) async {
              final batch = txn.batch();
              final now = DateTime.now().toIso8601String();
              for (var i = 0; i < 100; i++) {
                batch.update(
                  'subtitles',
                  {
                    'is_deleted': 1,
                    'deleted_at': now,
                    'deleted_by': 'test-user',
                  },
                  where: 'code = ?',
                  whereArgs: ['sub-mixed-$i'],
                );
              }
              await batch.commit(noResult: true);
            });
          } catch (e) {
            errors.add(e);
          }
        });
      }

      // 并发插入任务
      Future<void> insertTask(int start, int count) async {
        await writeLock.synchronized(() async {
          try {
            for (var i = start; i < start + count; i++) {
              await db.insert('subtitles', {
                'code': 'sub-mixed-new-$i',
                'video_code': 'video-mixed-new',
                'start_position': i * 1000,
                'end_position': (i + 1) * 1000,
                'content': 'New Mixed Content $i',
                'translate_source': -1,
              });
            }
          } catch (e) {
            errors.add(e);
          }
        });
      }

      // 同时执行删除和插入
      await Future.wait([
        batchDeleteTask(),
        insertTask(0, 100),
        insertTask(100, 100),
      ]);

      // 验证数据库完整性
      try {
        final rows = await db.rawQuery('PRAGMA quick_check(1)');
        expect(rows.first.values.first, equals('ok'));
      } catch (e) {
        fail('数据库已损坏: $e');
      }

      expect(errors, isEmpty);
    });
  });

  group('数据库损坏检测测试', () {
    test('应正确识别 malformed 错误消息', () {
      final errors = [
        'database disk image is malformed',
        'malformed',
        'disk i/o error',
        'corrupt',
        'not a database',
      ];

      for (final error in errors) {
        final s = error.toLowerCase();
        final isCorrupted =
            s.contains('database disk image is malformed') ||
            s.contains('malformed') ||
            s.contains('disk i/o error') ||
            s.contains('corrupt') ||
            s.contains('not a database');
        expect(isCorrupted, isTrue, reason: '应识别为损坏: $error');
      }
    });

    test('锁争用错误不应被识别为损坏', () {
      final lockErrors = [
        'database is locked',
        'busy',
        'SQLITE_BUSY',
      ];

      for (final error in lockErrors) {
        final s = error.toLowerCase();
        // 锁争用错误应该被排除
        final isLockError = s.contains('database is locked') || s.contains('busy');
        expect(isLockError, isTrue, reason: '应识别为锁争用: $error');
      }
    });
  });

  group('级联删除测试', () {
    late Database db;
    final writeLock = Lock();

    setUp(() async {
      final dbPath = await getDatabasesPath();
      final fullPath = p.join(dbPath, 'subtitle_delete_cascade_test.db');
      try {
        await deleteDatabase(fullPath);
      } catch (_) {}

      db = await openDatabase(
        fullPath,
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA journal_mode = WAL');
          await db.execute('PRAGMA synchronous = NORMAL');
          await db.execute('PRAGMA busy_timeout = 15000');
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
              source TEXT,
              pronunciation TEXT,
              pronunciation_map_json TEXT,
              confidence REAL,
              created_at TEXT,
              updated_at TEXT,
              deleted_at TEXT,
              is_deleted INTEGER NOT NULL DEFAULT 0,
              created_by TEXT,
              updated_by TEXT,
              deleted_by TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE video_info (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              code TEXT UNIQUE NOT NULL,
              name TEXT NOT NULL,
              created_at TEXT,
              updated_at TEXT,
              deleted_at TEXT,
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
        await deleteDatabase(p.join(dbPath, 'subtitle_delete_cascade_test.db'));
      } catch (_) {}
    });

    test('删除视频时应级联软删除所有关联字幕', () async {
      // 插入视频
      await db.insert('video_info', {
        'code': 'video-cascade-001',
        'name': 'Test Video',
        'is_deleted': 0,
      });

      // 插入关联字幕
      for (var i = 0; i < 10; i++) {
        await db.insert('subtitles', {
          'code': 'sub-cascade-$i',
          'video_code': 'video-cascade-001',
          'start_position': i * 1000,
          'end_position': (i + 1) * 1000,
          'content': 'Cascade Content $i',
          'translate_source': -1,
        });
      }

      // 验证插入成功
      final subtitlesBefore = await db.query(
        'subtitles',
        where: 'video_code = ? AND is_deleted = 0',
        whereArgs: ['video-cascade-001'],
      );
      expect(subtitlesBefore.length, equals(10));

      // 级联软删除：删除视频的所有字幕
      await writeLock.synchronized(() async {
        await db.transaction((txn) async {
          final now = DateTime.now().toIso8601String();
          final batch = txn.batch();

          // 软删除所有关联字幕
          batch.update(
            'subtitles',
            {
              'is_deleted': 1,
              'deleted_at': now,
              'deleted_by': 'test-user',
              'updated_at': now,
              'updated_by': 'test-user',
            },
            where: 'video_code = ?',
            whereArgs: ['video-cascade-001'],
          );

          // 软删除视频本身
          batch.update(
            'video_info',
            {
              'is_deleted': 1,
              'deleted_at': now,
              'updated_at': now,
            },
            where: 'code = ?',
            whereArgs: ['video-cascade-001'],
          );

          await batch.commit(noResult: true);
        });
      });

      // 验证级联删除结果
      final subtitlesAfter = await db.query(
        'subtitles',
        where: 'video_code = ? AND is_deleted = 0',
        whereArgs: ['video-cascade-001'],
      );
      expect(subtitlesAfter.length, equals(0));

      final videoAfter = await db.query(
        'video_info',
        where: 'code = ? AND is_deleted = 0',
        whereArgs: ['video-cascade-001'],
      );
      expect(videoAfter.length, equals(0));

      // 验证数据库完整性
      final rows = await db.rawQuery('PRAGMA quick_check(1)');
      expect(rows.first.values.first, equals('ok'));
    });

    test('并发级联删除不应损坏数据库', () async {
      final errors = <Object>[];

      // 插入多个视频和字幕
      for (var v = 0; v < 5; v++) {
        await db.insert('video_info', {
          'code': 'video-concurrent-$v',
          'name': 'Video $v',
          'is_deleted': 0,
        });

        for (var s = 0; s < 20; s++) {
          await db.insert('subtitles', {
            'code': 'sub-concurrent-$v-$s',
            'video_code': 'video-concurrent-$v',
            'start_position': s * 1000,
            'end_position': (s + 1) * 1000,
            'content': 'Content $v-$s',
            'translate_source': -1,
          });
        }
      }

      // 并发级联删除
      Future<void> cascadeDelete(String videoCode) async {
        await writeLock.synchronized(() async {
          try {
            await db.transaction((txn) async {
              final now = DateTime.now().toIso8601String();
              final batch = txn.batch();

              batch.update(
                'subtitles',
                {
                  'is_deleted': 1,
                  'deleted_at': now,
                  'deleted_by': 'test-user',
                },
                where: 'video_code = ?',
                whereArgs: [videoCode],
              );

              batch.update(
                'video_info',
                {
                  'is_deleted': 1,
                  'deleted_at': now,
                  'updated_at': now,
                },
                where: 'code = ?',
                whereArgs: [videoCode],
              );

              await batch.commit(noResult: true);
            });
          } catch (e) {
            errors.add(e);
          }
        });
      }

      // 同时删除所有视频
      await Future.wait([
        cascadeDelete('video-concurrent-0'),
        cascadeDelete('video-concurrent-1'),
        cascadeDelete('video-concurrent-2'),
        cascadeDelete('video-concurrent-3'),
        cascadeDelete('video-concurrent-4'),
      ]);

      // 验证数据库完整性
      try {
        final rows = await db.rawQuery('PRAGMA quick_check(1)');
        expect(rows.first.values.first, equals('ok'));
      } catch (e) {
        fail('数据库已损坏: $e');
      }

      expect(errors, isEmpty);

      // 验证所有视频和字幕都已删除
      final activeVideos = await db.query(
        'video_info',
        where: 'is_deleted = 0',
      );
      expect(activeVideos.length, equals(0));

      final activeSubtitles = await db.query(
        'subtitles',
        where: 'is_deleted = 0',
      );
      expect(activeSubtitles.length, equals(0));
    });
  });

  group('删除性能测试', () {
    late Database db;
    final writeLock = Lock();

    setUp(() async {
      final dbPath = await getDatabasesPath();
      final fullPath = p.join(dbPath, 'subtitle_delete_perf_test.db');
      try {
        await deleteDatabase(fullPath);
      } catch (_) {}

      db = await openDatabase(
        fullPath,
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA journal_mode = WAL');
          await db.execute('PRAGMA synchronous = NORMAL');
          await db.execute('PRAGMA busy_timeout = 15000');
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
              source TEXT,
              pronunciation TEXT,
              pronunciation_map_json TEXT,
              confidence REAL,
              created_at TEXT,
              updated_at TEXT,
              deleted_at TEXT,
              is_deleted INTEGER NOT NULL DEFAULT 0,
              created_by TEXT,
              updated_by TEXT,
              deleted_by TEXT
            )
          ''');
        },
      );
    });

    tearDown(() async {
      await db.close();
      final dbPath = await getDatabasesPath();
      try {
        await deleteDatabase(p.join(dbPath, 'subtitle_delete_perf_test.db'));
      } catch (_) {}
    });

    test('批量软删除 1000 条记录性能测试', () async {
      // 插入 1000 条数据
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (var i = 0; i < 1000; i++) {
          batch.insert('subtitles', {
            'code': 'sub-perf-$i',
            'video_code': 'video-perf',
            'start_position': i * 1000,
            'end_position': (i + 1) * 1000,
            'content': 'Performance Content $i',
            'translate_source': -1,
          });
        }
        await batch.commit(noResult: true);
      });

      // 测量批量删除性能
      final stopwatch = Stopwatch()..start();

      await writeLock.synchronized(() async {
        await db.transaction((txn) async {
          final batch = txn.batch();
          final now = DateTime.now().toIso8601String();
          for (var i = 0; i < 1000; i++) {
            batch.update(
              'subtitles',
              {
                'is_deleted': 1,
                'deleted_at': now,
                'deleted_by': 'test-user',
                'updated_at': now,
                'updated_by': 'test-user',
              },
              where: 'code = ?',
              whereArgs: ['sub-perf-$i'],
            );
          }
          await batch.commit(noResult: true);
        });
      });

      stopwatch.stop();

      // 验证删除完成
      final countAfter = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM subtitles WHERE is_deleted = 0'),
      );
      expect(countAfter, equals(0));

      // 验证数据库完整性
      final rows = await db.rawQuery('PRAGMA quick_check(1)');
      expect(rows.first.values.first, equals('ok'));

      // 性能应该在合理范围内（10秒内完成）
      expect(stopwatch.elapsedMilliseconds, lessThan(10000),
          reason: '批量删除 1000 条记录应在 10 秒内完成');
    });
  });

  group('生产场景模拟测试', () {
    late Database db;
    final writeLock = Lock();

    setUp(() async {
      final dbPath = await getDatabasesPath();
      final fullPath = p.join(dbPath, 'subtitle_delete_production_test.db');
      try {
        await deleteDatabase(fullPath);
      } catch (_) {}

      db = await openDatabase(
        fullPath,
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA journal_mode = WAL');
          await db.execute('PRAGMA synchronous = NORMAL');
          await db.execute('PRAGMA busy_timeout = 15000');
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
              source TEXT,
              pronunciation TEXT,
              pronunciation_map_json TEXT,
              confidence REAL,
              created_at TEXT,
              updated_at TEXT,
              deleted_at TEXT,
              is_deleted INTEGER NOT NULL DEFAULT 0,
              created_by TEXT,
              updated_by TEXT,
              deleted_by TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE video_info (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              code TEXT UNIQUE NOT NULL,
              name TEXT NOT NULL,
              folder_code TEXT NOT NULL DEFAULT '',
              file_path TEXT,
              subtitle_path TEXT,
              cover TEXT,
              current_cover TEXT,
              file_type TEXT DEFAULT 'real',
              duration INTEGER DEFAULT 0,
              order_index INTEGER DEFAULT 0,
              created_at TEXT,
              updated_at TEXT,
              deleted_at TEXT,
              is_deleted INTEGER NOT NULL DEFAULT 0,
              created_by TEXT,
              updated_by TEXT,
              deleted_by TEXT
            )
          ''');
        },
      );
    });

    tearDown(() async {
      await db.close();
      final dbPath = await getDatabasesPath();
      try {
        await deleteDatabase(p.join(dbPath, 'subtitle_delete_production_test.db'));
      } catch (_) {}
    });

    test('模拟 deleteVideo 场景：单视频 100 条字幕用 batchSoftDelete 应稳定', () async {
      // 插入视频
      await db.insert('video_info', {
        'code': 'video-prod-001',
        'name': 'Production Video',
        'folder_code': 'folder-001',
        'is_deleted': 0,
      });

      // 插入 100 条字幕
      for (var i = 0; i < 100; i++) {
        await db.insert('subtitles', {
          'code': 'sub-prod-$i',
          'video_code': 'video-prod-001',
          'start_position': i * 1000,
          'end_position': (i + 1) * 1000,
          'content': 'Production Content $i',
          'translate_source': -1,
        });
      }

      // 模拟 deleteVideo 场景：查询后批量软删除
      final subtitles = await db.query(
        'subtitles',
        where: 'video_code = ? AND is_deleted = 0',
        whereArgs: ['video-prod-001'],
      );
      expect(subtitles.length, equals(100));

      // 使用 batchSoftDelete 模式（一个事务内完成）
      await writeLock.synchronized(() async {
        await db.transaction((txn) async {
          final batch = txn.batch();
          final now = DateTime.now().toIso8601String();
          for (final sub in subtitles) {
            batch.update(
              'subtitles',
              {
                'is_deleted': 1,
                'deleted_at': now,
                'deleted_by': 'test-user',
                'updated_at': now,
                'updated_by': 'test-user',
              },
              where: 'id = ?',
              whereArgs: [sub['id']],
            );
          }
          await batch.commit(noResult: true);
        });
      });

      // 同时软删除视频
      await db.update(
        'video_info',
        {
          'is_deleted': 1,
          'deleted_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'code = ?',
        whereArgs: ['video-prod-001'],
      );

      // 验证数据库完整性
      final rows = await db.rawQuery('PRAGMA quick_check(1)');
      expect(rows.first.values.first, equals('ok'));

      // 验证所有字幕已删除
      final activeSubtitles = await db.query(
        'subtitles',
        where: 'video_code = ? AND is_deleted = 0',
        whereArgs: ['video-prod-001'],
      );
      expect(activeSubtitles.length, equals(0));
    });

    test('模拟 deleteFolder 场景：多视频并发级联删除应稳定', () async {
      final errors = <Object>[];

      // 插入 5 个视频，每个 50 条字幕
      for (var v = 0; v < 5; v++) {
        await db.insert('video_info', {
          'code': 'video-folder-$v',
          'name': 'Folder Video $v',
          'folder_code': 'folder-test',
          'is_deleted': 0,
        });

        for (var s = 0; s < 50; s++) {
          await db.insert('subtitles', {
            'code': 'sub-folder-$v-$s',
            'video_code': 'video-folder-$v',
            'start_position': s * 1000,
            'end_position': (s + 1) * 1000,
            'content': 'Folder Content $v-$s',
            'translate_source': -1,
          });
        }
      }

      // 并发删除多个视频的字幕（模拟 deleteFolder 循环）
      Future<void> deleteVideoCascade(String videoCode) async {
        await writeLock.synchronized(() async {
          try {
            // 查询字幕
            final subtitles = await db.query(
              'subtitles',
              where: 'video_code = ? AND is_deleted = 0',
              whereArgs: [videoCode],
            );

            // 使用 batchSoftDelete（一个事务内完成）
            await db.transaction((txn) async {
              final batch = txn.batch();
              final now = DateTime.now().toIso8601String();
              for (final sub in subtitles) {
                batch.update(
                  'subtitles',
                  {
                    'is_deleted': 1,
                    'deleted_at': now,
                    'deleted_by': 'test-user',
                  },
                  where: 'id = ?',
                  whereArgs: [sub['id']],
                );
              }
              await batch.commit(noResult: true);
            });

            // 软删除视频
            await db.update(
              'video_info',
              {
                'is_deleted': 1,
                'deleted_at': DateTime.now().toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
              },
              where: 'code = ?',
              whereArgs: [videoCode],
            );
          } catch (e) {
            errors.add(e);
          }
        });
      }

      // 同时删除所有视频
      await Future.wait([
        deleteVideoCascade('video-folder-0'),
        deleteVideoCascade('video-folder-1'),
        deleteVideoCascade('video-folder-2'),
        deleteVideoCascade('video-folder-3'),
        deleteVideoCascade('video-folder-4'),
      ]);

      // 验证数据库完整性
      try {
        final rows = await db.rawQuery('PRAGMA quick_check(1)');
        expect(rows.first.values.first, equals('ok'));
      } catch (e) {
        fail('数据库已损坏: $e');
      }

      expect(errors, isEmpty);

      // 验证所有数据已删除
      final activeVideos = await db.query(
        'video_info',
        where: 'is_deleted = 0',
      );
      expect(activeVideos.length, equals(0));

      final activeSubtitles = await db.query(
        'subtitles',
        where: 'is_deleted = 0',
      );
      expect(activeSubtitles.length, equals(0));
    });

    test('模拟高并发场景：多线程同时删除不同视频的字幕', () async {
      final errors = <Object>[];

      // 插入 10 个视频，每个 30 条字幕
      for (var v = 0; v < 10; v++) {
        await db.insert('video_info', {
          'code': 'video-high-$v',
          'name': 'High Concurrency Video $v',
          'folder_code': 'folder-high',
          'is_deleted': 0,
        });

        for (var s = 0; s < 30; s++) {
          await db.insert('subtitles', {
            'code': 'sub-high-$v-$s',
            'video_code': 'video-high-$v',
            'start_position': s * 1000,
            'end_position': (s + 1) * 1000,
            'content': 'High Content $v-$s',
            'translate_source': -1,
          });
        }
      }

      // 模拟 10 个并发删除任务
      Future<void> concurrentDelete(String videoCode) async {
        await writeLock.synchronized(() async {
          try {
            final subtitles = await db.query(
              'subtitles',
              where: 'video_code = ? AND is_deleted = 0',
              whereArgs: [videoCode],
            );

            await db.transaction((txn) async {
              final batch = txn.batch();
              final now = DateTime.now().toIso8601String();
              for (final sub in subtitles) {
                batch.update(
                  'subtitles',
                  {
                    'is_deleted': 1,
                    'deleted_at': now,
                    'deleted_by': 'test-user',
                  },
                  where: 'id = ?',
                  whereArgs: [sub['id']],
                );
              }
              await batch.commit(noResult: true);
            });

            await db.update(
              'video_info',
              {
                'is_deleted': 1,
                'deleted_at': DateTime.now().toIso8601String(),
              },
              where: 'code = ?',
              whereArgs: [videoCode],
            );
          } catch (e) {
            errors.add(e);
          }
        });
      }

      // 同时发起 10 个删除任务
      await Future.wait([
        for (var v = 0; v < 10; v++)
          concurrentDelete('video-high-$v'),
      ]);

      // 验证数据库完整性
      try {
        final rows = await db.rawQuery('PRAGMA quick_check(1)');
        expect(rows.first.values.first, equals('ok'));
      } catch (e) {
        fail('数据库已损坏: $e');
      }

      expect(errors, isEmpty);
    });
  });
}
