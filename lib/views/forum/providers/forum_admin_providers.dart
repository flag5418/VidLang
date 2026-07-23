import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vidlang/models/forum/forum_post.dart';
import 'package:vidlang/models/forum/forum_reply.dart';
import 'package:vidlang/models/forum/forum_report.dart';
import 'package:vidlang/models/forum/forum_feedback.dart';
import 'package:vidlang/models/forum/forum_tag.dart';
import 'package:vidlang/models/forum/forum_admin_user.dart';
import 'package:vidlang/services/forum/forum_service.dart';
import 'package:vidlang/views/forum/providers/forum_providers.dart';

/// 管理员认证状态
final adminAuthProvider = FutureProvider<bool>((ref) async {
  try {
    final supabase = ref.watch(supabaseProvider);
    final user = supabase.auth.currentUser;
    if (user == null) return false;
    final userMeta = user.userMetadata;
    return userMeta?['role'] == 'admin';
  } catch (_) {
    return false;
  }
});

/// 管理操作通用状态
class AdminActionState {
  final bool isLoading;
  final String? error;
  final bool success;

  const AdminActionState(
      {this.isLoading = false, this.error, this.success = false});

  AdminActionState copyWith({bool? isLoading, String? error, bool? success}) {
    return AdminActionState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      success: success ?? this.success,
    );
  }
}

// ═══════════════════════════════════════════════
// 帖子审核
// ═══════════════════════════════════════════════

/// 管理后台帖子列表（支持状态筛选、搜索、分页）
class AdminPostsParams {
  final String? status;
  final String? search;
  final int page;
  final int limit;
  const AdminPostsParams(
      {this.status, this.search, this.page = 1, this.limit = 20});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminPostsParams &&
          status == other.status &&
          search == other.search &&
          page == other.page &&
          limit == other.limit;

  @override
  int get hashCode => Object.hash(status, search, page, limit);
}

final adminPostsProvider =
    FutureProvider.family<PaginatedResponse<ForumPost>, AdminPostsParams>(
        (ref, params) async {
  final service = ref.watch(forumServiceProvider);
  return service.getAdminPosts(
    status: params.status,
    search: params.search,
    page: params.page,
    limit: params.limit,
  );
});

/// 待审核帖子（快捷 provider，status=pending）
final pendingPostsProvider = FutureProvider<List<ForumPost>>((ref) async {
  final res =
      ref.watch(adminPostsProvider(const AdminPostsParams(status: 'pending')));
  return res.whenData((r) => r.data).value ?? [];
});

/// 帖子审核 Notifier
class ModeratePostNotifier extends StateNotifier<AdminActionState> {
  final ForumService _service;
  ModeratePostNotifier(this._service) : super(const AdminActionState());

  Future<void> approvePost(int postId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _service.approvePost(postId);
      state = state.copyWith(isLoading: false, success: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> rejectPost(int postId, {String? reason}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _service.rejectPost(postId, reason: reason);
      state = state.copyWith(isLoading: false, success: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void reset() => state = const AdminActionState();
}

final moderatePostProvider =
    StateNotifierProvider<ModeratePostNotifier, AdminActionState>((ref) {
  final service = ref.watch(forumServiceProvider);
  return ModeratePostNotifier(service);
});

// ═══════════════════════════════════════════════
// 评论审核
// ═══════════════════════════════════════════════

/// 管理后台评论列表
class AdminRepliesParams {
  final String? status;
  final int page;
  final int limit;
  const AdminRepliesParams({this.status, this.page = 1, this.limit = 20});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminRepliesParams &&
          status == other.status &&
          page == other.page &&
          limit == other.limit;

  @override
  int get hashCode => Object.hash(status, page, limit);
}

final adminRepliesProvider =
    FutureProvider.family<PaginatedResponse<ForumReply>, AdminRepliesParams>(
        (ref, params) async {
  final service = ref.watch(forumServiceProvider);
  return service.getAdminReplies(
    status: params.status,
    page: params.page,
    limit: params.limit,
  );
});

/// 待审核评论（快捷 provider）
final pendingCommentsProvider = FutureProvider<List<ForumReply>>((ref) async {
  final res = ref.watch(
      adminRepliesProvider(const AdminRepliesParams(status: 'pending')));
  return res.whenData((r) => r.data).value ?? [];
});

/// 评论审核 Notifier
class ModerateCommentNotifier extends StateNotifier<AdminActionState> {
  final ForumService _service;
  ModerateCommentNotifier(this._service) : super(const AdminActionState());

  Future<void> approveComment(int commentId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _service.approveReply(commentId);
      state = state.copyWith(isLoading: false, success: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> rejectComment(int commentId, {String? reason}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _service.rejectReply(commentId, reason: reason);
      state = state.copyWith(isLoading: false, success: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void reset() => state = const AdminActionState();
}

final moderateCommentProvider =
    StateNotifierProvider<ModerateCommentNotifier, AdminActionState>((ref) {
  final service = ref.watch(forumServiceProvider);
  return ModerateCommentNotifier(service);
});

// ═══════════════════════════════════════════════
// 举报处理
// ═══════════════════════════════════════════════

class AdminReportsParams {
  final String? status;
  final int page;
  final int limit;
  const AdminReportsParams({this.status, this.page = 1, this.limit = 20});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminReportsParams &&
          status == other.status &&
          page == other.page &&
          limit == other.limit;

  @override
  int get hashCode => Object.hash(status, page, limit);
}

final adminReportsProvider = FutureProvider.family<
    PaginatedResponse<ForumReport>, AdminReportsParams>((ref, params) async {
  final service = ref.watch(forumServiceProvider);
  return service.getAdminReports(
    status: params.status,
    page: params.page,
    limit: params.limit,
  );
});

/// 待处理举报（快捷 provider）
final pendingReportsProvider = FutureProvider<List<ForumReport>>((ref) async {
  final res = ref.watch(
      adminReportsProvider(const AdminReportsParams(status: 'pending')));
  return res.whenData((r) => r.data).value ?? [];
});

/// 举报统计
final reportStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final all =
      ref.watch(adminReportsProvider(const AdminReportsParams(limit: 200)));
  return all.when(
    data: (r) {
      int pending = 0;
      int resolved = 0;
      int dismissed = 0;
      for (final report in r.data) {
        switch (report.status) {
          case 'pending':
            pending++;
          case 'resolved':
            resolved++;
          case 'dismissed':
            dismissed++;
        }
      }
      return {
        'pending': pending,
        'resolved': resolved,
        'dismissed': dismissed
      };
    },
    loading: () => {'pending': 0, 'resolved': 0, 'dismissed': 0},
    error: (_, _) => {'pending': 0, 'resolved': 0, 'dismissed': 0},
  );
});

/// 处理举报 Notifier
class HandleReportNotifier extends StateNotifier<AdminActionState> {
  final ForumService _service;
  HandleReportNotifier(this._service) : super(const AdminActionState());

  Future<void> resolveReport(int reportId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _service.handleReport(reportId, 'resolved');
      state = state.copyWith(isLoading: false, success: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> dismissReport(int reportId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _service.handleReport(reportId, 'dismissed');
      state = state.copyWith(isLoading: false, success: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void reset() => state = const AdminActionState();
}

final handleReportProvider =
    StateNotifierProvider<HandleReportNotifier, AdminActionState>((ref) {
  final service = ref.watch(forumServiceProvider);
  return HandleReportNotifier(service);
});

// ═══════════════════════════════════════════════
// 用户管理
// ═══════════════════════════════════════════════

class AdminUsersParams {
  final String? search;
  final String? role;
  final bool? isBanned;
  final int page;
  final int limit;
  const AdminUsersParams({
    this.search,
    this.role,
    this.isBanned,
    this.page = 1,
    this.limit = 20,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminUsersParams &&
          search == other.search &&
          role == other.role &&
          isBanned == other.isBanned &&
          page == other.page &&
          limit == other.limit;

  @override
  int get hashCode => Object.hash(search, role, isBanned, page, limit);
}

final adminUsersProvider = FutureProvider.family<
    PaginatedResponse<AdminUser>, AdminUsersParams>((ref, params) async {
  final service = ref.watch(forumServiceProvider);
  return service.getAdminUsers(
    search: params.search,
    role: params.role,
    isBanned: params.isBanned,
    page: params.page,
    limit: params.limit,
  );
});

/// 封禁/解封用户 Notifier
class BanUserNotifier extends StateNotifier<AdminActionState> {
  final ForumService _service;
  BanUserNotifier(this._service) : super(const AdminActionState());

  Future<void> banUser(String userId, {String? reason}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _service.banUser(userId, reason: reason);
      state = state.copyWith(isLoading: false, success: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> unbanUser(String userId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _service.unbanUser(userId);
      state = state.copyWith(isLoading: false, success: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void reset() => state = const AdminActionState();
}

final banUserProvider =
    StateNotifierProvider<BanUserNotifier, AdminActionState>((ref) {
  final service = ref.watch(forumServiceProvider);
  return BanUserNotifier(service);
});

// ═══════════════════════════════════════════════
// 反馈管理
// ═══════════════════════════════════════════════

class AdminFeedbackParams {
  final String? status;
  final int page;
  final int limit;
  const AdminFeedbackParams({this.status, this.page = 1, this.limit = 20});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminFeedbackParams &&
          status == other.status &&
          page == other.page &&
          limit == other.limit;

  @override
  int get hashCode => Object.hash(status, page, limit);
}

final adminFeedbackProvider =
    FutureProvider.family<PaginatedResponse<ForumFeedback>, AdminFeedbackParams>(
        (ref, params) async {
  final service = ref.watch(forumServiceProvider);
  return service.getAdminFeedback(
    status: params.status,
    page: params.page,
    limit: params.limit,
  );
});

/// 回复反馈 Notifier
class ReplyFeedbackNotifier extends StateNotifier<AdminActionState> {
  final ForumService _service;
  ReplyFeedbackNotifier(this._service) : super(const AdminActionState());

  Future<void> reply(int feedbackId, String reply) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _service.replyFeedback(feedbackId, reply);
      state = state.copyWith(isLoading: false, success: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> updateStatus(int feedbackId, String status) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _service.updateFeedbackStatus(feedbackId, status);
      state = state.copyWith(isLoading: false, success: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void reset() => state = const AdminActionState();
}

final replyFeedbackProvider =
    StateNotifierProvider<ReplyFeedbackNotifier, AdminActionState>((ref) {
  final service = ref.watch(forumServiceProvider);
  return ReplyFeedbackNotifier(service);
});

// ═══════════════════════════════════════════════
// 论坛统计（管理仪表盘）
// ═══════════════════════════════════════════════

final forumStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final service = ref.watch(forumServiceProvider);
  try {
    return service.getAdminDashboard();
  } catch (_) {
    // 降级：admin-dashboard 端点不可用时回退到 Supabase 直接查询
    final supabase = ref.watch(supabaseProvider);
    final totalPosts = await supabase
        .from('forum_posts')
        .select('*')
        .count(CountOption.exact);
    final totalComments = await supabase
        .from('forum_replies')
        .select('*')
        .count(CountOption.exact);
    final totalUsers = await supabase
        .from('profiles')
        .select('*')
        .count(CountOption.exact);
    final weekAgo =
        DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
    final activeUsersWeek = await supabase
        .from('forum_posts')
        .select('user_id')
        .gte('created_at', weekAgo)
        .count(CountOption.exact);
    return {
      'total_posts': totalPosts.count,
      'total_comments': totalComments.count,
      'total_users': totalUsers.count,
      'active_users_week': activeUsersWeek.count,
    };
  }
});

// ═══════════════════════════════════════════════
// 标签管理 — V2.0 替代板块管理
// ═══════════════════════════════════════════════

final adminTagsProvider = FutureProvider<List<ForumTag>>((ref) async {
  final service = ref.watch(forumServiceProvider);
  return service.getTags();
});

/// 标签管理 Notifier（增删改 + 切换启用状态）
class ManageTagNotifier extends StateNotifier<AdminActionState> {
  // ignore: unused_field
  final ForumService _service;
  ManageTagNotifier(this._service) : super(const AdminActionState());

  // TODO: ForumService 尚无 createTag 方法，待 Edge Function 实现后对接
  Future<ForumTag?> createTag({
    required String name,
    String color = '#4ADE80',
    int sortOrder = 0,
  }) async {
    state = state.copyWith(error: 'createTag 待实现');
    return null;
  }

  // TODO: ForumService 尚无 updateTag 方法
  Future<ForumTag?> updateTag(
    int id, {
    String? name,
    String? color,
    int? sortOrder,
    bool? isActive,
  }) async {
    state = state.copyWith(error: 'updateTag 待实现');
    return null;
  }

  // TODO: ForumService 尚无 deleteTag 方法
  Future<void> deleteTag(int id) async {
    state = state.copyWith(error: 'deleteTag 待实现');
  }

  void reset() => state = const AdminActionState();
}

final manageTagProvider =
    StateNotifierProvider<ManageTagNotifier, AdminActionState>((ref) {
  final service = ref.watch(forumServiceProvider);
  return ManageTagNotifier(service);
});
