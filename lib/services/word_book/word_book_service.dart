import 'dart:convert';

import 'package:flutter_vscode_logger/flutter_vscode_logger.dart';
import 'package:vidlang/models/base_entity.dart';
import 'package:vidlang/models/word_book.dart';
import 'package:vidlang/models/word_book_query_models.dart';
import 'package:vidlang/models/word_card_data.dart';
import 'package:vidlang/services/database_service.dart';
import 'package:vidlang/services/files/thumbnail_service.dart';

/// 单词收藏服务
///
/// 提供单词收藏的完整流程：
/// - 判定是否为可收藏的单个单词
/// - 视频/音频来源时截取当前画面截图
/// - 保存 WordBook 记录
class WordBookService {
  /// 判定文本是否为可收藏的单个单词
  ///
  /// 规则：
  /// - 去除首尾空白后不为空
  /// - 仅包含一个词（无空格）
  /// - 仅包含英文字母（允许带撇号如 don't）
  static bool isSingleWord(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    // 不包含空格 = 单个词
    if (trimmed.contains(' ')) return false;
    // 允许英文字母 + 撇号（如 don't, it's）
    return RegExp(r"^[a-zA-Z][a-zA-Z']*$").hasMatch(trimmed);
  }

  static WordBook applyMastery(WordBook word, {required bool recognized, DateTime? reviewedAt}) {
    final now = reviewedAt ?? DateTime.now();
    word.masteryLevel = recognized ? 'mastered' : 'learning';
    word.masteredAt = recognized ? now : null;
    word.lastReviewAt = now;
    return word;
  }

  static WordBook mergeTestResult(WordBook word, {required bool reviewed, required bool correct, DateTime? reviewedAt}) {
    if (!reviewed) return word;
    word.reviewCount += 1;
    if (correct) {
      word.correctCount += 1;
    }
    word.lastReviewAt = reviewedAt ?? DateTime.now();
    return word;
  }

  static List<WordDefinition> parseDefinitions(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded.map((item) {
        if (item is Map<String, dynamic>) {
          return WordDefinition(
            partOfSpeech: item['partOfSpeech'] as String? ?? item['part_of_speech'] as String?,
            meaning: item['meaning'] as String? ?? '',
            example: item['example'] as String?,
          );
        }
        if (item is Map) {
          return WordDefinition(
            partOfSpeech: item['partOfSpeech']?.toString() ?? item['part_of_speech']?.toString(),
            meaning: item['meaning']?.toString() ?? '',
            example: item['example']?.toString(),
          );
        }
        return WordDefinition(meaning: item.toString());
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  static String? firstMeaning(String? raw) {
    final definitions = parseDefinitions(raw);
    if (definitions.isEmpty) return null;
    final first = definitions.first;
    final pos = first.partOfSpeech?.trim();
    if (pos != null && pos.isNotEmpty) {
      return '$pos. ${first.meaning}';
    }
    return first.meaning;
  }

  /// 收藏单词
  ///
  /// [word] 单词
  /// [sourceType] 来源类型：video / article / music
  /// [sourceCode] 来源资源 code
  /// [sourceTitle] 来源标题
  /// [contextSentence] 上下文句子
  /// [segmentCode] 字幕/句子 code
  /// [wordCardData] 查询结果（用于缓存释义/音标）
  /// [videoPath] 视频文件路径（video/music 类型用于截图）
  /// [positionMs] 当前播放位置毫秒（video/music 类型用于截图）
  ///
  /// 返回保存后的 WordBook 实例，失败返回 null
  static Future<WordBook?> saveWord({
    required String word,
    required String sourceType,
    required String sourceCode,
    String? sourceTitle,
    String? contextSentence,
    String? segmentCode,
    WordCardData? wordCardData,
    String? videoPath,
    int? positionMs,
  }) async {
    final trimmed = word.trim();
    if (!isSingleWord(trimmed)) {
      logger.warning('收藏失败：非单个单词 "$trimmed"', tag: 'WordBook');
      return null;
    }

    // 检查是否已收藏过（同一用户 + 同一单词 + 同一来源）
    final userCode = await DatabaseService.getCurrentUserCode();
    final existing = await DatabaseService.findByCondition(
      () => WordBook(),
      where: 'word = ? AND source_type = ? AND source_code = ? AND is_deleted = 0',
      whereArgs: [trimmed.toLowerCase(), sourceType, sourceCode],
    );
    if (existing.isNotEmpty) {
      logger.info('单词已收藏: "$trimmed" from $sourceType/$sourceCode', tag: 'WordBook');
      return existing.first;
    }

    final wb = WordBook(
      word: trimmed.toLowerCase(),
      sourceType: sourceType,
      sourceCode: sourceCode,
      sourceTitle: sourceTitle,
      segmentCode: segmentCode,
      contextSentence: contextSentence,
    );

    // 从 WordCardData 缓存释义/音标
    if (wordCardData != null) {
      wb.phoneticUk = wordCardData.phonetic;
      wb.phoneticUs = wordCardData.phonetic;
      // 缓存 definitions 为 JSON
      if (wordCardData.definitions.isNotEmpty) {
        final defsJson = wordCardData.definitions.map((d) => {'partOfSpeech': d.partOfSpeech, 'meaning': d.meaning, 'example': d.example}).toList();
        wb.definitionsJson = jsonEncode(defsJson);
      }
    }

    // 视频/音频类型：截取当前画面截图
    if ((sourceType == 'video' || sourceType == 'music') && videoPath != null && positionMs != null) {
      try {
        final screenshotPath = await ThumbnailService.generateWordScreenshot(videoPath, sourceCode, positionMs: positionMs, wordCode: wb.code!);
        wb.screenshotPath = screenshotPath;
      } catch (e) {
        logger.warning('截图失败，继续保存: $e', tag: 'WordBook');
      }
    }

    // 设置间隔复习首次时间：+1天
    wb.nextReviewAt = DateTime.now().add(const Duration(days: 1));
    wb.userCode = userCode;

    try {
      await wb.save();
      logger.info('收藏成功: "$trimmed" from $sourceType/$sourceCode', tag: 'WordBook');
      return wb;
    } catch (e, st) {
      logger.error('收藏失败: $e', tag: 'WordBook', error: e, stackTrace: st);
      return null;
    }
  }

  static Future<WordBook?> saveSentence({
    required String text,
    required String sourceType,
    required String sourceCode,
    String? sourceTitle,
    String? segmentCode,
    String? translation,
    String? note,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    final userCode = await DatabaseService.getCurrentUserCode();
    final existing = await DatabaseService.findByCondition(
      () => WordBook(),
      where: 'content_type = ? AND source_text = ? AND source_type = ? AND source_code = ? AND is_deleted = 0',
      whereArgs: ['sentence', trimmed, sourceType, sourceCode],
    );
    if (existing.isNotEmpty) {
      return existing.first;
    }

    final wb = WordBook(
      word: trimmed,
      contentType: 'sentence',
      sourceText: trimmed,
      sourceTranslation: translation,
      sourceType: sourceType,
      sourceCode: sourceCode,
      sourceTitle: sourceTitle,
      segmentCode: segmentCode,
      note: note,
    );
    wb.userCode = userCode;

    try {
      await wb.save();
      return wb;
    } catch (e, st) {
      logger.error('收藏句子失败: $e', tag: 'WordBook', error: e, stackTrace: st);
      return null;
    }
  }

  /// 取消收藏
  static Future<bool> removeWord(int id) async {
    try {
      final wb = await DatabaseService.findById(id, () => WordBook());
      if (wb != null) {
        await wb.softDelete();
        return true;
      }
      return false;
    } catch (e) {
      logger.error('取消收藏失败: $e', tag: 'WordBook', error: e);
      return false;
    }
  }

  /// 检查单词是否已收藏
  static Future<bool> isWordSaved({required String word, required String sourceType, required String sourceCode}) async {
    final count = await DatabaseService.count(
      () => WordBook(),
      where: 'word = ? AND source_type = ? AND source_code = ? AND is_deleted = 0',
      whereArgs: [word.trim().toLowerCase(), sourceType, sourceCode],
    );
    return count > 0;
  }

  static Future<bool> isSentenceSaved({required String text, required String sourceType, required String sourceCode}) async {
    final count = await DatabaseService.count(
      () => WordBook(),
      where: 'content_type = ? AND source_text = ? AND source_type = ? AND source_code = ? AND is_deleted = 0',
      whereArgs: ['sentence', text.trim(), sourceType, sourceCode],
    );
    return count > 0;
  }

  static Future<bool> unsaveWord({required String word, required String sourceType, required String sourceCode}) async {
    try {
      final trimmed = word.trim().toLowerCase();
      final rows = await DatabaseService.findByCondition<WordBook>(
        () => WordBook(),
        where: 'word = ? AND source_type = ? AND source_code = ? AND is_deleted = 0',
        whereArgs: [trimmed, sourceType, sourceCode],
        limit: 1,
      );
      if (rows.isEmpty) return false;
      await rows.first.softDelete();
      return true;
    } catch (e) {
      logger.error('取消收藏失败: $e', tag: 'WordBook', error: e);
      return false;
    }
  }

  static Future<bool> unsaveSentence({required String text, required String sourceType, required String sourceCode}) async {
    try {
      final trimmed = text.trim();
      final rows = await DatabaseService.findByCondition<WordBook>(
        () => WordBook(),
        where: 'content_type = ? AND source_text = ? AND source_type = ? AND source_code = ? AND is_deleted = 0',
        whereArgs: ['sentence', trimmed, sourceType, sourceCode],
        limit: 1,
      );
      if (rows.isEmpty) return false;
      await rows.first.softDelete();
      return true;
    } catch (e) {
      logger.error('取消收藏句子失败: $e', tag: 'WordBook', error: e);
      return false;
    }
  }

  static Future<WordBook?> findWordByCode(String code) async {
    return BaseEntityExtension.findByCode(code, () => WordBook());
  }

  static Future<List<WordBook>> queryWords(WordBookFilter filter) async {
    final userCode = await DatabaseService.getCurrentUserCode();
    final args = <Object?>[];
    final where = <String>['wb.is_deleted = 0'];

    if (filter.status != null) {
      where.add('wb.mastery_level = ?');
      args.add(WordBook.normalizeMasteryLevel(filter.status!));
    }

    if (filter.contentType != null && filter.contentType!.isNotEmpty) {
      where.add('wb.content_type = ?');
      args.add(filter.contentType);
    }

    if (userCode != null) {
      where.add('wb.user_code = ?');
      args.add(userCode);
    }

    if (filter.tagCode != null && filter.tagCode!.isNotEmpty) {
      where.add('wbt.tag_code = ?');
      args.add(filter.tagCode);
      where.add('wbt.is_deleted = 0');
      if (userCode != null) {
        where.add('wbt.user_code = ?');
        args.add(userCode);
      }
    }

    final keyword = filter.keyword.trim();
    if (keyword.isNotEmpty) {
      where.add('(wb.word LIKE ? OR wb.context_sentence LIKE ? OR wb.source_text LIKE ? OR wb.note LIKE ? OR wb.source_title LIKE ?)');
      final keywordLike = '%$keyword%';
      args.addAll([keywordLike, keywordLike, keywordLike, keywordLike, keywordLike]);
    }

    final joinClause = filter.tagCode != null && filter.tagCode!.isNotEmpty ? 'INNER JOIN word_book_tag wbt ON wbt.word_book_code = wb.code' : '';

    final rows = await DatabaseService.rawQuery('''
      SELECT DISTINCT wb.*
      FROM word_book wb
      $joinClause
      WHERE ${where.join(' AND ')}
      ORDER BY
        CASE WHEN wb.next_review_at IS NULL THEN 1 ELSE 0 END,
        wb.next_review_at ASC,
        wb.created_at DESC
      ''', args);

    return rows.map((row) => WordBook().fromMap(row) as WordBook).toList();
  }

  static Future<List<WordBookNavItem>> loadNavItems(String status) async {
    final normalizedStatus = WordBook.normalizeMasteryLevel(status);
    final userCode = await DatabaseService.getCurrentUserCode();
    final args = <Object?>[normalizedStatus];
    final baseWhere = <String>['wb.is_deleted = 0', 'wb.mastery_level = ?'];

    if (userCode != null) {
      baseWhere.add('wb.user_code = ?');
      args.add(userCode);
    }

    final totalRows = await DatabaseService.rawQuery('''
      SELECT COUNT(*) AS count
      FROM word_book wb
      WHERE ${baseWhere.join(' AND ')}
      ''', args);
    final totalCount = (totalRows.first['count'] as int?) ?? 0;

    final tagRows = await DatabaseService.rawQuery(
      '''
      SELECT
        wt.code AS tag_code,
        wt.name AS tag_name,
        COUNT(DISTINCT wb.code) AS count
      FROM word_book wb
      INNER JOIN word_book_tag wbt
        ON wbt.word_book_code = wb.code
        AND wbt.is_deleted = 0
      INNER JOIN word_tag wt
        ON wt.code = wbt.tag_code
        AND wt.is_deleted = 0
      WHERE ${baseWhere.join(' AND ')}
      ${userCode != null ? 'AND wbt.user_code = ? AND wt.user_code = ?' : ''}
      GROUP BY wt.code, wt.name, wt.order_index
      ORDER BY wt.order_index ASC, wt.created_at ASC
      ''',
      [
        ...args,
        if (userCode != null) ...[userCode, userCode],
      ],
    );

    return [
      WordBookNavItem(code: '${normalizedStatus}_all', label: '全部', count: totalCount, status: normalizedStatus),
      ...tagRows.map(
        (row) => WordBookNavItem(
          code: row['tag_code']?.toString() ?? '',
          label: row['tag_name']?.toString() ?? '',
          count: row['count'] as int? ?? 0,
          status: normalizedStatus,
          tagCode: row['tag_code']?.toString(),
        ),
      ),
    ];
  }

  /// 加载知识库 Tab 导航项列表
  ///
  /// 按 masteryLevel（learning/mastered）分组，每组下按来源文章（sourceType + sourceCode + sourceTitle）聚合。
  /// 返回结构与 [loadNavItems] 相同，但分组键是文章而非标签。
  static Future<List<WordBookNavItem>> loadNavItemsForKnowledgeBase(String status) async {
    final normalizedStatus = WordBook.normalizeMasteryLevel(status);
    final userCode = await DatabaseService.getCurrentUserCode();
    final args = <Object?>[normalizedStatus, 'sentence'];
    final baseWhere = <String>['wb.is_deleted = 0', 'wb.mastery_level = ?', 'wb.content_type = ?'];

    if (userCode != null) {
      baseWhere.add('wb.user_code = ?');
      args.add(userCode);
    }

    final totalRows = await DatabaseService.rawQuery('''
      SELECT COUNT(*) AS count
      FROM word_book wb
      WHERE ${baseWhere.join(' AND ')}
      ''', args);
    final totalCount = (totalRows.first['count'] as int?) ?? 0;

    final articleRows = await DatabaseService.rawQuery('''
      SELECT
        wb.source_type AS source_type,
        wb.source_code AS source_code,
        wb.source_title AS source_title,
        COUNT(DISTINCT wb.code) AS count
      FROM word_book wb
      WHERE ${baseWhere.join(' AND ')}
      GROUP BY wb.source_type, wb.source_code, wb.source_title
      ORDER BY wb.source_title ASC
      ''', args);

    return [
      WordBookNavItem(code: '${normalizedStatus}_all', label: '全部', count: totalCount, status: normalizedStatus),
      ...articleRows.map(
        (row) => WordBookNavItem(
          code: '${normalizedStatus}_${row['source_code']}',
          label: row['source_title']?.toString() ?? '未命名',
          count: row['count'] as int? ?? 0,
          status: normalizedStatus,
          tagCode: row['source_code']?.toString(),
        ),
      ),
    ];
  }

  static Future<bool> updateMastery({required String wordBookCode, required bool recognized}) async {
    try {
      final word = await findWordByCode(wordBookCode);
      if (word == null) return false;
      applyMastery(word, recognized: recognized);
      await word.save();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> softDeleteWord(String wordBookCode) async {
    try {
      final word = await findWordByCode(wordBookCode);
      if (word == null || !word.isMastered) return false;
      await word.softDelete();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Map<String, String> parseMorphology(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return const {};
      return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
    } catch (_) {
      return const {};
    }
  }

  static Future<int> countTodayReviewed() async {
    try {
      final userCode = await DatabaseService.getCurrentUserCode();
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

      final where = <String>['is_deleted = 0', 'last_review_at >= ?', 'last_review_at <= ?'];
      final args = <Object?>[todayStart, todayEnd];

      if (userCode != null) {
        where.add('user_code = ?');
        args.add(userCode);
      }

      final rows = await DatabaseService.rawQuery('SELECT COUNT(*) as count FROM word_book WHERE ${where.join(' AND ')}', args);
      return (rows.first['count'] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<int> countTotalWords() async {
    try {
      final userCode = await DatabaseService.getCurrentUserCode();

      final where = <String>['is_deleted = 0'];
      final args = <Object?>[];

      if (userCode != null) {
        where.add('user_code = ?');
        args.add(userCode);
      }

      final rows = await DatabaseService.rawQuery('SELECT COUNT(*) as count FROM word_book WHERE ${where.join(' AND ')}', args);
      return (rows.first['count'] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> recordTestResults(List<WordBookTestResult> results) async {
    if (results.isEmpty) return;

    final merged = <String, WordBookTestResult>{};
    for (final result in results) {
      final existing = merged[result.wordBookCode];
      if (existing == null) {
        merged[result.wordBookCode] = result;
        continue;
      }
      merged[result.wordBookCode] = WordBookTestResult(
        wordBookCode: result.wordBookCode,
        correct: existing.correct || result.correct,
        reviewedAt: result.reviewedAt.isAfter(existing.reviewedAt) ? result.reviewedAt : existing.reviewedAt,
      );
    }

    for (final result in merged.values) {
      final word = await findWordByCode(result.wordBookCode);
      if (word == null) continue;
      mergeTestResult(word, reviewed: true, correct: result.correct, reviewedAt: result.reviewedAt);
      await word.save();
    }
  }
}
