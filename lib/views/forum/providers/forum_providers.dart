import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vidlang/models/forum/forum_post.dart';
import 'package:vidlang/models/forum/forum_reply.dart';
import 'package:vidlang/models/forum/forum_notification.dart';
import 'package:vidlang/models/forum/forum_tag.dart';
import 'package:vidlang/models/forum/forum_feedback.dart';
import 'package:vidlang/models/forum/forum_follow.dart';
import 'package:vidlang/models/forum/forum_tag_follow.dart';
import 'package:vidlang/services/forum/forum_service.dart';

// ═══════════════════════════════════════════════
// 基础 Provider
// ═══════════════════════════════════════════════

final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final forumServiceProvider = Provider<ForumService>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return ForumService(supabase);
});

// ═══════════════════════════════════════════════
// 标签
// ═══════════════════════════════════════════════

final forumTagsProvider = FutureProvider<List<ForumTag>>((ref) async {
  final service = ref.watch(forumServiceProvider);
  return service.getTags();
});

final forumTagFollowsProvider = FutureProvider<List<ForumTagFollow>>((ref) async {
  final service = ref.watch(forumServiceProvider);
  return service.getMyTagFollows();
});

// ═══════════════════════════════════════════════
// 帖子 — V2.0: tagId + followed
// ═══════════════════════════════════════════════

class ForumPostsParams {
  final int? tagId;
  final bool followed;
  final int page;
  final int limit;
  final String sort;
  const ForumPostsParams({
    this.tagId,
    this.followed = false,
    this.page = 1,
    this.limit = 20,
    this.sort = 'latest',
  });
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ForumPostsParams &&
          tagId == other.tagId &&
          followed == other.followed &&
          page == other.page &&
          limit == other.limit &&
          sort == other.sort;
  @override
  int get hashCode => Object.hash(tagId, followed, page, limit, sort);
}

final forumPostsProvider =
    FutureProvider.family<PaginatedResponse<ForumPost>, ForumPostsParams>(
        (ref, params) async {
  final service = ref.watch(forumServiceProvider);
  return service.getPosts(
    tagId: params.tagId,
    followed: params.followed,
    page: params.page,
    limit: params.limit,
    sort: params.sort,
  );
});

final forumPostDetailProvider =
    FutureProvider.family<ForumPost, int>((ref, postId) async {
  final service = ref.watch(forumServiceProvider);
  return service.getPostDetail(postId);
});

// ═══════════════════════════════════════════════
// 回复
// ═══════════════════════════════════════════════

final forumRepliesProvider = FutureProvider.family<
    PaginatedResponse<ForumReply>, ({int postId, int page})>((ref, params) async {
  final service = ref.watch(forumServiceProvider);
  return service.getReplies(
    params.postId,
    page: params.page,
  );
});

// ═══════════════════════════════════════════════
// 收藏 — V2.0 新增
// ═══════════════════════════════════════════════

final forumFavoritesProvider =
    FutureProvider.family<PaginatedResponse<ForumPost>, int>(
        (ref, page) async {
  final service = ref.watch(forumServiceProvider);
  return service.getMyFavorites(page: page);
});

// ═══════════════════════════════════════════════
// 关注用户 — V2.0 新增
// ═══════════════════════════════════════════════

final forumFollowsProvider =
    FutureProvider.family<PaginatedResponse<ForumFollow>, int>(
        (ref, page) async {
  final service = ref.watch(forumServiceProvider);
  return service.getMyFollows(page: page);
});

// ═══════════════════════════════════════════════
// 通知
// ═══════════════════════════════════════════════

final forumNotificationsProvider = FutureProvider.family<
    PaginatedResponse<ForumNotification>, int>((ref, page) async {
  final service = ref.watch(forumServiceProvider);
  return service.getNotifications(page: page);
});

final forumUnreadCountProvider = FutureProvider<int>((ref) async {
  final service = ref.watch(forumServiceProvider);
  return service.getUnreadCount();
});

// ═══════════════════════════════════════════════
// 我的
// ═══════════════════════════════════════════════

final forumMyPostsProvider =
    FutureProvider.family<PaginatedResponse<ForumPost>, int>((ref, page) async {
  final service = ref.watch(forumServiceProvider);
  return service.getMyPosts(page: page);
});

final forumMyRepliesProvider =
    FutureProvider.family<PaginatedResponse<ForumReply>, int>(
        (ref, page) async {
  final service = ref.watch(forumServiceProvider);
  return service.getMyReplies(page: page);
});

final forumMyLikesProvider =
    FutureProvider.family<PaginatedResponse<ForumPost>, int>(
        (ref, page) async {
  final service = ref.watch(forumServiceProvider);
  return service.getMyLikes(page: page);
});

// ═══════════════════════════════════════════════
// 封禁状态
// ═══════════════════════════════════════════════

final forumBanStatusProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final service = ref.watch(forumServiceProvider);
  return service.checkBanStatus();
});

// ═══════════════════════════════════════════════
// 我的反馈
// ═══════════════════════════════════════════════

final forumMyFeedbackProvider =
    FutureProvider.family<PaginatedResponse<ForumFeedback>, int>(
        (ref, page) async {
  final service = ref.watch(forumServiceProvider);
  return service.getMyFeedback(page: page);
});

// ═══════════════════════════════════════════════
// 当前选中的标签（UI 用）
// ═══════════════════════════════════════════════

final selectedTagIdProvider = StateProvider<int?>((ref) => null);

// ═══════════════════════════════════════════════
// 创建帖子状态 — V2.0: tagId 替代 boardId
// ═══════════════════════════════════════════════

enum CreatePostStatus { idle, loading, success, error }

class CreatePostState {
  final CreatePostStatus status;
  final String? error;
  final ForumPost? post;
  const CreatePostState(
      {this.status = CreatePostStatus.idle, this.error, this.post});
  CreatePostState copyWith(
      {CreatePostStatus? status, String? error, ForumPost? post}) {
    return CreatePostState(
      status: status ?? this.status,
      error: error,
      post: post ?? this.post,
    );
  }
}

class CreatePostNotifier extends StateNotifier<CreatePostState> {
  final ForumService _service;
  CreatePostNotifier(this._service) : super(const CreatePostState());

  Future<void> createPost({
    required int tagId,
    required String title,
    required String content,
    List<String>? imageUrls,
  }) async {
    state = state.copyWith(status: CreatePostStatus.loading, error: null);
    try {
      final post = await _service.createPost(
        tagId: tagId,
        title: title,
        content: content,
        imageUrls: imageUrls,
      );
      state = state.copyWith(status: CreatePostStatus.success, post: post);
    } catch (e) {
      state = state.copyWith(
          status: CreatePostStatus.error, error: e.toString());
    }
  }

  void reset() => state = const CreatePostState();
}

final createPostProvider =
    StateNotifierProvider<CreatePostNotifier, CreatePostState>((ref) {
  final service = ref.watch(forumServiceProvider);
  return CreatePostNotifier(service);
});

// ═══════════════════════════════════════════════
// 提交反馈状态
// ═══════════════════════════════════════════════

enum SubmitFeedbackStatus { idle, loading, success, error }

class SubmitFeedbackState {
  final SubmitFeedbackStatus status;
  final String? error;
  const SubmitFeedbackState(
      {this.status = SubmitFeedbackStatus.idle, this.error});
  SubmitFeedbackState copyWith({SubmitFeedbackStatus? status, String? error}) {
    return SubmitFeedbackState(
      status: status ?? this.status,
      error: error,
    );
  }
}

class SubmitFeedbackNotifier extends StateNotifier<SubmitFeedbackState> {
  final ForumService _service;
  SubmitFeedbackNotifier(this._service) : super(const SubmitFeedbackState());

  Future<bool> submit({
    required String type,
    required String title,
    required String content,
    List<String>? imageUrls,
  }) async {
    state = state.copyWith(status: SubmitFeedbackStatus.loading, error: null);
    try {
      await _service.submitFeedback(type, title, content, imageUrls);
      state = state.copyWith(status: SubmitFeedbackStatus.success);
      return true;
    } catch (e) {
      state = state.copyWith(
          status: SubmitFeedbackStatus.error, error: e.toString());
      return false;
    }
  }

  void reset() => state = const SubmitFeedbackState();
}

final submitFeedbackProvider =
    StateNotifierProvider<SubmitFeedbackNotifier, SubmitFeedbackState>((ref) {
  final service = ref.watch(forumServiceProvider);
  return SubmitFeedbackNotifier(service);
});
