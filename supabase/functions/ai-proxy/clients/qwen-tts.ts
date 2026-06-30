// deno-lint-ignore-file no-explicit-any
/**
 * 通义千问 TTS API 客户端（语音合成）
 *
 * 支持两种模式：
 * 1. 同步模式（默认）：调用 DashScope multimodal API，一次性返回 base64 音频
 * 2. 流式模式（experimental）：使用 WebSocket Realtime API，流式返回音频分片
 *
 * ⚠️ 费用控制要点（2026-06 核查确认）：
 *   - model 必须是 'qwen-tts'，不是 'qwen3-tts'（开源名≠API ID）
 *   - 不要加任何 extra_parameters（如 deep_thinking 等），会静默升配
 *   - 计费：输入 0.0016元/千Token + 输出 0.01元/千Token
 *   - 估算：10 秒音频 ≈ 500 Token output ≈ 0.005 元
 *
 * 可用音色（voice 参数）：
 *   英文：Aiden(男英), Chelsie(女英), Cherry(女英), Ethan(男英), Serena(女英)
 *   中文：Dylan(北京话-男), Jada(吴语-女), Sunny(四川话-女)
 */

import { QWEN_MODELS } from './qwen-chat.ts'

const TTS_URL =
  "https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation";

interface TtsParams {
  text: string;
  model?: string;
  voice?: string;
}

/** TTS 合成结果 */
export interface TtsResult {
  audioBase64: string;
  format: string;
}

/**
 * 调用 Qwen TTS（同步模式）
 *
 * 使用 DashScope /api/v1/services/aigc/multimodal-generation/generation 端点
 * 返回完整的 base64 编码音频数据。
 *
 * 这是默认且稳定的模式，适用于大多数场景。
 * 对于需要更低首包延迟的场景，可考虑使用 qwenTtsStreaming。
 */
export async function qwenTts(
  apiKey: string,
  params: TtsParams
): Promise<TtsResult> {
  const model = params.model || QWEN_MODELS.TTS;
  const voice = params.voice || "Aiden";

  console.log(`🔊 [TTS] 开始合成: model=${model}, voice=${voice}, text长度=${params.text.length}`);

  const startTime = Date.now();

  const response = await fetch(TTS_URL, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
      "X-DashScope-OssResourceResolve": "enable",
    },
    body: JSON.stringify({
      model: model,
      input: { text: params.text },
      parameters: {
        text_type: "PlainText",
        voice: voice,
        language_type: "English",
        sample_rate: 24000,
        format: "mp3",
      },
    }),
  });

  if (!response.ok) {
    const errText = await response.text();
    console.error(`🔊 [TTS] API error ${response.status}: ${errText}`);
    throw new Error(`TTS API error ${response.status}: ${errText}`);
  }

  const data = await response.json() as any;
  const audioUrl = data?.output?.audio?.url;

  if (audioUrl) {
    // 下载音频文件
    const audioResp = await fetch(audioUrl);
    if (!audioResp.ok) throw new Error("Failed to download TTS audio");
    const buffer = await audioResp.arrayBuffer();
    const base64 = btoa(
      String.fromCharCode(...new Uint8Array(buffer))
    );
    const elapsed = Date.now() - startTime;
    console.log(`🔊 [TTS] 合成成功 (${elapsed}ms): voice=${voice}, 音频大小=${(base64.length * 0.75 / 1024).toFixed(1)}KB`);
    return { audioBase64: base64, format: "mp3" };
  }

  throw new Error("TTS response missing audio URL");
}

/**
 * 调用 Qwen TTS（流式模式）
 *
 * 使用 DashScope WebSocket Realtime API 实现流式音频输出。
 * 通过回调函数逐步返回音频分片，实现"边合成边传输"的效果。
 *
 * 注意：此函数在 Edge Function (Deno) 环境中运行，
 * 由于 Deno 的 WebSocket 支持限制，此模式主要用于服务端代理场景。
 *
 * @param apiKey - DashScope API Key
 * @param params - TTS 参数
 * @param onAudioChunk - 接收音频分片的回调 (base64 字符串)
 * @param onDone - 完成回调
 * @param onError - 错误回调
 */
export async function qwenTtsStreaming(
  apiKey: string,
  params: TtsParams,
  onAudioChunk: (base64Chunk: string) => void,
  onDone?: () => void,
  onError?: (error: Error) => void,
): Promise<void> {
  const model = params.model || QWEN_MODELS.TTS;
  const voice = params.voice || "Aiden";
  // Realtime API 使用不同的模型名前缀
  const realtimeModel = model === 'qwen-tts' ? 'qwen2.5-tts' : model;

  console.log(`🔊 [TTS-Stream] 开始流式合成: model=${realtimeModel}, voice=${voice}`);

  const wsUrl = `wss://dashscope.aliyuncs.com/api-ws/v1/realtime`;

  try {
    const ws = new WebSocket(wsUrl);

    ws.addEventListener('open', () => {
      // 发送运行时配置指令
      ws.send(JSON.stringify({
        type: 'RunTimeConfig',
        config: {
          modalities: ['audio'],
          audio: {
            format: 'mp3',
            sample_rate: 24000,
          },
        },
      }));

      // 发送文本输入指令
      ws.send(JSON.stringify({
        type: 'SessionInput',
        text: params.text,
      }));
    });

    ws.addEventListener('message', (event) => {
      try {
        const data = JSON.parse(event.data as any);

        switch (data.type) {
          case 'AudioChunk':
            // 收到音频分片
            if (data.data) {
              onAudioChunk(data.data);
            }
            break;

          case 'ResultFinished':
            // 合成完成
            console.log('🔊 [TTS-Stream] 合成完成');
            onDone?.();
            ws.close();
            break;

          case 'Error':
            const errMsg = data.error?.message || 'Unknown streaming error';
            console.error(`🔊 [TTS-Stream] 错误: ${errMsg}`);
            onError?.(new Error(errMsg));
            ws.close();
            break;

          case 'SessionStarted':
            console.log('🔊 [TTS-Stream] 会话已建立');
            break;

          default:
            // 忽略其他事件类型（如 Heartbeat 等）
            break;
        }
      } catch (e) {
        console.error('🔊 [TTS-Stream] 解析消息失败:', e);
      }
    });

    ws.addEventListener('error', (event) => {
      console.error('🔊 [TTS-Stream] WebSocket 错误:', event);
      onError?.(new Error('WebSocket connection error'));
    });

    ws.addEventListener('close', () => {
      console.log('🔊 [TTS-Stream] 连接已关闭');
    });

    // 设置超时（30秒）
    setTimeout(() => {
      if (ws.readyState === WebSocket.OPEN) {
        console.warn('🔊 [TTS-Stream] 超时关闭');
        ws.close();
        onDone?.();
      }
    }, 30000);

  } catch (error) {
    console.error('🔊 [TTS-Stream] 创建连接失败:', error);
    onError?.(error instanceof Error ? error : new Error(String(error)));
  }
}
