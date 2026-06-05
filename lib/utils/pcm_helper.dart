import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// PCM 音频数据工具类
/// 提供 PCM 数据与 WAV 文件之间的相互转换和保存功能
class PcmHelper {
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

      // 2. 生成 WAV 文件头
      final Uint8List wavHeader = _createWavHeader(pcmData.length, sampleRate, bitDepth, channels);

      // 3. 合并 WAV 头和 PCM 数据
      final Uint8List wavData = Uint8List.fromList([...wavHeader, ...pcmData]);

      // 4. 保存到文件
      final baseDirectory = await getApplicationDocumentsDirectory();
      final savePath = fileDirectory != null && fileDirectory.isNotEmpty
          ? path.join(baseDirectory.path, fileDirectory)
          : baseDirectory.path;
      final saveDirectory = Directory(savePath);
      if (!await saveDirectory.exists()) {
        await saveDirectory.create(recursive: true);
      }
      final String filePath = path.join(savePath, '$fileName.wav');
      final File file = File(filePath);
      await file.writeAsBytes(wavData);

      return filePath;
    } catch (e) {
      print('PcmHelper 转换保存失败: $e');
      return null;
    }
  }

  /// 将 PCM Base64 字符串转换为 WAV 文件
  static Future<String?> convertAndSave(
    String base64PcmData, {
    required String fileName,
    String? fileDirectory,
    int sampleRate = 24000,
    int bitDepth = 16,
    int channels = 1,
  }) async {
    if (!isValidPcmBase64(base64PcmData)) return null;

    try {
      final Uint8List pcmData = base64.decode(base64PcmData);
      final Uint8List wavHeader = _createWavHeader(pcmData.length, sampleRate, bitDepth, channels);
      final Uint8List wavData = Uint8List.fromList([...wavHeader, ...pcmData]);

      final baseDirectory = await getApplicationDocumentsDirectory();
      final savePath = fileDirectory != null && fileDirectory.isNotEmpty
          ? path.join(baseDirectory.path, fileDirectory)
          : baseDirectory.path;
      final saveDirectory = Directory(savePath);
      if (!await saveDirectory.exists()) {
        await saveDirectory.create(recursive: true);
      }
      final String filePath = path.join(savePath, '$fileName.wav');
      final File file = File(filePath);
      await file.writeAsBytes(wavData);

      return filePath;
    } catch (e) {
      print('PcmHelper 转换失败: $e');
      return null;
    }
  }

  /// 创建 WAV 文件头
  static Uint8List _createWavHeader(int pcmDataLength, int sampleRate, int bitDepth, int channels) {
    final byteRate = sampleRate * channels * bitDepth ~/ 8;
    final blockAlign = channels * bitDepth ~/ 8;
    final dataSize = pcmDataLength;
    final totalSize = 36 + dataSize;

    final header = ByteData(44);

    header.setUint8(0, 0x52); // R
    header.setUint8(1, 0x49); // I
    header.setUint8(2, 0x46); // F
    header.setUint8(3, 0x46); // F
    header.setUint32(4, totalSize, Endian.little);
    header.setUint8(8, 0x57); // W
    header.setUint8(9, 0x41); // A
    header.setUint8(10, 0x56); // V
    header.setUint8(11, 0x45); // E
    header.setUint8(12, 0x66); // f
    header.setUint8(13, 0x6D); // m
    header.setUint8(14, 0x74); // t
    header.setUint8(15, 0x20); //
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitDepth, Endian.little);
    header.setUint8(36, 0x64); // d
    header.setUint8(37, 0x61); // a
    header.setUint8(38, 0x74); // t
    header.setUint8(39, 0x61); // a
    header.setUint32(40, dataSize, Endian.little);

    return header.buffer.asUint8List();
  }

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
    final wavHeader = _createWavHeader(silenceBytes.length, sampleRate, bitDepth, channels);
    return Uint8List.fromList([...wavHeader, ...silenceBytes]);
  }

  /// 归一化输入音频字节（移除可能的 WAV 头部）
  static Uint8List normalizeIncomingAudioBytes(Uint8List bytes, {required bool isFirstChunk}) {
    if (isFirstChunk && _looksLikeWavHeader(bytes)) {
      if (bytes.length <= 44) return Uint8List(0);
      return Uint8List.fromList(bytes.sublist(44));
    }
    return bytes;
  }

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
