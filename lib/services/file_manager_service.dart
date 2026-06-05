import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

enum DirectoryType {
  documents,
  applicationSupport,
  temporary,
  downloads,
}

class FileManagerService {
  static Future<Directory> _getDirectory(DirectoryType type) async {
    switch (type) {
      case DirectoryType.documents:
        return await getApplicationDocumentsDirectory();
      case DirectoryType.applicationSupport:
        return await getApplicationSupportDirectory();
      case DirectoryType.temporary:
        return await getTemporaryDirectory();
      case DirectoryType.downloads:
        if (Platform.isAndroid) {
          return Directory('/storage/emulated/0/Download');
        } else {
          return await getApplicationDocumentsDirectory();
        }
    }
  }

  static Future<String> createFolder(
    String folderName, {
    DirectoryType parentType = DirectoryType.documents,
    String? parentPath,
  }) async {
    Directory parentDir;
    if (parentPath != null) {
      parentDir = Directory(parentPath);
    } else {
      parentDir = await _getDirectory(parentType);
    }

    Directory newFolder = Directory(path.join(parentDir.path, folderName));
    if (!await newFolder.exists()) {
      await newFolder.create(recursive: true);
    }
    return newFolder.path;
  }

  static Future<String> createFile(
    String fileName, {
    DirectoryType parentType = DirectoryType.documents,
    String? parentPath,
    String? content,
  }) async {
    Directory parentDir;
    if (parentPath != null) {
      parentDir = Directory(parentPath);
    } else {
      parentDir = await _getDirectory(parentType);
    }

    File file = File(path.join(parentDir.path, fileName));
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    if (content != null) {
      await file.writeAsString(content);
    }
    return file.path;
  }

  static Future<bool> renameFolder(
    String oldPath,
    String newName,
  ) async {
    Directory dir = Directory(oldPath);
    if (!await dir.exists()) {
      return false;
    }

    String parentPath = path.dirname(oldPath);
    String newPath = path.join(parentPath, newName);

    try {
      await dir.rename(newPath);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> renameFile(
    String oldPath,
    String newName,
  ) async {
    File file = File(oldPath);
    if (!await file.exists()) {
      return false;
    }

    String parentPath = path.dirname(oldPath);
    String newPath = path.join(parentPath, newName);

    try {
      await file.rename(newPath);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> deleteFolder(
    String folderPath, {
    bool recursive = true,
  }) async {
    Directory dir = Directory(folderPath);
    if (!await dir.exists()) {
      return false;
    }

    try {
      await dir.delete(recursive: recursive);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> deleteFile(String filePath) async {
    File file = File(filePath);
    if (!await file.exists()) {
      return false;
    }

    try {
      await file.delete();
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<String> writeToFile(
    String filePath,
    String content, {
    bool append = false,
  }) async {
    File file = File(filePath);
    if (!await file.exists()) {
      await file.create(recursive: true);
    }

    if (append) {
      await file.writeAsString(content, mode: FileMode.append);
    } else {
      await file.writeAsString(content);
    }
    return file.path;
  }

  static Future<String?> readFromFile(String filePath) async {
    File file = File(filePath);
    if (!await file.exists()) {
      return null;
    }

    try {
      return await file.readAsString();
    } catch (e) {
      return null;
    }
  }

  static Future<bool> fileExists(String filePath) async {
    return await File(filePath).exists();
  }

  static Future<bool> folderExists(String folderPath) async {
    return await Directory(folderPath).exists();
  }

  static Future<List<FileSystemEntity>> listFiles(
    String folderPath, {
    bool recursive = false,
  }) async {
    Directory dir = Directory(folderPath);
    if (!await dir.exists()) {
      return [];
    }

    List<FileSystemEntity> entities = await dir.list(recursive: recursive).toList();
    return entities;
  }

  static Future<List<String>> listFileNames(
    String folderPath, {
    bool recursive = false,
  }) async {
    List<FileSystemEntity> entities = await listFiles(folderPath, recursive: recursive);
    return entities.map((entity) => path.basename(entity.path)).toList();
  }

  static Future<int> getFileSize(String filePath) async {
    File file = File(filePath);
    if (!await file.exists()) {
      return 0;
    }

    return await file.length();
  }

  static Future<DateTime?> getFileLastModified(String filePath) async {
    File file = File(filePath);
    if (!await file.exists()) {
      return null;
    }

    return await file.lastModified();
  }

  static String getFileExtension(String filePath) {
    return path.extension(filePath);
  }

  static String getFileName(String filePath) {
    return path.basename(filePath);
  }

  static String getFileNameWithoutExtension(String filePath) {
    return path.basenameWithoutExtension(filePath);
  }

  static String getParentPath(String filePath) {
    return path.dirname(filePath);
  }

  static Future<String> getDocumentsPath() async {
    return (await getApplicationDocumentsDirectory()).path;
  }

  static Future<String> getTemporaryPath() async {
    return (await getTemporaryDirectory()).path;
  }

  static Future<String> getApplicationSupportPath() async {
    return (await getApplicationSupportDirectory()).path;
  }

  static Future<String> getDownloadsPath() async {
    if (Platform.isAndroid) {
      return '/storage/emulated/0/Download';
    } else {
      return (await getApplicationDocumentsDirectory()).path;
    }
  }

  static Future<String> copyFile(String sourcePath, String destinationPath) async {
    File source = File(sourcePath);
    if (!await source.exists()) {
      throw Exception('Source file does not exist');
    }

    File destination = File(destinationPath);
    await source.copy(destination.path);
    return destination.path;
  }

  static Future<String> moveFile(String sourcePath, String destinationPath) async {
    File source = File(sourcePath);
    if (!await source.exists()) {
      throw Exception('Source file does not exist');
    }

    File destination = File(destinationPath);
    await source.rename(destination.path);
    return destination.path;
  }
}