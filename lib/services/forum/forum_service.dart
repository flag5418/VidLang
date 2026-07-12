import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/forum/forum_post.dart';
import '../../models/forum/forum_category.dart';
import 'package:vidlang/services/app_keys_service.dart';

class ForumService {
  final SupabaseClient _supabase;
  static String get baseUrl => '${AppKeysService.supabaseUrl}/functions/v1';

  ForumService(this._supabase);

  // 获取帖子列表
  Future<PaginatedResponse<ForumPost>> getPosts({
    int page = 1,
    int limit = 10,
    String? category,
    String? type,
    String? search,
  }) async {
    try {
      final token = _supabase.auth.currentSession?.accessToken;
      final response = await http.get(
        Uri.parse('$baseUrl/forum-service/posts').replace(
          queryParameters: {
            'page': page.toString(),
            'limit': limit.toString(),
            'category': ?category,
            'type': ?type,
            'search': ?search,
          },
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final posts = (data['data'] as List)
            .map((item) => ForumPost.fromJson(item))
            .toList();

        return PaginatedResponse<ForumPost>(
          data: posts,
          pagination: PaginationInfo.fromJson(data['pagination']),
        );
      } else {
        throw Exception('获取帖子失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('获取帖子失败: $e');
    }
  }

  // 获取分类列表
  Future<List<ForumCategory>> getCategories() async {
    try {
      final token = _supabase.auth.currentSession?.accessToken;
      final response = await http.get(
        Uri.parse('$baseUrl/forum-service/categories'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['data'] as List)
            .map((item) => ForumCategory.fromJson(item))
            .toList();
      } else {
        throw Exception('获取分类失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('获取分类失败: $e');
    }
  }

  // 获取用户帖子
  Future<PaginatedResponse<ForumPost>> getUserPosts({
    int page = 1,
    int limit = 10,
    bool includeDrafts = false,
  }) async {
    try {
      final token = _supabase.auth.currentSession?.accessToken;
      final response = await http.get(
        Uri.parse('$baseUrl/forum-service/user-posts').replace(
          queryParameters: {
            'page': page.toString(),
            'limit': limit.toString(),
            'drafts': includeDrafts.toString(),
          },
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final posts = (data['data'] as List)
            .map((item) => ForumPost.fromJson(item))
            .toList();

        return PaginatedResponse<ForumPost>(
          data: posts,
          pagination: PaginationInfo.fromJson(data['pagination']),
        );
      } else {
        throw Exception('获取用户帖子失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('获取用户帖子失败: $e');
    }
  }

  // 获取用户收藏
  Future<List<ForumPost>> getUserFavorites() async {
    try {
      final token = _supabase.auth.currentSession?.accessToken;
      final response = await http.get(
        Uri.parse('$baseUrl/forum-service/favorites'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['data'] as List)
            .map((item) => ForumPost.fromJson(item))
            .toList();
      } else {
        throw Exception('获取用户收藏失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('获取用户收藏失败: $e');
    }
  }

  // 获取论坛统计数据
  Future<Map<String, dynamic>> getForumStats() async {
    try {
      final token = _supabase.auth.currentSession?.accessToken;
      final response = await http.get(
        Uri.parse('$baseUrl/forum-service/stats'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'];
      } else {
        throw Exception('获取论坛统计失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('获取论坛统计失败: $e');
    }
  }

  // 创建帖子
  Future<ForumPost> createPost({
    required String title,
    required String content,
    required int categoryId,
    String postType = 'discussion',
    String? resourceType,
    String? resourceUrl,
    String? resourceDescription,
    List<String>? tags,
  }) async {
    try {
      final token = _supabase.auth.currentSession?.accessToken;
      final response = await http.post(
        Uri.parse('$baseUrl/forum-service/posts'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'title': title,
          'content': content,
          'category_id': categoryId,
          'post_type': postType,
          'resource_type': ?resourceType,
          'resource_url': ?resourceUrl,
          'resource_description': ?resourceDescription,
          'tags': ?tags,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ForumPost.fromJson(data['data']);
      } else {
        throw Exception('创建帖子失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('创建帖子失败: $e');
    }
  }

  // 更新帖子
  Future<ForumPost> updatePost({
    required int id,
    required String title,
    required String content,
    required int categoryId,
    List<String>? tags,
  }) async {
    try {
      final token = _supabase.auth.currentSession?.accessToken;
      final response = await http.put(
        Uri.parse('$baseUrl/forum-service/post'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'id': id,
          'title': title,
          'content': content,
          'category_id': categoryId,
          'tags': ?tags,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ForumPost.fromJson(data['data']);
      } else {
        throw Exception('更新帖子失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('更新帖子失败: $e');
    }
  }

  // 删除帖子
  Future<void> deletePost(int id) async {
    try {
      final token = _supabase.auth.currentSession?.accessToken;
      final response = await http.delete(
        Uri.parse(
          '$baseUrl/forum-service/post',
        ).replace(queryParameters: {'id': id.toString()}),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('删除帖子失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('删除帖子失败: $e');
    }
  }

  // 点赞/取消点赞帖子
  Future<void> toggleLike(int postId) async {
    try {
      final token = _supabase.auth.currentSession?.accessToken;

      // 首先检查是否已经点赞
      final likeData = await _supabase
          .from('forum_likes')
          .select('id')
          .eq('post_id', postId)
          .eq('user_id', _supabase.auth.currentUser!.id)
          .maybeSingle();

      if (likeData != null) {
        // 取消点赞
        final response = await http.delete(
          Uri.parse(
            '$baseUrl/forum-service/like-post',
          ).replace(queryParameters: {'id': postId.toString()}),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );

        if (response.statusCode != 200) {
          throw Exception('取消点赞失败: ${response.statusCode}');
        }
      } else {
        // 点赞
        final response = await http.post(
          Uri.parse('$baseUrl/forum-service/like-post'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: json.encode({'post_id': postId}),
        );

        if (response.statusCode != 200) {
          throw Exception('点赞失败: ${response.statusCode}');
        }
      }
    } catch (e) {
      throw Exception('点赞操作失败: $e');
    }
  }

  // 收藏/取消收藏帖子
  Future<void> toggleFavorite(int postId) async {
    try {
      final token = _supabase.auth.currentSession?.accessToken;

      // 首先检查是否已经收藏
      final favoriteData = await _supabase
          .from('user_favorites')
          .select('id')
          .eq('post_id', postId)
          .eq('user_id', _supabase.auth.currentUser!.id)
          .maybeSingle();

      if (favoriteData != null) {
        // 取消收藏
        final response = await http.delete(
          Uri.parse(
            '$baseUrl/forum-service/favorite',
          ).replace(queryParameters: {'id': postId.toString()}),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );

        if (response.statusCode != 200) {
          throw Exception('取消收藏失败: ${response.statusCode}');
        }
      } else {
        // 收藏
        final response = await http.post(
          Uri.parse('$baseUrl/forum-service/favorite'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: json.encode({'post_id': postId}),
        );

        if (response.statusCode != 200) {
          throw Exception('收藏失败: ${response.statusCode}');
        }
      }
    } catch (e) {
      throw Exception('收藏操作失败: $e');
    }
  }

  // 提交反馈
  Future<Map<String, dynamic>> submitFeedback({
    required String feedbackType,
    required String title,
    required String content,
    String priority = 'medium',
  }) async {
    try {
      final token = _supabase.auth.currentSession?.accessToken;
      final response = await http.post(
        Uri.parse('$baseUrl/forum-service/feedback'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'feedback_type': feedbackType,
          'title': title,
          'content': content,
          'priority': priority,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        throw Exception('提交反馈失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('提交反馈失败: $e');
    }
  }

  // 获取用户通知
  Future<Map<String, dynamic>> getUserNotifications({
    int page = 1,
    int limit = 20,
    bool unread = false,
  }) async {
    try {
      final token = _supabase.auth.currentSession?.accessToken;
      final response = await http.get(
        Uri.parse('$baseUrl/forum-service/notifications').replace(
          queryParameters: {
            'page': page.toString(),
            'limit': limit.toString(),
            if (unread) 'unread': 'true',
          },
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        throw Exception('获取通知失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('获取通知失败: $e');
    }
  }

  // 标记通知为已读
  Future<void> markNotificationsRead(List<int> notificationIds) async {
    try {
      final token = _supabase.auth.currentSession?.accessToken;
      final response = await http.post(
        Uri.parse('$baseUrl/forum-service/notifications-read'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'notification_ids': notificationIds}),
      );

      if (response.statusCode != 200) {
        throw Exception('标记通知为已读失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('标记通知为已读失败: $e');
    }
  }

  // 获取帖子详情
  Future<ForumPost> getPostById(int id) async {
    try {
      // 增加浏览量
      await _supabase.rpc('increment_view_count', params: {'post_id': id});

      final response = await _supabase
          .from('forum_posts')
          .select('''
            *,
            author:auth.users(email, raw_user_meta_data),
            category:forum_categories(name, slug)
          ''')
          .eq('id', id)
          .eq('status', 'published')
          .single();

      return ForumPost.fromJson(response);
    } catch (e) {
      throw Exception('获取帖子详情失败: $e');
    }
  }
}

// 分页响应类
class PaginatedResponse<T> {
  final List<T> data;
  final PaginationInfo pagination;

  PaginatedResponse({required this.data, required this.pagination});
}

// 分页信息类
class PaginationInfo {
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  PaginationInfo({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  factory PaginationInfo.fromJson(Map<String, dynamic> json) {
    return PaginationInfo(
      page: json['page'] ?? 1,
      limit: json['limit'] ?? 10,
      total: json['total'] ?? 0,
      totalPages: json['totalPages'] ?? 0,
    );
  }
}
