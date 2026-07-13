# API 设计模板

> **版本**: V1.0 | **日期**: YYYY-MM-DD
> **状态**: 草稿/评审中/已批准

---

## 一、API 概述

### 1.1 API 基础信息

```yaml
openapi: 3.1.0
info:
  title: VidLang API
  version: 1.0.0
  description: VidLang 语言学习应用 API
```

### 1.2 认证方式

```yaml
components:
  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT
```

---

## 二、接口定义

### 2.1 视频相关接口

#### 获取视频列表

```yaml
/api/v1/videos:
  get:
    summary: 获取视频列表
    description: 获取指定文件夹下的视频列表
    tags:
      - videos
    security:
      - bearerAuth: []
    parameters:
      - name: folder_id
        in: query
        required: true
        schema:
          type: string
        description: 文件夹 ID
      - name: page
        in: query
        required: false
        schema:
          type: integer
          default: 1
        description: 页码
      - name: limit
        in: query
        required: false
        schema:
          type: integer
          default: 20
        description: 每页数量
    responses:
      '200':
        description: 成功
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/VideoListResponse'
      '401':
        $ref: '#/components/responses/Unauthorized'
      '404':
        $ref: '#/components/responses/NotFound'
```

#### 获取视频详情

```yaml
/api/v1/videos/{id}:
  get:
    summary: 获取视频详情
    description: 获取指定视频的详细信息
    tags:
      - videos
    security:
      - bearerAuth: []
    parameters:
      - name: id
        in: path
        required: true
        schema:
          type: string
        description: 视频 ID
    responses:
      '200':
        description: 成功
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/VideoResponse'
      '401':
        $ref: '#/components/responses/Unauthorized'
      '404':
        $ref: '#/components/responses/NotFound'
```

### 2.2 字幕相关接口

#### 获取字幕列表

```yaml
/api/v1/videos/{video_id}/subtitles:
  get:
    summary: 获取字幕列表
    description: 获取指定视频的字幕列表
    tags:
      - subtitles
    security:
      - bearerAuth: []
    parameters:
      - name: video_id
        in: path
        required: true
        schema:
          type: string
        description: 视频 ID
    responses:
      '200':
        description: 成功
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/SubtitleListResponse'
      '401':
        $ref: '#/components/responses/Unauthorized'
      '404':
        $ref: '#/components/responses/NotFound'
```

### 2.3 AI 查询接口

#### AI 问答

```yaml
/api/v1/ai/query:
  post:
    summary: AI 问答
    description: 向 AI 提问
    tags:
      - ai
    security:
      - bearerAuth: []
    requestBody:
      required: true
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/AiQueryRequest'
    responses:
      '200':
        description: 成功
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/AiQueryResponse'
      '401':
        $ref: '#/components/responses/Unauthorized'
      '429':
        $ref: '#/components/responses/RateLimitExceeded'
```

---

## 三、数据模型

### 3.1 请求模型

```yaml
components:
  schemas:
    # 视频列表请求
    VideoListRequest:
      type: object
      required:
        - folder_id
      properties:
        folder_id:
          type: string
          description: 文件夹 ID
        page:
          type: integer
          default: 1
          description: 页码
        limit:
          type: integer
          default: 20
          description: 每页数量
          
    # AI 查询请求
    AiQueryRequest:
      type: object
      required:
        - question
      properties:
        question:
          type: string
          description: 问题
        context:
          type: string
          description: 上下文
        video_id:
          type: string
          description: 视频 ID（可选）
```

### 3.2 响应模型

```yaml
components:
  schemas:
    # 视频列表响应
    VideoListResponse:
      type: object
      properties:
        success:
          type: boolean
          description: 是否成功
        data:
          type: array
          items:
            $ref: '#/components/schemas/Video'
          description: 视频列表
        pagination:
          $ref: '#/components/schemas/Pagination'
          
    # 视频详情响应
    VideoResponse:
      type: object
      properties:
        success:
          type: boolean
          description: 是否成功
        data:
          $ref: '#/components/schemas/Video'
          
    # 视频模型
    Video:
      type: object
      properties:
        id:
          type: string
          description: 视频 ID
        name:
          type: string
          description: 视频名称
        folder_id:
          type: string
          description: 文件夹 ID
        duration:
          type: integer
          description: 视频时长（毫秒）
        path:
          type: string
          description: 视频路径
        created_at:
          type: string
          format: date-time
          description: 创建时间
          
    # 字幕列表响应
    SubtitleListResponse:
      type: object
      properties:
        success:
          type: boolean
          description: 是否成功
        data:
          type: array
          items:
            $ref: '#/components/schemas/Subtitle'
          description: 字幕列表
          
    # 字幕模型
    Subtitle:
      type: object
      properties:
        id:
          type: string
          description: 字幕 ID
        video_id:
          type: string
          description: 视频 ID
        start_time:
          type: integer
          description: 开始时间（毫秒）
        end_time:
          type: integer
          description: 结束时间（毫秒）
        content:
          type: string
          description: 字幕内容
        translation:
          type: string
          description: 翻译
          
    # AI 查询响应
    AiQueryResponse:
      type: object
      properties:
        success:
          type: boolean
          description: 是否成功
        data:
          type: object
          properties:
            answer:
              type: string
              description: 回答
            sources:
              type: array
              items:
                type: string
              description: 来源
              
    # 分页信息
    Pagination:
      type: object
      properties:
        page:
          type: integer
          description: 当前页码
        limit:
          type: integer
          description: 每页数量
        total:
          type: integer
          description: 总数量
        total_pages:
          type: integer
          description: 总页数
```

### 3.3 错误模型

```yaml
components:
  schemas:
    # 错误响应
    ErrorResponse:
      type: object
      properties:
        success:
          type: boolean
          description: 是否成功
          enum: [false]
        error:
          type: object
          properties:
            code:
              type: string
              description: 错误代码
            message:
              type: string
              description: 错误消息
            details:
              type: object
              description: 错误详情
              
    # 分页响应
    PaginationResponse:
      type: object
      properties:
        success:
          type: boolean
          description: 是否成功
        data:
          type: array
          items:
            type: object
          description: 数据列表
        pagination:
          $ref: '#/components/schemas/Pagination'
```

---

## 四、错误处理

### 4.1 错误代码

| 错误代码 | HTTP 状态码 | 说明 |
|----------|-------------|------|
| UNAUTHORIZED | 401 | 未授权 |
| NOT_FOUND | 404 | 资源不存在 |
| VALIDATION_ERROR | 400 | 验证错误 |
| RATE_LIMIT_EXCEEDED | 429 | 请求过于频繁 |
| INTERNAL_ERROR | 500 | 服务器内部错误 |

### 4.2 错误响应格式

```json
{
  "success": false,
  "error": {
    "code": "NOT_FOUND",
    "message": "视频不存在",
    "details": {
      "video_id": "123"
    }
  }
}
```

---

## 五、认证与授权

### 5.1 认证方式

- **Bearer Token**：JWT 格式
- **Header**：`Authorization: Bearer <token>`

### 5.2 授权规则

| 接口 | 认证要求 | 说明 |
|------|----------|------|
| GET /api/v1/* | 必需 | 所有读取接口需要认证 |
| POST /api/v1/* | 必需 | 所有写入接口需要认证 |
| POST /api/v1/ai/query | 必需 | AI 查询需要认证 |

---

## 六、限流策略

### 6.1 限流规则

| 接口 | 限流 | 说明 |
|------|------|------|
| GET /api/v1/* | 100 次/分钟 | 读取接口 |
| POST /api/v1/* | 30 次/分钟 | 写入接口 |
| POST /api/v1/ai/query | 10 次/分钟 | AI 查询 |

### 6.2 限流响应

```json
{
  "success": false,
  "error": {
    "code": "RATE_LIMIT_EXCEEDED",
    "message": "请求过于频繁，请稍后再试",
    "details": {
      "retry_after": 60
    }
  }
}
```

---

## 七、版本管理

### 7.1 API 版本

- **当前版本**：v1
- **版本格式**：`/api/v1/`
- **向后兼容**：新版本发布后，旧版本保留 6 个月

### 7.2 变更记录

| 版本 | 日期 | 变更 |
|------|------|------|
| v1.0 | YYYY-MM-DD | 初始版本 |

---

**文档版本**：V1.0
**创建时间**：YYYY-MM-DD
**最后更新**：YYYY-MM-DD
