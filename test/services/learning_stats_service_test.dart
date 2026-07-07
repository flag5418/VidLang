import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vidlang/models/study_record.dart';
import 'package:vidlang/services/learning_stats_service.dart';

/// LearningStatsService 核心路径单元测试
///
/// 覆盖范围：
/// 1. 会话管理：beginSession / endSession / switchResource（内存状态）
/// 2. 会话状态字段：resourceCode / resourceType / folderCode
/// 3. 行为指标接口调用（不依赖 DB 的路径）
/// 4. 查询方法空数据返回值
/// 5. 数据模型：ResourceLearningSummary / RecentResource
/// 6. 边界条件：重复 begin、无活跃会话时 end 等
///
/// 注意：涉及 DatabaseService 写入的测试（如 beginSession 创建记录、
/// endSession 更新记录）需要 path_provider 插件，在纯单元测试环境中
/// 会抛 MissingPluginException。这些场景应在 integration_test 中覆盖。
void main() {
  final service = LearningStatsService.instance;

  group('LearningStatsService - 会话管理（内存状态）', () {
    test('初始状态应无活跃会话', () {
      expect(service.isSessionActive, isFalse);
      expect(service.currentResourceCode, isNull);
      expect(service.currentResourceType, isNull);
      expect(service.currentFolderCode, isNull);
    });

    test('beginSession 应设置活跃状态和资源信息', () async {
      await service.endSession();

      await service.beginSession(
        resourceCode: 'test-video-001',
        resourceType: 'video',
        folderCode: 'folder-001',
      );

      expect(service.isSessionActive, isTrue);
      expect(service.currentResourceCode, equals('test-video-001'));
      expect(service.currentResourceType, equals('video'));
      expect(service.currentFolderCode, equals('folder-001'));

      await service.endSession();
    });

    test('beginSession 同一资源重复调用应忽略', () async {
      await service.endSession();

      await service.beginSession(
        resourceCode: 'dup-video',
        resourceType: 'video',
      );

      final firstStartTime = DateTime.now(); // 记录第一次 begin 的时间点

      // 重复调用同一资源
      await service.beginSession(
        resourceCode: 'dup-video',
        resourceType: 'video',
      );

      // 应该仍然只有一个活跃会话，状态不变
      expect(service.isSessionActive, isTrue);
      expect(service.currentResourceCode, equals('dup-video'));

      await service.endSession();
    });

    test('beginSession 不同资源应先结束旧会话再开启新的', () async {
      await service.endSession();

      await service.beginSession(
        resourceCode: 'old-resource',
        resourceType: 'article',
        folderCode: 'folder-old',
      );

      expect(service.currentResourceCode, equals('old-resource'));
      expect(service.currentFolderCode, equals('folder-old'));

      // 切换到新资源（内部会先 end 再 begin）
      await service.beginSession(
        resourceCode: 'new-resource',
        resourceType: 'video',
        folderCode: 'folder-new',
      );

      expect(service.currentResourceCode, equals('new-resource'));
      expect(service.currentResourceType, equals('video'));
      expect(service.currentFolderCode, equals('folder-new'));

      await service.endSession();
    });

    test('endSession 应重置所有会话状态', () async {
      await service.endSession();

      await service.beginSession(
        resourceCode: 'to-end',
        resourceType: 'music',
        folderCode: 'folder-music',
      );

      expect(service.isSessionActive, isTrue);

      await service.endSession();

      expect(service.isSessionActive, isFalse);
      expect(service.currentResourceCode, isNull);
      expect(service.currentResourceType, isNull);
      expect(service.currentFolderCode, isNull);
    });

    test('endSession 无活跃会话时应安全返回（不抛异常）', () async {
      await service.endSession();

      // 多次连续调用不应抛异常
      await service.endSession();
      await service.endSession();

      expect(service.isSessionActive, isFalse);
    });
  });

  group('LearningStatsService - switchResource 原子操作', () {
    test('switchResource 应完整切换会话', () async {
      await service.endSession();

      await service.beginSession(
        resourceCode: 'switch-from',
        resourceType: 'video',
      );

      expect(service.currentResourceCode, equals('switch-from'));

      await service.switchResource(
        resourceCode: 'switch-to',
        resourceType: 'article',
        folderCode: 'folder-art',
      );

      expect(service.currentResourceCode, equals('switch-to'));
      expect(service.currentResourceType, equals('article'));
      expect(service.currentFolderCode, equals('folder-art'));

      await service.endSession();
    });

    test('switchResource 无活跃会话时应安全执行', () async {
      await service.endSession();

      await service.switchResource(
        resourceCode: 'fresh-switch',
        resourceType: 'music',
        folderCode: 'folder-music-new',
      );

      expect(service.isSessionActive, isTrue);
      expect(service.currentResourceCode, equals('fresh-switch'));

      await service.endSession();
    });
  });

  group('LearningStatsService - folderCode 可选参数', () {
    test('不传 folderCode 时 currentFolderCode 返回 null', () async {
      await service.endSession();

      await service.beginSession(
        resourceCode: 'no-folder-res',
        resourceType: 'video',
        // 不传 folderCode
      );

      expect(service.isSessionActive, isTrue);
      expect(service.currentResourceCode, equals('no-folder-res'));
      expect(service.currentFolderCode, isNull);

      await service.endSession();
    });

    test('传入空字符串 folderCode 时 currentFolderCode 返回空字符串', () async {
      await service.endSession();

      await service.beginSession(
        resourceCode: 'empty-folder-res',
        resourceType: 'article',
        folderCode: '',
      );

      // 空字符串会被原样保存，与 null（不传）行为不同
      expect(service.isSessionActive, isTrue);
      expect(service.currentFolderCode, equals(''));

      await service.endSession();
    });
  });

  group('LearningStatsService - 行为指标（接口调用验证）', () {
    test('recordFollowScore 无活跃会话时不崩溃', () async {
      await service.endSession();

      // 没有活跃会话时调用不应抛异常
      await service.recordFollowScore(
        resourceCode: 'orphan-follow',
        score: 90.0,
        sentenceCode: 's1',
      );
      // 静默通过即可
    });

    test('recordQuizResult 无活跃会话时不崩溃', () async {
      await service.endSession();

      await service.recordQuizResult(
        resourceCode: 'orphan-quiz',
        questionType: 'listen_choose',
        isCorrect: true,
      );
      // 静默通过即可
    });

    test('completeTestSession totalQuestions=0 应安全返回', () async {
      await service.endSession();

      // 不应抛异常
      await service.completeTestSession(
        resourceCode: 'zero-quiz',
        totalQuestions: 0,
        correctCount: 0,
      );
    });

    test('completeTestSession 正常参数应安全执行', () async {
      await service.endSession();

      await service.completeTestSession(
        resourceCode: 'normal-quiz',
        totalQuestions: 10,
        correctCount: 8,
        resourceType: 'video',
      );
      // 不抛异常即通过
    });
  });

  group('LearningStatsService - 数据模型', () {
    group('ResourceLearningSummary', () {
      test('formattedDuration 大于 1 小时', () {
        final summary = ResourceLearningSummary(
          resourceCode: 'test',
          resourceType: 'video',
          totalDurationSeconds: 7260, // 2h 1min
          sessionCount: 3,
          totalFollowCount: 10,
        );
        expect(summary.formattedDuration, equals('2h 1m'));
      });

      test('formattedDuration 小于 1 小时', () {
        final summary = ResourceLearningSummary(
          resourceCode: 'test',
          resourceType: 'video',
          totalDurationSeconds: 1500, // 25min
          sessionCount: 1,
          totalFollowCount: 5,
        );
        expect(summary.formattedDuration, equals('25m'));
      });

      test('formattedDuration 为 0', () {
        final summary = ResourceLearningSummary(
          resourceCode: 'test',
          resourceType: 'video',
          totalDurationSeconds: 0,
          sessionCount: 0,
          totalFollowCount: 0,
        );
        expect(summary.formattedDuration, equals('0m'));
      });

      test('formattedDuration 刚好 1 小时', () {
        final summary = ResourceLearningSummary(
          resourceCode: 'test',
          resourceType: 'video',
          totalDurationSeconds: 3600,
          sessionCount: 1,
          totalFollowCount: 0,
        );
        expect(summary.formattedDuration, equals('1h 0m'));
      });

      test('所有字段正确存储', () {
        final now = DateTime.now();
        final summary = ResourceLearningSummary(
          resourceCode: 'res-code',
          resourceType: 'article',
          totalDurationSeconds: 5000,
          sessionCount: 10,
          bestFollowScore: 95.5,
          latestTestScore: 88.0,
          totalFollowCount: 50,
          lastStudiedAt: now,
        );

        expect(summary.resourceCode, equals('res-code'));
        expect(summary.resourceType, equals('article'));
        expect(summary.totalDurationSeconds, equals(5000));
        expect(summary.sessionCount, equals(10));
        expect(summary.bestFollowScore, equals(95.5));
        expect(summary.latestTestScore, equals(88.0));
        expect(summary.totalFollowCount, equals(50));
        expect(summary.lastStudiedAt, equals(now));
      });
    });

    group('RecentResource', () {
      test('所有字段正确存储', () {
        final now = DateTime.now();
        final resource = RecentResource(
          resourceCode: 'recent-001',
          resourceType: 'article',
          resourceTitle: '测试文章标题',
          folderCode: 'folder-recent',
          lastStudiedAt: now,
          lastDurationSeconds: 120,
        );

        expect(resource.resourceCode, equals('recent-001'));
        expect(resource.resourceType, equals('article'));
        expect(resource.resourceTitle, equals('测试文章标题'));
        expect(resource.folderCode, equals('folder-recent'));
        expect(resource.lastStudiedAt, equals(now));
        expect(resource.lastDurationSeconds, equals(120));
      });

      test('可选字段为 null', () {
        final resource = RecentResource(
          resourceCode: 'recent-002',
          resourceType: 'video',
          lastStudiedAt: DateTime.now(),
          lastDurationSeconds: 60,
        );

        expect(resource.resourceCode, equals('recent-002'));
        expect(resource.resourceTitle, isNull);
        expect(resource.folderCode, isNull);
      });
    });
  });

  group('LearningStatsService - StudyRecord 模型', () {
    test('StudyRecord 默认值正确', () {
      final record = StudyRecord();

      expect(record.resourceCode, isEmpty);
      expect(record.resourceType, equals('video'));
      expect(record.folderCode, isEmpty);
      expect(record.duration, equals(0));
      expect(record.playCount, equals(0));
      expect(record.segmentsStudied, equals(0));
      expect(record.wordsSaved, equals(0));
      expect(record.followCount, equals(0));
      expect(record.testScore, isNull);
      expect(record.bestFollowScore, isNull);
      expect(record.videoCode, isNull);
      expect(record.isDeleted, isFalse);
    });

    test('StudyRecord 自定义构造', () {
      final now = DateTime.now();
      final record = StudyRecord(
        resourceCode: 'custom-res',
        resourceType: 'article',
        folderCode: 'folder-custom',
        date: now,
        startTime: now,
        duration: 120,
        followCount: 5,
        bestFollowScore: 88.0,
        testScore: 75.0,
      );

      expect(record.resourceCode, equals('custom-res'));
      expect(record.resourceType, equals('article'));
      expect(record.folderCode, equals('folder-custom'));
      expect(record.duration, equals(120));
      expect(record.followCount, equals(5));
      expect(record.bestFollowScore, equals(88.0));
      expect(record.testScore, equals(75.0));
    });

    test('StudyRecord toMap/fromMap 往返一致性', () {
      final record = StudyRecord(
        resourceCode: 'roundtrip-test',
        resourceType: 'music',
        folderCode: 'folder-rt',
        duration: 300,
        followCount: 10,
        bestFollowScore: 92.5,
      );
      record.code = 'test-code-123';

      final map = record.toMap();
      expect(map['resource_code'], equals('roundtrip-test'));
      expect(map['resource_type'], equals('music'));
      expect(map['folder_code'], equals('folder-rt'));
      expect(map['duration'], equals(300));
      expect(map['follow_count'], equals(10));
      expect(map['best_follow_score'], equals(92.5));

      final restored = StudyRecord().fromMap(map) as StudyRecord;
      expect(restored.resourceCode, equals(record.resourceCode));
      expect(restored.resourceType, equals(record.resourceType));
      expect(restored.folderCode, equals(record.folderCode));
      expect(restored.duration, equals(record.duration));
      expect(restored.followCount, equals(record.followCount));
    });
  });

  group('LearningStatsService - 边界条件', () {
    test('快速连续 switchResource 内存状态一致', () async {
      await service.endSession();

      // 快速切换多次
      for (int i = 0; i < 5; i++) {
        await service.switchResource(
          resourceCode: 'rapid-$i',
          resourceType: 'video',
        );
      }

      // 最终状态应该是最后一次切换的资源
      expect(service.isSessionActive, isTrue);
      expect(service.currentResourceCode, equals('rapid-4'));

      await service.endSession();
    });

    test('多次 begin 不同资源只保留最后一个', () async {
      await service.endSession();

      const resources = ['a', 'b', 'c', 'd'];
      for (final r in resources) {
        await service.beginSession(
          resourceCode: r,
          resourceType: 'video',
        );
      }

      expect(service.currentResourceCode, equals('d'));

      await service.endSession();
    });
  });
}
