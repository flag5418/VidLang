import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:vidlang/models/config.dart';
import 'package:vidlang/models/participle.dart';
import 'package:vidlang/models/study_record.dart';
import 'package:vidlang/models/subtitles.dart';
import 'package:vidlang/models/user.dart';
import 'package:vidlang/models/video_folder.dart';
import 'package:vidlang/models/video_info.dart';
import 'package:vidlang/providers/file_provider.dart';
import 'package:vidlang/providers/user_provider.dart';
import 'package:vidlang/services/database_service.dart';
import 'package:vidlang/services/settings_service.dart';
import 'package:vidlang/services/thumbnail_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('deleteFolder should soft-delete db rows and delete files', (tester) async {
    DatabaseService.registerEntities({
      'video_folder': EntityConfig(creator: () => VideoFolder(), description: '视频文件夹表'),
      'video_info': EntityConfig(creator: () => VideoInfo(), description: '视频信息表'),
      'subtitles': EntityConfig(creator: () => Subtitles(), description: '字幕表（支持全文检索）', enableFullTextSearch: true),
      'participle': EntityConfig(creator: () => Participle(), description: '分词表（支持全文检索）', enableFullTextSearch: true),
      'config': EntityConfig(creator: () => Config(), description: '配置表'),
      'study_record': EntityConfig(creator: () => StudyRecord(), description: '学习记录表'),
      'user': EntityConfig(creator: () => User(), description: '用户表'),
    });

    await DatabaseService.database;
    await ensureDefaultAdminSession();

    final groupCode = await SettingsService.ensureDefaultGroupCode();
    final folderCode = const Uuid().v4().replaceAll('-', '');
    final folderName = '_test_delete_$folderCode';
    final folder = VideoFolder(name: folderName, type: VideoFolderType.virtual, parentCode: groupCode, thumbnailTime: 0)..code = folderCode;
    await DatabaseService.insert(folder);

    final docs = await getApplicationDocumentsDirectory();
    final videoPath = '${docs.path}/_tmp_$folderCode.bin';
    final subtitlePath = '${docs.path}/_tmp_$folderCode.srt';
    await File(videoPath).writeAsBytes([1, 2, 3]);
    await File(subtitlePath).writeAsString('1\n00:00:00,000 --> 00:00:01,000\nhi\n');

    final videoCode = const Uuid().v4().replaceAll('-', '');
    final coverRelative = 'covers/$folderCode/$videoCode.png';
    final coverFull = await ThumbnailService.getFullPath(coverRelative);
    await File(coverFull).create(recursive: true);
    await File(coverFull).writeAsBytes([0]);

    final video = VideoInfo(
      name: 'tmp',
      folderCode: folderCode,
      filePath: videoPath,
      subtitlePath: subtitlePath,
      extensionName: 'bin',
      duration: 0,
      cover: coverRelative,
      hasSubtitles: true,
    )..code = videoCode;
    await DatabaseService.insert(video);

    final s = Subtitles(videoCode: videoCode, startPosition: 0, endPosition: 1000, content: 'hi');
    await DatabaseService.insert(s);
    final p = Participle(videoCode: videoCode, subtitlesCode: s.code!, content: 'hi');
    await DatabaseService.insert(p);

    final notifier = FileNotifier();
    final err = await notifier.deleteFolder(folderCode);
    expect(err, isNull);

    final folders = await DatabaseService.findByCondition(() => VideoFolder(), where: 'code = ?', whereArgs: [folderCode], limit: 1);
    expect(folders.length, 1);
    expect(folders.first.isDeleted, isTrue);

    final videos = await DatabaseService.findByCondition(() => VideoInfo(), where: 'code = ?', whereArgs: [videoCode], limit: 1);
    expect(videos.length, 1);
    expect(videos.first.isDeleted, isTrue);

    final subtitles = await DatabaseService.findByCondition(() => Subtitles(), where: 'video_code = ? AND is_deleted = 0', whereArgs: [videoCode]);
    expect(subtitles.length, 0);

    final participles = await DatabaseService.findByCondition(() => Participle(), where: 'video_code = ? AND is_deleted = 0', whereArgs: [videoCode]);
    expect(participles.length, 0);

    expect(await File(videoPath).exists(), isFalse);
    expect(await File(subtitlePath).exists(), isFalse);
  });
}


/// 集成测试辅助函数：确保有默认管理员会话
Future<void> ensureDefaultAdminSession() async {
  // 检查是否已有管理员用户，如无则创建一个
  final users = await DatabaseService.findByCondition(
    () => User(),
    where: 'role = ?',
    whereArgs: ['admin'],
    limit: 1,
  );
  if (users.isEmpty) {
    final user = User(
      username: 'admin',
      nickname: '管理员',
      email: 'admin@test.local',
      role: 'admin',
    );
    await DatabaseService.insert(user);
  }
}
