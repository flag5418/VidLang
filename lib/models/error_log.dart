import 'package:vidlang/models/base_entity.dart';

class ErrorLog extends BaseEntity {
  String level;
  String tag;
  String message;
  String? error;
  String? stackTrace;
  String? extra;

  ErrorLog({
    this.level = 'error',
    this.tag = 'APP',
    this.message = '',
    this.error,
    this.stackTrace,
    this.extra,
  });

  @override
  String get tableName => 'error_log';

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'user_code': userCode,
      'level': level,
      'tag': tag,
      'message': message,
      'error': error,
      'stack_trace': stackTrace,
      'extra': extra,
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
    userCode = map['user_code'];
    level = map['level'] ?? 'error';
    tag = map['tag'] ?? 'APP';
    message = map['message'] ?? '';
    error = map['error'];
    stackTrace = map['stack_trace'];
    extra = map['extra'];
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

