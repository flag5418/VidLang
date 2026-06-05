# VidLang 开发规范

## 代码规范

### 注释要求

所有代码必须包含清晰的注释，便于后期维护：

#### 1. 类注释（必须）

```dart
/// 类名描述
/// 
/// 类的详细功能说明，包括主要用途、功能列表等。
/// 
/// 示例：
/// ```dart
/// final example = MyClass();
/// ```
class MyClass {
  // ...
}
```

#### 2. 属性注释（必须）

```dart
/// 属性描述
/// 
/// 属性的详细说明，包括用途、取值范围、默认值等
String propertyName;
```

#### 3. 方法注释（必须）

```dart
/// 方法描述
/// 
/// 方法的详细说明，包括参数、返回值、异常等
/// 
/// [param1]: 参数1的描述
/// [param2]: 参数2的描述
/// 
/// 返回值：返回值的描述
/// 
/// 示例：
/// ```dart
/// final result = myMethod('test');
/// ```
void myMethod(String param1, {String? param2}) {
  // ...
}
```

#### 4. 行内注释（必要时）

```dart
// 单行注释
void calculate() {
  // 初始化变量
  int count = 0;
  
  // 执行计算
  count = count + 1;
}
```

### Dart 代码风格

#### 文件结构

```dart
// 1. 导入语句
import 'package:flutter/material.dart';
import '../models/example.dart';

// 2. 常量定义
const int kDefaultValue = 10;

// 3. 类定义
class MyWidget extends StatelessWidget {
  // ...
}
```

#### 命名规范

| 类型 | 规范 | 示例 |
|------|------|------|
| 类/枚举 | PascalCase | `VideoFolder`, `VideoFolderType` |
| 方法/变量 | camelCase | `videoList`, `loadVideos()` |
| 常量 | k + PascalCase | `kDefaultDuration` |
| 私有成员 | _ + camelCase | `_internalState` |
| 文件名 | snake_case | `video_folder.dart` |

#### 类型使用

```dart
// ✅ 推荐：明确类型声明
final String name = 'example';
final List<VideoInfo> videos = [];

// ✅ 推荐：使用类型推断
var count = 0;
var isLoading = true;

// ❌ 避免：var 替代明确类型
var name = 'example'; // 如果需要 String，应明确声明
```

#### 空安全

```dart
// ✅ 推荐：安全调用
final length = list?.length ?? 0;

// ✅ 推荐：late 声明
late final String _name;

// ❌ 避免：双重空检查
if (value != null && value.isNotEmpty) {
  // ...
}
```

## 数据模型规范

### 实体类结构

```dart
class EntityName extends BaseEntity {
  // 1. 属性定义
  String name;
  int? optionalField;
  
  // 2. 构造函数
  EntityName({
    this.name = '',
    this.optionalField,
  });
  
  // 3. 表名
  @override
  String get tableName => 'table_name';
  
  // 4. toMap 方法
  @override
  Map<String, dynamic> toMap() {
    return {
      // 映射逻辑
    };
  }
  
  // 5. fromMap 方法
  @override
  BaseEntity fromMap(Map<String, dynamic> map) {
    // 映射逻辑
    return this;
  }
}
```

### 字段类型映射

| Dart 类型 | SQLite 类型 | 说明 |
|-----------|-------------|------|
| int | INTEGER | 整数 |
| double | REAL | 浮点数 |
| String | TEXT | 文本 |
| bool | INTEGER | 布尔（0/1） |
| DateTime | TEXT | ISO8601 |
| int? | INTEGER | 可空整数 |

### 时间字段规范

- **数据库存储**：使用 ISO8601 格式的字符串
- **时长字段**：视频相关使用毫秒，其他使用秒
- **显示转换**：使用 `DurationHelper` 进行格式化

## 状态管理规范

### Provider 命名

```dart
// Provider
final myProvider = Provider<MyService>((ref) {
  return MyService();
});

// StateNotifier
final myNotifierProvider = StateNotifierProvider<MyNotifier, MyState>((ref) {
  return MyNotifier();
});

// 状态
class MyState {
  final List<Item> items;
  final bool isLoading;
  final String? error;
  
  MyState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });
}
```

### 异步操作

```dart
Future<void> loadData() async {
  state = state.copyWith(isLoading: true);
  try {
    final data = await _service.fetchData();
    state = state.copyWith(
      items: data,
      isLoading: false,
    );
  } catch (e) {
    state = state.copyWith(
      isLoading: false,
      error: e.toString(),
    );
  }
}
```

## UI 组件规范

### 组件结构

```dart
class MyWidget extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;
  
  const MyWidget({
    super.key,
    required this.title,
    this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        // 样式
        child: Text(title),
      ),
    );
  }
}
```

### 尺寸规范

- 最小点击区域：48x48 dp
- 卡片圆角：16 dp
- 按钮圆角：8 dp
- 内边距：16 dp
- 组件间距：8 dp / 16 dp

### 颜色使用

| 用途 | 颜色 |
|------|------|
| 主色 | `#4ADE80` |
| 深色背景 | `#1F2937` |
| 浅色背景 | `#F3F4F6` |
| 文字主色 | `#FFFFFF` |
| 文字次色 | `#6B7280` |
| 成功 | `#10B981` |
| 错误 | `#EF4444` |

## 数据库规范

### 表命名

- 使用小写下划线命名
- 避免缩写
- 体现业务含义

### 索引设计

- 主键：`id` (INTEGER PRIMARY KEY)
- 业务主键：`code` (TEXT UNIQUE)
- 外键索引：自动创建
- 常用查询字段添加索引

### 查询规范

```dart
// ✅ 推荐：使用参数化查询
await DatabaseService.findByCondition(
  () => VideoInfo(),
  where: 'folder_code = ? AND is_deleted = 0',
  whereArgs: [folderCode],
  orderBy: 'play_date DESC',
);

// ✅ 推荐：分页查询
await DatabaseService.findByCondition(
  () => VideoInfo(),
  where: 'is_deleted = 0',
  limit: 20,
  offset: page * 20,
);
```

## 测试规范

### 单元测试

- 公共方法必须测试
- 边界条件必须覆盖
- 错误处理必须测试

### 集成测试

- 页面功能测试
- 数据库操作测试
- 服务层测试

## Git 提交规范

### 提交格式

```
<类型>: <描述>

[可选的详细说明]
```

### 类型

| 类型 | 说明 |
|------|------|
| feat | 新功能 |
| fix | 修复bug |
| docs | 文档更新 |
| style | 代码格式 |
| refactor | 重构 |
| test | 测试相关 |
| chore | 构建/工具 |

### 示例

```
feat: 添加视频播放功能

- 集成 better_player
- 实现播放进度保存
- 添加截图功能

Closes #123
```

## 文档维护

### 必须保持更新的文档

- `docs/README.md`: 项目整体说明
- `docs/DEVELOPMENT.md`: 开发规范
- 模型类的注释：字段说明和使用示例
- 服务类的注释：接口说明

### 文档审查

- PR 必须包含文档更新（如有必要）
- 重大功能必须更新文档
- 重构必须同步更新文档
