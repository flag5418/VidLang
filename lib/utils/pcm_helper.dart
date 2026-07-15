import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// PCM 音频数据工具类
///
/// 提供 PCM 数据与 WAV 数据之间的转换功能。
/// 统一项目中所有 PCM→WAV 的转换逻辑，避免各模块重复实现。
///
/// 使用场景：
/// - AI 对话模块播放 PCM 音频流（conversation_provider）
/// - 跟读评分录音回放（未来扩展）
/// - TTS 音频处理（未来扩展）
class PcmHelper {
  PcmHelper._();

  // ═══════════════════════════════════════════════════════════════
  // 核心转换方法
  // ═══════════════════════════════════════════════════════════════

  /// 将原始 PCM 字节数据转换为 WAV 格式字节数据（内存操作，无 I/O）
  ///
  /// 这是项目中最常用的转换方式，用于：
  /// - AI 对话中接收到的 PCM 音频流 → 播放器可识别的 WAV
  /// - 任何需要将裸 PCM 数据包装为标准 WAV 格式的场景
  ///
  /// [pcmData] 原始 PCM 音频数据
  /// [sampleRate] 采样率，如 16000、24000、44100 等
  /// [channels] 声道数，通常为 1（单声道）
  /// [bitsPerSample] 位深度，通常为 16
  static Uint8List pcmToWav(
    Uint8List pcmData, {
    required int sampleRate,
    int channels = 1,
    int bitsPerSample = 16,
  }) {
    final wavHeader = _createWavHeader(
      pcmData.length,
      sampleRate: sampleRate,
      channels: channels,
      bitsPerSample: bitsPerSample,
    );
    return Uint8List.fromList([...wavHeader, ...pcmData]);
  }

  /// 将 PCM Base64 字符串解码并转换为 WAV 字节数据
  static Uint8List? base64PcmToWav(
    String base64PcmData, {
    int sampleRate = 24000,
    int channels = 1,
    int bitsPerSample = 16,
  }) {
    if (!isValidPcmBase64(base64PcmData)) return null;
    try {
      final pcmData = base64.decode(base64PcmData);
      return pcmToWav(
        pcmData,
        sampleRate: sampleRate,
        channels: channels,
        bitsPerSample: bitsPerSample,
      );
    } catch (e) {
      print('PcmHelper base64PcmToWav 转换失败: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 文件保存方法（带磁盘 I/O）
  // ═══════════════════════════════════════════════════════════════

  /// 将 PCM 数据块列表合并并保存为 WAV 文件
  static Future<String?> convertPcmListAndSave(
    List<Uint8List> pcmDataList, {
    required String fileName,
    String? fileDirectory,
    int sampleRate = 16000,
    int bitDepth = 16,
    int channels = 1,
  }) async {
    if (pcmDataList.isEmpty) return null;

    try {
      // 1. 合并 PCM 数据
      int totalLength = 0;
      for (final chunk in pcmDataList) {
        totalLength += chunk.length;
      }
      final Uint8List pcmData = Uint8List(totalLength);
      int offset = 0;
      for (final chunk in pcmDataList) {
        pcmData.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      }

      // 2. 转换为 WAV 并保存
      return await saveWavFile(
        pcmToWav(pcmData, sampleRate: sampleRate, channels: channels, bitsPerSample: bitDepth),
        fileName: '$fileName.wav',
        fileDirectory: fileDirectory,
      );
    } catch (e) {
      print('PcmHelper 转换保存失败: $e');
      return null;
    }
  }

  /// 将 PCM Base64 字符串转换为 WAV 文件并保存到磁盘
  static Future<String?> convertAndSave(
    String base64PcmData, {
    required String fileName,
    String? fileDirectory,
    int sampleRate = 24000,
    int bitDepth = 16,
    int channels = 1,
  }) async {
    final wavBytes = base64PcmToWav(
      base64PcmData,
      sampleRate: sampleRate,
      channels: channels,
      bitsPerSample: bitDepth,
    );
    if (wavBytes == null) return null;

    return await saveWavFile(wavBytes, fileName: '$fileName.wav', fileDirectory: fileDirectory);
  }

  /// 将 WAV 字节数据保存到文件系统
  static Future<String?> saveWavFile(
    Uint8List wavData, {
    required String fileName,
    String? fileDirectory,
  }) async {
    try {
      final baseDirectory = await getApplicationDocumentsDirectory();
      final savePath = fileDirectory != null && fileDirectory.isNotEmpty
          ? path.join(baseDirectory.path, fileDirectory)
          : baseDirectory.path;
      final saveDirectory = Directory(savePath);
      if (!await saveDirectory.exists()) {
        await saveDirectory.create(recursive: true);
      }
      final String filePath = path.join(savePath, fileName);
      final File file = File(filePath);
      await file.writeAsBytes(wavData);
      return filePath;
    } catch (e) {
      print('PcmHelper 保存文件失败: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // WAV 头生成（内部方法）
  // ═══════════════════════════════════════════════════════════════

  /// 创建标准 RIFF/WAV 文件头（44 字节）
  ///
  /// WAV 文件格式：
  /// - RIFF chunk descriptor (12 bytes)
  /// - fmt sub-chunk (24 bytes)
  /// - data sub-chunk header (8 bytes)
  static Uint8List _createWavHeader(
    int pcmDataLength, {
    required int sampleRate,
    required int channels,
    required int bitsPerSample,
  }) {
    final byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
    final blockAlign = channels * (bitsPerSample ~/ 8);
    final dataSize = pcmDataLength;
    final riffChunkSize = 36 + dataSize;

    final header = ByteData(44);

    // ── RIFF Chunk Descriptor ──
    header.setUint8(0, 0x52); // 'R'
    header.setUint8(1, 0x49); // 'I'
    header.setUint8(2, 0x46); // 'F'
    header.setUint8(3, 0x46); // 'F'
    header.setUint32(4, riffChunkSize, Endian.little); // 文件大小 - 8
    header.setUint8(8, 0x57); // 'W'
    header.setUint8(9, 0x41); // 'A'
    header.setUint8(10, 0x56); // 'V'
    header.setUint8(11, 0x45); // 'E'

    // ── fmt Sub-Chunk ──
    header.setUint32(12, 16, Endian.little); // Chunk size (PCM = 16)
    header.setUint16(20, 1, Endian.little); // Audio format (1 = PCM)
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);

    // ── data Sub-Chunk Header ──
    header.setUint8(36, 0x64); // 'd'
    header.setUint8(37, 0x61); // 'a'
    header.setUint8(38, 0x74); // 't'
    header.setUint8(39, 0x61); // 'a'
    header.setUint32(40, dataSize, Endian.little);

    return header.buffer.asUint8List();
  }

  // ═══════════════════════════════════════════════════════════════
  // 工具方法
  // ═══════════════════════════════════════════════════════════════

  /// 验证 Base64 字符串是否可能是有效的 PCM 数据
  static bool isValidPcmBase64(String base64String) {
    try {
      base64.decode(base64String);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 创建指定时长的静音 PCM 数据
  static Uint8List createSilenceBytes(int durationMs, int sampleRate, int bitDepth, int channels) {
    final bytesPerSample = bitDepth ~/ 8;
    final samples = (sampleRate * durationMs / 1000).round();
    final totalBytes = samples * bytesPerSample * channels;
    return Uint8List(totalBytes);
  }

  /// 生成指定时长的静音 WAV 音频数据
  static Uint8List createSilenceWav({
    int durationMs = 1000,
    int sampleRate = 16000,
    int bitDepth = 16,
    int channels = 1,
  }) {
    final silenceBytes = createSilenceBytes(durationMs, sampleRate, bitDepth, channels);
    return pcmToWav(silenceBytes, sampleRate: sampleRate, channels: channels, bitsPerSample: bitDepth);
  }

  /// 归一化输入音频字节（移除可能的 WAV 头部）
  ///
  /// 当音频流的首包可能包含 WAV 头时使用（如某些录音设备输出）。
  /// [isFirstChunk] 为 true 时检测并剥离 44 字节 WAV 头。
  static Uint8List normalizeIncomingAudioBytes(Uint8List bytes, {required bool isFirstChunk}) {
    if (isFirstChunk && _looksLikeWavHeader(bytes)) {
      if (bytes.length <= 44) return Uint8List(0);
      return Uint8List.fromList(bytes.sublist(44));
    }
    return bytes;
  }

  /// 检测字节数据是否以 RIFF/WAV magic number 开头
  static bool _looksLikeWavHeader(Uint8List bytes) {
    if (bytes.length < 12) return false;
    return bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x41 &&
        bytes[10] == 0x56 &&
        bytes[11] == 0x45;
  }

  /// 采样率转换（线性插值）
  ///
  /// 用于将音频数据从一种采样率转换到另一种采样率。
  /// 例如将 48kHz 的音频降采样到 16kHz 以匹配评测 API 要求。
  static Uint8List resample(Uint8List input, int srcSampleRate, int dstSampleRate) {
    if (srcSampleRate == dstSampleRate) return input;
    if (input.length < 4) return input;

    final srcLen = input.length ~/ 2;
    final dstLen = (srcLen * dstSampleRate / srcSampleRate).round();
    final ratio = srcSampleRate / dstSampleRate;

    final ByteData srcData = ByteData.sublistView(input);
    final ByteData dstData = ByteData(dstLen * 2);

    for (int i = 0; i < dstLen; i++) {
      final double srcIndex = i * ratio;
      final int index0 = srcIndex.floor();
      final int index1 = (index0 + 1 < srcLen) ? index0 + 1 : index0;
      final double t = srcIndex - index0;
      final int val0 = srcData.getInt16(index0 * 2, Endian.little);
      final int val1 = srcData.getInt16(index1 * 2, Endian.little);
      final int val = (val0 * (1 - t) + val1 * t).round();
      dstData.setInt16(i * 2, val, Endian.little);
    }
    return dstData.buffer.asUint8List();
  }
}
