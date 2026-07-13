# TDesign Flutter 组件库知识库

> **版本**: v0.2.7 (本地定制版)
> **最后更新**: 2026-07-12
> **状态**: ✅ 已启用 - 项目唯一 UI 组件库
> **官方文档**: https://tdesign.tencent.com/flutter/getting-started

---

## 📋 目录

1. [核心原则](#核心原则)
2. [安装与引入](#安装与引入)
3. [组件分类总览](#组件分类总览)
4. [基础组件](#基础组件)
5. [导航组件](#导航组件)
6. [输入组件](#输入组件)
7. [数据展示组件](#数据展示组件)
8. [反馈组件（重点）](#反馈组件重点)
9. [主题系统](#主题系统)
10. [项目使用规范](#项目使用规范)
11. [常见问题与最佳实践](#常见问题与最佳实践)

---

## 核心原则

### ⚠️ 强制规范

> **TDesign 是本项目唯一的 UI 组件库**，所有弹窗、抽屉、提示、选择、按钮等 UI 组件必须统一使用 TDesign。

**禁止行为**:
- ❌ 使用原生 `showDialog` + `AlertDialog`（应使用 `TDDialog`）
- ❌ 使用原生 `ScaffoldMessenger` + `SnackBar`（应使用 `TDToast` 或 `TDMessage`）
- ❌ 使用原生 `ElevatedButton` / `TextButton`（应使用 `TDButton`）
- ❌ 使用原生 `CircularProgressIndicator`（应使用 `TDLoading`）
- ❌ 使用第三方 UI 库（如 `cupertino_icons`、`fluttertoast` 等）

**正确示例**:
```dart
// ✅ 正确：使用 TDesign 组件
import 'package:tdesign_flutter/tdesign_flutter.dart';

// 按钮
TDButton(
  text: '确认',
  type: TDButtonType.fill,
  theme: TDButtonTheme.primary,
  onTap: () {},
);

// Toast 提示
TDToast.showText('操作成功', context: context);

// Dialog 弹窗
TDDialog(
  title: '提示',
  content: '确定删除该文件？',
  actions: [
    TDDialogButtonOptions(title: '取消', action: () => Navigator.pop(context)),
    TDDialogButtonOptions(title: '确定', action: _confirmDelete),
  ],
);
```

---

## 安装与引入

### 依赖配置

```yaml
# pubspec.yaml (本地路径引用)
dependencies:
  tdesign_flutter:
    path: plugs/tdesign_flutter
```

### 统一引入方式

```dart
// 所有页面/组件统一使用此导入
import 'package:tdesign_flutter/tdesign_flutter.dart';
```

**一次性导出内容**:
- 所有组件（Button、Dialog、Toast、Loading 等）
- 主题系统（TDTheme、TDColors、TDIcons）
- 工具类（context 扩展等）

---

## 组件分类总览

### 🎯 按使用频率分级（项目视角）

| 频率 | 组件 | 应用场景 |
|------|------|----------|
| 🔴 高频 | `TDButton` | 所有按钮交互 |
| 🔴 高频 | `TDToast` | 轻量操作反馈 |
| 🔴 高频 | `TDDialog` | 确认/输入弹窗 |
| 🔴 高频 | `TDLoading` | 加载状态 |
| 🔴 高频 | `TDActionSheet` | 底部动作面板 |
| 🟡 中频 | `TDNavBar` | 页面导航栏 |
| 🟡 中频 | `TDSearchBar` | 搜索框 |
| 🟡 中频 | `TDCell` / `TDCellGroup` | 列表项 |
| 🟡 中频 | `TDEmpty` | 空状态占位 |
| 🟡 中频 | `TDSkeleton` | 骨架屏 |
| 🟢 低频 | `TDDrawer` | 侧边抽屉 |
| 🟢 低频 | `TDPopup` | 弹出层 |
| 🟢 低频 | `TDSwiper` | 轮播图 |
| 🟢 低频 | `TDMessage` | 全局消息通知 |

---

## 基础组件

### 1. TDButton（按钮）⭐⭐⭐

**唯一按钮组件**，替代所有原生和第三方按钮。

#### 尺寸规格

```dart
enum TDButtonSize {
  large,      // 大按钮（48px 高度）- 用于主要操作
  medium,     // 中等按钮（40px 高度）- 默认尺寸
  small,      // 小按钮（32px 高度）- 用于紧凑场景
  extraSmall  // 迷你按钮（24px 高度）- 用于标签式按钮
}
```

#### 类型变体

```dart
enum TDButtonType {
  fill,    // 实心填充（默认）
  outline, // 描边按钮
  text,    // 文字按钮
  ghost,   // 幽灵按钮（浅色背景）
}
```

#### 形状选项

```dart
enum TDButtonShape {
  rectangle, // 矩形（默认，小圆角）
  round,     // 圆角矩形（胶囊形）
  square,    // 方形（无圆角）
  circle,    // 圆形
  filled,    // 填充形
}
```

#### 主题色

```dart
enum TDButtonTheme {
  defaultTheme, // 默认（灰色系）
  primary,      // 主色（品牌蓝）
  danger,       // 危险（红色）
  light,        // 浅色
}
```

#### 使用示例

```dart
// 1️⃣ 主要操作按钮（提交表单、确认操作）
TDButton(
  text: '确认购买',
  size: TDButtonSize.large,
  type: TDButtonType.fill,
  theme: TDButtonTheme.primary,
  isBlock: true,  // 通栏按钮
  onTap: _handlePurchase,
)

// 2️⃣ 危险操作按钮（删除、取消订阅）
TDButton(
  text: '删除',
  size: TDButtonSize.small,
  type: TDButtonType.text,
  theme: TDButtonTheme.danger,
  onTap: _handleDelete,
)

// 3️⃣ 次要操作按钮（取消、返回）
TDButton(
  text: '取消',
  size: TDButtonSize.medium,
  type: TDButtonType.outline,
  onTap: () => Navigator.pop(context),
)

// 4️⃣ 图标按钮
TDButton(
  icon: TDIcons.add,
  text: '新建文件夹',
  size: TDButtonSize.medium,
  type: TDButtonType.fill,
  onTap: _createFolder,
)

// 5️⃣ 禁用状态
TDButton(
  text: '保存',
  disabled: true,  // 禁用点击
  onTap: null,
)

// 6️⃣ 渐变背景按钮
TDButton(
  text: 'VIP 会员',
  size: TDButtonSize.large,
  gradient: LinearGradient(
    colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
  ),
  onTap: _openVipPage,
)
```

#### 项目约定

```dart
// ✅ 推荐的按钮命名模式
class AppButtons {
  // 主要操作
  static Widget primary({
    required String text,
    required VoidCallback onTap,
    bool isBlock = false,
  }) => TDButton(
    text: text,
    size: TDButtonSize.large,
    type: TDButtonType.fill,
    theme: TDButtonTheme.primary,
    isBlock: isBlock,
    onTap: onTap,
  );

  // 危险操作
  static Widget danger({
    required String text,
    required VoidCallback onTap,
  }) => TDButton(
    text: text,
    size: TDButtonSize.small,
    type: TDButtonType.text,
    theme: TDButtonTheme.danger,
    onTap: onTap,
  );

  // 文本按钮
  static Widget text({
    required String text,
    required VoidCallback onTap,
  }) => TDButton(
    text: text,
    size: TDButtonSize.medium,
    type: TDButtonType.text,
    onTap: onTap,
  );
}
```

---

### 2. TDText（文本）

统一的文本样式组件，支持主题色自动适配。

```dart
TDText(
  '标题文本',
  font: TDTheme.of(context).fontTitleLarge,
  color: TDTheme.of(context).fontGyColor1,
)

// 常用字体预设
TDTheme.of(context).fontBodyLarge   // 正文大
TDTheme.of(context).fontBodyMedium  // 正文中等（默认）
TDTheme.of(context).fontBodySmall   // 正文小
TDTheme.of(context).fontTitleLarge  // 标题大
TDTheme.of(context).fontTitleMedium // 标题中
TDTheme.of(context).fontHeadline    // 大标题
TDTheme.of(context).fontCaption     // 说明文字
```

---

### 3. TDIcon（图标）

TDesign 内置图标库（TTF 格式），不跟随主题切换。

```dart
// 使用内置图标
Icon(TDIcons.activity)       // 活动
Icon(TDIcons.add)            // 添加
Icon(TDIcons.close)          // 关闭
Icon(TDIcons.delete)         // 删除
Icon(TDIcons.edit)           // 编辑
Icon(TDIcons.search)         // 搜索
Icon(TDIcons.settings)       // 设置
Icon(TDIcons.user)           // 用户
Icon(TDIcons.home)           // 首页
Icon(TDIcons.chevron_left)   // 左箭头
Icon(TDIcons.chevron_right)  // 右箭头

// 自定义图标（优先使用项目 AppIcons）
Icon(AppIcons.customIcon)    // 项目自定义图标
```

**查看完整图标列表**: 
[TDIcons 定义文件](../../../plugs/tdesign_flutter/lib/src/components/icon/td_icons.dart)

---

## 导航组件

### 4. TDNavBar（导航栏）

替代原生 `AppBar`，提供更灵活的导航体验。

```dart
TDNavBar(
  title: '资源管理',
  titleFontWeight: FontWeight.w600,
  leftWidget: IconButton(
    icon: Icon(TDIcons.chevron_left),
    onPressed: () => Navigator.pop(context),
  ),
  rightWidget: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(icon: Icon(TDIcons.search), onPressed: _search),
      IconButton(icon: Icon(TDIcons.more), onPressed: _showMore),
    ],
  ),
  backgroundColor: Colors.white,
  elevation: 0.5,
)

// 仅标题模式（用于二级页面）
TDNavBar(
  title: '文件夹详情',
  useDefaultBack: true,  // 自动添加返回按钮
)
```

### 5. TDTabs（选项卡）

```dart
TDTabs(
  tabs: const [
    TdTab(text: '视频'),
    TdTab(text: '音频'),
    TdTab(text: '文章'),
  ],
  currentIndex: _currentTab,
  onChanged: (index) => setState(() => _currentTab = index),
  controller: _tabController,
)
```

### 6. TDDrawer（抽屉）

```dart
TDDrawer(
  visible: _drawerVisible,
  child: Container(
    width: MediaQuery.of(context).size.width * 0.8,
    color: Colors.white,
    child: _buildDrawerContent(),
  ),
  onClose: () => setState(() => _drawerVisible = false),
)
```

---

## 输入组件

### 7. TDInput（输入框）

```dart
TDInput(
  controller: _controller,
  hintText: '请输入文件夹名称',
  prefixIcon: Icon(TDIcons.search),
  clearable: true,  // 显示清除按钮
  onChanged: (value) => _onSearchChanged(value),
  onSubmitted: (value) => _onSearchSubmit(value),
)

// 必填项标记
TDInput(
  controller: _controller,
  hintText: '请输入用户名',
  requiredMark: true,  // 显示红色星号
)
```

### 8. TDSearchBar（搜索栏）

```dart
TDSearchBar(
  controller: _searchController,
  autoFocus: false,
  placeHolder: '搜索视频、音频、文章...',
  onSubmitted: (value) {
    _performSearch(value);
  },
)
```

### 9. TDCheckBox / TDRadio（多选/单选）

```dart
// 多选框
TDCheckBox(
  checked: _isChecked,
  title: '同意用户协议',
  onChanged: (checked) => setState(() => _isChecked = checked ?? false),
)

// 单选框组
TDRadioGroup(
  value: _selectedOption,
  onChanged: (value) => setState(() => _selectedOption = value),
  children: [
    TDRadio(value: 'option1', text: '选项一'),
    TDRadio(value: 'option2', text: '选项二'),
    TDRadio(value: 'option3', text: '选项三'),
  ],
)
```

### 10. TDSwitch（开关）

```dart
TDSwitch(
  value: _isDarkMode,
  onChanged: (value) => setState(() => _isDarkMode = value ?? false),
)
```

---

## 数据展示组件

### 11. TDCell / TDCellGroup（单元格）

**列表项的标准容器**，用于设置页、信息展示等场景。

```dart
TDCellGroup(
  children: [
    // 基础单元格
    TDCell(
      title: '用户名',
      note: 'John Doe',
      arrowType: TDArrowType.rightArrow,  // 右箭头
      onClick: () => _editUsername(),
    ),

    // 带描述的单元格
    TDCell(
      title: '手机号',
      note: '138****8888',
      description: '已绑定，可用于登录和找回密码',
      arrowType: TDArrowType.rightArrow,
      onClick: () => _changePhone(),
    ),

    // 开关单元格
    TDCell(
      title: '消息推送',
      rightWidget: TDSwitch(
        value: _pushEnabled,
        onChanged: (v) => setState(() => _pushEnabled = v ?? false),
      ),
    ),

    // 带图标的单元格
    TDCell(
      title: '我的收藏',
      leftWidget: Icon(TDIcons.star, color: Colors.orange),
      arrowType: TDArrowType.rightArrow,
      onClick: () => _openFavorites(),
    ),
  ],
)
```

### 12. TDEmpty（空状态）

```dart
TDEmpty(
  emptyIcon: Icon(TDIcons.file, size: 80),
  title: '暂无文件',
  description: '快去导入你的第一个视频吧',
  action: TDButton(
    text: '立即导入',
    size: TDButtonSize.medium,
    type: TDButtonType.fill,
    theme: TDButtonTheme.primary,
    onTap: _importFile,
  ),
)
```

### 13. TDSkeleton（骨架屏）

```dart
// 列表骨架屏
TDSkeleton(
  skeletonType: TDSkeletonType.rectangle,
  borderRadius: BorderRadius.circular(8),
  height: 120,
)

// 复杂卡片骨架
Column(
  children: [
    TDSkeleton(skeletonType: TDSkeletonType.circle, radius: 30),
    SizedBox(height: 12),
    TDSkeleton(skeletonType: TDSkeletonType.rectangle, height: 16, width: 120),
    SizedBox(height: 8),
    TDSkeleton(skeletonType: TDSkeletonType.rectangle, height: 14, width: 200),
  ],
)
```

### 14. 其他数据展示组件

```dart
// 徽标（未读数等）
TDBadge(
  count: 99,
  child: Icon(TDIcons.notification),
)

// 标签
TDTag(
  text: 'VIP',
  theme: TDTagTheme.primary,
  size: TDTagSize.small,
)

// 进度条
TDProgress(
  percentage: 75,
  color: TDTheme.of(context).brandNormalColor,
)

// 折叠面板
TDCollapse(
  panels: [
    TDCollapsePanel(
      header: '高级设置',
      content: _buildAdvancedSettings(),
    ),
  ],
)
```

---

## 反馈组件（重点）

### 15. TDToast（轻提示）⭐⭐⭐

**最常用的反馈组件**，用于操作结果的即时提示。

#### 使用方法

```dart
// 1️⃣ 文本提示（最常用）
TDToast.showText('操作成功', context: context);
TDToast.showText('网络错误，请重试', context: context);

// 2️⃣ 成功图标
TDToast.showSuccess('保存成功', context: context);

// 3️⃣ 警告图标
TDToast.showWarning('余额不足', context: context);

// 4️⃣ 错误图标
TDToast.showError('加载失败', context: context);

// 5️⃣ 加载提示（带进度）
TDToast.showLoading('正在上传...', context: context);

// 6️⃣ 自定义时长（默认 2 秒）
TDToast.showText(
  '此提示将显示 3 秒',
  context: context,
  duration: Duration(seconds: 3),
);

// 7️⃣ 自定义位置
TDToast.showText(
  '顶部提示',
  context: context,
  alignment: Alignment.topCenter,
);
```

#### 项目封装建议

```dart
// lib/utils/toast_utils.dart
class AppToast {
  /// 显示成功提示
  static success(String message, {required BuildContext context}) {
    TDToast.showSuccess(message, context: context);
  }

  /// 显示错误提示
  static error(String message, {required BuildContext context}) {
    TDToast.showError(message, context: context);
  }

  /// 显示警告提示
  static warning(String message, {required BuildContext context}) {
    TDToast.showWarning(message, context: context);
  }

  /// 显示普通文本
  static info(String message, {required BuildContext context}) {
    TDToast.showText(message, context: context);
  }

  /// 显示加载中
  static loading(String message, {required BuildContext context}) {
    TDToast.showLoading(message, context: context);
  }
}

// 使用示例
AppToast.success('保存成功', context: context);
AppToast.error('网络异常', context: context);
```

---

### 16. TDDialog（对话框）⭐⭐⭐

**标准弹窗组件**，支持多种类型。

#### 16.1 确认对话框（Alert）

```dart
TDDialog(
  title: '确认删除',
  content: '删除后无法恢复，确定要继续吗？',
  actions: [
    TDDialogButtonOptions(
      title: '取消',
      action: () => Navigator.pop(context),
    ),
    TDDialogButtonOptions(
      title: '删除',
      titleColor: TDTheme.of(context).errorNormalColor,
      theme: TDButtonTheme.danger,
      action: () {
        Navigator.pop(context);
        _executeDelete();
      },
    ),
  ],
);
```

#### 16.2 输入对话框（Input）

```dart
TDInputDialog(
  title: '新建文件夹',
  hintText: '请输入文件夹名称',
  confirm: (text) {
    if (text?.isNotEmpty == true) {
      _createFolder(text!);
      return true;  // 关闭对话框
    }
    return false;  // 不关闭，显示验证错误
  },
  cancel: () => Navigator.pop(context),
);
```

#### 16.3 图片预览对话框

```dart
TDImageDialog(
  imageUrl: 'https://example.com/image.jpg',
  onClose: () => Navigator.pop(context),
)
```

#### 16.4 自定义内容对话框

```dart
TDDialog(
  title: '会员权益',
  content: Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('✓ 无限次数 AI 查词'),
      Text('✓ 高清视频播放'),
      Text('✓ 云端同步'),
    ],
  ),
  actions: [
    TDDialogButtonOptions(
      title: '开通 VIP',
      theme: TDButtonTheme.primary,
      action: _purchaseVip,
    ),
    TDDialogButtonOptions(
      title: '以后再说',
      action: () => Navigator.pop(context),
    ),
  ],
)
```

#### 项目封装建议

```dart
// lib/widgets/app_dialogs.dart
class AppDialogs {
  /// 确认对话框
  static Future<bool?> confirm({
    required BuildContext context,
    required String title,
    String? content,
    String confirmText = '确定',
    String cancelText = '取消',
    bool isDanger = false,
  }) async {
    bool? result;
    await TDDialog(
      title: title,
      content: content,
      actions: [
        TDDialogButtonOptions(
          title: cancelText,
          action: () {
            Navigator.pop(context);
            result = false;
          },
        ),
        TDDialogButtonOptions(
          title: confirmText,
          titleColor: isDanger
              ? TDTheme.of(context).errorNormalColor
              : null,
          theme: isDanger ? TDButtonTheme.danger : null,
          action: () {
            Navigator.pop(context);
            result = true;
          },
        ),
      ],
    );
    return result;
  }

  /// 输入对话框
  static Future<String?> input({
    required BuildContext context,
    required String title,
    String? hintText,
    String? defaultValue,
  }) async {
    String? result;
    await TDInputDialog(
      title: title,
      hintText: hintText ?? '请输入...',
      confirm: (text) {
        if (text?.isNotEmpty == true) {
          result = text;
          return true;
        }
        return false;
      },
      cancel: () => Navigator.pop(context),
    );
    return result;
  }

  /// 成功提示对话框
  static success({
    required BuildContext context,
    required String title,
    String? content,
  }) {
    TDDialog(
      title: title,
      content: content,
      actions: [
        TDDialogButtonOptions(
          title: '我知道了',
          theme: TDButtonTheme.primary,
          action: () => Navigator.pop(context),
        ),
      ],
    );
  }
}

// 使用示例
final confirmed = await AppDialogs.confirm(
  context: context,
  title: '确认删除',
  content: '删除后无法恢复',
  isDanger: true,
);

if (confirmed == true) {
  _deleteItem();
}
```

---

### 17. TDActionSheet（动作面板）⭐⭐⭐

**底部弹出菜单**，用于从多个选项中选择一个操作。

```dart
// 基础用法
TDActionSheet(
  actions: [
    TDActionSheetItem(
      title: '拍照',
      onClick: () {
        Navigator.pop(context);
        _takePhoto();
      },
    ),
    TDActionSheetItem(
      title: '从相册选择',
      onClick: () {
        Navigator.pop(context);
        _pickFromGallery();
      },
    ),
  ],
  cancel: (
    title: '取消',
    action: () => Navigator.pop(context),
  ),
  showCancelButton: true,
)

// 带图标的高级用法
TDActionSheet(
  actions: [
    TDActionSheetItem(
      title: '编辑',
      prefixIcon: Icon(TDIcons.edit),
      onClick: _editItem,
    ),
    TDActionSheetItem(
      title: '分享',
      prefixIcon: Icon(TDIcons.share_nodes),
      onClick: _shareItem,
    ),
    TDActionSheetItem(
      title: '删除',
      prefixIcon: Icon(TDIcons.delete),
      textStyle: TextStyle(color: TDTheme.of(context).errorNormalColor),
      onClick: _deleteItem,
    ),
  ],
  showCancelButton: true,
)

// 网格布局（图片选择器风格）
TDActionSheet(
  gridItems: [
    TDActionSheetGridItem(
      icon: Icon(Icons.camera_alt),
      text: '拍摄',
      onClick: _takePhoto,
    ),
    TDActionSheetGridItem(
      icon: Icon(Icons.photo_library),
      text: '相册',
      onClick: _pickFromGallery,
    ),
    TDActionSheetGridItem(
      icon: Icon(Icons.file_copy),
      text: '文件',
      onClick: _pickFromFile,
    ),
  ],
  showCancelButton: true,
)
```

**实际应用场景**:

```dart
// 头像更换
void _changeAvatar() {
  showModalBottomSheet(
    context: context,
    builder: (ctx) => TDActionSheet(
      actions: [
        TDActionSheetItem(
          title: '拍照',
          onClick: () => _pickImage(ImageSource.camera),
        ),
        TDActionSheetItem(
          title: '从相册选择',
          onClick: () => _pickImage(ImageSource.gallery),
        ),
      ],
      showCancelButton: true,
    ),
  );
}

// 文件操作菜单
void _showFileMenu(VideoInfo file) {
  showModalBottomSheet(
    context: context,
    builder: (ctx) => TDActionSheet(
      actions: [
        TDActionSheetItem(title: '重命名', onClick: () => _rename(file)),
        TDActionSheetItem(title: '移动到...', onClick: () => _move(file)),
        TDActionSheetItem(title: '分享', onClick: () => _share(file)),
        TDActionSheetItem(
          title: '删除',
          textStyle: TextStyle(
            color: TDTheme.of(context).errorNormalColor,
          ),
          onClick: () => _delete(file),
        ),
      ],
      showCancelButton: true,
    ),
  );
}
```

---

### 18. TDLoading（加载指示器）⭐⭐

**全屏或局部加载状态**。

```dart
// 1️⃣ 全屏加载遮罩
TDLoading(
  size: TDLoadingSize.large,
  text: '正在加载...',
  containerColor: Colors.white.withOpacity(0.8),
  loadingType: TDLoadingType.circle,
)

// 2️⃣ 小型内联加载
TDLoading(
  size: TDLoadingSize.small,
  loadingType: TDLoadingType.circle,
)

// 3️⃣ 点状加载动画
TDLoading(
  size: TDLoadingSize.medium,
  loadingType: TDLoadingType.points,
)

// 4️⃣ 作为页面内容显示
Scaffold(
  body: Center(
    child: TDLoading(
      size: TDLoadingSize.large,
      text: '数据同步中...',
    ),
  ),
)
```

**结合 Riverpod 的加载状态管理**:

```dart
@override
Widget build(BuildContext context) {
  final state = ref.watch(fileProvider);

  // 加载中状态
  if (state.isLoading) {
    return Scaffold(
      body: Center(
        child: TDLoading(
          size: TDLoadingSize.large,
          text: '加载中...',
        ),
      ),
    );
  }

  // 正常内容
  return Scaffold(
    body: _buildContent(state.folders),
  );
}
```

---

### 19. TDMessage（全局消息通知）

**顶部横幅提示**，用于系统级通知（非操作反馈）。

```dart
// 成功消息
TDMessage.successMessage(
  context: context,
  content: '数据同步完成',
  duration: Duration(seconds: 3),
)

// 错误消息
TDMessage.errorMessage(
  context: context,
  content: '网络连接失败',
)

// 警告消息
TDMessage.warningMessage(
  context: context,
  content: '存储空间不足',
)

// 可关闭的消息
TDMessage.infoMessage(
  context: context,
  content: '新版本可用',
  closeBtn: '我知道了',
  onClose: () => _dismissUpdateNotice(),
)
```

**适用场景对比**:

| 场景 | 推荐组件 | 示例 |
|------|----------|------|
| 操作成功/失败 | `TDToast` | "保存成功" |
| 系统级通知 | `TDMessage` | "网络断开" |
| 需要用户确认 | `TDDialog` | "确定删除？" |
| 多选操作 | `TDActionSheet` | "拍照/相册" |
| 数据加载 | `TDLoading` | "加载中..." |

---

### 20. TDPopup（弹出层）

**通用弹出层**，可自定义位置和内容。

```dart
TDPopup(
  visible: _popupVisible,
  direction: TDPopupDirection.bottom,  // bottom/top/left/right
  child: Container(
    padding: EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(...)],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('弹出内容'),
        TDButton(text: '关闭', onTap: () => _popupVisible = false),
      ],
    ),
  ),
  onClose: () => _popupVisible = false,
)
```

---

### 21. 其他反馈组件

#### TDPullDownRefresh（下拉刷新）

```dart
TDPullDownRefresh(
  onRefresh: _refreshData,
  child: ListView.builder(
    itemCount: items.length,
    itemBuilder: (context, index) => _buildItem(items[index]),
  ),
)
```

#### TDSwipeCell（滑动操作）

```dart
TDSwipeCell(
  key: ValueKey(item.id),
  child: TDCell(title: item.name),
  actions: <SwipeAction>[
    SwipeAction(
      text: '编辑',
      foregroundColor: Colors.blue,
      onPressed: (_) => _edit(item),
    ),
    SwipeAction(
      text: '删除',
      foregroundColor: Colors.red,
      onPressed: (_) => _delete(item),
    ),
  ],
)
```

#### TDNoticeBar（消息提醒条）

```dart
TDNoticeBar(
  content: '系统维护通知：今晚 22:00-23:00 将进行升级',
  prefixIcon: Icon(TDIcons.info_circle_filled),
  marquee: true,  // 滚动显示
  onClose: _dismissNotice,
)
```

---

## 主题系统

### TDTheme（主题访问）

**获取主题数据的两种方式**:

```dart
// ✅ 推荐：响应式主题（随父级主题变化）
TDTheme.of(context).brandNormalColor
TDTheme.of(context).fontBodyLarge
TDTheme.of(context).errorNormalColor

// ⚠️ 仅用于不跟随局部主题的静态组件
TDTheme.defaultData().brandNormalColor
```

### TDColors（颜色系统）

#### 功能色组

```dart
// 品牌色（10 级梯度）
TDTheme.of(context).brandLightColor    // #F2F3FF 最浅
TDTheme.of(context).brandFocusColor    // #D9E1FF 聚焦
TDTheme.of(context).brandDisabledColor // #B5C7FF 禁用
TDTheme.of(context).brandHoverColor    // #366EF4 悬停
TDTheme.of(context).brandNormalColor   // #0052D9 主色 ⭐
TDTheme.of(context).brandClickColor    // #003CAB 点击

// 错误色
TDTheme.of(context).errorNormalColor   // #D54941 ⭐

// 警告色
TDTheme.of(context).warningNormalColor // #BE5A00 ⭐

// 成功色
TDTheme.of(context).successNormalColor // #2BA471 ⭐
```

#### 字体色（灰度）

```dart
TDTheme.of(context).fontGyColor1  // 主要文字（标题）
TDTheme.of(context).fontGyColor2  // 次要文字（正文）
TDTheme.of(context).fontGyColor3  // 辅助文字（说明）
TDTheme.of(context).fontWhColor1  // 白色文字（深色背景上）
```

#### 背景色

```dart
TDTheme.of(context).bgColorWhite         // 白色背景
TDTheme.of(context).bgColorSpecialnormal // 特殊背景
TDTheme.of(context).bgColorComponent     // 组件背景
```

### 自定义主题（可选）

如果需要修改品牌色或其他设计 token：

```dart
// 方式 1：JSON 配置（简单场景）
String themeConfig = '''
{
  "myTheme": {
    "color": {
      "brandNormalColor": "#D7B386"
    }
  }
}
''';

MaterialApp(
  theme: ThemeData(
    extensions: [TDThemeData.fromJson('myTheme', themeConfig)!],
  ),
);

// 方式 2：主题生成器（推荐，完整定制）
// 1. 访问 https://tdesign.tencent.com/vue/custom-theme
// 2. 选择颜色，下载 theme.css
// 3. 转换为 theme.json
// 4. 引入应用
var jsonString = await rootBundle.loadString('assets/theme.json');
var _themeData = TDThemeData.fromJson('custom', jsonString);

MaterialApp(
  theme: ThemeData(extensions: [_themeData]),
);
```

---

## 项目使用规范

### 规范清单

#### ✅ 必须使用 TDesign 的场景

| UI 元素 | TDesign 组件 | 备注 |
|---------|-------------|------|
| 所有按钮 | `TDButton` | 包括主次、危险、文字按钮 |
| 弹窗确认 | `TDDialog` | 禁止原生 AlertDialog |
| 底部菜单 | `TDActionSheet` | 禁止自定义 BottomSheet |
| 轻提示 | `TDToast` | 禁止 fluttertoast 等 |
| 加载状态 | `TDLoading` | 禁止 CircularProgressIndicator |
| 导航栏 | `TDNavBar` | 替代 AppBar |
| 输入框 | `TDInput` / `TDSearchBar` | 统一样式 |
| 列表项 | `TDCell` / `TDCellGroup` | 设置页等 |
| 空状态 | `TDEmpty` | 统一空态设计 |
| 骨架屏 | `TDSkeleton` | 加载占位 |
| 消息通知 | `TDMessage` | 系统级通知 |
| 下拉刷新 | `TDPullDownRefresh` | 列表刷新 |
| 滑动操作 | `TDSwipeCell` | 左滑菜单 |

#### ❌ 禁止使用的原生/第三方组件

```dart
// ❌ 禁止
AlertDialog()              // → 用 TDDialog
ElevatedButton()           // → 用 TDButton
TextButton()               // → 用 TDButton(type: text)
SnackBar()                 // → 用 TDToast
CircularProgressIndicator() // → 用 TDLoading
showDialog()               // → 用 TDDialog
CupertinoAlertDialog()     // → 用 TDDialog
Fluttertoast.showToast()   // → 用 TDToast
```

#### 📝 代码模板

**标准页面结构**:

```dart
class ExamplePage extends ConsumerStatefulWidget {
  const ExamplePage({super.key});

  @override
  ConsumerState<ExamplePage> createState() => _ExamplePageState();
}

class _ExamplePageState extends ConsumerState<ExamplePage> {
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Scaffold(
      backgroundColor: AppColors.getSurfaceHighest(brightness: brightness),

      // ✅ 使用 TDNavBar
      appBar: TDNavBar(
        title: '页面标题',
        useDefaultBack: true,
      ),

      // ✅ 根据 Riverpod 状态渲染
      body: _buildBody(),

      // ✅ 使用 TDActionButton（如有浮动按钮）
      floatingActionButton: TDButton(
        icon: TDIcons.add,
        shape: TDButtonShape.circle,
        theme: TDButtonTheme.primary,
        onTap: _addAction,
      ),
    );
  }

  Widget _buildBody() {
    final state = ref.watch(exampleProvider);

    if (state.isLoading) {
      // ✅ 使用 TDLoading
      return Center(child: TDLoading(size: TDLoadingSize.large));
    }

    if (state.error != null) {
      // ✅ 使用 ErrorDisplayWidget（内部已集成 TDesign 主题色）
      return ErrorDisplayWidget(
        error: state.error!,
        onRetry: ref.read(exampleProvider.notifier).loadData,
      );
    }

    if (state.items.isEmpty) {
      // ✅ 使用 TDEmpty
      return Center(
        child: TDEmpty(
          emptyIcon: Icon(TDIcons.file, size: 80),
          title: '暂无数据',
        ),
      );
    }

    // ✅ 使用 TDPullDownRefresh 包裹列表
    return TDPullDownRefresh(
      onRefresh: ref.read(exampleProvider.notifier).refresh,
      child: ListView.builder(
        itemCount: state.items.length,
        itemBuilder: (context, index) => _buildItem(state.items[index]),
      ),
    );
  }

  Widget _buildItem(ItemModel item) {
    // ✅ 使用 TDSwipeCell 包裹卡片
    return TDSwipeCell(
      key: ValueKey(item.id),
      actions: [
        SwipeAction(
          text: '删除',
          foregroundColor: TDTheme.of(context).errorNormalColor,
          onPressed: (_) => _deleteItem(item),
        ),
      ],
      child: _buildCard(item),
    );
  }
}
```

---

## 常见问题与最佳实践

### Q1: 如何处理 Dialog 的异步操作？

```dart
// ✅ 正确：在回调中处理异步逻辑
TDDialog(
  title: '确认',
  content: '确定删除吗？',
  actions: [
    TDDialogButtonOptions(
      title: '确定',
      action: () async {
        Navigator.pop(context);  // 先关闭弹窗
        await _delete();         // 再执行异步操作
        TDToast.showText('删除成功', context: context);
      },
    ),
  ],
)
```

### Q2: Toast 在异步操作后如何显示？

```dart
// ✅ 确保 context 仍然有效
void _saveData() async {
  final messenger = ScaffoldMessenger.of(context);

  try {
    await service.save();
    
    // ✅ 检查 mounted
    if (mounted) {
      TDToast.showText('保存成功', context: context);
    }
  } catch (e) {
    if (mounted) {
      TDToast.showError('保存失败: $e', context: context);
    }
  }
}
```

### Q3: 如何自定义 ActionSheet 的危险操作样式？

```dart
TDActionSheet(
  actions: [
    TDActionSheetItem(
      title: '删除',
      // ✅ 使用主题色标记危险操作
      textStyle: TextStyle(
        color: TDTheme.of(context).errorNormalColor,
        fontWeight: FontWeight.w600,
      ),
      onClick: _delete,
    ),
  ],
)
```

### Q4: Loading 状态如何与 Riverpod 配合？

```dart
// Provider 中定义状态
class ExampleNotifier extends StateNotifier<ExampleState> {
  ExampleNotifier() : super(const ExampleState());

  Future<void> loadData() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final data = await service.fetch();
      state = state.copyWith(isLoading: false, items: data);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

// UI 层根据状态渲染
@override
Widget build(BuildContext context) {
  final state = ref.watch(exampleProvider);

  return state.isLoading
      ? Center(child: TDLoading(size: TDLoadingSize.large))
      : _buildContent(state);
}
```

### Q5: 如何实现主题切换？

```dart
// 1. 开启多主题功能
TDTheme.needMultiTheme();

// 2. MaterialApp 配置
MaterialApp(
  theme: _lightTheme.systemThemeDataLight,
  darkTheme: _darkTheme.systemThemeDataDark,
  themeMode: ThemeMode.system,  // 或通过 Provider 控制
);

// 3. 通过 Riverpod 切换
final themeMode = ref.watch(themeProvider);
// 更新 themeMode 即可触发全局主题切换
```

---

## 📚 相关文档

- [TDesign 官方文档](https://tdesign.tencent.com/flutter/getting-started)
- [TDesign 组件 API 参考](https://github.com/Tencent/tdesign-flutter/tree/main/tdesign-component/lib/src/components)
- [项目主题系统](./theme-system.md)（待创建）
- [项目全局规则](../../PROJECT_RULES.md)
- [代码知识库索引](./CODE_KNOWLEDGE_BASE.md)

---

## 🔄 版本历史

| 版本 | 日期 | 变更内容 | 作者 |
|------|------|----------|------|
| v1.0.0 | 2026-07-12 | 初版建立，完整组件分类与使用规范 | AI Assistant |

---

## ✅ 检查清单（后续彻查时使用）

- [ ] 所有页面按钮已替换为 `TDButton`
- [ ] 所有弹窗已替换为 `TDDialog`
- [ ] 所有轻提示已替换为 `TDToast`
- [ ] 所有加载状态已替换为 `TDLoading`
- [ ] 所有底部菜单已替换为 `TDActionSheet`
- [ ] 所有导航栏已替换为 `TDNavBar`
- [ ] 所有空状态已替换为 `TDEmpty`
- [ ] 所有输入框已替换为 `TDInput` / `TDSearchBar`
- [ ] 所有列表项已使用 `TDCell` / `TDCellGroup`
- [ ] 无原生 `AlertDialog` / `ElevatedButton` / `SnackBar` 残留
- [ ] 无第三方 UI 库依赖（除 TDesign 外）
- [ ] 所有颜色值均来自 `TDTheme.of(context)`
- [ ] 所有字体大小均来自 `TDTheme.of(context).font*`
