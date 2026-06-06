import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vidlang/config.dart';
import 'package:vidlang/models/base_entity.dart';
import 'package:vidlang/models/user.dart';
import 'package:vidlang/services/database_service.dart';

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

  String _hashPassword(String password) => sha256.convert(utf8.encode(password)).toString();

  bool _looksLikeSha256(String value) => RegExp(r'^[a-f0-9]{64}$').hasMatch(value);

  /// 用户登录
  ///
  /// [username] 用户名
  /// [password] 密码
  ///
  /// 根据用户名密码验证用户，成功则加载用户信息
  Future<void> login(String username, String password) async {
    final hashed = _hashPassword(password);
    final users = await BaseEntityExtension.findByCondition<User>(
      () => User(),
      where: 'username = ? AND is_deleted = 0 AND (password = ? OR password = ?)',
      whereArgs: [username, hashed, password],
    );

    if (users.isNotEmpty) {
      state = users.first;
      if (state != null && !_looksLikeSha256(state!.password) && state!.password == password) {
        state!.password = hashed;
        await state!.save();
      }
      // 保存当前用户到数据库配置
      await DatabaseService.setCurrentUserCode(state!.code);
      AppConfig.currentUser = state;
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
    AppConfig.currentUser = null;
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
      AppConfig.currentUser = updatedUser;
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
      AppConfig.currentUser = state;
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
  Future<void> updateProfile({String? nickname, String? avatar, String? email, String? phone}) async {
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
    if (user.password.isNotEmpty && !_looksLikeSha256(user.password)) {
      user.password = _hashPassword(user.password);
    }
    await user.save();
    state = user;
    await DatabaseService.setCurrentUserCode(user.code);
    AppConfig.currentUser = user;
    return user;
  }
}

/// User 类的拷贝扩展
///
/// 提供深拷贝功能，用于状态更新时创建新实例
extension UserCopy on User {
  /// 创建当前用户的深拷贝
  User copy() {
    return User(username: username, password: password, nickname: nickname, avatar: avatar, email: email, phone: phone, role: role, token: token)
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
