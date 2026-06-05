import 'package:vidlang/models/base_entity.dart';

/// 配置值类型枚举
/// 
/// 用于定义配置项的值类型，确保类型安全和正确解析
enum ValueType {
  /// 字符串类型
  /// 用于存储文本配置
  string,
  
  /// 数字类型
  /// 用于存储数值配置
  number,
  
  /// 布尔类型
  /// 用于存储开关类配置
  boolean,
  
  /// 日期时间类型
  /// 用于存储时间配置
  datetime,
  
  /// JSON类型
  /// 用于存储复杂对象配置
  json,
}

/// 配置实体类
/// 
/// 用于存储和管理应用配置信息，采用键值对形式存储。
/// 支持分类管理，可以存储多种类型的配置值。
/// 
/// 主要功能：
/// - 存储应用全局配置
/// - 存储用户偏好设置
/// - 存储业务配置参数
/// - 支持分类分组管理
/// 
/// 使用场景：
/// - 应用初始化配置
/// - 用户偏好设置（如播放速度、主题等）
/// - 功能开关配置
/// - API配置参数
/// 
/// 示例：
/// ```dart
/// // 存储播放速度配置
/// final config = Config(
///   category: 'player',
///   key: 'playback_speed',
///   valueType: ValueType.number,
///   value: '1.5',
/// );
/// 
/// // 存储主题配置
/// final themeConfig = Config(
///   category: 'appearance',
///   key: 'theme_mode',
///   valueType: ValueType.string,
///   value: 'dark',
/// );
/// ```
class Config extends BaseEntity {
  /// 配置分类
  /// 
  /// 用于分组管理配置，如 'player'、'appearance'、'network' 等
  String category;
  
  /// 配置键名
  /// 
  /// 配置的唯一标识，不能重复
  String key;
  
  /// 配置值类型
  /// 
  /// 指定 value 字段的数据类型
  ValueType valueType;
  
  /// 配置值
  /// 
  /// 实际存储的配置值，类型由 valueType 指定
  String? value;

  Config({
    this.category = '',
    this.key = '',
    this.valueType = ValueType.string,
    this.value,
  });

  @override
  String get tableName => 'config';

  @override
  BaseEntity fromMap(Map<String, dynamic> map) {
    id = map['id'];
    code = map['code'];
    userCode = map['user_code'];
    category = map['category'] ?? '';
    key = map['key'] ?? '';
    valueType = _parseValueType(map['value_type'] ?? 'string');
    value = map['value'];
    createdAt = map['created_at'] != null ? DateTime.parse(map['created_at']) : null;
    updatedAt = map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null;
    deletedAt = map['deleted_at'] != null ? DateTime.parse(map['deleted_at']) : null;
    isDeleted = map['is_deleted'] == 1;
    createdBy = map['created_by'];
    updatedBy = map['updated_by'];
    deletedBy = map['deleted_by'];
    return this;
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'user_code': userCode,
      'category': category,
      'key': key,
      'value_type': _valueTypeToString(valueType),
      'value': value,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
      'created_by': createdBy,
      'updated_by': updatedBy,
      'deleted_by': deletedBy,
    };
  }

  /// 将 ValueType 转换为字符串
  /// 
  /// [type] 配置值类型枚举
  /// 返回类型对应的字符串标识
  String _valueTypeToString(ValueType type) {
    switch (type) {
      case ValueType.string:
        return 'string';
      case ValueType.number:
        return 'number';
      case ValueType.boolean:
        return 'boolean';
      case ValueType.datetime:
        return 'datetime';
      case ValueType.json:
        return 'json';
    }
  }

  /// 将字符串解析为 ValueType
  /// 
  /// [value] 类型字符串标识
  /// 返回对应的 ValueType 枚举值，默认返回 string
  ValueType _parseValueType(String? value) {
    switch (value) {
      case 'number':
        return ValueType.number;
      case 'boolean':
        return ValueType.boolean;
      case 'datetime':
        return ValueType.datetime;
      case 'json':
        return ValueType.json;
      default:
        return ValueType.string;
    }
  }
}
