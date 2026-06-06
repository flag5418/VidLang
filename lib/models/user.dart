import 'package:vidlang/models/base_entity.dart';

/// 用户实体类
///
/// 用于存储和管理用户账户信息，包括登录凭证和个人资料。
/// 支持用户认证、角色管理和会话Token。
///
/// 主要功能：
/// - 用户登录凭证管理（用户名、密码）
/// - 个人资料存储（昵称、头像、邮箱、手机）
/// - 角色权限管理
/// - 认证Token管理
///
/// 使用场景：
/// - 用户登录验证
/// - 个人资料展示和修改
/// - API请求认证
/// - 多用户数据隔离
///
/// 示例：
/// ```dart
/// final user = User(
///   username: 'john',
///   password: 'encrypted_password',
///   nickname: 'John Doe',
///   email: 'john@example.com',
///   role: 'user',
/// );
/// ```
class User extends BaseEntity {
  /// 用户名（登录账号）
  ///
  /// 用于用户登录，唯一标识
  String username;

  /// 密码（加密存储）
  ///
  /// 建议使用哈希加密存储，不要明文
  String password;

  /// 用户昵称
  ///
  /// 用于界面显示
  String nickname;

  /// 用户头像URL
  String? avatar;

  /// 电子邮箱
  String? email;

  /// 手机号码
  String? phone;

  /// 用户角色
  ///
  /// 常用值：'user'（普通用户）、'admin'（管理员）
  String role;

  bool isPrimary;

  /// 认证Token
  ///
  /// 登录成功后生成的认证令牌
  /// 用于API请求认证和会话保持
  String? token;

  String authProvider;
  String? supabaseUserId;

  User({
    this.username = '',
    this.password = '',
    this.nickname = '',
    this.avatar,
    this.email,
    this.phone,
    this.role = 'user',
    this.token,
    this.isPrimary = false,
    this.authProvider = 'local',
    this.supabaseUserId,
  });

  @override
  String get tableName => 'user';

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'username': username,
      'password': password,
      'nickname': nickname,
      'avatar': avatar,
      'email': email,
      'phone': phone,
      'role': role,
      'token': token,
      'auth_provider': authProvider,
      'supabase_user_id': supabaseUserId,
      'is_primary': isPrimary ? 1 : 0,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
      'created_by': createdBy,
      'updated_by': updatedBy,
      'deleted_by': deletedBy,
    };
  }

  @override
  BaseEntity fromMap(Map<String, dynamic> map) {
    id = map['id'];
    code = map['code'];
    username = map['username'] ?? '';
    password = map['password'] ?? '';
    nickname = map['nickname'] ?? '';
    avatar = map['avatar'];
    email = map['email'];
    phone = map['phone'];
    role = map['role'] ?? 'user';
    token = map['token'];
    authProvider = map['auth_provider'] ?? 'local';
    supabaseUserId = map['supabase_user_id'];
    isPrimary = map['is_primary'] == 1;
    createdAt = map['created_at'] != null ? DateTime.parse(map['created_at']) : null;
    updatedAt = map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null;
    deletedAt = map['deleted_at'] != null ? DateTime.parse(map['deleted_at']) : null;
    isDeleted = map['is_deleted'] == 1;
    createdBy = map['created_by'];
    updatedBy = map['updated_by'];
    deletedBy = map['deleted_by'];
    return this;
  }
}
