import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_vscode_logger/flutter_vscode_logger.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:synchronized/synchronized.dart';
import 'package:uuid/uuid.dart';
import 'package:vidlang/models/article_sentence.dart';
import 'package:vidlang/models/subtitles.dart';

import '../models/base_entity.dart';

/// 实体配置类
///
/// 用于配置实体的创建方式和特性
class EntityConfig {
  /// 实体创建工厂
  ///
  /// 用于创建实体实例，如 () => VideoInfo()
  final BaseEntity Function() creator;

  /// 实体描述
  ///
  /// 用于文档和调试目的
  final String description;

  /// 是否启用全文检索
  ///
  /// 设为 true 时会自动创建 FTS5 虚拟表和触发器
  final bool enableFullTextSearch;

  EntityConfig({required this.creator, this.description = '', this.enableFullTextSearch = false});
}

/// 数据库服务类
///
/// 提供统一的数据库操作接口，支持：
/// - SQLite 数据库初始化和版本管理
/// - 实体自动注册和表创建
/// - 自动字段迁移（新增字段无需重建表）
/// - CRUD 操作（增删改查）
/// - 批量操作（批量插入、更新、删除）
/// - 全文检索（FTS5）
/// - 多用户数据隔离
/// - 当前用户/Token 管理
///
/// 使用前必须先注册实体：
/// ```dart
/// DatabaseService.registerEntities({
///   'video_info': EntityConfig(creator: () => VideoInfo()),
///   'subtitles': EntityConfig(creator: () => Subtitles(), enableFullTextSearch: true),
/// });
/// ```
class DatabaseService {
  /// 数据库实例（单例）
  static Database? _database;
  static String? _dbPathCache;

  /// 数据库名称
  static const String _databaseName = 'vidlang.db';

  /// 数据库版本号
  ///
  /// 用于数据库升级迁移。每次数据库结构发生变更（新增表、修改字段类型、数据迁移等）时，
  /// 必须递增此版本号，并在 [_onUpgrade] 中编写对应的迁移逻辑。
  static const int _databaseVersion = 2;

  /// 实体 Schema 哈希存储键名
  ///
  /// 用于在 config 表中存储上次启动时的实体结构哈希值
  static const String _schemaHashKey = 'db_schema_hash';

  /// 初始化并发控制锁（防止多线程同时打开数据库）
  static final Lock _initLock = Lock();

  /// 写操作并发控制锁（防止 SQLite 并发写入导致数据库损坏）
  static final Lock _writeLock = Lock();

  /// 上次检测是否通过的标志
  static bool _schemaCheckPassed = false;

  /// 已注册的实体配置映射
  static final Map<String, EntityConfig> _registeredEntities = {};

  /// 当前用户Code的配置键名
  static const String _currentUserCodeKey = 'current_user_code';

  /// 系统配置分类
  static const String _systemCategory = 'system';

  /// 注册单个实体
  ///
  /// [name] 实体名称（通常与 tableName 相同）
  /// [config] 实体配置
  static void registerEntity(String name, EntityConfig config) {
    _registeredEntities[name] = config;
  }

  /// 批量注册实体
  ///
  /// [entities] 实体配置映射
  static void registerEntities(Map<String, EntityConfig> entities) {
    _registeredEntities.addAll(entities);
  }

  /// 获取所有已注册的实体
  static Map<String, EntityConfig> get registeredEntities => _registeredEntities;

  /// 获取数据库实例
  ///
  /// 如果数据库未初始化，则自动初始化
  /// 返回数据库实例
  static Future<Database> get database async {
    // 使用初始化专用锁
    return await _initLock.synchronized(() async {
      if (_database != null && _database!.isOpen) {
        return _database!;
      }

      _database = await _initDatabase();
      return _database!;
    });
  }

  /// 初始化数据库
  ///
  /// 创建数据库文件并打开连接
  /// 触发 onCreate 和 onOpen 回调
  static Future<Database> _initDatabase() async {
    final path = await _resolveDbPath();
    try {
      // 先尝试重试打开（处理锁争用）
      return await _retryOnLockError<Database>(
        () => _openDatabaseAtPath(path),
        maxRetries: 3,
        baseDelayMs: 200,
      ) ?? await _openDatabaseAtPath(path);
    } catch (e, st) {
      logger.error('db open failed', tag: 'DB', error: e, stackTrace: st, extra: {'dbPath': path});
      try {
        if (_isDatabaseCorrupted(e)) {
          await _recoverCorruptedDatabase(e, st);
          return await _openDatabaseAtPath(path);
        }
      } catch (deleteError) {
        logger.error('db recovery failed', tag: 'DB', error: deleteError, extra: {'dbPath': path});
      }
      try {
        await _deleteDbFiles(path);
      } catch (_) {}
      return await _openDatabaseAtPath(path);
    }
  }

  static bool _isDatabaseCorrupted(Object e) {
    final s = e.toString().toLowerCase();
    // 仅将真正的文件损坏视为 corruption
    // "database is locked" 是锁争用问题，不应触发删除重建
    if (s.contains('database is locked') || s.contains('busy')) {
      return false;
    }
    return s.contains('database disk image is malformed') ||
        s.contains('malformed') ||
        s.contains('disk i/o error') ||
        s.contains('corrupt') ||
        s.contains('not a database');
  }

  /// 判断是否为锁争用错误（应重试而非删除重建）
  static bool _isLockError(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('database is locked') || s.contains('busy');
  }


  /// 运行时数据库损坏恢复
  ///
  /// 当运行中检测到数据库损坏时调用，
  /// 关闭损坏的连接，备份所有文件，删除后重新初始化数据库。
  static Future<void> _recoverRuntimeCorruption(Object error, StackTrace st) async {
    // 恢复数据库属于全局初始化级别操作，使用 _initLock
    await _initLock.synchronized(() async {
      final path = await _getDbPath();
      logger.fatal('database corrupted at runtime', tag: 'DB', error: error, stackTrace: st, extra: {'dbPath': path});

      // 关闭并清空损坏的数据库引用
      try {
        if (_database != null) {
          await _database!.close();
        }
      } catch (_) {}
      _database = null;

      // 等待文件锁释放
      await Future.delayed(const Duration(milliseconds: 200));

      // 备份所有数据库文件（主文件 + wal + shm）
      try {
        final ts = DateTime.now().millisecondsSinceEpoch;
        final backupPrefix = '$path.corrupt-$ts';
        await _backupDbFiles(path, backupPrefix);
        logger.warning('corrupted db backed up (including wal/shm)', tag: 'DB', extra: {'backupPrefix': backupPrefix});
      } catch (e) {
        logger.error('corrupted db backup failed', tag: 'DB', error: e);
      }

      // 尝试 ATTACH 导出救援：在删除前尽量把可读数据导出到新文件
      try {
        final exportPath = '$path.export-${DateTime.now().millisecondsSinceEpoch}';
        final exported = await _tryExportToNewDb(path, exportPath);
        if (exported) {
          logger.warning('data exported before recovery', tag: 'DB', extra: {'exportPath': exportPath});
        }
      } catch (e) {
        logger.error('export attempt failed', tag: 'DB', error: e);
      }

      // 删除所有数据库文件
      try {
        await _deleteDbFiles(path);
        logger.warning('corrupted db deleted for recovery', tag: 'DB', extra: {'dbPath': path});
      } catch (e) {
        logger.error('corrupted db delete failed', tag: 'DB', error: e, extra: {'dbPath': path});
      }

      // 重新初始化数据库
      try {
        _database = await _openDatabaseAtPath(path);
        logger.info('database re-initialized after runtime corruption', tag: 'DB', extra: {'dbPath': path});
      } catch (e, st) {
        logger.fatal('database re-init failed after runtime corruption', tag: 'DB', error: e, stackTrace: st);
        rethrow;
      }
    });
  }

  /// 尝试将损坏数据库的可读数据导出到新文件（ATTACH 方式）
  /// 返回 true 表示导出成功，新文件可用
  static Future<bool> _tryExportToNewDb(String corruptedPath, String newPath) async {
    Database? db;
    try {
      db = await openDatabase(corruptedPath, readOnly: true);
      await db.execute("ATTACH DATABASE ? AS newdb", [newPath]);

      // 获取所有用户表
      final tables = await db.rawQuery(
        "SELECT name, sql FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
      );

      for (final row in tables) {
        final name = row['name'] as String;
        final sql = (row['sql'] as String?) ?? '';

        // 在新库中创建表结构
        if (sql.isNotEmpty) {
          try {
            final createSql = sql.replaceFirst(
              RegExp(r'CREATE TABLE\s+' + RegExp.escape(name), caseSensitive: false),
              'CREATE TABLE newdb.$name',
            );
            await db.execute(createSql);
          } catch (_) {
            // 创建失败时用 SELECT AS 方式
            try {
              await db.execute('CREATE TABLE IF NOT EXISTS newdb.$name AS SELECT * FROM main.$name WHERE 0');
            } catch (_) {}
          }
        }

        // 复制数据
        try {
          await db.execute('INSERT INTO newdb.$name SELECT * FROM main.$name WHERE 1=1');
        } catch (_) {
          // 部分表可能因 corruption 无法复制，跳过
        }
      }

      await db.execute("DETACH DATABASE newdb");
      logger.warning('export to new db succeeded', tag: 'DB', extra: {'newPath': newPath, 'tables': tables.length});
      return true;
    } catch (e) {
      logger.error('export to new db failed', tag: 'DB', error: e);
      try {
        await db?.execute("DETACH DATABASE newdb");
      } catch (_) {}
      return false;
    } finally {
      try {
        await db?.close();
      } catch (_) {}
    }
  }

  static Future<String> _getLegacyDbPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return join(dir.path, _databaseName);
  }

  static Future<String> _getNewDbPath() async {
    final dir = await getApplicationSupportDirectory();
    return join(dir.path, _databaseName);
  }

  static Future<String> _resolveDbPath() async {
    if (_dbPathCache != null) return _dbPathCache!;

    final newPath = await _getNewDbPath();
    final legacyPath = await _getLegacyDbPath();

    final newFile = File(newPath);
    if (await newFile.exists()) {
      _dbPathCache = newPath;
      return newPath;
    }

    final legacyFile = File(legacyPath);
    if (await legacyFile.exists()) {
      try {
        await Directory(dirname(newPath)).create(recursive: true);
      } catch (_) {}

      try {
        await legacyFile.copy(newPath);
        await legacyFile.delete();
        logger.warning('db migrated', tag: 'DB', extra: {'from': legacyPath, 'to': newPath});
      } catch (e, st) {
        logger.error('db migrate failed', tag: 'DB', error: e, stackTrace: st, extra: {'from': legacyPath, 'to': newPath});
      }
    }

    _dbPathCache = newPath;
    return newPath;
  }

  static Future<String> _getDbPath() async {
    return _resolveDbPath();
  }

  /// 备份数据库文件（包括 -wal 和 -shm）
  static Future<void> _backupDbFiles(String path, String backupPrefix) async {
    final main = File(path);
    final wal = File('$path-wal');
    final shm = File('$path-shm');

    if (await main.exists()) {
      await main.copy('$backupPrefix.db');
    }
    if (await wal.exists()) {
      await wal.copy('$backupPrefix.db-wal');
    }
    if (await shm.exists()) {
      await shm.copy('$backupPrefix.db-shm');
    }
  }

  /// 删除数据库文件（包括 -wal 和 -shm）
  static Future<void> _deleteDbFiles(String path) async {
    for (final suffix in ['', '-wal', '-shm']) {
      try {
        final f = File('$path$suffix');
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }

  /// 重试逻辑：指数退避重试（用于锁争用场景）
  static Future<T?> _retryOnLockError<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    int baseDelayMs = 200,
  }) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        return await operation();
      } catch (e) {
        if (_isLockError(e) && attempt < maxRetries - 1) {
          final delay = baseDelayMs * (1 << attempt); // 200, 400, 800
          await Future.delayed(Duration(milliseconds: delay));
          continue;
        }
        rethrow;
      }
    }
    return null;
  }

  /// 检查数据库完整性
  /// 返回 true 表示数据库完好，false 表示已损坏
  static Future<bool> _checkIntegrity(Database db) async {
    try {
      final rows = await db.rawQuery('PRAGMA integrity_check;');
      if (rows.isEmpty) return false;
      final v = rows.first.values.first?.toString() ?? '';
      return v.toLowerCase() == 'ok';
    } catch (e) {
      logger.error('integrity_check failed', tag: 'DB', error: e);
      return false;
    }
  }

  /// 异常时备份三个数据库文件（主文件 + wal + shm）
  static Future<void> _backupDbOnException(String path, String tag) async {
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final backupPrefix = '$path.err-$ts-$tag';
      await _backupDbFiles(path, backupPrefix);
      logger.warning('db backed up on exception', tag: 'DB', extra: {'backupPrefix': backupPrefix, 'trigger': tag});
    } catch (e) {
      logger.error('db backup on exception failed', tag: 'DB', error: e);
    }
  }

  static Future<void> _onConfigure(Database db) async {
    try {
      await db.execute('PRAGMA foreign_keys = ON');
    } catch (_) {}
    try {
      // WAL 模式：提升并发写和崩溃恢复能力
      await db.execute('PRAGMA journal_mode = WAL');
    } catch (_) {}
    try {
      // iOS APFS 文件系统下 NORMAL 模式配合 WAL checkpoint(TRUNCATE) 
      // 会导致数据库文件头损坏，iOS 平台强制使用 FULL
      if (Platform.isIOS) {
        await db.execute('PRAGMA synchronous = FULL');
      } else {
        await db.execute('PRAGMA synchronous = NORMAL');
      }
    } catch (_) {}
    try {
      await db.execute('PRAGMA busy_timeout = 15000');
    } catch (_) {}
  }

  static Future<void> _checkDatabaseHealth(Database db, String path) async {
    try {
      final rows = await db.rawQuery('PRAGMA quick_check(1)');
      final v = rows.isNotEmpty ? rows.first.values.first : null;
      if (v != 'ok') {
        throw Exception('PRAGMA quick_check failed: $rows');
      }
    } catch (e, st) {
      logger.error('db quick_check failed', tag: 'DB', error: e, stackTrace: st, extra: {'dbPath': path});
      rethrow;
    }
  }

  static Future<Database> _openDatabaseAtPath(String path) async {
    final db = await openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: _onOpen,
    );
    // PRAGMA quick_check 失败说明数据库确实损坏了，直接抛出异常让上层恢复
    await _checkDatabaseHealth(db, path);
    return db;
  }

  static Future<void> _recoverCorruptedDatabase(Object error, StackTrace st) async {
    final path = await _getDbPath();
    logger.fatal('database corrupted', tag: 'DB', error: error, stackTrace: st, extra: {'dbPath': path});

    try {
      if (_database != null) {
        await _database!.close();
      }
    } catch (_) {}
    _database = null;

    // 等待文件锁释放
    await Future.delayed(const Duration(milliseconds: 200));

    // 备份所有数据库文件（主文件 + wal + shm）
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final backupPrefix = '$path.corrupt-$ts';
      await _backupDbFiles(path, backupPrefix);
      logger.warning('database backed up (including wal/shm)', tag: 'DB', extra: {'backupPrefix': backupPrefix});
    } catch (e) {
      logger.error('database backup failed', tag: 'DB', error: e);
    }

    // 删除所有数据库文件
    try {
      await _deleteDbFiles(path);
      logger.warning('database files deleted for recovery', tag: 'DB', extra: {'dbPath': path});
    } catch (e) {
      logger.error('database delete failed', tag: 'DB', error: e, extra: {'dbPath': path});
    }

    try {
      _database = await _openDatabaseAtPath(path);
    } catch (e, st) {
      logger.fatal('database re-init failed', tag: 'DB', error: e, stackTrace: st);
      rethrow;
    }
  }

  static Future<void> _tryInsertErrorLog(Database db, Map<String, Object?> map) async {
    try {
      await db.insert('error_log', map);
    } catch (_) {}
  }

  /// 数据库创建回调
  ///
  /// [db] 数据库实例
  /// [version] 数据库版本号
  ///
  /// 首次创建数据库时调用，创建所有已注册实体的表
  static Future<void> _onCreate(Database db, int version) async {
    for (var config in _registeredEntities.values) {
      BaseEntity entity = config.creator();
      await _createTable(db, entity, config.enableFullTextSearch);
    }
  }

  /// 数据库升级回调
  ///
  /// [db] 数据库实例
  /// [oldVersion] 旧版本号
  /// [newVersion] 新版本号
  ///
  /// 当应用升级导致数据库版本号增加时调用。
  /// 按版本号逐步执行迁移脚本，确保每个版本的升级逻辑都被执行。
  ///
  /// 迁移原则：
  /// 1. 新增表：在对应版本号中创建
  /// 2. 新增字段：优先使用 [_autoMigrateTable] 自动补齐，复杂场景在此处理
  /// 3. 字段类型变更：SQLite 不支持 ALTER COLUMN，需重建表
  /// 4. 数据迁移：在此执行数据转换逻辑
  ///
  /// 示例：
  /// ```dart
  /// if (oldVersion < 2) {
  ///   // v1 -> v2: 新增 learning_activity 表
  ///   await _createTable(db, LearningActivity(), false);
  /// }
  /// if (oldVersion < 3) {
  ///   // v2 -> v3: 修改某表字段类型（需重建表）
  ///   await _rebuildTableWithNewSchema(db, 'some_table', ...);
  /// }
  /// ```
  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    logger.info('database upgrading', tag: 'DB', extra: {'oldVersion': oldVersion, 'newVersion': newVersion});

    try {
      // 按版本号逐步执行迁移
      if (oldVersion < 2) {
        // v1 -> v2: 自动补齐所有已注册实体的新字段和新表
        // 此版本引入了系统化的自动迁移机制，确保所有表结构一致
        for (var entry in _registeredEntities.entries) {
          BaseEntity entity = entry.value.creator();
          await _autoMigrateTable(db, entity, enableFTS: entry.value.enableFullTextSearch);
        }
      }

      // 后续版本迁移在此继续添加：
      // if (oldVersion < 3) { ... }
      // if (oldVersion < 4) { ... }

      logger.info('database upgrade completed', tag: 'DB', extra: {'from': oldVersion, 'to': newVersion});
    } catch (e, st) {
      logger.error('database upgrade failed', tag: 'DB', error: e, stackTrace: st, extra: {'oldVersion': oldVersion, 'newVersion': newVersion});
      rethrow;
    }
  }

  // ============================================================
  // 启动时 Schema 强制检测（防遗忘版本号导致的事故）
  // ============================================================

  /// 计算当前所有注册实体的 Schema 哈希
  ///
  /// 基于所有实体的表名、字段名和字段类型生成唯一指纹。
  /// 当任何实体新增/删除字段、新增/删除表时，哈希值都会改变。
  ///
  /// 返回 SHA-256 哈希字符串
  static String _computeSchemaHash() {
    final buffer = StringBuffer();

    // 按表名排序确保顺序一致
    final sortedEntries = _registeredEntities.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    for (final entry in sortedEntries) {
      final entity = entry.value.creator();
      buffer.write('TABLE:${entity.tableName};');

      final map = entity.toMap();
      // 按字段名排序确保顺序一致
      final sortedKeys = map.keys.toList()..sort();
      for (final key in sortedKeys) {
        final type = _getColumnType(map[key]);
        buffer.write('$key:$type;');
      }
      buffer.write('FTS:${entry.value.enableFullTextSearch};');
    }

    final bytes = utf8.encode(buffer.toString());
    return sha256.convert(bytes).toString();
  }

  /// 启动时强制检测数据库结构一致性
  ///
  /// 此方法必须在应用启动时、进入主界面之前调用。
  /// 它会对比当前代码中的实体定义和数据库实际结构，
  /// 如果不一致，自动执行迁移修复。
  ///
  /// 检测逻辑：
  /// 1. 计算当前所有注册实体的 Schema 哈希
  /// 2. 读取数据库中保存的上次哈希
  /// 3. 如果哈希不一致，执行全量自动迁移
  /// 4. 保存新的哈希到数据库
  ///
  /// 返回 true 表示检测通过（或修复成功），false 表示检测/修复失败
  static Future<bool> verifySchemaOnStartup() async {
    if (_schemaCheckPassed) return true;

    try {
      final db = await database;
      final currentHash = _computeSchemaHash();

      // 读取上次保存的哈希
      String? savedHash;
      try {
        final rows = await db.rawQuery('SELECT value FROM config WHERE category = ? AND key = ? AND is_deleted = 0', [
          _systemCategory,
          _schemaHashKey,
        ]);
        if (rows.isNotEmpty) {
          savedHash = rows.first['value'] as String?;
        }
      } catch (_) {
        // config 表可能不存在（首次启动），忽略错误
      }

      // 如果哈希一致，说明结构没有变化，快速通过
      if (savedHash == currentHash) {
        _schemaCheckPassed = true;
        logger.info('schema check passed (hash match)', tag: 'DB', extra: {'hash': currentHash.substring(0, 16)});
        return true;
      }

      // 哈希不一致，需要执行自动迁移
      logger.warning(
        'schema mismatch detected, auto migrating',
        tag: 'DB',
        extra: {'savedHash': savedHash?.substring(0, 16), 'currentHash': currentHash.substring(0, 16)},
      );

      // 执行全量自动迁移：补齐所有缺失的表和字段
      for (final entry in _registeredEntities.entries) {
        final entity = entry.value.creator();
        await _autoMigrateTable(db, entity, enableFTS: entry.value.enableFullTextSearch);
      }

      // 保存新的哈希
      await _saveSchemaHash(db, currentHash);

      _schemaCheckPassed = true;
      logger.info('schema auto migration completed', tag: 'DB', extra: {'hash': currentHash.substring(0, 16)});
      return true;
    } catch (e, st) {
      logger.error('schema verification failed', tag: 'DB', error: e, stackTrace: st);
      return false;
    }
  }

  /// 保存 Schema 哈希到数据库
  static Future<void> _saveSchemaHash(Database db, String hash) async {
    try {
      final rows = await db.rawQuery('SELECT id FROM config WHERE category = ? AND key = ? AND is_deleted = 0', [_systemCategory, _schemaHashKey]);

      final now = DateTime.now().toIso8601String();
      final map = <String, dynamic>{'category': _systemCategory, 'key': _schemaHashKey, 'value_type': 'string', 'value': hash, 'updated_at': now};

      if (rows.isNotEmpty) {
        await db.update('config', map, where: 'id = ?', whereArgs: [rows.first['id']]);
      } else {
        map['code'] = const Uuid().v4().replaceAll('-', '');
        map['created_at'] = now;
        map['is_deleted'] = 0;
        await db.insert('config', map);
      }
    } catch (e, st) {
      // config 表可能不存在，忽略错误
      logger.warning('save schema hash failed', tag: 'DB', extra: {'error': e.toString(), 'stackTrace': st.toString()});
    }
  }

  /// 重置 Schema 检测状态
  ///
  /// 用于测试或需要重新检测的场景
  static void resetSchemaCheck() {
    _schemaCheckPassed = false;
  }

  /// 数据库打开回调
  ///
  /// [db] 数据库实例
  ///
  /// 每次打开数据库时调用，执行自动迁移
  static Future<void> _onOpen(Database db) async {
    for (var entry in _registeredEntities.entries) {
      BaseEntity entity = entry.value.creator();
      await _autoMigrateTable(db, entity, enableFTS: entry.value.enableFullTextSearch);
    }
    await _migrateLocalUserPasswordHash(db);
    await _ensureIndexes(db);
  }

  /// 为高频查询字段创建索引，避免全表扫描导致 IO 压力
  static Future<void> _ensureIndexes(Database db) async {
    const indexes = [
      'CREATE INDEX IF NOT EXISTS idx_subtitles_code ON subtitles(code)',
      'CREATE INDEX IF NOT EXISTS idx_article_sentence_code ON article_sentence(code)',
      'CREATE INDEX IF NOT EXISTS idx_subtitles_video_code ON subtitles(video_code)',
      'CREATE INDEX IF NOT EXISTS idx_article_sentence_article_code ON article_sentence(article_code)',
      'CREATE INDEX IF NOT EXISTS idx_study_record_user_code ON study_record(user_code)',
      'CREATE INDEX IF NOT EXISTS idx_word_book_user_code ON word_book(user_code)',
    ];
    for (final sql in indexes) {
      try {
        await db.execute(sql);
      } catch (_) {}
    }
  }

  static bool _looksLikeSha256(String value) => RegExp(r'^[a-f0-9]{64}$').hasMatch(value);

  static Future<void> _migrateLocalUserPasswordHash(Database db) async {
    try {
      final rows = await db.rawQuery(
        "SELECT id, password FROM user WHERE is_deleted = 0 AND (auth_provider IS NULL OR auth_provider = 'local') AND password IS NOT NULL AND password != ''",
      );
      for (final row in rows) {
        final id = row['id'];
        final password = row['password']?.toString() ?? '';
        if (id == null || password.isEmpty || _looksLikeSha256(password)) continue;
        final hashed = sha256.convert(utf8.encode(password)).toString();
        await db.update('user', {'password': hashed}, where: 'id = ?', whereArgs: [id]);
      }
    } catch (_) {}
  }

  /// 创建数据表
  ///
  /// [db] 数据库实例
  /// [entity] 实体实例
  /// [enableFTS] 是否启用全文检索
  ///
  /// 如果启用全文检索，会创建对应的 FTS5 虚拟表和触发器
  static Future<void> _createTable(Database db, BaseEntity entity, bool enableFTS) async {
    String tableName = entity.tableName;
    Map<String, dynamic> map = entity.toMap();

    StringBuffer columns = StringBuffer();
    // 主键
    columns.write('id INTEGER PRIMARY KEY AUTOINCREMENT');

    // 用于创建 FTS 表的文本列
    Map<String, String> textColumns = {};

    map.forEach((key, value) {
      if (key != 'id') {
        String columnType = _getColumnType(value);
        String nullable = _isNullable(value) ? '' : ' NOT NULL';
        columns.write(', $key $columnType$nullable');

        // 记录文本列用于 FTS
        if (columnType == 'TEXT' && key != 'code') {
          textColumns[key] = columnType;
        }
      }
    });

    // 创建表
    String createSql = 'CREATE TABLE IF NOT EXISTS $tableName ($columns)';
    await db.execute(createSql);

    // 如果启用全文检索，创建 FTS 虚拟表和触发器
    // 注意：Android 某些设备可能不支持 FTS5，需要捕获异常
    if (enableFTS && textColumns.isNotEmpty) {
      try {
        String ftsTableName = '${tableName}_fts';
        String ftsColumns = textColumns.keys.join(', ');

        // 创建 FTS5 虚拟表
        String createFtsSql =
            '''
          CREATE VIRTUAL TABLE IF NOT EXISTS $ftsTableName 
          USING FTS5($ftsColumns, content=$tableName, content_rowid=id)
        ''';
        await db.execute(createFtsSql);

        // 插入触发器
        await db.execute('''
          CREATE TRIGGER IF NOT EXISTS ${tableName}_after_insert 
          AFTER INSERT ON $tableName BEGIN
            INSERT INTO $ftsTableName(rowid, $ftsColumns) 
            VALUES (new.id, ${textColumns.keys.map((k) => 'new.$k').join(', ')});
          END
        ''');

        // 更新触发器
        await db.execute('''
          CREATE TRIGGER IF NOT EXISTS ${tableName}_after_update 
          AFTER UPDATE ON $tableName BEGIN
            UPDATE $ftsTableName SET 
              ${textColumns.keys.map((k) => '$k = new.$k').join(', ')}
            WHERE rowid = old.id;
          END
        ''');

        // 删除触发器
        await db.execute('''
          CREATE TRIGGER IF NOT EXISTS ${tableName}_after_delete 
          AFTER DELETE ON $tableName BEGIN
            DELETE FROM $ftsTableName WHERE rowid = old.id;
          END
        ''');
      } catch (e) {
        // FTS5 不支持时静默处理，不影响应用正常运行
        // Android 某些设备的 SQLite 可能不包含 FTS5 模块
      }
    }
  }

  /// 自动迁移表结构
  ///
  /// [db] 数据库实例
  /// [entity] 实体实例
  /// [enableFTS] 是否启用全文检索
  ///
  /// 自动检测并添加新字段和新表，无需重建表。
  /// 对于已存在的表，会：
  /// 1. 检测实体定义中新增的普通字段，自动执行 ALTER TABLE ADD COLUMN
  /// 2. 检测 FTS5 虚拟表是否存在，不存在则创建并回填历史数据
  /// 3. 检测 FTS 触发器是否存在，不存在则创建
  static Future<void> _autoMigrateTable(Database db, BaseEntity entity, {bool enableFTS = false}) async {
    String tableName = entity.tableName;

    List<Map<String, dynamic>> existingColumns = await db.rawQuery('PRAGMA table_info($tableName)');

    // 表不存在时直接建表（例如后注册的实体）
    if (existingColumns.isEmpty) {
      await _createTable(db, entity, enableFTS);
      return;
    }

    Set<String> existingColumnNames = existingColumns.map((col) => col['name'] as String).toSet();

    Map<String, dynamic> entityMap = entity.toMap();
    Map<String, String> textColumns = {};
    bool hasNewColumns = false;

    for (var entry in entityMap.entries) {
      String columnName = entry.key;
      // id 由建表语句单独处理，且 toMap 里常为 null，不可 ALTER 成 TEXT
      if (columnName == 'id' || existingColumnNames.contains(columnName)) {
        continue;
      }
      String columnType = _getColumnType(entry.value);
      await db.execute('ALTER TABLE $tableName ADD COLUMN $columnName $columnType');
      hasNewColumns = true;

      // 记录文本列用于 FTS 检测
      if (columnType == 'TEXT' && columnName != 'code') {
        textColumns[columnName] = columnType;
      }
    }

    // 如果启用了 FTS，检查并补齐 FTS 虚拟表和触发器
    if (enableFTS) {
      await _autoMigrateFTS(db, tableName, entityMap, existingColumnNames);
    }

    if (hasNewColumns) {
      logger.info(
        'table auto migrated',
        tag: 'DB',
        extra: {'table': tableName, 'newColumns': entityMap.keys.where((k) => k != 'id' && !existingColumnNames.contains(k)).toList()},
      );
    }
  }

  /// 自动补齐 FTS5 虚拟表和触发器
  ///
  /// [db] 数据库实例
  /// [tableName] 主表名
  /// [entityMap] 实体字段映射
  /// [existingColumnNames] 已存在的列名集合
  ///
  /// 检测 FTS 虚拟表和触发器是否存在，不存在则创建，并回填历史数据。
  static Future<void> _autoMigrateFTS(Database db, String tableName, Map<String, dynamic> entityMap, Set<String> existingColumnNames) async {
    String ftsTableName = '${tableName}_fts';

    // 收集所有文本列（包括新添加的和已存在的）
    Map<String, String> textColumns = {};
    for (var entry in entityMap.entries) {
      String columnName = entry.key;
      if (columnName == 'id' || columnName == 'code') continue;
      dynamic value = entry.value;
      if (value == null || value is String || value is DateTime) {
        textColumns[columnName] = 'TEXT';
      }
    }

    if (textColumns.isEmpty) return;

    String ftsColumns = textColumns.keys.join(', ');

    try {
      // 检查 FTS 表是否存在
      final ftsExists = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name=?", [ftsTableName]);

      if (ftsExists.isEmpty) {
        // 创建 FTS5 虚拟表
        String createFtsSql =
            '''
          CREATE VIRTUAL TABLE IF NOT EXISTS $ftsTableName 
          USING FTS5($ftsColumns, content=$tableName, content_rowid=id)
        ''';
        await db.execute(createFtsSql);
        logger.info('fts table created', tag: 'DB', extra: {'table': ftsTableName});

        // 回填历史数据
        await db.execute('''
          INSERT INTO $ftsTableName(rowid, $ftsColumns)
          SELECT id, ${textColumns.keys.join(', ')} FROM $tableName WHERE is_deleted = 0
        ''');
        logger.info('fts data backfilled', tag: 'DB', extra: {'table': ftsTableName});
      }

      // 检查并补齐触发器
      final triggers = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='trigger' AND tbl_name=?", [tableName]);
      Set<String> existingTriggerNames = triggers.map((t) => t['name'] as String).toSet();

      String insertTrigger = '${tableName}_after_insert';
      String updateTrigger = '${tableName}_after_update';
      String deleteTrigger = '${tableName}_after_delete';

      if (!existingTriggerNames.contains(insertTrigger)) {
        await db.execute('''
          CREATE TRIGGER IF NOT EXISTS $insertTrigger 
          AFTER INSERT ON $tableName BEGIN
            INSERT INTO $ftsTableName(rowid, $ftsColumns) 
            VALUES (new.id, ${textColumns.keys.map((k) => 'new.$k').join(', ')});
          END
        ''');
      }

      if (!existingTriggerNames.contains(updateTrigger)) {
        await db.execute('''
          CREATE TRIGGER IF NOT EXISTS $updateTrigger 
          AFTER UPDATE ON $tableName BEGIN
            UPDATE $ftsTableName SET 
              ${textColumns.keys.map((k) => '$k = new.$k').join(', ')}
            WHERE rowid = old.id;
          END
        ''');
      }

      if (!existingTriggerNames.contains(deleteTrigger)) {
        await db.execute('''
          CREATE TRIGGER IF NOT EXISTS $deleteTrigger 
          AFTER DELETE ON $tableName BEGIN
            DELETE FROM $ftsTableName WHERE rowid = old.id;
          END
        ''');
      }
    } catch (e) {
      // FTS5 不支持时静默处理，不影响应用正常运行
      logger.warning('fts auto migrate skipped', tag: 'DB', extra: {'table': tableName, 'error': e.toString()});
    }
  }

  /// 批量 UPDATE 后恢复 FTS5 索引和触发器
  ///
  /// [db] 数据库实例
  /// [tableNames] 需要恢复的表名列表（如 ['subtitles', 'article_sentence']）
  ///
  /// 先执行 `INSERT INTO fts_table(fts_table) VALUES('rebuild')` 全量重建索引，
  /// 再通过 `_autoMigrateFTS` 重新创建之前被 DROP 的 AFTER UPDATE 触发器。
  static Future<void> _restoreFTSAfterBatch(Database db, List<String> tableNames) async {
    for (final tableName in tableNames) {
      final ftsTableName = '${tableName}_fts';
      // 全量重建 FTS5 全文索引（从 content= 外部内容表重新读取）
      try {
        await db.execute("INSERT INTO $ftsTableName($ftsTableName) VALUES('rebuild')");
        logger.info('fts rebuilt after batch', tag: 'DB', extra: {'table': ftsTableName});
      } catch (e) {
        logger.error('fts rebuild failed', tag: 'DB', error: e, extra: {'table': ftsTableName});
      }

      // 恢复被 DROP 的触发器
      try {
        final config = _registeredEntities[tableName];
        if (config != null) {
          final entity = config.creator();
          final existingColumns = (await db.rawQuery('PRAGMA table_info($tableName)'))
              .map((c) => c['name'] as String)
              .toSet();
          await _autoMigrateFTS(db, tableName, entity.toMap(), existingColumns);
          logger.info('fts triggers restored after batch', tag: 'DB', extra: {'table': tableName});
        }
      } catch (e) {
        logger.error('fts trigger restore failed', tag: 'DB', error: e, extra: {'table': tableName});
      }
    }
  }

  /// 获取 Dart 类型对应的 SQLite 列类型
  ///
  /// [value] 字段值
  /// 返回 SQLite 列类型字符串
  static String _getColumnType(dynamic value) {
    if (value == null) return 'TEXT';
    if (value is int) return 'INTEGER';
    if (value is double) return 'REAL';
    if (value is bool) return 'INTEGER';
    if (value is DateTime) return 'TEXT';
    return 'TEXT';
  }

  /// 判断字段是否可为空
  ///
  /// [value] 字段值
  /// 返回是否可为空
  static bool _isNullable(dynamic value) {
    return value == null;
  }

  /// 执行原生 SQL
  ///
  /// [sql] SQL 语句
  /// [arguments] 参数列表
  static Future<void> execute(String sql, [List<Object?>? arguments]) async {
    final db = await database;
    await db.execute(sql, arguments);
  }

  /// 执行原生查询（复杂 JOIN、聚合等场景）
  ///
  /// [sql] SQL 查询语句
  /// [arguments] 参数列表
  /// 返回查询结果
  static Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<Object?>? arguments]) async {
    final db = await database;
    return await db.rawQuery(sql, arguments);
  }

  static bool _isMissingColumnError(Object error) {
    final s = error.toString();
    return s.contains('has no column named');
  }

  static String? _extractMissingColumnName(Object error) {
    final s = error.toString();
    final m = RegExp(r'has no column named\s+([a-zA-Z0-9_]+)').firstMatch(s);
    return m?.group(1);
  }

  static Future<void> _autoMigrateEntity(Database db, BaseEntity entity) async {
    final config = _registeredEntities[entity.tableName];
    await _autoMigrateTable(db, entity, enableFTS: config?.enableFullTextSearch ?? false);
  }

  /// 插入单条记录
  ///
  /// [entity] 要插入的实体
  /// 返回插入记录的自增ID
  static Future<int> insert(BaseEntity entity) async {
    // 1. 在锁外获取数据库实例（get database 内部使用了 _initLock）
    final db = await database;
    final userCode = await getCurrentUserCode();

    // 2. 用 _writeLock 包裹写操作
    return await _writeLock.synchronized(() async {
      entity.code ??= const Uuid().v4().replaceAll('-', '');
      if (entity.code != null && entity.code!.isEmpty) {
        entity.code = const Uuid().v4().replaceAll('-', '');
      }
      entity.createdAt = DateTime.now();
      entity.updatedAt = DateTime.now();
      entity.isDeleted = false;
      if (entity.tableName != 'user') {
        entity.userCode ??= userCode;
      }
      entity.createdBy ??= userCode;
      entity.updatedBy ??= userCode;

      Map<String, dynamic> map = entity.toMap();
      map.remove('id'); // 移除 id，让数据库自动生成
      try {
        int insertedId = await db.insert(entity.tableName, map, conflictAlgorithm: ConflictAlgorithm.replace);
        entity.id = insertedId;
        return insertedId;
      } catch (e, st) {
        if (_isMissingColumnError(e)) {
          final missing = _extractMissingColumnName(e);
          logger.warning(
            'db missing column, auto migrate and retry insert',
            tag: 'DB',
            extra: {'table': entity.tableName, 'missing': missing, 'code': entity.code},
          );
          await _autoMigrateEntity(db, entity);
          final retryMap = entity.toMap()..remove('id');
          final insertedId = await db.insert(entity.tableName, retryMap, conflictAlgorithm: ConflictAlgorithm.replace);
          entity.id = insertedId;
          return insertedId;
        }
        logger.error('db insert failed', tag: 'DB', error: e, stackTrace: st, extra: {'table': entity.tableName, 'code': entity.code});
        rethrow;
      }
    });
  }

  /// 批量插入记录
  ///
  /// [entities] 要插入的实体列表
  /// 返回插入记录的ID列表
  static Future<List<int>> batchInsert(List<BaseEntity> entities) async {
    if (entities.isEmpty) return [];

    final db = await database;
    final userCode = await getCurrentUserCode();
    final tableName = entities.first.tableName;
    List<int> insertedIds = [];

    return await _writeLock.synchronized(() async {
      await _autoMigrateEntity(db, entities.first);

      await db.transaction((txn) async {
        for (var entity in entities) {
          entity.code ??= const Uuid().v4().replaceAll('-', '');
          if (entity.code != null && entity.code!.isEmpty) {
            entity.code = const Uuid().v4().replaceAll('-', '');
          }
          entity.createdAt = DateTime.now();
          entity.updatedAt = DateTime.now();
          entity.isDeleted = false;
          if (tableName != 'user') {
            entity.userCode ??= userCode;
          }
          entity.createdBy ??= userCode;
          entity.updatedBy ??= userCode;

          Map<String, dynamic> map = entity.toMap();
          map.remove('id');

          int insertedId = await txn.insert(tableName, map);
          entity.id = insertedId;
          insertedIds.add(insertedId);
        }
      }, exclusive: true);

      return insertedIds;
    });
  }

  /// 更新单条记录
  ///
  /// [entity] 要更新的实体
  /// 返回影响行数
  static Future<int> update(BaseEntity entity) async {
    // 1. 在锁外获取数据库实例（防止死锁）
    final db = await database;

    // 2. 用 _writeLock 包裹写操作
    return await _writeLock.synchronized(() async {
      // 确保表结构匹配实体定义，防止因缺少列导致事务内 SQL 错误
      await _autoMigrateEntity(db, entity);
      entity.updatedAt = DateTime.now();
      // 锁争用重试
      return await _retryOnLockError<int>(() async {
        try {
          final map = entity.toMap();
          map.remove('id');
          map.removeWhere((key, value) => value == null);
          return await db.update(entity.tableName, map, where: 'id = ?', whereArgs: [entity.id]);
        } catch (e, st) {
          if (_isLockError(e)) rethrow;
          if (_isDatabaseCorrupted(e)) {
            logger.fatal('db corrupted during update, attempting recovery', tag: 'DB', error: e, stackTrace: st);
            await _recoverRuntimeCorruption(e, st);
            return 0;
          }
          logger.error(
            'db update failed',
            tag: 'DB',
            error: e,
            stackTrace: st,
            extra: {'table': entity.tableName, 'id': entity.id, 'code': entity.code},
          );
          await _tryInsertErrorLog(db, {
            'code': const Uuid().v4().replaceAll('-', ''),
            'user_code': entity.userCode,
            'level': 'error',
            'tag': 'DB',
            'message': 'db update failed',
            'error': e.toString(),
            'stack_trace': st.toString(),
            'extra': '{"table":"${entity.tableName}","id":${entity.id},"code":"${entity.code}"}',
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
            'is_deleted': 0,
            'created_by': entity.userCode,
            'updated_by': entity.userCode,
          });
          rethrow;
        }
      }, maxRetries: 3, baseDelayMs: 200) ?? 0;
    });
  }

  /// 轻量级专用：根据 code 仅更新实体的翻译字段
  /// 避免使用 toMap() 全量更新引发的潜在空字段或 SQLite 约束问题
  static Future<int> updateTranslationsByCode(List<BaseEntity> entities) async {
    if (entities.isEmpty) return 0;

    return await _doUpdateTranslationsByCode(entities, retry: true);
  }

  static Future<int> _doUpdateTranslationsByCode(List<BaseEntity> entities, {bool retry = true}) async {
    if (entities.isEmpty) return 0;

    // 与其他写入操作串行化，防止并发写入导致数据库损坏
    return await _writeLock.synchronized(() async {
      final db = await database;
      final path = await _getDbPath();
      final subtitles = entities.whereType<Subtitles>().toList();
      final articleSentences = entities.whereType<ArticleSentence>().toList();
      final totalCount = subtitles.length + articleSentences.length;

      // 诊断日志：记录更新前的环境信息
      final sw = Stopwatch()..start();
      logger.info(
        'translation batch update start',
        tag: 'DB',
        extra: {'subtitles': subtitles.length, 'sentences': articleSentences.length, 'total': totalCount},
      );

      // 1. Pre-check：检查数据库完整性
      final integrityOk = await _checkIntegrity(db);
      if (!integrityOk) {
        logger.fatal('pre-update integrity_check failed, aborting', tag: 'DB', extra: {'total': totalCount});
        await _backupDbOnException(path, 'pre-check-failed');
        throw Exception('db integrity check failed before translation update');
      }

      // 2. WAL checkpoint 已移除：SQLite WAL 模式下会自动管理 WAL 文件
      //    iOS APFS + synchronous=NORMAL 下手动 TRUNCATE checkpoint 会导致文件头损坏（SQLITE_NOTADB）

      // 3. 禁用所有 FTS5 触发器（INSERT/UPDATE/DELETE）
      //    批量 UPDATE 时触发器会同步写 FTS5 虚拟表，
      //    在 WAL 模式下可能导致 SQLITE_NOTADB 或 corruption。
      //    事务完成后手动 REBUILD 索引并恢复触发器。
      final ftsTablesToRestore = <String>[];
      const ftsTriggerSuffixes = ['after_insert', 'after_update', 'after_delete'];
      if (subtitles.isNotEmpty) {
        for (final suffix in ftsTriggerSuffixes) {
          try {
            await db.execute('DROP TRIGGER IF EXISTS subtitles_$suffix');
          } catch (_) {}
        }
        ftsTablesToRestore.add('subtitles');
      }
      if (articleSentences.isNotEmpty) {
        for (final suffix in ftsTriggerSuffixes) {
          try {
            await db.execute('DROP TRIGGER IF EXISTS article_sentence_$suffix');
          } catch (_) {}
        }
        ftsTablesToRestore.add('article_sentence');
      }

      Future<int> doUpdate() async {
        int updatedCount = 0;

        // 使用 batch 在单个事务内提交所有更新，避免逐条独立事务
        final batch = db.batch();

        for (final sub in subtitles) {
          if (sub.code == null || sub.code!.isEmpty) continue;
          if (sub.contentTranslate == null) continue;
          batch.update(
            sub.tableName,
            {
              'content_translate': sub.contentTranslate,
              'translate_source': sub.translateSource,
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'code = ?',
            whereArgs: [sub.code],
          );
        }

        for (final sentence in articleSentences) {
          if (sentence.code == null || sentence.code!.isEmpty) continue;
          if (sentence.contentTranslate == null) continue;
          batch.update(
            sentence.tableName,
            {
              'content_translate': sentence.contentTranslate,
              'translate_source': sentence.translateSource,
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'code = ?',
            whereArgs: [sentence.code],
          );
        }

        // 单次提交所有更新（原子操作）
        final results = await batch.commit(noResult: true);
        updatedCount = results.length;

        sw.stop();
        logger.info(
          'translation batch update done',
          tag: 'DB',
          extra: {'updated': updatedCount, 'ms': sw.elapsedMilliseconds},
        );

        return updatedCount;
      }

      try {
        final result = retry
            ? await _retryOnLockError<int>(doUpdate, maxRetries: 3, baseDelayMs: 300) ?? 0
            : await doUpdate();

        // 4. 手动重建 FTS5 全文索引并恢复触发器
        await _restoreFTSAfterBatch(db, ftsTablesToRestore);

        return result;
      } catch (e, st) {
        sw.stop();
        logger.error(
          'translation batch update failed',
          tag: 'DB',
          error: e,
          stackTrace: st,
          extra: {'total': totalCount, 'ms': sw.elapsedMilliseconds},
        );

        // 尝试恢复 FTS 触发器（非 corruption 错误时需要）
        try {
          await _restoreFTSAfterBatch(db, ftsTablesToRestore);
        } catch (_) {
          // 数据库可能已损坏，恢复触发器失败是预期行为
        }

        // 异常时立即备份三个文件，供离线分析
        await _backupDbOnException(path, 'batch-update-failed');
        // 再次检查 integrity，记录结果
        try {
          final afterOk = await _checkIntegrity(db);
          logger.error('integrity_check after failure', tag: 'DB', extra: {'ok': afterOk});
        } catch (_) {}
        // SQLITE_NOTADB / SQLITE_CORRUPT 等 corruption 错误：恢复数据库
        if (_isDatabaseCorrupted(e)) {
          logger.fatal('corruption detected during batch update, recovering', tag: 'DB', error: e, stackTrace: st);
          await _recoverRuntimeCorruption(e, st);
        }
        rethrow;
      }
    });
  }

  /// 批量更新记录
  ///
  /// [entities] 要更新的实体列表
  /// 返回影响行数
  static Future<int> batchUpdate(List<BaseEntity> entities) async {
    if (entities.isEmpty) return 0;

    // 1. 在锁外获取数据库实例（防止死锁）
    final db = await database;
    final tableName = entities.first.tableName;
    int updatedCount = 0;

    // 2. 用 _writeLock 包裹写操作
    await _writeLock.synchronized(() async {
      // 确保表结构匹配实体定义，防止因缺少列导致事务内 SQL 错误
      await _autoMigrateEntity(db, entities.first);
      const batchSize = 100;
      for (int i = 0; i < entities.length; i += batchSize) {
        final batch = entities.sublist(i, (i + batchSize < entities.length) ? i + batchSize : entities.length);
        try {
          await db.transaction((txn) async {
            for (var entity in batch) {
              entity.updatedAt = DateTime.now();
              final map = entity.toMap();
              map.remove('id'); // 移除 id，避免 UPDATE 语句包含 id = NULL
              // 移除 null 值的字段，避免不必要的 NULL 更新
              map.removeWhere((key, value) => value == null);
              int count = await txn.update(tableName, map, where: 'id = ?', whereArgs: [entity.id]);
              updatedCount += count;
            }
          }, exclusive: true); // 使用独占事务避免在并发下与后台任务冲突
        } catch (e, st) {
          if (_isDatabaseCorrupted(e)) {
            logger.fatal('db corrupted during batchUpdate, attempting recovery', tag: 'DB', error: e, stackTrace: st);
            await _recoverRuntimeCorruption(e, st);
            return 0;
          }
          rethrow;
        }
      }
    });

    return updatedCount;
  }

  /// 物理删除记录
  ///
  /// [entity] 要删除的实体
  /// 返回影响行数
  /// 注意：物理删除不可恢复，建议使用 softDelete
  static Future<int> delete(BaseEntity entity) async {
    final db = await database;
    return await _writeLock.synchronized(() async {
      return await db.delete(entity.tableName, where: 'id = ?', whereArgs: [entity.id]);
    });
  }

  /// 批量物理删除记录
  ///
  /// [entities] 要删除的实体列表
  /// 返回影响行数
  static Future<int> batchDelete(List<BaseEntity> entities) async {
    if (entities.isEmpty) return 0;

    final db = await database;
    final tableName = entities.first.tableName;
    int deletedCount = 0;

    await _writeLock.synchronized(() async {
      await db.transaction((txn) async {
        for (var entity in entities) {
          int count = await txn.delete(tableName, where: 'id = ?', whereArgs: [entity.id]);
          deletedCount += count;
        }
      });
    });

    return deletedCount;
  }

  /// 软删除单条记录
  ///
  /// [entity] 要删除的实体
  /// 返回影响行数
  /// 设置 is_deleted = 1，数据仍然保留
  static Future<int> softDelete(BaseEntity entity) async {
    final db = await database;
    entity.isDeleted = true;
    entity.deletedAt ??= DateTime.now();
    entity.updatedAt = DateTime.now();
    final currentUserCode = await getCurrentUserCode();
    if (entity.tableName != 'user') {
      entity.userCode ??= currentUserCode;
    }
    entity.deletedBy ??= currentUserCode;
    entity.updatedBy ??= currentUserCode;

    return await _writeLock.synchronized(() async {
      try {
        return await db.update(
          entity.tableName,
          {
            'is_deleted': 1,
            'deleted_at': entity.deletedAt?.toIso8601String(),
            'deleted_by': entity.deletedBy,
            'updated_at': entity.updatedAt?.toIso8601String(),
            'updated_by': entity.updatedBy,
          },
          where: 'id = ?',
          whereArgs: [entity.id],
        );
      } catch (e, st) {
        logger.error(
          'db softDelete failed',
          tag: 'DB',
          error: e,
          stackTrace: st,
          extra: {'table': entity.tableName, 'id': entity.id, 'code': entity.code},
        );
        await _tryInsertErrorLog(db, {
          'code': const Uuid().v4().replaceAll('-', ''),
          'user_code': entity.userCode,
          'level': 'error',
          'tag': 'DB',
          'message': 'db softDelete failed',
          'error': e.toString(),
          'stack_trace': st.toString(),
          'extra': '{"table":"${entity.tableName}","id":${entity.id},"code":"${entity.code}"}',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'is_deleted': 0,
          'created_by': entity.userCode,
          'updated_by': entity.userCode,
        });

        rethrow;
      }
    });
  }

  /// 批量软删除记录
  ///
  /// [entities] 要删除的实体列表
  /// 返回影响行数
  ///
  /// [entities] 要删除的实体列表
  /// 返回影响行数
  static Future<int> batchSoftDelete(List<BaseEntity> entities) async {
    if (entities.isEmpty) return 0;

    final db = await database;
    final tableName = entities.first.tableName;
    int deletedCount = 0;
    final currentUserCode = await getCurrentUserCode();

    await _writeLock.synchronized(() async {
      try {
        await db.transaction((txn) async {
          for (var entity in entities) {
            entity.isDeleted = true;
            entity.deletedAt ??= DateTime.now();
            entity.updatedAt = DateTime.now();
            if (tableName != 'user') {
              entity.userCode ??= currentUserCode;
            }
            entity.deletedBy ??= currentUserCode;
            entity.updatedBy ??= currentUserCode;

            int count = await txn.update(
              tableName,
              {
                'is_deleted': 1,
                'deleted_at': entity.deletedAt?.toIso8601String(),
                'deleted_by': entity.deletedBy,
                'updated_at': entity.updatedAt?.toIso8601String(),
                'updated_by': entity.updatedBy,
              },
              where: 'id = ?',
              whereArgs: [entity.id],
            );
            deletedCount += count;
          }
        });
      } catch (e, st) {
        logger.error('db batchSoftDelete failed', tag: 'DB', error: e, stackTrace: st, extra: {'table': tableName, 'count': entities.length});
        await _tryInsertErrorLog(db, {
          'code': const Uuid().v4().replaceAll('-', ''),
          'user_code': currentUserCode,
          'level': 'error',
          'tag': 'DB',
          'message': 'db batchSoftDelete failed',
          'error': e.toString(),
          'stack_trace': st.toString(),
          'extra': '{"table":"$tableName","count":${entities.length}}',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'is_deleted': 0,
          'created_by': currentUserCode,
          'updated_by': currentUserCode,
        });

        rethrow;
      }
    });

    return deletedCount;
  }

  /// 根据主键查询
  ///
  /// [id] 主键ID
  /// [create] 实体创建工厂
  /// 返回查询到的实体，未找到返回 null
  static Future<T?> findById<T extends BaseEntity>(int id, T Function() create) async {
    final db = await database;
    T entity = create();
    final List<Map<String, dynamic>> maps = await db.query(entity.tableName, where: 'id = ? AND is_deleted = 0', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return entity.fromMap(maps.first) as T;
    }
    return null;
  }

  /// 查询所有未删除的记录
  ///
  /// [create] 实体创建工厂
  /// 返回所有 is_deleted = 0 的记录列表
  static Future<List<T>> findAll<T extends BaseEntity>(T Function() create) async {
    final db = await database;
    T entity = create();
    final userCode = await getCurrentUserCode();

    String whereClause = 'is_deleted = 0';
    List<Object?> whereArgs = [];

    // user 表不添加用户过滤
    if (userCode != null && entity.tableName != 'user') {
      whereClause += ' AND user_code = ?';
      whereArgs.add(userCode);
    }

    final List<Map<String, dynamic>> maps = await db.query(entity.tableName, where: whereClause, whereArgs: whereArgs, orderBy: 'created_at DESC');
    return maps.map((map) => create().fromMap(map) as T).toList();
  }

  /// 条件查询
  ///
  /// [create] 实体创建工厂
  /// [where] WHERE 条件语句
  /// [whereArgs] 条件参数列表
  /// [orderBy] 排序字段
  /// [limit] 返回记录数限制
  /// [offset] 跳过记录数
  /// 返回符合条件的记录列表
  static Future<List<T>> findByCondition<T extends BaseEntity>(
    T Function() create, {
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    T entity = create();
    final userCode = await getCurrentUserCode();

    String? finalWhere = where;
    List<Object?> finalWhereArgs = whereArgs ?? [];

    // 自动添加用户过滤
    if (userCode != null && entity.tableName != 'user') {
      finalWhere = finalWhere != null ? '$finalWhere AND user_code = ?' : 'user_code = ?';
      finalWhereArgs.add(userCode);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      entity.tableName,
      where: finalWhere,
      whereArgs: finalWhereArgs,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
    return maps.map((map) => create().fromMap(map) as T).toList();
  }

  /// 全文检索查询
  ///
  /// [create] 实体创建工厂
  /// [query] 搜索关键词
  /// [columns] 要搜索的列名，null 表示搜索所有 FTS 列
  /// 返回匹配的记录列表
  static Future<List<T>> searchFullText<T extends BaseEntity>(T Function() create, String query, {List<String>? columns}) async {
    final db = await database;
    T entity = create();
    String tableName = entity.tableName;
    String ftsTableName = '${tableName}_fts';
    final userCode = await getCurrentUserCode();

    // 构建 MATCH 查询
    String whereClause = columns != null && columns.isNotEmpty
        ? columns.map((col) => '$ftsTableName.$col MATCH ?').join(' OR ')
        : '$ftsTableName MATCH ?';

    List<Object?> args = columns != null && columns.isNotEmpty ? List.filled(columns.length, query) : [query];

    // 添加用户过滤
    String userCodeClause = '';
    if (userCode != null && tableName != 'user') {
      userCodeClause = ' AND $tableName.user_code = ?';
      args.add(userCode);
    }

    // 执行联合查询
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT $tableName.* FROM $tableName 
      JOIN $ftsTableName ON $tableName.id = $ftsTableName.rowid 
      WHERE $whereClause
      AND $tableName.is_deleted = 0
      $userCodeClause
    ''', args);

    return maps.map((map) => create().fromMap(map) as T).toList();
  }

  /// 统计记录数
  ///
  /// [create] 实体创建工厂
  /// [where] WHERE 条件语句
  /// [whereArgs] 条件参数列表
  /// 返回符合条件的记录总数
  static Future<int> count<T extends BaseEntity>(T Function() create, {String? where, List<Object?>? whereArgs}) async {
    final db = await database;
    T entity = create();
    final userCode = await getCurrentUserCode();

    String? finalWhere = where;
    List<Object?> finalWhereArgs = whereArgs ?? [];

    // 自动添加用户过滤
    if (userCode != null && entity.tableName != 'user') {
      finalWhere = finalWhere != null ? '$finalWhere AND user_code = ?' : 'user_code = ?';
      finalWhereArgs.add(userCode);
    }

    final List<Map<String, dynamic>> result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${entity.tableName} ${finalWhere != null ? 'WHERE $finalWhere' : ''}',
      finalWhereArgs,
    );
    return result.first['count'] as int;
  }

  /// 根据视频Code查询
  ///
  /// [videoCode] 视频code
  /// [create] 实体创建工厂
  /// [orderBy] 排序字段
  /// 返回该视频相关的所有记录
  static Future<List<T>> findByVideoCode<T extends BaseEntity>(String videoCode, T Function() create, {String? orderBy}) async {
    return await findByCondition(create, where: 'video_code = ? AND is_deleted = 0', whereArgs: [videoCode], orderBy: orderBy);
  }

  /// 关闭数据库连接
  ///
  /// 通常在应用退出时调用
  static Future<void> closeDatabase() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  /// 获取当前登录用户的 Code
  ///
  /// 返回用户code，未登录返回 null
  static Future<String?> getCurrentUserCode() async {
    final db = await _initLock.synchronized(() async {
      if (_database != null && _database!.isOpen) {
        return _database!;
      }
      _database = await _initDatabase();
      return _database!;
    });
    final List<Map<String, dynamic>> maps = await db.query(
      'config',
      where: 'category = ? AND key = ? AND is_deleted = 0',
      whereArgs: [_systemCategory, _currentUserCodeKey],
    );
    if (maps.isNotEmpty) {
      return maps.first['value'] as String?;
    }
    return null;
  }

  /// 设置当前用户Code
  ///
  /// [userCode] 用户code，null 表示清除
  static Future<void> setCurrentUserCode(String? userCode) async {
    await _setConfig(_currentUserCodeKey, userCode);
  }

  /// 设置系统配置
  ///
  /// [key] 配置键名
  /// [value] 配置值
  static Future<void> _setConfig(String key, String? value) async {
    // 必须在此处使用 await _initLock.synchronized 获取，因为 _setConfig 是底层操作
    // 有可能在还没有调用过 get database 的时候被调用，防止死锁
    final db = await _initLock.synchronized(() async {
      if (_database != null && _database!.isOpen) {
        return _database!;
      }
      _database = await _initDatabase();
      return _database!;
    });

    await _writeLock.synchronized(() async {
      final List<Map<String, dynamic>> existing = await db.query('config', where: 'category = ? AND key = ?', whereArgs: [_systemCategory, key]);

      Map<String, dynamic> configMap = {
        'category': _systemCategory,
        'key': key,
        'value_type': 'string',
        'value': value,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (existing.isNotEmpty) {
        // 更新现有配置
        await db.update('config', configMap, where: 'id = ?', whereArgs: [existing.first['id']]);
      } else {
        // 创建新配置
        configMap['code'] = const Uuid().v4().replaceAll('-', '');
        configMap['created_at'] = DateTime.now().toIso8601String();
        configMap['is_deleted'] = 0;
        await db.insert('config', configMap);
      }
    });
  }

  /// 清除当前用户信息
  ///
  /// 退出登录时调用，清除当前用户code
  static Future<void> clearCurrentUser() async {
    await setCurrentUserCode(null);
  }

  static Future<void> resetAllData({bool deleteCovers = true}) async {
    final db = await database;

    await _writeLock.synchronized(() async {
      await db.transaction((txn) async {
        for (final tableName in _registeredEntities.keys) {
          await txn.delete(tableName);
        }
      });
    });

    await clearCurrentUser();

    if (deleteCovers) {
      try {
        final documentsDirectory = await getApplicationDocumentsDirectory();
        final coversDir = Directory(join(documentsDirectory.path, 'covers'));
        if (await coversDir.exists()) {
          await coversDir.delete(recursive: true);
        }
      } catch (_) {}
    }
  }
}
