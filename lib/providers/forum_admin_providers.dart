import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/forum/forum_service.dart';
import '../providers/forum_providers.dart';

// 管理员认证状态 provider
final adminAuthProvider = FutureProvider<bool>((ref) async {
  try {
    final supabase = ref.watch(supabaseProvider);
    final user = supabase.auth.currentUser;

    if (user == null) {
      return false;
    }

    // 检查用户是否为管理员
    final userMeta = user.userMetadata;
    return userMeta?['role'] == 'admin';
  } catch (e) {
    return false;
  }
});

// 待审核帖子列表 provider
final pendingPostsProvider = FutureProvider((ref) async {
  try {
    final forumService = ref.watch(forumServiceProvider);
    // 这里需要实现获取待审核帖子的方法
    // 暂时返回空列表，后续实现
    return <dynamic>[];
  } catch (e) {
    throw Exception('获取待审核帖子失败: $e');
  }
});

// 待审核评论列表 provider
final pendingCommentsProvider = FutureProvider((ref) async {
  try {
    final forumService = ref.watch(forumServiceProvider);
    // 这里需要实现获取待审核评论的方法
    // 暂时返回空列表，后续实现
    return <dynamic>[];
  } catch (e) {
    throw Exception('获取待审核评论失败: $e');
  }
});

// 论坛统计数据 provider
final forumStatsProvider = FutureProvider((ref) async {
  try {
    final forumService = ref.watch(forumServiceProvider);
    return await forumService.getForumStats();
  } catch (e) {
    throw Exception('获取论坛统计数据失败: $e');
  }
});

// 管理操作状态 providers
final moderatePostProvider =
    StateNotifierProvider<ModeratePostNotifier, ModeratePostState>((ref) {
      final forumService = ref.watch(forumServiceProvider);
      return ModeratePostNotifier(forumService);
    });

final moderateCommentProvider =
    StateNotifierProvider<ModerateCommentNotifier, ModerateCommentState>((ref) {
      final forumService = ref.watch(forumServiceProvider);
      return ModerateCommentNotifier(forumService);
    });

// 管理操作状态类
class ModeratePostState {
  final bool isLoading;
  final String? error;
  final bool success;

  ModeratePostState({this.isLoading = false, this.error, this.success = false});

  ModeratePostState copyWith({bool? isLoading, String? error, bool? success}) {
    return ModeratePostState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      success: success ?? this.success,
    );
  }
}

class ModerateCommentState {
  final bool isLoading;
  final String? error;
  final bool success;

  ModerateCommentState({
    this.isLoading = false,
    this.error,
    this.success = false,
  });

  ModerateCommentState copyWith({
    bool? isLoading,
    String? error,
    bool? success,
  }) {
    return ModerateCommentState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      success: success ?? this.success,
    );
  }
}

// 帖子审核操作类
class ModeratePostNotifier extends StateNotifier<ModeratePostState> {
  final ForumService _forumService;

  ModeratePostNotifier(this._forumService) : super(ModeratePostState());

  Future<void> approvePost(int postId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // 实现帖子审核通过逻辑
      // 这里需要调用管理员边缘函数
      await Future.delayed(const Duration(seconds: 1)); // 模拟网络请求

      state = state.copyWith(isLoading: false, success: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> rejectPost(int postId, {String? reason}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // 实现帖子审核拒绝逻辑
      await Future.delayed(const Duration(seconds: 1)); // 模拟网络请求

      state = state.copyWith(isLoading: false, success: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void reset() {
    state = ModeratePostState();
  }
}

// 评论审核操作类
class ModerateCommentNotifier extends StateNotifier<ModerateCommentState> {
  final ForumService _forumService;

  ModerateCommentNotifier(this._forumService) : super(ModerateCommentState());

  Future<void> approveComment(int commentId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // 实现评论审核通过逻辑
      await Future.delayed(const Duration(seconds: 1)); // 模拟网络请求

      state = state.copyWith(isLoading: false, success: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> rejectComment(int commentId, {String? reason}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // 实现评论审核拒绝逻辑
      await Future.delayed(const Duration(seconds: 1)); // 模拟网络请求

      state = state.copyWith(isLoading: false, success: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void reset() {
    state = ModerateCommentState();
  }
}

// 数据模型（暂时定义，实际需要根据边缘函数返回的数据结构调整）
class PendingPost {
  final int id;
  final String title;
  final String content;
  final String postType;
  final String? authorName;
  final DateTime createdAt;

  PendingPost({
    required this.id,
    required this.title,
    required this.content,
    required this.postType,
    this.authorName,
    required this.createdAt,
  });

  factory PendingPost.fromJson(Map<String, dynamic> json) {
    return PendingPost(
      id: json['id'],
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      postType: json['post_type'] ?? 'discussion',
      authorName: json['author']?['raw_user_meta_data']?['full_name'] ?? '未知用户',
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class PendingComment {
  final int id;
  final String content;
  final String? userName;
  final String? postTitle;
  final int postId;
  final DateTime createdAt;

  PendingComment({
    required this.id,
    required this.content,
    this.userName,
    this.postTitle,
    required this.postId,
    required this.createdAt,
  });

  factory PendingComment.fromJson(Map<String, dynamic> json) {
    return PendingComment(
      id: json['id'],
      content: json['content'] ?? '',
      userName: json['user']?['email']?.split('@')[0] ?? '未知用户',
      postTitle: json['post']?['title'] ?? '未知帖子',
      postId: json['post_id'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
