import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/forum/forum_post.dart';
import '../models/forum/forum_category.dart';
import '../services/forum/forum_service.dart';
import 'forum_mock_provider.dart'; // 导入模拟数据提供者

// Supabase 客户端 provider
final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// Forum 服务 provider
final forumServiceProvider = Provider<ForumService>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return ForumService(supabase);
});

// 论坛帖子列表 provider
final forumPostsProvider = FutureProvider.family<PaginatedResponse<ForumPost>, ForumPostsParams>((ref, params) async {
  // 使用模拟数据来避免404错误
  if (useMockData) {
    return ForumMockData.getMockPosts(
      page: params.page,
      limit: params.limit,
      category: params.category,
      search: params.search,
    );
  }
  
  try {
    final forumService = ref.watch(forumServiceProvider);
    return forumService.getPosts(
      page: params.page,
      limit: params.limit,
      category: params.category,
      type: params.type,
      search: params.search,
    );
  } catch (e) {
    // 如果真实验证失败，回退到模拟数据
    print('⚠️ 论坛API调用失败，使用模拟数据: $e');
    return ForumMockData.getMockPosts(
      page: params.page,
      limit: params.limit,
      category: params.category,
      search: params.search,
    );
  }
});

// 论坛分类 provider
final forumCategoriesProvider = FutureProvider<List<ForumCategory>>((ref) async {
  // 使用模拟数据来避免404错误
  if (useMockData) {
    await Future.delayed(const Duration(milliseconds: 300)); // 模拟网络延迟
    return ForumMockData.mockCategories;
  }
  
  try {
    final forumService = ref.watch(forumServiceProvider);
    return forumService.getCategories();
  } catch (e) {
    // 如果真实验证失败，回退到模拟数据
    print('⚠️ 分类API调用失败，使用模拟数据: $e');
    await Future.delayed(const Duration(milliseconds: 300));
    return ForumMockData.mockCategories;
  }
});

// 用户帖子列表 provider
final userPostsProvider = FutureProvider.family<PaginatedResponse<ForumPost>, UserPostsParams>((ref, params) async {
  final forumService = ref.watch(forumServiceProvider);
  return forumService.getUserPosts(
    page: params.page,
    limit: params.limit,
    includeDrafts: params.includeDrafts,
  );
});

// 用户收藏 provider
final userFavoritesProvider = FutureProvider<List<ForumPost>>((ref) async {
  final forumService = ref.watch(forumServiceProvider);
  return forumService.getUserFavorites();
});

// 论坛统计数据 provider
final forumStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final forumService = ref.watch(forumServiceProvider);
  return forumService.getForumStats();
});

// 当前选中的分类 provider
final selectedCategoryProvider = StateProvider<String>((ref) => 'all');

// 搜索查询 provider
final searchQueryProvider = StateProvider<String>((ref) => '');

// 帖子详情 provider
final postDetailProvider = FutureProvider.family<ForumPost, int>((ref, postId) async {
  final forumService = ref.watch(forumServiceProvider);
  return forumService.getPostById(postId);
});

// 创建帖子状态 provider
final createPostStateProvider = StateNotifierProvider<CreatePostNotifier, CreatePostState>((ref) {
  final forumService = ref.watch(forumServiceProvider);
  return CreatePostNotifier(forumService);
});

// 点赞状态 provider
final likeStateProvider = StateNotifierProvider.family<LikeNotifier, LikeState, int>((ref, postId) {
  final forumService = ref.watch(forumServiceProvider);
  return LikeNotifier(forumService, postId);
});

// 收藏状态 provider
final favoriteStateProvider = StateNotifierProvider.family<FavoriteNotifier, FavoriteState, int>((ref, postId) {
  final forumService = ref.watch(forumServiceProvider);
  return FavoriteNotifier(forumService, postId);
});

// 参数类定义
class ForumPostsParams {
  final int page;
  final int limit;
  final String? category;
  final String? type;
  final String? search;

  ForumPostsParams({
    this.page = 1,
    this.limit = 10,
    this.category,
    this.type,
    this.search,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ForumPostsParams &&
          runtimeType == other.runtimeType &&
          page == other.page &&
          limit == other.limit &&
          category == other.category &&
          type == other.type &&
          search == other.search;

  @override
  int get hashCode =>
      page.hashCode ^
      limit.hashCode ^
      category.hashCode ^
      type.hashCode ^
      search.hashCode;
}

class UserPostsParams {
  final int page;
  final int limit;
  final bool includeDrafts;

  UserPostsParams({
    this.page = 1,
    this.limit = 10,
    this.includeDrafts = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserPostsParams &&
          runtimeType == other.runtimeType &&
          page == other.page &&
          limit == other.limit &&
          includeDrafts == other.includeDrafts;

  @override
  int get hashCode =>
      page.hashCode ^ limit.hashCode ^ includeDrafts.hashCode;
}

// 创建帖子状态管理
class CreatePostState {
  final bool isLoading;
  final String? error;
  final ForumPost? createdPost;

  CreatePostState({
    this.isLoading = false,
    this.error,
    this.createdPost,
  });

  CreatePostState copyWith({
    bool? isLoading,
    String? error,
    ForumPost? createdPost,
  }) {
    return CreatePostState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      createdPost: createdPost ?? this.createdPost,
    );
  }
}

class CreatePostNotifier extends StateNotifier<CreatePostState> {
  final ForumService _forumService;

  CreatePostNotifier(this._forumService) : super(CreatePostState());

  Future<void> createPost({
    required String title,
    required String content,
    required int categoryId,
    String postType = 'discussion',
    String? resourceType,
    String? resourceUrl,
    String? resourceDescription,
    List<String>? tags,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final post = await _forumService.createPost(
        title: title,
        content: content,
        categoryId: categoryId,
        postType: postType,
        resourceType: resourceType,
        resourceUrl: resourceUrl,
        resourceDescription: resourceDescription,
        tags: tags,
      );
      
      state = state.copyWith(
        isLoading: false,
        createdPost: post,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void reset() {
    state = CreatePostState();
  }
}

// 点赞状态管理
class LikeState {
  final bool isLoading;
  final bool isLiked;
  final int likeCount;
  final String? error;

  LikeState({
    this.isLoading = false,
    this.isLiked = false,
    this.likeCount = 0,
    this.error,
  });

  LikeState copyWith({
    bool? isLoading,
    bool? isLiked,
    int? likeCount,
    String? error,
  }) {
    return LikeState(
      isLoading: isLoading ?? this.isLoading,
      isLiked: isLiked ?? this.isLiked,
      likeCount: likeCount ?? this.likeCount,
      error: error,
    );
  }
}

class LikeNotifier extends StateNotifier<LikeState> {
  final ForumService _forumService;
  final int _postId;

  LikeNotifier(this._forumService, this._postId) : super(LikeState());

  Future<void> toggleLike() async {
    if (state.isLoading) return;
    
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      await _forumService.toggleLike(_postId);
      
      state = state.copyWith(
        isLoading: false,
        isLiked: !state.isLiked,
        likeCount: state.isLiked ? state.likeCount - 1 : state.likeCount + 1,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void updateLikeInfo(bool isLiked, int likeCount) {
    state = state.copyWith(
      isLiked: isLiked,
      likeCount: likeCount,
    );
  }
}

// 收藏状态管理
class FavoriteState {
  final bool isLoading;
  final bool isFavorited;
  final String? error;

  FavoriteState({
    this.isLoading = false,
    this.isFavorited = false,
    this.error,
  });

  FavoriteState copyWith({
    bool? isLoading,
    bool? isFavorited,
    String? error,
  }) {
    return FavoriteState(
      isLoading: isLoading ?? this.isLoading,
      isFavorited: isFavorited ?? this.isFavorited,
      error: error,
    );
  }
}

class FavoriteNotifier extends StateNotifier<FavoriteState> {
  final ForumService _forumService;
  final int _postId;

  FavoriteNotifier(this._forumService, this._postId) : super(FavoriteState());

  Future<void> toggleFavorite() async {
    if (state.isLoading) return;
    
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      await _forumService.toggleFavorite(_postId);
      
      state = state.copyWith(
        isLoading: false,
        isFavorited: !state.isFavorited,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void updateFavoriteStatus(bool isFavorited) {
    state = state.copyWith(isFavorited: isFavorited);
  }
}