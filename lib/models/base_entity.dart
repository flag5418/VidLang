import 'package:uuid/uuid.dart';

import '../services/database_service.dart';

/// 实体基类
/// 
/// 所有数据模型必须继承此类，提供以下核心功能：
/// - 自动生成唯一业务标识符（code）
/// - 统一的数据序列化/反序列化（toMap/fromMap）
/// - 软删除支持
/// - 自动填充审计字段（创建人、创建时间等）
/// - 通用数据库操作方法（保存、删除、查询等）
/// 
/// 使用示例：
/// ```dart
/// class VideoInfo extends BaseEntity {
///   String name;
///   int duration;
///   
///   @override
///   String get tableName => 'video_info';
///   
///   @override
///   Map<String, dynamic> toMap() {
///     return {'name': name, 'duration': duration};
///   }
///   
///   @override
///   BaseEntity fromMap(Map<String, dynamic> map) {
///     name = map['name'];
///     duration = map['duration'];
///     return this;
///   }
/// }
/// ```
abstract class BaseEntity {
  /// 数据库自增主键
  int? id;

  /// 业务唯一标识符（UUID）
  /// 用于在业务层唯一标识一条记录
  String? code;

  /// 用户标识
  /// 用于支持多用户数据隔离
  String? userCode;

  /// 创建时间
  DateTime? createdAt;

  /// 最后更新时间
  DateTime? updatedAt;

  /// 是否已删除（软删除标志）
  bool isDeleted = false;

  /// 删除时间
  DateTime? deletedAt;

  /// 创建人编码
  String? createdBy;

  /// 更新人编码
  String? updatedBy;

  /// 删除人编码
  String? deletedBy;

  /// 构造函数
  /// 
  /// 自动生成 UUID 和设置创建时间
  BaseEntity() {
    // 生成32位无横线的 UUID
    code = const Uuid().v4().replaceAll('-', '');
    createdAt = DateTime.now();
    isDeleted = false;
  }

  /// 将实体转换为 Map
  /// 
  /// 用于数据库插入/更新操作
  /// 子类必须实现此方法
  Map<String, dynamic> toMap();

  /// 从 Map 恢复实体
  /// 
  /// 用于数据库查询结果转换
  /// [map] 数据库查询结果
  /// 返回当前实体实例
  BaseEntity fromMap(Map<String, dynamic> map);

  /// 获取表名
  /// 
  /// 子类必须实现此属性
  String get tableName;
}

/// BaseEntity 扩展方法
/// 
/// 提供常用的数据库操作方法
extension BaseEntityExtension on BaseEntity {
  /// 保存实体
  /// 
  /// 根据 id 是否为空判断是插入还是更新
  /// - 新增时自动设置 createdBy 和 userCode
  /// - 更新时自动设置 updatedAt 和 updatedBy
  /// 
  /// 返回影响行数
  Future<int> save() async {
    // 获取当前登录用户的 code
    final userCode = await DatabaseService.getCurrentUserCode();

    if (id == null) {
      // 新增操作
      createdBy = userCode;
      this.userCode = userCode;
      return await DatabaseService.insert(this);
    } else {
      // 更新操作
      updatedAt = DateTime.now();
      updatedBy = userCode;
      return await DatabaseService.update(this);
    }
  }

  /// 物理删除
  /// 
  /// 直接从数据库删除记录（不可恢复）
  /// 通常不推荐使用，建议使用 softDelete()
  Future<int> delete() async {
    return await DatabaseService.delete(this);
  }

  /// 软删除
  /// 
  /// 设置 is_deleted = true 并记录删除信息
  /// - 设置 isDeleted = true
  /// - 设置 deletedAt = 当前时间
  /// - 设置 deletedBy = 当前用户
  /// 
  /// 返回影响行数
  Future<int> softDelete() async {
    isDeleted = true;
    deletedAt = DateTime.now();
    deletedBy = await DatabaseService.getCurrentUserCode();
    return await DatabaseService.softDelete(this);
  }

  /// 根据主键查询
  /// 
  /// [id] 数据库主键
  /// [create] 实体创建工厂
  /// 返回查询到的实体，未找到返回 null
  static Future<T?> findById<T extends BaseEntity>(
    int id,
    T Function() create,
  ) async {
    return await DatabaseService.findById(id, create);
  }

  /// 查询所有未删除的记录
  /// 
  /// [create] 实体创建工厂
  /// 返回所有 is_deleted = 0 的记录列表
  static Future<List<T>> findAll<T extends BaseEntity>(
    T Function() create,
  ) async {
    return await DatabaseService.findAll(create);
  }

  /// 根据业务标识查询
  /// 
  /// [code] 业务唯一标识
  /// [create] 实体创建工厂
  /// 
  /// 自动添加 userCode 过滤，支持多用户数据隔离
  /// 返回查询到的实体，未找到返回 null
  static Future<T?> findByCode<T extends BaseEntity>(
    String code,
    T Function() create,
  ) async {
    final userCode = await DatabaseService.getCurrentUserCode();
    final db = await DatabaseService.database;
    T entity = create();

    String whereClause = 'code = ? AND is_deleted = 0';
    List<Object?> whereArgs = [code];

    // user 表不添加用户过滤
    if (userCode != null && entity.tableName != 'user') {
      whereClause += ' AND user_code = ?';
      whereArgs.add(userCode);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      entity.tableName,
      where: whereClause,
      whereArgs: whereArgs,
    );

    if (maps.isNotEmpty) {
      return entity.fromMap(maps.first) as T;
    }
    return null;
  }

  /// 条件查询
  /// 
  /// [create] 实体创建工厂
  /// [where] WHERE 条件语句
  /// [whereArgs] 条件参数列表
  /// [orderBy] 排序字段，如 'created_at DESC'
  /// [limit] 返回记录数限制
  /// [offset] 跳过记录数（分页偏移）
  /// 
  /// 返回符合条件的记录列表
  static Future<List<T>> findByCondition<T extends BaseEntity>(
    T Function() create, {
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    return await DatabaseService.findByCondition(
      create,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  /// 统计记录数
  /// 
  /// [create] 实体创建工厂
  /// [where] WHERE 条件语句
  /// [whereArgs] 条件参数列表
  /// 返回符合条件的记录总数
  static Future<int> count<T extends BaseEntity>(
    T Function() create, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    return await DatabaseService.count(
      create,
      where: where,
      whereArgs: whereArgs,
    );
  }

  /// 根据分类查询
  /// 
  /// [category] 分类值
  /// [create] 实体创建工厂
  /// [orderBy] 排序字段
  /// 返回该分类下的所有未删除记录
  static Future<List<T>> findByCategory<T extends BaseEntity>(
    String category,
    T Function() create, {
    String? orderBy,
  }) async {
    return await DatabaseService.findByCondition(
      create,
      where: 'category = ? AND is_deleted = 0',
      whereArgs: [category],
      orderBy: orderBy,
    );
  }

  /// 根据键名查询
  /// 
  /// [key] 键名字段值
  /// [create] 实体创建工厂
  /// [orderBy] 排序字段
  /// 返回匹配键名的所有未删除记录
  static Future<List<T>> findByKey<T extends BaseEntity>(
    String key,
    T Function() create, {
    String? orderBy,
  }) async {
    return await DatabaseService.findByCondition(
      create,
      where: 'key = ? AND is_deleted = 0',
      whereArgs: [key],
      orderBy: orderBy,
    );
  }
}
