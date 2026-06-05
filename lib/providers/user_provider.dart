import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:vidlang/models/base_entity.dart';
import 'package:vidlang/models/user.dart';
import 'package:vidlang/services/database_service.dart';

Future<User> ensureDefaultAdminSession() async {
  final currentUserCode = await DatabaseService.getCurrentUserCode();
  if (currentUserCode != null) {
    final user = await BaseEntityExtension.findByCode<User>(currentUserCode, () => User());
    if (user != null) return user;
  }

  final users = await BaseEntityExtension.findByCondition<User>(
    () => User(),
    where: 'username = ? AND is_deleted = 0',
    whereArgs: ['admin'],
    limit: 1,
  );

  User admin;
  if (users.isNotEmpty) {
    admin = users.first;
    admin.isPrimary = true;
    admin.role = 'admin';
    admin.nickname = admin.nickname.isEmpty ? '管理员' : admin.nickname;
    admin.password = admin.password.isEmpty ? '123' : admin.password;
    admin.token ??= const Uuid().v4().replaceAll('-', '');
    await DatabaseService.update(admin);
  } else {
    admin = User(
      username: 'admin',
      password: '123',
      nickname: '管理员',
      role: 'admin',
      isPrimary: true,
      token: const Uuid().v4().replaceAll('-', ''),
    );
    await DatabaseService.insert(admin);
  }

  await DatabaseService.setCurrentUserCode(admin.code);
  await DatabaseService.setCurrentToken(admin.token);
  return admin;
}

/// 用户管理 Provider
/// 
/// 使用 Riverpod 状态管理，提供用户认证和个人信息管理
final userProvider = StateNotifierProvider<UserNotifier, User?>((ref) {
  return UserNotifier();
});

/// 用户状态管理器
/// 
/// 负责处理用户认证和个人信息相关业务逻辑：
/// - 用户登录/登出
/// - 当前用户加载
/// - 用户信息更新
/// - Token 管理
class UserNotifier extends StateNotifier<User?> {
  UserNotifier() : super(null);

  /// 用户登录
  /// 
  /// [username] 用户名
  /// [password] 密码
  /// 
  /// 根据用户名密码验证用户，成功则加载用户信息
  Future<void> login(String username, String password) async {
    final users = await BaseEntityExtension.findByCondition<User>(
      () => User(),
      where: 'username = ? AND password = ? AND is_deleted = 0',
      whereArgs: [username, password],
    );
    
    if (users.isNotEmpty) {
      state = users.first;
      // 保存当前用户到数据库配置
      await DatabaseService.setCurrentUserCode(state!.code);
      await DatabaseService.setCurrentToken(state!.token);
    } else {
      state = null;
    }
  }

  /// 用户登出
  /// 
  /// 清除当前用户状态和数据库中的用户配置
  Future<void> logout() async {
    state = null;
    await DatabaseService.clearCurrentUser();
  }

  /// 加载当前用户
  /// 
  /// 从数据库配置中读取用户code，然后加载完整用户信息
  Future<void> loadCurrentUser() async {
    final userCode = await DatabaseService.getCurrentUserCode();
    if (userCode != null) {
      final user = await BaseEntityExtension.findByCode<User>(userCode, () => User());
      state = user;
    } else {
      state = null;
    }
  }

  /// 更新用户信息
  /// 
  /// [updatedUser] 更新后的用户对象
  /// 
  /// 保存到数据库并更新状态
  Future<void> updateUser(User updatedUser) async {
    if (state != null && state!.id == updatedUser.id) {
      await updatedUser.save();
      state = updatedUser;
      
      // 更新数据库中的用户配置
      if (updatedUser.code != null) {
        await DatabaseService.setCurrentUserCode(updatedUser.code);
      }
      if (updatedUser.token != null) {
        await DatabaseService.setCurrentToken(updatedUser.token);
      }
    }
  }

  /// 更新用户Token
  /// 
  /// [newToken] 新Token
  /// 
  /// 用于Token刷新或更新
  Future<void> updateToken(String newToken) async {
    if (state != null) {
      state!.token = newToken;
      await state!.save();
      await DatabaseService.setCurrentToken(newToken);
    }
  }

  /// 更新用户资料
  /// 
  /// [nickname] 昵称
  /// [avatar] 头像
  /// [email] 邮箱
  /// [phone] 手机号
  /// 
  /// 仅更新提供的非空字段
  Future<void> updateProfile({
    String? nickname,
    String? avatar,
    String? email,
    String? phone,
  }) async {
    if (state != null) {
      if (nickname != null) state!.nickname = nickname;
      if (avatar != null) state!.avatar = avatar;
      if (email != null) state!.email = email;
      if (phone != null) state!.phone = phone;
      
      await state!.save();
      state = state!.copy();
    }
  }

  /// 用户注册
  /// 
  /// [user] 用户对象
  /// 
  /// 保存用户并设置为当前用户
  Future<User?> register(User user) async {
    await user.save();
    state = user;
    await DatabaseService.setCurrentUserCode(user.code);
    await DatabaseService.setCurrentToken(user.token);
    return user;
  }
}

/// User 类的拷贝扩展
/// 
/// 提供深拷贝功能，用于状态更新时创建新实例
extension UserCopy on User {
  /// 创建当前用户的深拷贝
  User copy() {
    return User(
      username: username,
      password: password,
      nickname: nickname,
      avatar: avatar,
      email: email,
      phone: phone,
      role: role,
      token: token,
    )
      ..id = id
      ..code = code
      ..createdAt = createdAt
      ..updatedAt = updatedAt
      ..deletedAt = deletedAt
      ..isDeleted = isDeleted
      ..createdBy = createdBy
      ..updatedBy = updatedBy
      ..deletedBy = deletedBy;
  }
}
