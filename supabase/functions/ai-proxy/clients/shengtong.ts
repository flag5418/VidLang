// deno-lint-ignore-file no-explicit-any
/**
 * 声通语音评测 API 客户端（HTTP REST）
 *
 * 接口规格：
 *   POST https://api.stkouyu.com:8443/{coreType}
 *   Content-Type: multipart/form-data
 *   Header: Request-Index: 0
 *
 * 签名算法：
 *   start_sig = SHA1(appKey + timestamp + userId + secretKey) → HEX 编码
 *   timestamp 为毫秒级 UTC 时间戳
 *
 * coreType:
 *   en.word.eval  — 单词评测（返回音素级 dp_message）
 *   en.sent.eval  — 句子/短语评测（返回 fluency/accuracy/integrity/连读/爆破/语调）
 *
 * 音频要求：16000Hz / 单声道 / 16bit / WAV
 */

// ─── 类型定义 ───

export interface ShengtongParams {
  coreType: string; // en.word.eval | en.sent.eval
  refText: string; // 参考文本
  userId: string; // 用户标识
  audioBase64: string; // base64 编码的音频数据
  tokenId?: string; // 可选 token
  audioType?: string; // 默认 wav
  sampleRate?: number; // 默认 16000
}

/** 单词评测返回 */
export interface WordEvalResult {
  score: number;
  overall: number;
  words: Array<{
    word: string;
    score: number;
    phonemes: Array<{
      phoneme: string;
      dp_message: number; // 0-正确 1-错误 2-漏读
    }>;
  }>;
}

/** 句子评测返回 */
export interface SentEvalResult {
  score: number;
  overall: number;
  fluency: number;
  accuracy: number;
  integrity: number;
  linking?: number; // 连读
  plosion?: number; // 爆破
  intonation?: number; // 语调
}

// ─── 工具函数 ───

/** SHA1 + HEX（使用 Web Crypto API） */
async function sha1Hex(input: string): Promise<string> {
  const data = new TextEncoder().encode(input);
  const hashBuffer = await crypto.subtle.digest("SHA-1", data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");
}

/** 生成 start 签名 */
async function generateStartSig(
  appKey: string,
  timestamp: string,
  userId: string,
  secretKey: string,
): Promise<string> {
  return sha1Hex(`${appKey}${timestamp}${userId}${secretKey}`);
}

/** Base64 字符串 → Uint8Array */
function base64ToBytes(base64: string): Uint8Array {
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

// ─── 主函数 ───

/**
 * 调用声通 HTTP REST API 进行语音评测
 */
export async function shengtongEvaluate(
  appKey: string,
  secretKey: string,
  serverUrl: string,
  params: ShengtongParams,
): Promise<any> {
  const {
    coreType,
    refText,
    userId,
    audioBase64,
    tokenId,
    audioType = "wav",
    sampleRate = 16000,
  } = params;

  const timestamp = String(Date.now());
  const sig = await generateStartSig(appKey, timestamp, userId, secretKey);
  const url = `${serverUrl}/${coreType}`;

  // 构建 multipart/form-data
  const boundary = `----ShengtongBoundary${crypto.randomUUID()}`;

  const parts: string[] = [];

  parts.push(`--${boundary}`);
  parts.push(`Content-Disposition: form-data; name="appKey"`);
  parts.push(``);
  parts.push(appKey);

  parts.push(`--${boundary}`);
  parts.push(`Content-Disposition: form-data; name="timestamp"`);
  parts.push(``);
  parts.push(timestamp);

  parts.push(`--${boundary}`);
  parts.push(`Content-Disposition: form-data; name="sig"`);
  parts.push(``);
  parts.push(sig);

  parts.push(`--${boundary}`);
  parts.push(`Content-Disposition: form-data; name="userId"`);
  parts.push(``);
  parts.push(userId);

  parts.push(`--${boundary}`);
  parts.push(`Content-Disposition: form-data; name="coreType"`);
  parts.push(``);
  parts.push(coreType);

  parts.push(`--${boundary}`);
  parts.push(`Content-Disposition: form-data; name="refText"`);
  parts.push(``);
  parts.push(refText);

  if (tokenId) {
    parts.push(`--${boundary}`);
    parts.push(`Content-Disposition: form-data; name="tokenId"`);
    parts.push(``);
    parts.push(tokenId);
  }

  parts.push(`--${boundary}`);
  parts.push(`Content-Disposition: form-data; name="sampleRate"`);
  parts.push(``);
  parts.push(String(sampleRate));

  parts.push(`--${boundary}`);
  parts.push(`Content-Disposition: form-data; name="audioType"`);
  parts.push(``);
  parts.push(audioType);

  // 音频文件
  parts.push(`--${boundary}`);
  parts.push(`Content-Disposition: form-data; name="audio"; filename="audio.${audioType}"`);
  parts.push(`Content-Type: audio/wav`);
  parts.push(``);

  // 构建混合 body：文本部分 → Uint8Array，音频部分 → Uint8Array
  const textEncoder = new TextEncoder();
  const textPart = textEncoder.encode(parts.join("\r\n") + "\r\n");
  const audioBytes = base64ToBytes(audioBase64);
  const endPart = textEncoder.encode(`\r\n--${boundary}--\r\n`);

  const bodyBytes = new Uint8Array(
    textPart.length + audioBytes.length + endPart.length,
  );
  bodyBytes.set(textPart, 0);
  bodyBytes.set(audioBytes, textPart.length);
  bodyBytes.set(endPart, textPart.length + audioBytes.length);

  // 发送请求
  const response = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": `multipart/form-data; boundary=${boundary}`,
      "Request-Index": "0",
    },
    body: bodyBytes,
  });

  if (!response.ok) {
    const errText = await response.text();
    throw new Error(
      `Shengtong API error ${response.status}: ${errText}`,
    );
  }

  const result = await response.json() as any;

  // 检查声通返回码
  if (result.code !== undefined && result.code !== 0) {
    throw new Error(
      `Shengtong eval error code=${result.code}: ${result.error || result.message || "unknown error"}`,
    );
  }

  return result;
}
