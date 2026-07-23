# Skill: 新增模块

> **版本**: V1.0 | **日期**: 2026-07-12
> **触发条件**: 当用户要求新增功能模块时

---

## 一、工作流

### 1.1 规划阶段

- [ ] 1. 理解用户需求，明确模块功能
- [ ] 2. 查阅相关知识库文档
- [ ] 3. 设计数据模型
- [ ] 4. 设计 API 接口（如需要）
- [ ] 5. 制定实施计划

### 1.2 实现阶段

- [ ] 1. 创建数据模型（继承 BaseEntity）
- [ ] 2. 注册实体到 DatabaseService
- [ ] 3. 创建服务类（使用构造函数注入，便于 mock）
- [ ] 4. 创建状态管理（Riverpod）
- [ ] 5. 创建页面和组件
- [ ] 6. 编写对应测试（模型/服务/Provider/Widget）
- [ ] 7. 更新文档

### 1.3 验证阶段

- [ ] 1. 运行全部测试：`dart run flutter test`
- [ ] 2. 检查代码规范：`dart analyze`
- [ ] 3. 验证测试覆盖新增代码路径
- [ ] 4. 更新知识库
- [ ] 5. 提交代码

---

## 二、检查清单

### 2.1 数据模型

- [ ] 模型继承 BaseEntity
- [ ] 实现 tableName getter
- [ ] 实现 toMap() 方法
- [ ] 实现 fromMap() 方法
- [ ] 字段命名符合规范（snake_case）

### 2.2 服务层

- [ ] 服务类有完整文档注释
- [ ] 异步方法处理异常
- [ ] 数据库操作使用参数化查询
- [ ] 文件操作有权限检查

### 2.3 状态管理

- [ ] 使用 Riverpod StateNotifierProvider
- [ ] State 类定义完整
- [ ] Notifier 类实现完整
- [ ] Provider 定义正确

### 2.4 页面

- [ ] 页面有完整文档注释
- [ ] 使用 const 构造函数
- [ ] 支持主题适配
- [ ] 最小点击区域 48×48 dp

### 2.5 文档

- [ ] 更新 AGENTS.md 目录结构
- [ ] 更新 AGENT_CONTEXT.md
- [ ] 更新知识库文档
- [ ] 提交 Commit

---

## 三、知识库加载

### 3.1 自动加载

- `overall-architecture.md` - 整体架构
- `flutter-code-structure.md` - 代码结构

### 3.2 按需加载

- `database-design.md` - 数据库设计（当修改数据模型时）
- `services-architecture.md` - 服务架构（当创建服务时）
- `models-design.md` - 数据模型设计（当创建模型时）

---

## 四、输出格式

### 4.1 代码输出

```dart
// 1. 数据模型
class NewModel extends BaseEntity {
  // 字段定义
  
  @override
  String get tableName => 'new_model';
  
  @override
  Map<String, dynamic> toMap() {
    // 实现
  }
  
  @override
  BaseEntity fromMap(Map<String, dynamic> map) {
    // 实现
  }
}

// 2. 服务类
class NewService {
  // 服务实现
}

// 3. 状态管理
class NewState {
  // 状态定义
}

class NewNotifier extends StateNotifier<NewState> {
  // Notifier 实现
}

final newProvider = StateNotifierProvider<NewNotifier, NewState>((ref) {
  // Provider 定义
});

// 4. 页面
class NewPage extends StatefulWidget {
  // 页面实现
}
```

### 4.2 文档输出

```markdown
# 新模块说明

## 功能概述
[功能描述]

## 数据模型
[模型说明]

## API 接口
[接口说明]

## 使用说明
[使用方法]
```

---

## 五、注意事项

1. **遵循规范**：所有代码必须遵循项目规范
2. **文档完整**：所有代码必须有完整注释
3. **测试覆盖**：核心功能必须有测试
4. **知识库同步**：代码变更必须同步更新知识库

---

**文档版本**：V1.0
**创建时间**：2026-07-12
