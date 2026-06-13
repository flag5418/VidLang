import 'package:vidlang/models/base_entity.dart';
import 'package:vidlang/models/word_book_tag.dart';
import 'package:vidlang/models/word_tag.dart';
import 'package:vidlang/services/database_service.dart';

class WordTagService {
  static Future<List<WordTag>> listTags() async {
    return BaseEntityExtension.findByCondition(
      () => WordTag(),
      where: 'is_deleted = 0',
      orderBy: 'order_index ASC, created_at ASC',
    );
  }

  static Future<List<WordTag>> listTagsForWord(String wordBookCode) async {
    final all = await listTagsForWords([wordBookCode]);
    return all[wordBookCode] ?? const [];
  }

  static Future<Map<String, List<WordTag>>> listTagsForWords(List<String> wordBookCodes) async {
    if (wordBookCodes.isEmpty) return const {};

    final db = await DatabaseService.database;
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

    final rows = await db.rawQuery(sql.toString(), args);
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

    final uniqueTagCodes = tagCodes.where((code) => code.trim().isNotEmpty).toSet().toList();
    if (uniqueTagCodes.isEmpty) return;

    final entities = uniqueTagCodes
        .map((tagCode) => WordBookTag(wordBookCode: wordBookCode, tagCode: tagCode))
        .toList();
    await DatabaseService.batchInsert(entities);
  }
}
