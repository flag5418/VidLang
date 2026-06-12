// deno-lint-ignore-file no-explicit-any
/**
 * 通义千问 TTS API 客户端（语音合成）
 */

const TTS_URL =
  "https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation";

interface TtsParams {
  text: string;
  model?: string;
  voice?: string;
}

/** 调用 Qwen TTS，返回 base64 编码的音频 */
export async function qwenTts(
  apiKey: string,
  params: TtsParams
): Promise<{ audioBase64: string; format: string }> {
  const response = await fetch(TTS_URL, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
      "X-DashScope-OssResourceResolve": "enable",
    },
    body: JSON.stringify({
      model: params.model || "qwen3-tts-flash",
      input: { text: params.text },
      parameters: {
        text_type: "PlainText",
        voice: params.voice || "Aiden",
        language_type: "English",
        sample_rate: 24000,
        format: "mp3",
      },
    }),
  });

  if (!response.ok) {
    const errText = await response.text();
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
    return { audioBase64: base64, format: "mp3" };
  }

  throw new Error("TTS response missing audio URL");
}
