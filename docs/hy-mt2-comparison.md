# MarianMT vs Hy-MT2 对比分析报告

## 1. 模型基本信息

| 维度 | MarianMT (当前) | Hy-MT2 (腾讯) |
|------|----------------|---------------|
| **全称** | Mozilla Marian Machine Translation | Tencent Hunyuan Multilingual Translation 2 |
| **架构** | Transformer Encoder-Decoder (分离 encoder/decoder) | Decoder-only LLM (自回归生成) |
| **参数量** | ~117M (6层encoder + 6层decoder, d_model=512) | 1.8B / 7B / 30B-A3B(MoE) |
| **模型格式** | ONNX (.onnx) | PyTorch (safetensors/BF16) |
| **量化版本** | 无量化 (FP32/FP16) | FP16, 8-bit, 4-bit, 2-bit, 1.25-bit |
| **量化技术** | N/A | AngelSlim (1.25-bit极端量化) |
| **开源协议** | Mozilla Public License 2.0 | Apache 2.0 |
| **部署方式** | 端侧 ONNX Runtime | 云端 GPU / 端侧 (1.25-bit量化) |
| **模型仓库** | Helsinki-NLP/opus-mt-en-zh | tencent/Hy-MT2-1.8B |

## 2. 语言支持

| 维度 | MarianMT | Hy-MT2-1.8B |
|------|----------|-------------|
| **语言数量** | 仅 2 种 (英语→中文) | 33 种语言 + 5 种方言 |
| **翻译方向** | 1 个方向 (en→zh) | 1056 个方向 |
| **支持语言** | English, Chinese | 中英日韩法德俄西等主流语言 + 泰越印阿等小语种 + 藏蒙维粤闽等方言 |
| **多语言扩展** | 需要训练新模型 | 原生支持，无需额外训练 |

## 3. 技术架构差异

### 3.1 MarianMT (当前系统)

```
┌─────────────────────────────────────────────────┐
│  MarianMT Encoder-Decoder 架构                   │
│                                                  │
│  Input Text                                      │
│     │                                            │
│     ▼                                            │
│  ┌──────────┐                                   │
│  │ SentencePiece │  (Viterbi 分词)                │
│  └────┬─────┘                                   │
│       │                                          │
│       ▼                                          │
│  ┌──────────┐     ┌──────────┐                   │
│  │ Encoder   │────▶│ Decoder   │  (贪心解码)       │
│  │ ONNX     │     │ ONNX     │                   │
│  └──────────┘     └──────────┘                   │
│                                                  │
│  Output: 中文文本                                 │
└─────────────────────────────────────────────────┘
```

**关键特点：**
- Encoder 和 Decoder 是两个独立的 ONNX 模型文件
- 使用自定义 SentencePiece Viterbi 分词器 (`sentencepiece_tokenizer.dart`)
- Decoder 使用贪心解码 (Greedy Decoding)，每一步取概率最高的 token
- 最大输入长度: 128 tokens
- 最大输出长度: 64 tokens
- 推理引擎: ONNX Runtime

### 3.2 Hy-MT2 (候选替换)

```
┌─────────────────────────────────────────────────┐
│  Hy-MT2 Decoder-Only LLM 架构                    │
│                                                  │
│  Input: [System Prompt] + [Source Text]          │
│     │                                            │
│     ▼                                            │
│  ┌──────────────────┐                           │
│  │ HuggingFace      │                            │
│  │ Tokenizer        │  (BPE/SentencePiece混合)     │
│  └────┬─────────────┘                           │
│       │                                          │
│       ▼                                          │
│  ┌──────────────────┐                           │
│  │ Transformer      │                           │
│  │ Decoder-Only     │  (自回归生成)               │
│  │ (1.8B/7B/30B)    │                           │
│  └────┬─────────────┘                           │
│       │                                          │
│       ▼                                          │
│  Output: 中文文本 (带指令跟随能力)                 │
└─────────────────────────────────────────────────┘
```

**关键特点：**
- Decoder-only 架构 (类似 GPT)，单次前向传播生成整个译文
- 使用 HuggingFace Transformers 的 Tokenizer
- 支持指令跟随 (术语、风格、上下文、个性化等 7 种翻译模式)
- 最大上下文长度: 4096 tokens
- 推理引擎: PyTorch (GPU) / ONNX (需导出) / GGUF (CPU)
- 1.25-bit 量化后可在端侧运行 (440MB)

## 4. 翻译质量对比 (基于论文数据)

### 4.1 FLORES-200 基准测试 (XX→XX 平均)

| 模型 | XCOMET-XXL | CometKiwi | GEMBA |
|------|-----------|-----------|-------|
| **Microsoft Translator** | 72.85 | 84.79 | - |
| **HY-MT1.5-1.8B** | 76.55 | 75.12 | - |
| **Hy-MT2-1.8B** | **79.77** | **78.64** | - |
| **Hy-MT2-7B** | 86.89 | 87.23 | - |
| **Gemini 3.1 Pro** | 78.96 | 92.14 | - |

### 4.2 WMT25 基准测试

| 模型 | XCOMET-XXL | CometKiwi | GEMBA |
|------|-----------|-----------|-------|
| **Microsoft Translator** | 85.48 | 87.34 | - |
| **Doubao Translator** | 83.49 | 84.46 | - |
| **HY-MT1.5-1.8B** | 84.11 | 81.35 | - |
| **Hy-MT2-1.8B** | **85.46** | **84.05** | - |
| **Hy-MT2-7B** | 88.07 | 89.34 | - |

### 4.3 领域翻译 (DomainMTBench 平均分)

| 模型 | XCOMET | GEMBA |
|------|--------|-------|
| **Microsoft Translator** | 89.01 | 89.01 |
| **HY-MT1.5-1.8B** | 88.82 | 93.52 |
| **Hy-MT2-1.8B** | **91.08** | **93.41** |

### 4.4 真实场景翻译 (WildMTBench)

| 模型 | XCOMET | GEMBA |
|------|--------|-------|
| **Microsoft Translator** | 79.32 | 79.19 |
| **Doubao Translator** | 77.61 | 78.07 |
| **HY-MT1.5-1.8B** | 80.84 | 87.41 |
| **Hy-MT2-1.8B** | **86.04** | **87.43** |

**关键结论：** Hy-MT2-1.8B 在多项基准测试中已超过 Microsoft Translator 和 Doubao，且远超其前身 Hy-MT1.5-1.8B。

## 5. 端侧部署可行性分析

### 5.1 当前 MarianMT 在 Flutter 中的部署

| 项目 | 详情 |
|------|------|
| **推理引擎** | `onnxruntime` (Flutter 插件) |
| **模型大小** | encoder: 50MB + decoder: 89MB ≈ 140MB |
| **内存占用** | ~1GB (常驻) |
| **启动时间** | ~3秒 |
| **推理速度** | 短文本 0.18秒，长文本 0.5-0.8秒 |
| **设备要求** | 骁龙865+/A14+, 8GB RAM |
| **Flutter 集成度** | ✅ 已完成，生产可用 |

### 5.2 Hy-MT2 在 Flutter 中部署的可行性

| 项目 | 现状 | 可行性评估 |
|------|------|-----------|
| **推理引擎** | Flutter 暂无成熟的 PyTorch Mobile 支持 | ⚠️ 需要 ONNX 导出或 GGUF |
| **模型格式** | 原生为 PyTorch safetensors | ⚠️ 需要转换为 ONNX |
| **Tokenizer** | HuggingFace SentencePiece/BPE | ⚠️ 需要在 Dart 中实现 |
| **模型大小** | FP16: ~3.6GB / 1.25-bit量化: 440MB | ✅ 可行 |
| **内存占用** | 1.25-bit 量化版预计 ~2-3GB | ⚠️ 较高 |
| **推理速度** | GPU: <0.1秒 / CPU: 1-3秒 | ⚠️ CPU 较慢 |
| **Flutter 集成** | 无现成插件 | ❌ 需要大量开发工作 |

### 5.3 关键技术障碍

1. **ONNX 导出**: Hy-MT2 是 Decoder-only LLM，需要将 PyTorch 模型导出为 ONNX。目前腾讯官方未提供 ONNX 版本。

2. **自回归推理**: MarianMT 使用 encoder-decoder 架构，可以分离推理；Hy-MT2 是自回归生成，每一步需要等待上一步的输出，无法像 MarianMT 那样并行推理。

3. **Flutter 推理引擎**: 
   - `onnxruntime` 支持 Transformer 架构，但需要手动处理自回归生成循环
   - 需要实现 HuggingFace Tokenizer (BPE/SentencePiece)
   - 1.8B 模型在 CPU 上推理速度可能较慢

4. **内存管理**: 1.8B 模型即使 1.25-bit 量化，也需要 ~2-3GB 内存，对低端设备不友好。

## 6. 代码改动量评估

如果替换为 Hy-MT2，需要改动的文件：

| 文件 | 改动类型 | 预估工作量 |
|------|---------|-----------|
| `local_translation_service.dart` | **重写** | 2-3天 |
| `sentencepiece_tokenizer.dart` | **替换** 为 HuggingFace Tokenizer | 1-2天 |
| `local_model_service.dart` | 修改模型检测逻辑 | 0.5天 |
| `model_path_service.dart` | 更新模型路径 | 0.5天 |
| `translation_init_service.dart` | 可能需调整 | 0.5天 |
| `unified_translation_service.dart` | 增加语言路由 | 1天 |
| `pubspec.yaml` | 添加新依赖 | 0.5天 |
| **总计** | | **5-8天** |

## 7. 建议方案

### 方案 A: 渐进式替换 (推荐)

1. **第一阶段**：保留 MarianMT 作为英→中翻译 (已完成，稳定运行)
2. **第二阶段**：尝试将 Hy-MT2 导出为 ONNX，在 Flutter 中测试可行性
3. **第三阶段**：如果 ONNX 推理可行，增加语言路由，Hy-MT2 处理非英语翻译
4. **第四阶段**：根据性能表现决定是否完全替换

### 方案 B: 云端 Hy-MT2 API (快速验证)

1. 部署 Hy-MT2 到云端 GPU 服务器
2. 通过 Edge Function 调用
3. 免费模式下仍用 MarianMT，收费模式可切换 Hy-MT2
4. 优点：无需修改端侧代码，快速验证质量

### 方案 C: 混合方案 (长期最优)

1. 英→中：继续使用 MarianMT (已验证，轻量高效)
2. 其他语言对：使用 Hy-MT2 (通过 ONNX 导出)
3. 云端：Hy-MT2-7B/30B 处理复杂翻译任务
4. 端侧：Hy-MT2-1.8B (量化) 处理其他语言

## 8. 核心结论

| 维度 | 结论 |
|------|------|
| **翻译质量** | Hy-MT2 显著优于 MarianMT，尤其在多语言场景 |
| **端侧部署** | **技术上可行但需要大量开发工作** (ONNX导出 + Tokenizer实现) |
| **代码改动** | 中等偏大 (5-8天) |
| **短期收益** | 低 (需要先完成技术验证) |
| **长期价值** | 高 (多语言支持 + 指令跟随 + 持续迭代) |
| **推荐行动** | **先做技术验证 (本测试的目的)，再决定是否替换** |
