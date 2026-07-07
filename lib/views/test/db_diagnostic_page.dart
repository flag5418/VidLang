import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:vidlang/models/subtitles.dart';
import 'package:vidlang/models/video_folder.dart';
import 'package:vidlang/models/video_info.dart';
import 'package:vidlang/services/database_service.dart';
import 'package:vidlang/theme/theme.dart';

/// 数据库诊断与自动修复页面
///
/// 功能：
/// 1. 全面诊断（文件状态、完整性、表统计、softDelete 测试、级联分析）
/// 2. 自动修复（多级策略：checkpoint → 导出 → 重建）
class DbDiagnosticPage extends StatefulWidget {
  const DbDiagnosticPage({super.key});

  @override
  State<DbDiagnosticPage> createState() => _DbDiagnosticPageState();
}

class _DbDiagnosticPageState extends State<DbDiagnosticPage> {
  final List<String> _logs = [];
  bool _isRunning = false;

  void _log(String msg) {
    setState(() {
      final time = DateTime.now().toString().substring(11, 23);
      _logs.add('[$time] $msg');
    });
  }

  // ==================== 自动诊断+修复（一键） ====================

  Future<void> _autoDiagnoseAndFix() async {
    if (_isRunning) return;
    setState(() { _isRunning = true; _logs.clear(); });

    try {
      _log('🚀 启动自动诊断与修复流程');

      // Step 1: 检查文件
      await _checkDbFiles();

      // Step 2: 完整性检查
      final isHealthy = await _checkIntegrity();

      if (isHealthy) {
        _log('');
        _log('✅ 数据库健康，无需修复！');
        return;
      }

      _log('');
      _log('⚠️ 数据库损坏，启动自动修复...');

      // Step 3: 自动修复（调用 DatabaseService 内部的多级恢复逻辑）
      await _autoRepair();

      // Step 4: 验证修复结果
      _log('');
      _log('验证修复结果...');
      final repairedHealthy = await _checkIntegrity();
      if (repairedHealthy) {
        _log('✅✅✅ 自动修复成功！数据库已恢复正常。');
      } else {
        _log('❌ 自动修复未能完全恢复数据库');
        _log('   建议：点击"强制修复"重建数据库');
      }
    } catch (e, st) {
      _log('❌ 流程异常: $e');
      _log('   $st');
    } finally {
      setState(() => _isRunning = false);
    }
  }

  /// 调用 DatabaseService 的多级恢复流程
  Future<void> _autoRepair() async {
    _log('');
    _log('🔧 触发自动修复（多级策略）...');

    try {
      // 通过触发一次会失败的写操作来激活 corruption recovery
      // 但更直接的方式是模拟 corruption 场景

      final dbPath = await _getDbPath();
      _log('  数据库路径: $dbPath');

      // 直接使用反射式修复：手动执行 Level 1 → Level 2 → Level 3
      final level1Ok = await _tryCheckpointRepair(dbPath);
      if (level1Ok) {
        _log('  ✅ Level 1 (WAL Checkpoint) 修复成功！');
        return;
      }

      _log('  ⚠️ Level 1 无效，尝试 Level 2 (数据导出)...');
      final level2Ok = await _tryExportRepair(dbPath);
      if (level2Ok) {
        _log('  ✅ Level 2 (数据导出) 修复成功！数据已保留。');
        return;
      }

      _log('  ❌ Level 2 也无效');
      _log('  💡 如需继续修复，请点击「强制重建」按钮');
    } catch (e) {
      _log('  ❌ 自动修复异常: $e');
    }
  }

  /// Level 1: WAL Checkpoint 修复
  static Future<bool> _tryCheckpointRepair(String dbPath) async {
    Database? db;
    try {
      _printLog?.call('  [L1] 以 readOnly 打开数据库...');
      db = await openDatabase(dbPath, readOnly: true);

      _printLog?.call('  [L1] 执行 PRAGMA wal_checkpoint(TRUNCATE)...');
      try {
        await db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
      } catch (e) {
        _printLog?.call('  [L1] TRUNCATE 失败，尝试 PASSIVE: $e');
        try { await db.execute('PRAGMA wal_checkpoint(PASSIVE)'); } catch (_) {}
      }

      await db.close();
      db = null;

      // 删除 WAL/SHM
      for (final s in ['-wal', '-shm']) {
        try {
          final f = File('$dbPath$s');
          if (await f.exists()) { await f.delete(); }
        } catch (_) {}
      }
      await Future.delayed(const Duration(milliseconds: 100));

      // 验证
      final vDb = await openDatabase(dbPath, readOnly: true);
      final r = await vDb.rawQuery('PRAGMA integrity_check;');
      await vDb.close();
      final ok = r.isNotEmpty && r.first.values.first?.toString().toLowerCase() == 'ok';
      _printLog?.call('  [L1] integrity_check: ${ok ? "OK ✅" : "FAILED ❌"}');
      return ok;
    } catch (e) {
      _printLog?.call('  [L1] 异常: $e');
      try { await db?.close(); } catch (_) {}
      return false;
    }
  }

  /// Level 2: 导出可读数据到新文件
  static Future<bool> _tryExportRepair(String dbPath) async {
    Database? db;
    try {
      final exportPath = '$dbPath.export-${DateTime.now().millisecondsSinceEpoch}';
      _printLog?.call('  [L2] 尝试导出数据到 $exportPath ...');

      db = await openDatabase(dbPath, readOnly: true);
      await db.execute("ATTACH DATABASE ? AS newdb", [exportPath]);

      final tables = await db.rawQuery(
        "SELECT name, sql FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
      );

      int totalRows = 0;
      for (final row in tables) {
        final name = row['name'] as String;
        final sql = (row['sql'] as String?) ?? '';
        if (sql.isEmpty) continue;

        // 创建表
        try {
          final createSql = sql.replaceFirst(
            RegExp(r'CREATE TABLE\s+' + RegExp.escape(name), caseSensitive: false),
            'CREATE TABLE newdb.$name',
          );
          await db.execute(createSql);
        } catch (_) {
          try { await db.execute('CREATE TABLE IF NOT EXISTS newdb.$name AS SELECT * FROM main.$name WHERE 0'); } catch (_) {}
        }

        // 复制数据
        try {
          await db.execute('INSERT INTO newdb.$name SELECT * FROM main.$name');
          final cnt = await db.rawQuery('SELECT COUNT(*) as c FROM newdb.$name');
          totalRows += (cnt.first['c'] as int? ?? 0);
        } catch (_) {}
      }

      await db.execute("DETACH DATABASE newdb");
      await db.close();

      if (totalRows > 0) {
        // 用导出的文件替换原文件
        _printLog?.call('  [L2] 成功导出 $totalRows 行，替换原文件...');
        for (final s in ['', '-wal', '-shm']) {
          try { await File('$dbPath$s').delete(); } catch (_) {}
        }
        await File(exportPath).copy(dbPath);
        try { await File(exportPath).delete(); } catch (_) {}

        // 验证
        final vDb = await openDatabase(dbPath, readOnly: true);
        final r = await vDb.rawQuery('PRAGMA integrity_check;');
        await vDb.close();
        final ok = r.isNotEmpty && r.first.values.first?.toString().toLowerCase() == 'ok';
        _printLog?.call('  [L2] 替换后 integrity: ${ok ? "OK ✅" : "FAILED ❌"}');
        return ok;
      }

      _printLog?.call('  [L2] 导出了 0 行数据');
      try { await File(exportPath).delete(); } catch (_) {};
      return false;
    } catch (e) {
      _printLog?.call('  [L2] 异常: $e');
      try { await db?.close(); } catch (_) {}
      return false;
    }
  }

  // ==================== 详细诊断步骤 ====================

  Future<bool> _checkDbFiles() async {
    _log('═══ 1. 文件状态 ═══');
    try {
      final dbPath = await _getDbPath();
      _log('  路径: $dbPath');

      for (final e in [
        ('主文件 (.db)', File(dbPath)),
        ('WAL (-wal)', File('$dbPath-wal')),
        ('SHM (-shm)', File('$dbPath-shm')),
      ]) {
        final f = e.$2;
        if (await f.exists()) {
          final s = await f.stat();
          _log('  ${e.$1}: ${(s.size / 1024).toStringAsFixed(1)}KB  ${s.modified.toString().substring(5, 16)}');
        } else {
          _log('  ${e.$1}: 不存在');
        }
      }
    } catch (e) { _log('  ❌ $e'); }
    return true;
  }

  /// 返回 true 表示健康
  Future<bool> _checkIntegrity() async {
    _log('');
    _log('═══ 2. 完整性检查 ═══');
    try {
      final db = await DatabaseService.database;

      final sw = Stopwatch()..start();
      final rows = await db.rawQuery('PRAGMA integrity_check;');
      sw.stop();
      final result = rows.isNotEmpty ? rows.first.values.first?.toString() ?? '' : '(empty)';
      final ok = result.toLowerCase() == 'ok';

      _log('  integrity_check: ${ok ? "✅ OK" : "❌ $result"} (${sw.elapsedMilliseconds}ms)');

      if (!ok && rows.length > 1) {
        for (int i = 1; i < rows.length && i < 5; i++) {
          _log('    ${(rows[i] as Map).values.first}');
        }
      }

      // quick_check
      final qRows = await db.rawQuery('PRAGMA quick_check;');
      final qResult = qRows.isNotEmpty ? qRows.first.values.first?.toString() ?? '' : '';
      _log('  quick_check: ${qResult.toLowerCase() == 'ok' ? "✅ OK" : "❌ $qResult"}');

      // 页面信息
      final pg = await db.rawQuery('PRAGMA page_count;');
      final jm = await db.rawQuery('PRAGMA journal_mode;');
      _log('  页数: ${pg.first.values.first} | 模式: ${jm.first.values.first}');

      return ok;
    } catch (e, st) {
      _log('  ❌ 异常: $e');
      _log('  $st');
      return false;
    }
  }

  Future<void> _checkTableStats() async {
    _log('');
    _log('═══ 3. 表统计 ═══');
    for (final t in [
      'video_folder', 'video_info', 'subtitles', 'participle',
      'article', 'article_chapter', 'article_paragraph', 'article_sentence',
      'config', 'error_log', 'study_record', 'word_book',
    ]) {
      try {
        final total = await _getCount(t);
        final del = await _getCount(t, where: 'is_deleted = 1');
        _log('  $t: $total (已删:$del)');
      } catch (e) { _log('  $t: ❌ $e'); }
    }
  }

  Future<void> _testSoftDelete() async {
    _log('');
    _log('═══ 4. SoftDelete 测试 ═══');
    try {
      final subs = await DatabaseService.findByCondition(() => Subtitles(), where: 'is_deleted = 0', limit: 1);
      if (subs.isEmpty) { _log('  ⚠️ 无 subtitles 记录'); return; }

      final s = subs.first;
      _log('  测试 id=${s.id} code=${s.code}');
      _log('  执行 softDelete...');
      final sw = Stopwatch()..start();
      await DatabaseService.softDelete(s);
      sw.stop();
      _log('  ✅ 成功 (${sw.elapsedMilliseconds}ms)');

      // 恢复
      s.isDeleted = false; s.deletedAt = null; s.deletedBy = null;
      await DatabaseService.update(s);
      _log('  ✅ 已撤销测试删除');
    } on DatabaseException catch (e) {
      _log('  ❌ DatabaseException: ${e.toString()}');
      _log('  🔧 这是数据库损坏的特征错误！');
    } catch (e) {
      _log('  ❌ (${e.runtimeType}): $e');
    }
  }

  Future<void> _testCascadeAnalysis() async {
    _log('');
    _log('═══ 5. 级联删除分析 ═══');
    try {
      final folders = await DatabaseService.findByCondition(
        () => VideoFolder(), where: 'is_deleted = 0', orderBy: 'created_at DESC', limit: 3,
      );
      for (final f in folders) {
        final videos = await DatabaseService.findByCondition(
          () => VideoInfo(), where: 'folder_code = ? AND is_deleted = 0', whereArgs: [f.code],
        );
        int sCount = 0, pCount = 0;
        for (final v in videos) {
          final vc = v.code ?? ''; if (vc.isEmpty) continue;
          sCount += await _getCount('subtitles', where: 'video_code = "$vc" AND is_deleted = 0');
          pCount += await _getCount('participle', where: 'video_code = "$vc" AND is_deleted = 0');
        }
        _log('  📁 "${f.name}"(${f.folderType.name}): ${videos.length}资源 $sCount字幕 $pCount分词 → 删除需${videos.length+sCount+pCount+1}次写操作');
      }
    } catch (e) { _log('  ❌ $e'); }
  }

  Future<void> _forceRebuild() async {
    _log('');
    _log('⚠️ 强制重建数据库...');
    try {
      final p = await _getDbPath();
      final ts = DateTime.now().millisecondsSinceEpoch;
      // 备份
      for (final s in ['', '-wal', '-shm']) {
        try { await File('$p$s').copy('$p.backup-$ts.db$s'); } catch (_) {}
      }
      _log('  已备份');
      // 删除
      for (final s in ['', '-wal', '-shm']) {
        try { await File('$p$s').delete(); } catch (_) {}
      }
      _log('  已删除');
      _log('  ✅ 请重启应用自动重建');
    } catch (e) { _log('  ❌ $e'); }
  }

  // ==================== 工具 ====================

  static void Function(String)? _printLog;
  static Future<String> _getDbPath() async {
    final d = await getApplicationDocumentsDirectory();
    return p.join(d.path, 'vidlang.db');
  }

  static Future<int> _getCount(String table, {String? where}) async {
    final db = await DatabaseService.database;
    final sql = where != null ? 'SELECT COUNT(*) as c FROM $table WHERE $where' : 'SELECT COUNT(*) as c FROM $table';
    final r = await db.rawQuery(sql);
    return (r.first['c'] as int?) ?? 0;
  }

  @override
  void initState() {
    super.initState();
    _printLog = _log;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('数据库诊断与修复'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(icon: const Icon(AppIcons.deleteSweep), onPressed: () => setState(() => _logs.clear()), tooltip: '清空'),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isRunning ? null : _autoDiagnoseAndFix,
                    icon: _isRunning
                        ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(AppIcons.autoFixHigh),
                    label: Text(_isRunning ? '自动修复中...' : '🚀 一键诊断+自动修复'),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: _isRunning
                            ? null
                            : () async {
                                _log('--- 手动详细诊断 ---');
                                await _checkDbFiles();
                                await _checkIntegrity();
                                await _checkTableStats();
                                await _testSoftDelete();
                                await _testCascadeAnalysis();
                              },
                        child: const Text('🔬 详细诊断'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: _isRunning ? null : _forceRebuild,
                        style: FilledButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('⚠️ 强制重建'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _logs.isEmpty
                ? const Center(
                    child: Text(
                      '推荐先点「一键诊断+自动修复」\n\n它会自动检测并尝试修复数据库问题',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _logs.length,
                    itemBuilder: (c, i) {
                      final l = _logs[i];
                      Color color = Colors.black87;
                      if (l.contains('❌')) color = Colors.red[700]!;
                      if (l.contains('✅')) color = Colors.green[700]!;
                      if (l.contains('⚠️') || l.contains('🔧') || l.contains('💡')) color = Colors.orange[700]!;
                      if (l.contains('🚀')) color = Colors.blue[700]!;
                      if (l.contains('📁')) color = Colors.purple[700]!;
                      return SelectableText(l, style: TextStyle(color: color, fontSize: 12, fontFamily: 'monospace', height: 1.4));
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
