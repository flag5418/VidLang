import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/forum/forum_post.dart';
import '../models/forum/forum_category.dart';
import '../services/forum/forum_service.dart';
import 'forum_providers.dart';

/// 论坛模拟数据提供者
/// 当 Supabase Edge Functions 未部署时，提供离线测试数据
class ForumMockData {
  static final List<ForumCategory> mockCategories = [
    ForumCategory(
      id: 1,
      name: '资源分享',
      description: '分享有价值的学习资源',
      slug: 'resources',
      sortOrder: 1,
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      updatedAt: DateTime.now().subtract(const Duration(days: 30)),
    ),
    ForumCategory(
      id: 2,
      name: '学习讨论',
      description: '学习中的问题讨论和交流',
      slug: 'discussion',
      sortOrder: 2,
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 25)),
      updatedAt: DateTime.now().subtract(const Duration(days: 25)),
    ),
    ForumCategory(
      id: 3,
      name: '反馈建议',
      description: '应用反馈和改进建议',
      slug: 'feedback',
      sortOrder: 3,
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 20)),
      updatedAt: DateTime.now().subtract(const Duration(days: 20)),
    ),
  ];

  static final List<ForumPost> mockPosts = [
    ForumPost(
      id: 1,
      title: '🎥 Flutter 入门教学视频分享',
      content: '我整理了一套完整的Flutter入门教学视频，适合零基础同学学习。包含Dart语法、Widget系统、状态管理等核心内容。希望大家喜欢！',
      categoryId: 1,
      categoryName: '资源分享',
      authorId: 'user001',
      authorName: '张三',
      authorEmail: 'zhangsan@example.com',
      postType: 'resource',
      resourceType: 'video',
      resourceUrl: 'https://example.com/flutter-course.mp4',
      resourceDescription: '适合新手的Flutter视频课程',
      tags: ['Flutter', 'Dart', '入门教程', '视频'],
      viewCount: 156,
      likeCount: 28,
      commentCount: 12,
      isFeatured: true,
      isPinned: false,
      status: 'published',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
      isLikedByCurrentUser: false,
      isFavoritedByCurrentUser: true,
    ),
    ForumPost(
      id: 2,
      title: '💡 关于状态管理的讨论',
      content: '大家在项目中使用什么状态管理方案？Provider、Bloc、Riverpod 还是其他？能否分享一下各自的心得体会？',
      categoryId: 2,
      categoryName: '学习讨论',
      authorId: 'user002',
      authorName: '李四',
      authorEmail: 'lisi@example.com',
      postType: 'discussion',
      tags: ['状态管理', 'Provider', 'Bloc', 'Riverpod'],
      viewCount: 89,
      likeCount: 15,
      commentCount: 8,
      isFeatured: false,
      isPinned: true,
      status: 'published',
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 5)),
      isLikedByCurrentUser: true,
      isFavoritedByCurrentUser: false,
    ),
    ForumPost(
      id: 3,
      title: '🎧 英语学习音频资源分享',
      content: '带来一套高质量的英语学习音频材料，包含BBC新闻、TED演讲精华等。听力提升必备资源！',
      categoryId: 1,
      categoryName: '资源分享',
      authorId: 'user003',
      authorName: '王五',
      authorEmail: 'wangwu@example.com',
      postType: 'resource',
      resourceType: 'audio',
      resourceUrl: 'https://example.com/english-audio.zip',
      resourceDescription: 'BBC新闻和TED演讲音频集合',
      tags: ['英语学习', '听力', 'BBC', 'TED'],
      viewCount: 234,
      likeCount: 42,
      commentCount: 6,
      isFeatured: true,
      isPinned: false,
      status: 'published',
      createdAt: DateTime.now().subtract(const Duration(hours: 8)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 8)),
      isLikedByCurrentUser: false,
      isFavoritedByCurrentUser: false,
    ),
    ForumPost(
      id: 4,
      title: '🐛 应用闪退问题求助',
      content: '在使用视频播放功能时，偶尔会出现闪退。系统版本：iOS 16.5，设备：iPhone 12。有没有朋友遇到过类似问题？',
      categoryId: 2,
      categoryName: '学习讨论',
      authorId: 'user004',
      authorName: '赵六',
      authorEmail: 'zhaoliu@example.com',
      postType: 'help',
      tags: ['Bug反馈', 'iOS', '视频播放'],
      viewCount: 67,
      likeCount: 3,
      commentCount: 5,
      isFeatured: false,
      isPinned: false,
      status: 'published',
      createdAt: DateTime.now().subtract(const Duration(hours: 12)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 12)),
      isLikedByCurrentUser: false,
      isFavoritedByCurrentUser: false,
    ),
    ForumPost(
      id: 5,
      title: '💌 建议增加黑暗模式',
      content: '希望能增加黑暗模式，晚上使用时对眼睛更加友好。同时建议增加字体大小调节功能。',
      categoryId: 3,
      categoryName: '反馈建议',
      authorId: 'user005',
      authorName: '小明',
      authorEmail: 'xiaoming@example.com',
      postType: 'feedback',
      tags: ['新功能建议', '黑暗模式', '用户体验'],
      viewCount: 45,
      likeCount: 12,
      commentCount: 3,
      isFeatured: false,
      isPinned: false,
      status: 'published',
      createdAt: DateTime.now().subtract(const Duration(hours: 18)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 18)),
      isLikedByCurrentUser: true,
      isFavoritedByCurrentUser: false,
    ),
  ];

  /// 获取模拟帖子列表
  static PaginatedResponse<ForumPost> getMockPosts({
    int page = 1,
    int limit = 10,
    String? category,
    String? search,
  }) {
    List<ForumPost> filteredPosts = List.from(mockPosts);

    // 按分类筛选
    if (category != null && category != 'all') {
      filteredPosts = filteredPosts.where((post) {
        switch (category.toLowerCase()) {
          case 'resources':
            return post.postType == 'resource';
          case 'discussion':
            return post.postType == 'discussion';
          case 'feedback':
            return post.postType == 'feedback';
          case 'help':
            return post.postType == 'help';
          default:
            return true;
        }
      }).toList();
    }

    // 按搜索关键词筛选
    if (search != null && search.isNotEmpty) {
      filteredPosts = filteredPosts.where((post) {
        return post.title.toLowerCase().contains(search.toLowerCase()) ||
            post.content.toLowerCase().contains(search.toLowerCase()) ||
            post.tags.any((tag) => tag.toLowerCase().contains(search.toLowerCase()));
      }).toList();
    }

    // 分页
    final startIndex = (page - 1) * limit;
    final endIndex = (startIndex + limit).clamp(0, filteredPosts.length);
    final paginatedPosts = filteredPosts.sublist(
      startIndex.clamp(0, filteredPosts.length),
      endIndex,
    );

    return PaginatedResponse<ForumPost>(
      data: paginatedPosts,
      pagination: PaginationInfo(
        page: page,
        limit: limit,
        total: filteredPosts.length,
        totalPages: (filteredPosts.length / limit).ceil(),
      ),
    );
  }
}

/// 模拟论坛帖子提供者
final mockForumPostsProvider = FutureProvider.autoDispose
    .family<PaginatedResponse<ForumPost>, ForumPostsParams>((ref, params) async {
  // 模拟网络延迟
  await Future.delayed(const Duration(milliseconds: 500));
  
  return ForumMockData.getMockPosts(
    page: params.page,
    limit: params.limit,
    category: params.category,
    search: params.search,
  );
});

/// 模拟论坛分类提供者
final mockForumCategoriesProvider = FutureProvider.autoDispose<List<ForumCategory>>((ref) async {
  // 模拟网络延迟
  await Future.delayed(const Duration(milliseconds: 300));
  
  return ForumMockData.mockCategories;
});

/// 模拟论坛提供者开关
/// true: 使用模拟数据, false: 使用真实API
const bool useMockData = true;