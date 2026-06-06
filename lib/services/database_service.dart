import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_vscode_logger/flutter_vscode_logger.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

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
  /// 用于数据库升级迁移
  static const int _databaseVersion = 1;

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
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// 初始化数据库
  ///
  /// 创建数据库文件并打开连接
  /// 触发 onCreate 和 onOpen 回调
  static Future<Database> _initDatabase() async {
    final path = await _resolveDbPath();
    try {
      return await _openDatabaseAtPath(path);
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
        await deleteDatabase(path);
      } catch (_) {}
      return await _openDatabaseAtPath(path);
    }
  }

  static bool _isDatabaseCorrupted(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('database disk image is malformed') || s.contains('malformed');
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

  static Future<void> _onConfigure(Database db) async {
    try {
      await db.execute('PRAGMA foreign_keys = ON');
    } catch (_) {}
    try {
      await db.execute('PRAGMA journal_mode = WAL');
    } catch (_) {}
    try {
      await db.execute('PRAGMA synchronous = FULL');
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
    final db = await openDatabase(path, version: _databaseVersion, onConfigure: _onConfigure, onCreate: _onCreate, onOpen: _onOpen);
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

    try {
      final src = File(path);
      if (await src.exists()) {
        final backupPath = '$path.corrupt-${DateTime.now().millisecondsSinceEpoch}';
        try {
          await src.rename(backupPath);
          logger.warning('database backed up', tag: 'DB', extra: {'backupPath': backupPath});
        } catch (e, st) {
          try {
            await src.copy(backupPath);
            logger.warning('database backed up', tag: 'DB', extra: {'backupPath': backupPath, 'mode': 'copy'});
          } catch (_) {
            logger.error('database backup failed', tag: 'DB', error: e, stackTrace: st);
          }
        }
      }
    } catch (e) {
      logger.error('database backup failed', tag: 'DB', error: e);
    }

    try {
      await deleteDatabase(path);
      logger.warning('database deleted for recovery', tag: 'DB', extra: {'dbPath': path});
    } catch (e) {
      logger.error('database delete failed', tag: 'DB', error: e, extra: {'dbPath': path});
    }

    try {
      _database = await _openDatabaseAtPath(path);
    } catch (e) {
      logger.fatal('database re-init failed', tag: 'DB', error: e);
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
  ///
  /// 自动检测并添加新字段，无需重建表
  static Future<void> _autoMigrateTable(Database db, BaseEntity entity, {bool enableFTS = false}) async {
    String tableName = entity.tableName;

    List<Map<String, dynamic>> existingColumns = await db.rawQuery('PRAGMA table_info($tableName)');

    // 表不存在时直接建表（例如后注册的 study_record）
    if (existingColumns.isEmpty) {
      await _createTable(db, entity, enableFTS);
      return;
    }

    Set<String> existingColumnNames = existingColumns.map((col) => col['name'] as String).toSet();

    Map<String, dynamic> entityMap = entity.toMap();

    for (var entry in entityMap.entries) {
      String columnName = entry.key;
      // id 由建表语句单独处理，且 toMap 里常为 null，不可 ALTER 成 TEXT
      if (columnName == 'id' || existingColumnNames.contains(columnName)) {
        continue;
      }
      String columnType = _getColumnType(entry.value);
      await db.execute('ALTER TABLE $tableName ADD COLUMN $columnName $columnType');
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
    final db = await database;
    final userCode = await getCurrentUserCode();
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
      int insertedId = await db.insert(entity.tableName, map);
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
        final insertedId = await db.insert(entity.tableName, retryMap);
        entity.id = insertedId;
        return insertedId;
      }
      logger.error('db insert failed', tag: 'DB', error: e, stackTrace: st, extra: {'table': entity.tableName, 'code': entity.code});
      rethrow;
    }
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
    });

    return insertedIds;
  }

  /// 更新单条记录
  ///
  /// [entity] 要更新的实体
  /// 返回影响行数
  static Future<int> update(BaseEntity entity) async {
    final db = await database;
    entity.updatedAt = DateTime.now();
    try {
      return await db.update(entity.tableName, entity.toMap(), where: 'id = ?', whereArgs: [entity.id]);
    } catch (e, st) {
      logger.error('db update failed', tag: 'DB', error: e, stackTrace: st, extra: {'table': entity.tableName, 'id': entity.id, 'code': entity.code});
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
      if (_isDatabaseCorrupted(e)) {
        await _recoverCorruptedDatabase(e, st);
      }
      rethrow;
    }
  }

  /// 批量更新记录
  ///
  /// [entities] 要更新的实体列表
  /// 返回影响行数
  static Future<int> batchUpdate(List<BaseEntity> entities) async {
    if (entities.isEmpty) return 0;

    final db = await database;
    final tableName = entities.first.tableName;
    int updatedCount = 0;

    await db.transaction((txn) async {
      for (var entity in entities) {
        entity.updatedAt = DateTime.now();
        int count = await txn.update(tableName, entity.toMap(), where: 'id = ?', whereArgs: [entity.id]);
        updatedCount += count;
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
    return await db.delete(entity.tableName, where: 'id = ?', whereArgs: [entity.id]);
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

    await db.transaction((txn) async {
      for (var entity in entities) {
        int count = await txn.delete(tableName, where: 'id = ?', whereArgs: [entity.id]);
        deletedCount += count;
      }
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

      if (_isDatabaseCorrupted(e)) {
        await _recoverCorruptedDatabase(e, st);
        return 0;
      }
      rethrow;
    }
  }

  /// 批量软删除记录
  ///
  /// [entities] 要删除的实体列表
  /// 返回影响行数
  static Future<int> batchSoftDelete(List<BaseEntity> entities) async {
    if (entities.isEmpty) return 0;

    final db = await database;
    final tableName = entities.first.tableName;
    int deletedCount = 0;
    final currentUserCode = await getCurrentUserCode();

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

      if (_isDatabaseCorrupted(e)) {
        await _recoverCorruptedDatabase(e, st);
        return 0;
      }
      rethrow;
    }

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
    final db = await database;
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
    final db = await database;
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
  }

  /// 清除当前用户信息
  ///
  /// 退出登录时调用，清除当前用户code
  static Future<void> clearCurrentUser() async {
    await setCurrentUserCode(null);
  }

  static Future<void> resetAllData({bool deleteCovers = true}) async {
    final db = await database;

    await db.transaction((txn) async {
      for (final tableName in _registeredEntities.keys) {
        await txn.delete(tableName);
      }
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
