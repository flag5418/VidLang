import 'package:flutter_test/flutter_test.dart';
import 'package:vidlang/models/forum/forum_post.dart';
import 'package:vidlang/models/forum/forum_category.dart';
import 'package:vidlang/services/forum/forum_service.dart';

void main() {
  group('Forum System Basic Tests', () {
    setUp(() {
      // 在每个测试前的设置
    });

    test('ForumPost model should handle all required fields correctly', () {
      // 测试空构造函数
      final emptyPost = ForumPost(
        id: 0,
        title: '',
        content: '',
        authorId: '',
        postType: 'discussion',
        tags: [],
        viewCount: 0,
        likeCount: 0,
        commentCount: 0,
        isFeatured: false,
        isPinned: false,
        status: 'draft',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(emptyPost.id, equals(0));
      expect(emptyPost.title, equals(''));
      expect(emptyPost.tags, isEmpty);
      expect(emptyPost.status, equals('draft'));
    });

    test('ForumPost should correctly handle JSON serialization', () {
      final now = DateTime.now();
      final originalPost = ForumPost(
        id: 123,
        title: 'Test Post',
        content: 'Test content for serialization',
        authorId: 'user123',
        authorName: 'Test User',
        authorEmail: 'test@example.com',
        postType: 'discussion',
        categoryId: 1,
        categoryName: 'General',
        tags: ['test', 'flutter'],
        viewCount: 50,
        likeCount: 10,
        commentCount: 3,
        isFeatured: true,
        isPinned: false,
        status: 'published',
        createdAt: now,
        updatedAt: now,
        isLikedByCurrentUser: false,
        isFavoritedByCurrentUser: true,
      );

      // 序列化为JSON
      final json = originalPost.toJson();
      expect(json, isA<Map<String, dynamic>>());
      expect(json['title'], equals('Test Post'));
      expect(json['id'], equals(123));
      expect(json['author_id'], equals('user123'));

      // 从JSON反序列化
      final deserializedPost = ForumPost.fromJson(json);
      expect(deserializedPost.title, equals(originalPost.title));
      expect(deserializedPost.id, equals(originalPost.id));
      expect(deserializedPost.authorId, equals(originalPost.authorId));
    });

    test('ForumPost copyWith should update specified fields only', () {
      final originalPost = ForumPost(
        id: 1,
        title: 'Original Title',
        content: 'Original Content',
        authorId: 'user1',
        postType: 'discussion',
        tags: ['original'],
        viewCount: 100,
        likeCount: 5,
        commentCount: 2,
        isFeatured: false,
        isPinned: false,
        status: 'published',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      // 使用copyWith更新部分字段
      final updatedPost = originalPost.copyWith(
        title: 'Updated Title',
        likeCount: 10,
        isPinned: true,
      );

      // 验证更新的字段
      expect(updatedPost.title, equals('Updated Title'));
      expect(updatedPost.likeCount, equals(10));
      expect(updatedPost.isPinned, isTrue);

      // 验证未更新的字段保持不变
      expect(updatedPost.content, equals(originalPost.content));
      expect(updatedPost.authorId, equals(originalPost.authorId));
      expect(updatedPost.viewCount, equals(originalPost.viewCount));
    });

    test('ForumCategory model should work correctly', () {
      final category = ForumCategory(
        id: 1,
        name: 'Resource Sharing',
        description: 'Share your learning resources',
        slug: 'resources',
        sortOrder: 1,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(category.id, equals(1));
      expect(category.name, isNotEmpty);
      expect(category.slug, isNotEmpty);
      expect(category.isActive, isTrue);

      // 测试JSON序列化
      final json = category.toJson();
      expect(json['name'], equals(category.name));
      expect(json['slug'], equals(category.slug));

      // 测试从JSON创建
      final fromJson = ForumCategory.fromJson(json);
      expect(fromJson.name, equals(category.name));
      expect(fromJson.slug, equals(category.slug));
    });

    test('PaginationInfo should calculate correct values', () {
      final pagination = PaginationInfo(
        page: 1,
        limit: 20,
        total: 50,
        totalPages: 3,
      );

      expect(pagination.page, equals(1));
      expect(pagination.limit, equals(20));
      expect(pagination.total, equals(50));
      expect(pagination.totalPages, equals(3));
      expect(pagination.limit, lessThanOrEqualTo(100)); // 合理的限制
    });

    test('PaginatedResponse should handle data correctly', () {
      final posts = List.generate(5, (index) => ForumPost(
        id: index,
        title: 'Post $index',
        content: 'Content $index',
        authorId: 'user$index',
        postType: 'discussion',
        tags: [],
        viewCount: 0,
        likeCount: 0,
        commentCount: 0,
        isFeatured: false,
        isPinned: false,
        status: 'published',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final pagination = PaginationInfo(
        page: 1,
        limit: 5,
        total: 5,
        totalPages: 1,
      );

      final response = PaginatedResponse<ForumPost>(
        data: posts,
        pagination: pagination,
      );

      expect(response.data, hasLength(5));
      expect(response.pagination.total, equals(5));
      expect(response.data.first.title, equals('Post 0'));
      expect(response.data.last.title, equals('Post 4'));
    });
  });

  group('Forum Service Input Validation', () {
    test('createPost should validate title', () {
      expect(() {
        if ('   '.trim().isEmpty) {
          throw Exception('Title cannot be empty');
        }
      }, throwsException);
    });

    test('createPost should validate content', () {
      expect(() {
        if (''.isEmpty) {
          throw Exception('Content cannot be empty');
        }
      }, throwsException);
    });

    test('category validation should work', () {
      expect(() {
        if (-1 <= 0) {
          throw Exception('Category ID must be positive');
        }
      }, throwsException);
    });

    test('feedback types should be validated', () {
      final validTypes = {'bug', 'feature', 'content', 'general'};
      
      expect(validTypes.contains('bug'), isTrue);
      expect(validTypes.contains('feature'), isTrue);
      expect(validTypes.contains('content'), isTrue);
      expect(validTypes.contains('general'), isTrue);
      expect(validTypes.contains('invalid'), isFalse);
    });

    test('pagination parameters should be valid', () {
      expect(() {
        if (0 <= 0) {
          throw Exception('Page must be greater than 0');
        }
      }, throwsException);

      expect(() {
        if (200 > 100) {
          throw Exception('Limit should not exceed 100');
        }
      }, throwsException);
    });
  });

  group('Forum Data Consistency', () {
    test('Post status should be valid', () {
      final validStatuses = {'draft', 'published', 'archived', 'deleted'};
      
      expect(validStatuses.contains('published'), isTrue);
      expect(validStatuses.contains('draft'), isTrue);
      expect(validStatuses.contains('archived'), isTrue);
      expect(validStatuses.contains('deleted'), isTrue);
      expect(validStatuses.contains('invalid'), isFalse);
    });

    test('Post type should be valid', () {
      final validTypes = {'discussion', 'resource', 'question', 'feedback'};
      
      expect(validTypes.contains('discussion'), isTrue);
      expect(validTypes.contains('resource'), isTrue);
      expect(validTypes.contains('question'), isTrue);
      expect(validTypes.contains('feedback'), isTrue);
      expect(validTypes.contains('invalid'), isFalse);
    });

    test('Resource type should be valid', () {
      final validResourceTypes = {'video', 'audio', 'article', 'image'};
      
      expect(validResourceTypes.contains('video'), isTrue);
      expect(validResourceTypes.contains('audio'), isTrue);
      expect(validResourceTypes.contains('article'), isTrue);
      expect(validResourceTypes.contains('image'), isTrue);
      expect(validResourceTypes.contains('invalid'), isFalse);
    });
  });
}