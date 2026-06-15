# VidLang

Learning languages through videos

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Supabase 常用命令

### 初始化/登录/关联项目

```bash
supabase --version
supabase login
supabase link --project-ref <PROJECT_REF>
```

### 数据库迁移（推送到远端）

```bash
supabase db push
```

### 部署 Edge Functions

```bash
supabase functions deploy ai-proxy
supabase functions deploy ai-conversation
```

### 配置 Secrets（Edge Functions 环境变量）

```bash
supabase secrets set qwen_api_key=<YOUR_KEY>
supabase secrets set qwen_base_url=https://dashscope.aliyuncs.com/compatible-mode/v1
```

### 查看函数日志

```bash
supabase functions logs ai-proxy
supabase functions logs ai-conversation
```

## 备注：Deno 类型报错

Supabase Edge Functions 使用 Deno 运行时，部分 IDE/TS 诊断会提示 “找不到名称 Deno / 找不到 https://esm.sh 模块类型”。
这不影响线上运行；如果需要快速消除本地诊断，可在对应函数文件顶部加 `// @ts-nocheck`。


#生成图标
dart run flutter_launcher_icons