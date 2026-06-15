import 'dart:io';
import 'dart:typed_data';

class Id3Tags {
  final String? title;
  final String? artist;
  final String? album;
  final Uint8List? coverData;
  final String? coverMimeType;

  const Id3Tags({this.title, this.artist, this.album, this.coverData, this.coverMimeType});

  bool get hasInfo => title != null || artist != null || album != null || coverData != null;
}

class Id3Parser {
  static Future<Id3Tags?> parse(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return null;

    final randomAccessFile = await file.open();
    try {
      final header = await randomAccessFile.read(3);
      if (header.length < 3) return null;

      final headerStr = String.fromCharCodes(header);
      if (headerStr == 'ID3') {
        return await _parseId3v2(randomAccessFile);
      }

      final size = await randomAccessFile.length();
      if (size < 128) return null;

      await randomAccessFile.setPosition(size - 128);
      final tag = await randomAccessFile.read(3);
      final tagStr = String.fromCharCodes(tag);
      if (tagStr == 'TAG') {
        return await _parseId3v1(randomAccessFile);
      }

      return null;
    } catch (_) {
      return null;
    } finally {
      await randomAccessFile.close();
    }
  }

  static Future<Id3Tags> _parseId3v2(RandomAccessFile raf) async {
    final versionBytes = await raf.read(2);
    final version = versionBytes[0];
    await raf.read(1);

    final sizeBytes = await raf.read(4);
    final totalSize = _decodeSyncSafeInt(sizeBytes);

    String? title;
    String? artist;
    String? album;
    Uint8List? coverData;
    String? coverMimeType;

    int bytesRead = 10;
    final maxRead = totalSize + 10;

    while (bytesRead < maxRead) {
      final frameIdBytes = await raf.read(4);
      if (frameIdBytes.length < 4) break;

      final frameId = String.fromCharCodes(frameIdBytes);
      if (frameId.codeUnitAt(0) < 'A'.codeUnitAt(0)) break;

      final frameSizeBytes = await raf.read(4);
      final frameSize = _decodeFrameSize(frameSizeBytes, version);
      await raf.read(2);

      if (frameSize <= 0 || frameSize > 10 * 1024 * 1024) {
        bytesRead += 10 + frameSize;
        if (frameSize > 0) await raf.setPosition(await raf.position() + frameSize);
        continue;
      }

      final frameData = await raf.read(frameSize);
      bytesRead += 10 + frameSize;

      if (frameData.isEmpty) continue;

      if (frameId == 'TIT2') {
        title = _decodeTextFrame(frameData);
      } else if (frameId == 'TPE1') {
        artist = _decodeTextFrame(frameData);
      } else if (frameId == 'TALB') {
        album = _decodeTextFrame(frameData);
      } else if (frameId == 'APIC' && frameSize < 5 * 1024 * 1024) {
        final apic = _decodeApicFrame(frameData);
        if (apic != null) {
          coverData = apic.$1;
          coverMimeType = apic.$2;
        }
      }
    }

    return Id3Tags(
      title: title,
      artist: artist,
      album: album,
      coverData: coverData,
      coverMimeType: coverMimeType,
    );
  }

  static Future<Id3Tags> _parseId3v1(RandomAccessFile raf) async {
    await raf.setPosition(await raf.position() - 3);

    final titleBytes = await raf.read(30);
    final artistBytes = await raf.read(30);
    final albumBytes = await raf.read(30);

    return Id3Tags(
      title: _trimNull(titleBytes),
      artist: _trimNull(artistBytes),
      album: _trimNull(albumBytes),
    );
  }

  static int _decodeSyncSafeInt(Uint8List bytes) {
    return (bytes[0] & 0x7F) << 21 |
        (bytes[1] & 0x7F) << 14 |
        (bytes[2] & 0x7F) << 7 |
        (bytes[3] & 0x7F);
  }

  static int _decodeFrameSize(Uint8List bytes, int version) {
    if (version >= 4) {
      return _decodeSyncSafeInt(bytes);
    }
    return (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
  }

  static String _decodeTextFrame(Uint8List data) {
    if (data.isEmpty) return '';
    final encoding = data[0];
    final textData = data.sublist(1);

    try {
      if (encoding == 0) {
        final end = textData.indexOf(0);
        final slice = end >= 0 ? textData.sublist(0, end) : textData;
        return String.fromCharCodes(slice).trim();
      } else if (encoding == 1) {
        final bom = textData.length >= 2 ? textData[0] << 8 | textData[1] : 0;
        Uint8List slice;
        if (bom == 0xFEFF || bom == 0xFFFE) {
          slice = textData.sublist(2);
        } else {
          slice = textData;
        }
        final chars = <int>[];
        for (int i = 0; i < slice.length - 1; i += 2) {
          final codeUnit = slice[i] << 8 | slice[i + 1];
          if (codeUnit == 0) break;
          chars.add(codeUnit);
        }
        return String.fromCharCodes(chars).trim();
      } else if (encoding == 2) {
        return String.fromCharCodes(textData.where((b) => b != 0)).trim();
      } else if (encoding == 3) {
        final end = textData.indexOf(0);
        final slice = end >= 0 ? textData.sublist(0, end) : textData;
        return String.fromCharCodes(slice).trim();
      }
    } catch (_) {}

    final end = textData.indexOf(0);
    final slice = end >= 0 ? textData.sublist(0, end) : textData;
    return String.fromCharCodes(slice.where((b) => b >= 32)).trim();
  }

  static (Uint8List, String)? _decodeApicFrame(Uint8List data) {
    if (data.isEmpty) return null;
    final encoding = data[0];

    int offset = 1;
    final mimeEnd = data.indexOf(0, offset);
    if (mimeEnd < 0) return null;

    final mimeType = String.fromCharCodes(data.sublist(offset, mimeEnd)).toLowerCase();
    offset = mimeEnd + 1;

    if (offset >= data.length) return null;
    final pictureType = data[offset];
    offset += 1;

    if (encoding == 1 || encoding == 2) {
      while (offset < data.length - 1) {
        if (data[offset] == 0 && data[offset + 1] == 0) {
          offset += 2;
          break;
        }
        offset += 2;
      }
    } else {
      final descEnd = data.indexOf(0, offset);
      if (descEnd >= 0) {
        offset = descEnd + 1;
      }
    }

    if (offset >= data.length) return null;

    final imageData = data.sublist(offset);
    return (Uint8List.fromList(imageData), mimeType);
  }

  static String _trimNull(Uint8List bytes) {
    final end = bytes.indexOf(0);
    final slice = end >= 0 ? bytes.sublist(0, end) : bytes;
    return String.fromCharCodes(slice.where((b) => b >= 32)).trim();
  }
}
