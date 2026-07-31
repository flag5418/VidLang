import 'package:flutter/foundation.dart';
import 'package:vidlang/models/base_entity.dart';
import 'package:vidlang/models/forum/forum_tag.dart';
import 'package:vidlang/models/forum/forum_tag_follow_local.dart';
import 'package:vidlang/services/database_service.dart';

/// 论坛标签关注本地服务
///
/// 管理用户关注的标签，数据存储在本地 SQLite 中。
///
/// 核心逻辑：
/// 1. 首次进入论坛时，如果本地无数据 → 从 Supabase 获取标签列表 → 默认全部关注（写入本地）
/// 2. 后续关注/取消关注仅操作本地数据库
/// 3. 发帖时通过 Supabase 用户身份上传，关联的标签以本地为准
class ForumTagFollowLocalService {
  ForumTagFollowLocalService._();
  static final ForumTagFollowLocalService instance = ForumTagFollowLocalService._();

  bool _tableFixed = false;

  /// 确保表结构正确
  ///
  /// 检测到 no such column 错误时调用，尝试修复缺失的列。
  Future<void> _ensureTableStructure() async {
    if (_tableFixed) return;

    try {
      final db = await DatabaseService.database;

      // 使用 DatabaseService 的内部迁移逻辑来修复表结构
      // 通过执行一次原始查询来触发 _isMissingColumnError 检测和自动修复
      // 但更直接的方式是手动检查并补齐

      final existingColumns = await db.rawQuery('PRAGMA table_info(forum_tag_follow_local)');
      final existingNames = existingColumns.map((col) => col['name'] as String).toSet();

      // 检查必要的 BaseEntity 列
      final requiredColumns = {
        'user_code': 'TEXT',
        'code': 'TEXT',
        'created_at': 'TEXT',
        'updated_at': 'TEXT',
        'is_deleted': 'INTEGER DEFAULT 0',
        'deleted_at': 'TEXT',
        'created_by': 'TEXT',
        'updated_by': 'TEXT',
      };

      for (final entry in requiredColumns.entries) {
        if (!existingNames.contains(entry.key)) {
          debugPrint('ForumTagFollowLocal: 补齐缺失列 ${entry.key}');
          await db.execute(
            'ALTER TABLE forum_tag_follow_local ADD COLUMN ${entry.key} ${entry.value}',
          );
        }
      }

      _tableFixed = true;
      debugPrint('ForumTagFollowLocal: 表结构修复完成');
    } catch (e) {
      debugPrint('ForumTagFollowLocal: 表结构修复失败: $e');
    }
  }

  /// 包装数据库操作，自动处理表结构问题
  Future<T> _withTableFix<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('no such column') || errorStr.contains('no such table')) {
        debugPrint('ForumTagFollowLocal: 检测到表结构问题，尝试修复: $e');
        await _ensureTableStructure();
        // 重试操作
        return await operation();
      }
      rethrow;
    }
  }

  /// 获取当前用户已关注的标签 ID 集合
  Future<Set<int>> getFollowedTagIds() async {
    return _withTableFix(() async {
      final userCode = await DatabaseService.getCurrentUserCode();
      if (userCode == null || userCode.isEmpty) return {};

      final rows = await DatabaseService.rawQuery('''
        SELECT tag_id FROM forum_tag_follow_local 
        WHERE user_code = ? AND is_deleted = 0
      ''', [userCode]);

      return rows
          .map((r) => r['tag_id'])
          .whereType<int>()
          .toSet();
    });
  }

  /// 获取当前用户所有已关注的标签记录
  Future<List<ForumTagFollowLocal>> getAllFollows() async {
    return _withTableFix(() async {
      final userCode = await DatabaseService.getCurrentUserCode();
      if (userCode == null || userCode.isEmpty) return [];

      final result = await BaseEntityExtension.findByCondition(
        () => ForumTagFollowLocal(),
        where: 'user_code = ? AND is_deleted = 0',
        whereArgs: [userCode],
      );

      return result.cast<ForumTagFollowLocal>();
    });
  }

  /// 关注某个标签
  Future<void> follow(ForumTag tag) async {
    return _withTableFix(() async {
      final entity = ForumTagFollowLocal(
        tagId: tag.id,
        tagName: tag.name,
        tagColor: tag.color,
      );
      await DatabaseService.insert(entity);
    });
  }

  /// 取消关注某个标签（软删除）
  Future<void> unfollow(int tagId) async {
    return _withTableFix(() async {
      final userCode = await DatabaseService.getCurrentUserCode();
      if (userCode == null) return;

      final follows = await BaseEntityExtension.findByCondition(
        () => ForumTagFollowLocal(),
        where: 'user_code = ? AND tag_id = ? AND is_deleted = 0',
        whereArgs: [userCode, tagId],
      );

      if (follows.isNotEmpty) {
        await DatabaseService.softDelete(follows.first);
      }
    });
  }

  /// 切换关注状态
  ///
  /// 返回切换后的状态：true=已关注，false=未关注
  Future<bool> toggleFollow(ForumTag tag) async {
    final followedIds = await getFollowedTagIds();
    if (followedIds.contains(tag.id)) {
      await unfollow(tag.id);
      return false;
    } else {
      await follow(tag);
      return true;
    }
  }

  /// 检查是否已初始化（本地是否有任何关注记录）
  Future<bool> get isInitialized async {
    return _withTableFix(() async {
      final userCode = await DatabaseService.getCurrentUserCode();
      if (userCode == null || userCode.isEmpty) return false;

      try {
        final result = await DatabaseService.rawQuery('''
          SELECT COUNT(*) as cnt FROM forum_tag_follow_local 
          WHERE user_code = ? AND is_deleted = 0
        ''', [userCode]);

        final count = result.first['cnt'] as int? ?? 0;
        return count > 0;
      } catch (e) {
        // 表可能存在但缺少某些列
        if (e.toString().contains('no such column')) {
          rethrow; // 让外层 _withTableFix 处理
        }
        return false;
      }
    });
  }

  /// 初始化标签关注数据
  ///
  /// 如果本地没有数据，从 Supabase 获取标签列表并默认全部关注。
  /// [remoteTags] 从 Supabase 获取的全部活跃标签列表。
  ///
  /// 返回值：
  /// - true: 初始化成功或已有数据
  /// - false: 初始化失败（表不存在等）
  Future<bool> initializeIfNeeded(List<ForumTag> remoteTags) async {
    return _withTableFix(() async {
      // 已有本地数据则跳过
      if (await isInitialized) return true;

      if (remoteTags.isEmpty) return false;

      try {
        // 批量插入所有标签的关注记录
        final entities = remoteTags.map((tag) => ForumTagFollowLocal(
          tagId: tag.id,
          tagName: tag.name,
          tagColor: tag.color,
        )).toList();

        await DatabaseService.batchInsert(entities);
        debugPrint('ForumTagFollowLocal: 初始化完成，写入 ${entities.length} 条记录');
        return true;
      } catch (e) {
        debugPrint('ForumTagFollowLocal: initializeIfNeeded 批量插入失败，尝试逐条写入: $e');

        // 降级为逐条写入
        int successCount = 0;
        for (final tag in remoteTags) {
          try {
            await follow(tag);
            successCount++;
          } catch (_) {}
        }

        if (successCount == 0) {
          debugPrint('ForumTagFollowLocal: 初始化完全失败，${remoteTags.length} 个标签均无法写入');
          return false;
        }
        debugPrint('ForumTagFollowLocal: 逐条写入成功 $successCount/${remoteTags.length}');
        return successCount == remoteTags.length;
      }
    });
  }

  /// 清除当前用户的全部关注数据（用于重置）
  Future<void> clearAll() async {
    return _withTableFix(() async {
      final userCode = await DatabaseService.getCurrentUserCode();
      if (userCode == null) return;

      final follows = await BaseEntityExtension.findByCondition(
        () => ForumTagFollowLocal(),
        where: 'user_code = ? AND is_deleted = 0',
        whereArgs: [userCode],
      );

      if (follows.isNotEmpty) {
        await DatabaseService.batchSoftDelete(follows);
      }
    });
  }

  /// 获取已关注数量
  Future<int> get followedCount async {
    return _withTableFix(() async {
      final userCode = await DatabaseService.getCurrentUserCode();
      if (userCode == null || userCode.isEmpty) return 0;

      try {
        final result = await DatabaseService.rawQuery('''
          SELECT COUNT(*) as cnt FROM forum_tag_follow_local 
          WHERE user_code = ? AND is_deleted = 0
        ''', [userCode]);

        return result.first['cnt'] as int? ?? 0;
      } catch (_) {
        return 0;
      }
    });
  }
}
