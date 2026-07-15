import 'package:vidlang/models/base_entity.dart';
import 'package:vidlang/models/word_book_tag.dart';
import 'package:vidlang/models/word_tag.dart';
import 'package:vidlang/services/database_service.dart';

class WordTagService {
  /// 默认标签名：未分类
  static const String defaultTagName = '未分类';
  static const List<String> builtInDifficultyTags = [defaultTagName, '小学', '初中', '高中', 'CET4', 'CET6', '考研', '雅思', '托福', 'GRE'];

  /// 确保默认标签存在，返回其 code
  static Future<String> ensureDefaultTag() async {
    final existing = await BaseEntityExtension.findByCondition(() => WordTag(), where: 'name = ? AND is_deleted = 0', whereArgs: [defaultTagName]);
    if (existing.isNotEmpty && existing.first.code != null) {
      return existing.first.code!;
    }
    final tag = WordTag(name: defaultTagName, orderIndex: 0);
    await DatabaseService.insert(tag);
    return tag.code!;
  }

  static Future<List<WordTag>> listTags() async {
    return BaseEntityExtension.findByCondition(() => WordTag(), where: 'is_deleted = 0', orderBy: 'order_index ASC, created_at ASC');
  }

  static Future<void> ensureBuiltInDifficultyTagsExist() async {
    for (int i = 0; i < builtInDifficultyTags.length; i++) {
      await _ensureTagExists(builtInDifficultyTags[i], orderIndex: i);
    }
  }

  static Future<WordTag> _ensureTagExists(String name, {required int orderIndex}) async {
    final existing = await BaseEntityExtension.findByCondition(() => WordTag(), where: 'name = ? AND is_deleted = 0', whereArgs: [name]);
    if (existing.isNotEmpty) {
      final tag = existing.first;
      if (tag.orderIndex != orderIndex) {
        tag.orderIndex = orderIndex;
        await DatabaseService.update(tag);
      }
      return tag;
    }
    final tag = WordTag(name: name, orderIndex: orderIndex);
    await DatabaseService.insert(tag);
    return tag;
  }

  static Future<List<WordTag>> listTagsForWord(String wordBookCode) async {
    final all = await listTagsForWords([wordBookCode]);
    return all[wordBookCode] ?? const [];
  }

  static Future<Map<String, List<WordTag>>> listTagsForWords(List<String> wordBookCodes) async {
    if (wordBookCodes.isEmpty) return const {};

    final userCode = await DatabaseService.getCurrentUserCode();
    final placeholders = List.filled(wordBookCodes.length, '?').join(', ');
    final args = <Object?>[...wordBookCodes];

    final sql = StringBuffer('''
      SELECT
        wbt.word_book_code,
        wt.*
      FROM word_book_tag wbt
      INNER JOIN word_tag wt
        ON wt.code = wbt.tag_code
        AND wt.is_deleted = 0
      WHERE wbt.is_deleted = 0
        AND wbt.word_book_code IN ($placeholders)
    ''');

    if (userCode != null) {
      sql.write(' AND wbt.user_code = ? AND wt.user_code = ?');
      args.addAll([userCode, userCode]);
    }

    sql.write(' ORDER BY wt.order_index ASC, wt.created_at ASC');

    final rows = await DatabaseService.rawQuery(sql.toString(), args);
    final grouped = <String, List<WordTag>>{};
    for (final row in rows) {
      final code = row['word_book_code']?.toString() ?? '';
      if (code.isEmpty) continue;
      grouped.putIfAbsent(code, () => <WordTag>[]).add(WordTag().fromMap(row) as WordTag);
    }
    return grouped;
  }

  static Future<void> replaceTags(String wordBookCode, List<String> tagCodes) async {
    final current = await BaseEntityExtension.findByCondition(
      () => WordBookTag(),
      where: 'word_book_code = ? AND is_deleted = 0',
      whereArgs: [wordBookCode],
    );

    if (current.isNotEmpty) {
      await DatabaseService.batchSoftDelete(current);
    }

    // 没有选中标签时，兜底关联到"未分类"
    final uniqueTagCodes = tagCodes.where((code) => code.trim().isNotEmpty).toSet().toList();
    if (uniqueTagCodes.isEmpty) {
      final defaultCode = await ensureDefaultTag();
      uniqueTagCodes.add(defaultCode);
    }

    final entities = uniqueTagCodes.map((tagCode) => WordBookTag(wordBookCode: wordBookCode, tagCode: tagCode)).toList();
    await DatabaseService.batchInsert(entities);
  }

  /// 创建新标签
  static Future<WordTag?> createTag(String name) async {
    if (name.trim().isEmpty) return null;
    final existing = await BaseEntityExtension.findByCondition(() => WordTag(), where: 'name = ? AND is_deleted = 0', whereArgs: [name.trim()]);
    if (existing.isNotEmpty) return existing.first;
    final tag = WordTag(name: name.trim(), orderIndex: builtInDifficultyTags.length + 10);
    await DatabaseService.insert(tag);
    return tag;
  }
}
