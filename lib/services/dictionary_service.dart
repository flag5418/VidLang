import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// 词典查询结果
class DictEntry {
  final String word;
  final String? phonetic;
  final String? translation;
  final String? pos;
  final int? collins;
  final bool oxford;
  final String? tag;
  final int? bnc;
  final int? frq;
  final String? exchange;

  DictEntry({
    required this.word,
    this.phonetic,
    this.translation,
    this.pos,
    this.collins,
    required this.oxford,
    this.tag,
    this.bnc,
    this.frq,
    this.exchange,
  });

  /// 获取中文释义的第一行（简明显示）
  String get shortTranslation {
    if (translation == null || translation!.isEmpty) return '';
    final lines = translation!.split('\n');
    final first = lines.first;
    final idx = first.indexOf(RegExp(r'[;;。]'));
    if (idx > 0) return first.substring(0, idx);
    return first.length > 120 ? first.substring(0, 120) : first;
  }

  /// 获取词性标签
  String get posLabel {
    if (pos == null || pos!.isEmpty) return '';
    return pos!.replaceAll('/', ', ');
  }

  Map<String, dynamic> toJson() => {
    'word': word,
    'phonetic': phonetic,
    'translation': translation,
    'shortTranslation': shortTranslation,
    'pos': pos,
    'collins': collins,
    'oxford': oxford,
    'tag': tag,
    'bnc': bnc,
    'frq': frq,
  };
}

/// ECDICT 本地词典查询服务
///
/// 使用 stardict.db 离线词典数据库查询单词释义。
/// Android 和 iOS 均可用，无需网络和 Google 服务。
///
/// 词典数据来源: https://github.com/skywind3000/ECDICT
class DictionaryService {
  DictionaryService._();
  static final DictionaryService _instance = DictionaryService._();
  factory DictionaryService() => _instance;

  Database? _db;
  bool _initialized = false;

  /// 初始化词典（从 assets 拷贝到可写目录）
  Future<void> initialize() async {
    if (_initialized) return;

    final dir = await getApplicationDocumentsDirectory();
    final dbPath = join(dir.path, 'stardict.db');

    if (!await File(dbPath).exists()) {
      final blob = await rootBundle.load('assets/dictionary/stardict.db');
      final bytes = blob.buffer.asUint8List();
      await File(dbPath).writeAsBytes(bytes);
    }

    _db = await openDatabase(dbPath, readOnly: true);
    _initialized = true;
  }

  /// 查询单词（精确匹配）
  Future<DictEntry?> lookup(String word) async {
    await initialize();
    if (_db == null) return null;

    final trimmed = word.trim().toLowerCase();
    if (trimmed.isEmpty) return null;
    final clean = trimmed.replaceAll(RegExp(r'[^a-zA-Z0-9-]'), '');
    if (clean.isEmpty) return null;

    final rows = await _db!.query(
      'stardict',
      columns: ['word', 'phonetic', 'translation', 'pos', 'collins', 'oxford', 'tag', 'bnc', 'frq', 'exchange'],
      where: 'word = ?',
      whereArgs: [clean],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    final r = rows.first;
    return DictEntry(
      word: r['word'] as String,
      phonetic: r['phonetic'] as String?,
      translation: r['translation'] as String?,
      pos: r['pos'] as String?,
      collins: r['collins'] as int?,
      oxford: (r['oxford'] as int?) == 1,
      tag: r['tag'] as String?,
      bnc: r['bnc'] as int?,
      frq: r['frq'] as int?,
      exchange: r['exchange'] as String?,
    );
  }

  /// 批量查询多个单词
  Future<List<DictEntry?>> lookupAll(List<String> words) async {
    final results = <DictEntry?>[];
    for (final w in words) {
      results.add(await lookup(w));
    }
    return results;
  }

  void dispose() {
    _db?.close();
    _db = null;
    _initialized = false;
  }
}
