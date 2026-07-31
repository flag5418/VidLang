import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/forum/forum_post.dart';
import '../../models/forum/forum_reply.dart';
import '../../models/forum/forum_notification.dart';
import '../../models/forum/forum_tag.dart';
import '../../models/forum/forum_feedback.dart';
import '../../models/forum/forum_report.dart';
import '../../models/forum/forum_follow.dart';
import '../../models/forum/forum_tag_follow.dart';
import '../../models/forum/forum_admin_user.dart';
import '../app_keys_service.dart';

/// 论坛服务 — 对接 Supabase Edge Functions（设计文档 V2.0 标签驱动）
class ForumService {
  final SupabaseClient _supabase;

  static String get _baseUrl => '${AppKeysService.supabaseUrl}/functions/v1';

  ForumService(this._supabase);

  String? get _token => _supabase.auth.currentSession?.accessToken;

  /// 确保 session 有效，过期时自动刷新。不阻塞已登录的正常流程。
  Future<void> _ensureSession() async {
    final session = _supabase.auth.currentSession;
    if (session == null) {
      throw Exception('登录已过期，请重新登录');
    }
    if (session.expiresAt != null) {
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (session.expiresAt! <= nowSec + 60) {
        // token 已过期或将在 60 秒内过期，主动刷新
        try {
          await _supabase.auth.refreshSession(session.refreshToken);
        } catch (_) {
          throw Exception('登录已过期，请重新登录');
        }
      }
    }
  }

  Map<String, String> _authHeaders() {
    final token = _token;
    if (token == null) {
      throw Exception('登录已过期，请重新登录');
    }
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  // ─────────────────────────────────────────────
  // 帖子 (forum-posts) — V2.0: tag_id + followed 筛选
  // ─────────────────────────────────────────────

  Future<PaginatedResponse<ForumPost>> getPosts({
    int? tagId,
    bool followed = false,
    int page = 1,
    int limit = 20,
    String sort = 'latest',
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
      'sort': sort,
    };
    if (tagId != null) params['tag_id'] = tagId.toString();
    if (followed) params['followed'] = '1';

    final res = await http.get(
      Uri.parse('$_baseUrl/forum-posts').replace(queryParameters: params),
      headers: _authHeaders(),
    );
    _checkStatus(res, '获取帖子列表');
    return _parsePaginatedPosts(res.body);
  }

  Future<ForumPost> getPostDetail(int id) async {
    final res = await http.get(
      Uri.parse(
        '$_baseUrl/forum-post-detail',
      ).replace(queryParameters: {'id': id.toString()}),
      headers: _authHeaders(),
    );
    _checkStatus(res, '获取帖子详情');
    final data = json.decode(res.body);
    return ForumPost.fromJson(data['data']);
  }

  Future<ForumPost> createPost({
    required int tagId,
    required String title,
    required String content,
    List<String>? imageUrls,
  }) async {
    await _ensureSession();

    final body = <String, dynamic>{
      'tag_id': tagId,
      'title': title,
      'content': content,
    };
    if (imageUrls != null && imageUrls.isNotEmpty) {
      body['image_urls'] = imageUrls;
    }

    final res = await http.post(
      Uri.parse('$_baseUrl/forum-posts'),
      headers: _authHeaders(),
      body: json.encode(body),
    );
    _checkStatus(res, '创建帖子');
    final data = json.decode(res.body);
    return ForumPost.fromJson(data['data']);
  }

  Future<ForumPost> updatePost(int id, {String? title, String? content}) async {
    await _ensureSession();
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (content != null) body['content'] = content;

    final res = await http.put(
      Uri.parse('$_baseUrl/forum-posts/$id'),
      headers: _authHeaders(),
      body: json.encode(body),
    );
    _checkStatus(res, '更新帖子');
    final data = json.decode(res.body);
    return ForumPost.fromJson(data['data']);
  }

  Future<void> deletePost(int id) async {
    await _ensureSession();
    final res = await http.delete(
      Uri.parse('$_baseUrl/forum-posts/$id'),
      headers: _authHeaders(),
    );
    _checkStatus(res, '删除帖子');
  }

  // ─────────────────────────────────────────────
  // 回复 (forum-replies) — V2.0: 单层回复（无 parent_id）
  // ─────────────────────────────────────────────

  Future<PaginatedResponse<ForumReply>> getReplies(
    int postId, {
    int page = 1,
    int limit = 20,
  }) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/forum-replies').replace(
        queryParameters: {
          'post_id': postId.toString(),
          'page': page.toString(),
          'limit': limit.toString(),
        },
      ),
      headers: _authHeaders(),
    );
    _checkStatus(res, '获取回复列表');
    final data = json.decode(res.body);
    final replies = (data['data'] as List)
        .map((e) => ForumReply.fromJson(e))
        .toList();
    return PaginatedResponse(
      data: replies,
      pagination: PaginationInfo.fromJson(data['pagination'] ?? {}),
    );
  }

  Future<ForumReply> createReply({
    required int postId,
    required String content,
    List<String>? imageUrls,
  }) async {
    await _ensureSession();

    final body = <String, dynamic>{'post_id': postId, 'content': content};
    if (imageUrls != null && imageUrls.isNotEmpty) {
      body['image_urls'] = imageUrls;
    }

    final res = await http.post(
      Uri.parse('$_baseUrl/forum-replies'),
      headers: _authHeaders(),
      body: json.encode(body),
    );
    _checkStatus(res, '创建回复');
    final data = json.decode(res.body);
    return ForumReply.fromJson(data['data']);
  }

  Future<void> deleteReply(int id) async {
    await _ensureSession();
    final res = await http.delete(
      Uri.parse('$_baseUrl/forum-replies/$id'),
      headers: _authHeaders(),
    );
    _checkStatus(res, '删除回复');
  }

  // ─────────────────────────────────────────────
  // 点赞 (forum-likes)
  // ─────────────────────────────────────────────

  Future<bool> toggleLike(String targetType, int targetId) async {
    await _ensureSession();
    final res = await http.post(
      Uri.parse('$_baseUrl/forum-likes'),
      headers: _authHeaders(),
      body: json.encode({'target_type': targetType, 'target_id': targetId}),
    );
    _checkStatus(res, '点赞操作');
    final data = json.decode(res.body);
    return data['action'] == 'liked';
  }

  // ─────────────────────────────────────────────
  // 收藏 (forum-favorites) — V2.0 新增
  // ─────────────────────────────────────────────

  Future<bool> toggleFavorite(int postId) async {
    await _ensureSession();
    final res = await http.post(
      Uri.parse('$_baseUrl/forum-favorites'),
      headers: _authHeaders(),
      body: json.encode({'post_id': postId}),
    );
    _checkStatus(res, '收藏操作');
    final data = json.decode(res.body);
    return data['action'] == 'favorited';
  }

  Future<PaginatedResponse<ForumPost>> getMyFavorites({
    int page = 1,
    int limit = 20,
  }) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/forum-favorites').replace(
        queryParameters: {'page': page.toString(), 'limit': limit.toString()},
      ),
      headers: _authHeaders(),
    );
    _checkStatus(res, '我的收藏');
    return _parsePaginatedPosts(res.body);
  }

  // ─────────────────────────────────────────────
  // 关注用户 (forum-follows) — V2.0 新增
  // ─────────────────────────────────────────────

  Future<bool> toggleFollow(String targetUserId) async {
    await _ensureSession();
    final res = await http.post(
      Uri.parse('$_baseUrl/forum-follows'),
      headers: _authHeaders(),
      body: json.encode({'target_user_id': targetUserId}),
    );
    _checkStatus(res, '关注操作');
    final data = json.decode(res.body);
    return data['action'] == 'followed';
  }

  Future<PaginatedResponse<ForumFollow>> getMyFollows({
    int page = 1,
    int limit = 20,
  }) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/forum-follows').replace(
        queryParameters: {'page': page.toString(), 'limit': limit.toString()},
      ),
      headers: _authHeaders(),
    );
    _checkStatus(res, '我的关注');
    final data = json.decode(res.body);
    final follows = (data['data'] as List)
        .map((e) => ForumFollow.fromJson(e))
        .toList();
    return PaginatedResponse(
      data: follows,
      pagination: PaginationInfo.fromJson(data['pagination'] ?? {}),
    );
  }

  // ─────────────────────────────────────────────
  // 标签关注 (forum-tag-follows) — V2.0 新增
  // ─────────────────────────────────────────────

  Future<bool> toggleTagFollow(int tagId) async {
    await _ensureSession();
    final res = await http.post(
      Uri.parse('$_baseUrl/forum-tag-follows'),
      headers: _authHeaders(),
      body: json.encode({'tag_id': tagId}),
    );
    _checkStatus(res, '标签关注操作');
    final data = json.decode(res.body);
    return data['data']?['followed'] == true;
  }

  Future<List<ForumTagFollow>> getMyTagFollows() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/forum-tag-follows'),
      headers: _authHeaders(),
    );
    _checkStatus(res, '我的标签关注');
    final data = json.decode(res.body);
    final raw = data['data'];
    if (raw == null) return [];
    return (raw as List)
        .map((e) => ForumTagFollow.fromJson(e))
        .toList();
  }

  // ─────────────────────────────────────────────
  // 举报 (forum-reports)
  // ─────────────────────────────────────────────

  Future<void> createReport(
    String targetType,
    int targetId,
    String reason,
    String? detail,
  ) async {
    await _ensureSession();
    final body = <String, dynamic>{
      'target_type': targetType,
      'target_id': targetId,
      'reason': reason,
    };
    if (detail != null && detail.isNotEmpty) body['detail'] = detail;

    final res = await http.post(
      Uri.parse('$_baseUrl/forum-reports'),
      headers: _authHeaders(),
      body: json.encode(body),
    );
    _checkStatus(res, '提交举报');
  }

  // ─────────────────────────────────────────────
  // 通知 (forum-notifications)
  // ─────────────────────────────────────────────

  Future<PaginatedResponse<ForumNotification>> getNotifications({
    int page = 1,
    int limit = 20,
  }) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/forum-notifications').replace(
        queryParameters: {'page': page.toString(), 'limit': limit.toString()},
      ),
      headers: _authHeaders(),
    );
    _checkStatus(res, '获取通知');
    final data = json.decode(res.body);
    final notifs = (data['data'] as List)
        .map((e) => ForumNotification.fromJson(e))
        .toList();
    return PaginatedResponse(
      data: notifs,
      pagination: PaginationInfo.fromJson(data['pagination'] ?? {}),
    );
  }

  Future<int> getUnreadCount() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/forum-notifications/unread-count'),
      headers: _authHeaders(),
    );
    _checkStatus(res, '获取未读数');
    final data = json.decode(res.body);
    return data['unread_count'] ?? 0;
  }

  Future<void> markRead(int id) async {
    final res = await http.put(
      Uri.parse('$_baseUrl/forum-notifications/$id/read'),
      headers: _authHeaders(),
    );
    _checkStatus(res, '标记已读');
  }

  Future<void> markAllRead() async {
    final res = await http.put(
      Uri.parse('$_baseUrl/forum-notifications/read-all'),
      headers: _authHeaders(),
    );
    _checkStatus(res, '全部已读');
  }

  // ─────────────────────────────────────────────
  // 我的 (forum-my)
  // ─────────────────────────────────────────────

  Future<PaginatedResponse<ForumPost>> getMyPosts({
    int page = 1,
    int limit = 20,
  }) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/forum-my/posts').replace(
        queryParameters: {'page': page.toString(), 'limit': limit.toString()},
      ),
      headers: _authHeaders(),
    );
    _checkStatus(res, '我的帖子');
    return _parsePaginatedPosts(res.body);
  }

  Future<PaginatedResponse<ForumReply>> getMyReplies({
    int page = 1,
    int limit = 20,
  }) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/forum-my/replies').replace(
        queryParameters: {'page': page.toString(), 'limit': limit.toString()},
      ),
      headers: _authHeaders(),
    );
    _checkStatus(res, '我的回复');
    final data = json.decode(res.body);
    final replies = (data['data'] as List)
        .map((e) => ForumReply.fromJson(e))
        .toList();
    return PaginatedResponse(
      data: replies,
      pagination: PaginationInfo.fromJson(data['pagination'] ?? {}),
    );
  }

  Future<PaginatedResponse<ForumPost>> getMyLikes({
    int page = 1,
    int limit = 20,
  }) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/forum-my/likes').replace(
        queryParameters: {'page': page.toString(), 'limit': limit.toString()},
      ),
      headers: _authHeaders(),
    );
    _checkStatus(res, '我点赞的帖子');
    return _parsePaginatedPosts(res.body);
  }

  // ─────────────────────────────────────────────
  // 图片上传 (forum-upload)
  // ─────────────────────────────────────────────

  Future<String> uploadImage(String filePath) async {
    await _ensureSession();

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/forum-upload'),
    );
    request.headers['Authorization'] = 'Bearer $_token';

    final ext = filePath.substring(filePath.lastIndexOf('.')).toLowerCase();
    final mediaType = _getMediaType(ext);

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        filePath,
        contentType: mediaType,
      ),
    );

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    _checkStatus(res, '上传图片');
    final data = json.decode(res.body);
    return data['url'] as String;
  }

  http.MediaType _getMediaType(String ext) {
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return http.MediaType('image', 'jpeg');
      case '.png':
        return http.MediaType('image', 'png');
      case '.webp':
        return http.MediaType('image', 'webp');
      case '.heic':
        return http.MediaType('image', 'heic');
      case '.heif':
        return http.MediaType('image', 'heif');
      default:
        return http.MediaType('application', 'octet-stream');
    }
  }

  // ─────────────────────────────────────────────
  // 标签 (forum-tags)
  // ─────────────────────────────────────────────

  Future<List<ForumTag>> getTags() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/forum-tags'),
      headers: _authHeaders(),
    );
    _checkStatus(res, '获取标签');
    final data = json.decode(res.body);
    return (data['data'] as List).map((e) => ForumTag.fromJson(e)).toList();
  }

  // ─────────────────────────────────────────────
  // 封禁检查 (forum-ban-check)
  // ─────────────────────────────────────────────

  Future<Map<String, dynamic>> checkBanStatus() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/forum-ban-check'),
      headers: _authHeaders(),
    );
    _checkStatus(res, '检查封禁状态');
    return json.decode(res.body);
  }

  // ─────────────────────────────────────────────
  // 反馈 (forum-feedback)
  // ─────────────────────────────────────────────

  Future<void> submitFeedback(
    String type,
    String title,
    String content,
    List<String>? imageUrls,
  ) async {
    await _ensureSession();
    final body = <String, dynamic>{
      'type': type,
      'title': title,
      'content': content,
    };
    if (imageUrls != null && imageUrls.isNotEmpty) {
      body['image_urls'] = imageUrls;
    }
    final res = await http.post(
      Uri.parse('$_baseUrl/forum-feedback'),
      headers: _authHeaders(),
      body: json.encode(body),
    );
    _checkStatus(res, '提交反馈');
  }

  Future<PaginatedResponse<ForumFeedback>> getMyFeedback({
    int page = 1,
    int limit = 20,
  }) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/forum-feedback/my').replace(
        queryParameters: {'page': page.toString(), 'limit': limit.toString()},
      ),
      headers: _authHeaders(),
    );
    _checkStatus(res, '我的反馈');
    final data = json.decode(res.body);
    final feedbacks = (data['data'] as List)
        .map((e) => ForumFeedback.fromJson(e))
        .toList();
    return PaginatedResponse(
      data: feedbacks,
      pagination: PaginationInfo.fromJson(data['pagination'] ?? {}),
    );
  }

  // ─────────────────────────────────────────────
  // 管理后台 — 帖子审核 (forum-admin-posts)
  // ─────────────────────────────────────────────

  Future<PaginatedResponse<ForumPost>> getAdminPosts({
    String? status,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (search != null && search.isNotEmpty) params['search'] = search;

    final res = await http.get(
      Uri.parse('$_baseUrl/forum-admin-posts').replace(queryParameters: params),
      headers: _authHeaders(),
    );
    _checkStatus(res, '获取管理帖子列表');
    return _parsePaginatedPosts(res.body);
  }

  Future<void> approvePost(int id) async {
    final res = await http.patch(
      Uri.parse('$_baseUrl/forum-admin-posts/$id'),
      headers: _authHeaders(),
      body: json.encode({'action': 'approve'}),
    );
    _checkStatus(res, '审核通过帖子');
  }

  Future<void> rejectPost(int id, {String? reason}) async {
    final res = await http.delete(
      Uri.parse('$_baseUrl/forum-admin-posts/$id'),
      headers: _authHeaders(),
      body: reason != null ? json.encode({'reason': reason}) : null,
    );
    _checkStatus(res, '拒绝帖子');
  }

  // ─────────────────────────────────────────────
  // 管理后台 — 评论审核 (forum-admin-replies)
  // ─────────────────────────────────────────────

  Future<PaginatedResponse<ForumReply>> getAdminReplies({
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (status != null && status.isNotEmpty) params['status'] = status;

    final res = await http.get(
      Uri.parse(
        '$_baseUrl/forum-admin-replies',
      ).replace(queryParameters: params),
      headers: _authHeaders(),
    );
    _checkStatus(res, '获取管理回复列表');
    final data = json.decode(res.body);
    final replies = (data['data'] as List)
        .map((e) => ForumReply.fromJson(e))
        .toList();
    return PaginatedResponse(
      data: replies,
      pagination: PaginationInfo.fromJson(data['pagination'] ?? {}),
    );
  }

  Future<void> approveReply(int id) async {
    final res = await http.patch(
      Uri.parse('$_baseUrl/forum-admin-replies/$id'),
      headers: _authHeaders(),
      body: json.encode({'action': 'approve'}),
    );
    _checkStatus(res, '审核通过评论');
  }

  Future<void> rejectReply(int id, {String? reason}) async {
    final res = await http.delete(
      Uri.parse('$_baseUrl/forum-admin-replies/$id'),
      headers: _authHeaders(),
      body: reason != null ? json.encode({'reason': reason}) : null,
    );
    _checkStatus(res, '拒绝评论');
  }

  // ─────────────────────────────────────────────
  // 管理后台 — 举报处理 (forum-admin-reports)
  // ─────────────────────────────────────────────

  Future<PaginatedResponse<ForumReport>> getAdminReports({
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (status != null && status.isNotEmpty) params['status'] = status;

    final res = await http.get(
      Uri.parse(
        '$_baseUrl/forum-admin-reports',
      ).replace(queryParameters: params),
      headers: _authHeaders(),
    );
    _checkStatus(res, '获取举报列表');
    final data = json.decode(res.body);
    final reports = (data['data'] as List)
        .map((e) => ForumReport.fromJson(e))
        .toList();
    return PaginatedResponse(
      data: reports,
      pagination: PaginationInfo.fromJson(data['pagination'] ?? {}),
    );
  }

  Future<void> handleReport(int id, String action) async {
    final res = await http.put(
      Uri.parse('$_baseUrl/forum-admin-reports/$id'),
      headers: _authHeaders(),
      body: json.encode({'action': action}),
    );
    _checkStatus(res, '处理举报');
  }

  // ─────────────────────────────────────────────
  // 管理后台 — 用户管理 (forum-admin-users)
  // ─────────────────────────────────────────────

  Future<PaginatedResponse<AdminUser>> getAdminUsers({
    String? search,
    String? role,
    bool? isBanned,
    int page = 1,
    int limit = 20,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (role != null && role.isNotEmpty) params['role'] = role;
    if (isBanned != null) params['is_banned'] = isBanned.toString();

    final res = await http.get(
      Uri.parse('$_baseUrl/forum-admin-users').replace(queryParameters: params),
      headers: _authHeaders(),
    );
    _checkStatus(res, '获取用户列表');
    final data = json.decode(res.body);
    final users = (data['data'] as List)
        .map((e) => AdminUser.fromJson(e))
        .toList();
    return PaginatedResponse(
      data: users,
      pagination: PaginationInfo.fromJson(data['pagination'] ?? {}),
    );
  }

  Future<void> banUser(String userId, {String? reason}) async {
    final body = <String, dynamic>{};
    if (reason != null && reason.isNotEmpty) body['reason'] = reason;

    final res = await http.post(
      Uri.parse('$_baseUrl/forum-admin-users/$userId/ban'),
      headers: _authHeaders(),
      body: json.encode(body),
    );
    _checkStatus(res, '封禁用户');
  }

  Future<void> unbanUser(String userId) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/forum-admin-users/$userId/unban'),
      headers: _authHeaders(),
    );
    _checkStatus(res, '解封用户');
  }

  // ─────────────────────────────────────────────
  // 管理后台 — 反馈管理 (forum-admin-feedback)
  // ─────────────────────────────────────────────

  Future<PaginatedResponse<ForumFeedback>> getAdminFeedback({
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (status != null && status.isNotEmpty) params['status'] = status;

    final res = await http.get(
      Uri.parse(
        '$_baseUrl/forum-admin-feedback',
      ).replace(queryParameters: params),
      headers: _authHeaders(),
    );
    _checkStatus(res, '获取反馈列表');
    final data = json.decode(res.body);
    final feedbacks = (data['data'] as List)
        .map((e) => ForumFeedback.fromJson(e))
        .toList();
    return PaginatedResponse(
      data: feedbacks,
      pagination: PaginationInfo.fromJson(data['pagination'] ?? {}),
    );
  }

  Future<void> replyFeedback(int id, String reply) async {
    final res = await http.put(
      Uri.parse('$_baseUrl/forum-admin-feedback/$id/reply'),
      headers: _authHeaders(),
      body: json.encode({'reply': reply}),
    );
    _checkStatus(res, '回复反馈');
  }

  Future<void> updateFeedbackStatus(int id, String status) async {
    final res = await http.patch(
      Uri.parse('$_baseUrl/forum-admin-feedback/$id'),
      headers: _authHeaders(),
      body: json.encode({'status': status}),
    );
    _checkStatus(res, '更新反馈状态');
  }

  // ─────────────────────────────────────────────
  // 管理后台 — 仪表盘 (forum-admin-dashboard)
  // ─────────────────────────────────────────────

  Future<Map<String, dynamic>> getAdminDashboard() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/forum-admin-dashboard'),
      headers: _authHeaders(),
    );
    _checkStatus(res, '获取仪表盘数据');
    final data = json.decode(res.body);
    return (data['data'] is Map<String, dynamic>)
        ? Map<String, dynamic>.from(data['data'])
        : Map<String, dynamic>.from(data);
  }

  // ─────────────────────────────────────────────
  // 内部工具方法
  // ─────────────────────────────────────────────

  void _checkStatus(http.Response res, String operation) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      String message;
      try {
        final body = json.decode(res.body);
        message = body['error'] ?? body['message'] ?? res.body;
      } catch (_) {
        message = res.body;
      }
      throw Exception('$operation失败 (${res.statusCode}): $message');
    }
  }

  PaginatedResponse<ForumPost> _parsePaginatedPosts(String body) {
    final data = json.decode(body);
    final posts = (data['data'] as List)
        .map((e) => ForumPost.fromJson(e))
        .toList();
    return PaginatedResponse(
      data: posts,
      pagination: PaginationInfo.fromJson(data['pagination'] ?? {}),
    );
  }
}

/// 分页响应
class PaginatedResponse<T> {
  final List<T> data;
  final PaginationInfo pagination;

  const PaginatedResponse({required this.data, required this.pagination});
}

/// 分页信息
class PaginationInfo {
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  const PaginationInfo({
    this.page = 1,
    this.limit = 20,
    this.total = 0,
    this.totalPages = 0,
  });

  bool get hasMore => page < totalPages;

  factory PaginationInfo.fromJson(Map<String, dynamic> json) {
    return PaginationInfo(
      page: json['page'] is int
          ? json['page']
          : int.tryParse(json['page']?.toString() ?? '1') ?? 1,
      limit: json['limit'] is int
          ? json['limit']
          : int.tryParse(json['limit']?.toString() ?? '20') ?? 20,
      total: json['total'] is int
          ? json['total']
          : int.tryParse(json['total']?.toString() ?? '0') ?? 0,
      totalPages: json['totalPages'] is int
          ? json['totalPages']
          : (json['total_pages'] is int
                ? json['total_pages']
                : int.tryParse(
                        json['total_pages']?.toString() ??
                            json['totalPages']?.toString() ??
                            '0',
                      ) ??
                      0),
    );
  }
}
