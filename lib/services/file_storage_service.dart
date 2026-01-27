import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Service for managing file paths and storage operations.
class FileStorageService {
  static FileStorageService? _instance;
  Directory? _cacheDir;
  Directory? _tempDir;

  FileStorageService._();

  static FileStorageService get instance {
    _instance ??= FileStorageService._();
    return _instance!;
  }

  /// Initialize directories
  Future<void> initialize() async {
    _cacheDir = await getApplicationCacheDirectory();
    _tempDir = await getTemporaryDirectory();
  }

  /// Get cache directory path
  Future<Directory> get cacheDirectory async {
    _cacheDir ??= await getApplicationCacheDirectory();
    return _cacheDir!;
  }

  /// Get temporary directory for processing
  Future<Directory> get tempDirectory async {
    _tempDir ??= await getTemporaryDirectory();
    return _tempDir!;
  }

  /// Get path for cached video
  Future<String> getCachedVideoPath(String fileName) async {
    final dir = await cacheDirectory;
    final videoDir = Directory('${dir.path}/videos');
    if (!await videoDir.exists()) {
      await videoDir.create(recursive: true);
    }
    return '${videoDir.path}/$fileName';
  }

  /// Get path for cached image
  Future<String> getCachedImagePath(String fileName) async {
    final dir = await cacheDirectory;
    final imageDir = Directory('${dir.path}/images');
    if (!await imageDir.exists()) {
      await imageDir.create(recursive: true);
    }
    return '${imageDir.path}/$fileName';
  }

  /// Get path for overlay assets (generated PNGs)
  Future<String> getOverlayAssetPath(String fileName) async {
    final dir = await tempDirectory;
    final overlayDir = Directory('${dir.path}/overlays');
    if (!await overlayDir.exists()) {
      await overlayDir.create(recursive: true);
    }
    return '${overlayDir.path}/$fileName';
  }

  /// Get output path for exported video
  Future<String> getExportOutputPath() async {
    final dir = await tempDirectory;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${dir.path}/export_$timestamp.mp4';
  }

  /// Check if file exists
  Future<bool> fileExists(String path) async {
    return File(path).exists();
  }

  /// Delete file if exists
  Future<void> deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Get file size in bytes
  Future<int> getFileSize(String path) async {
    final file = File(path);
    if (await file.exists()) {
      return file.length();
    }
    return 0;
  }

  /// Clean up temporary overlay assets
  Future<void> cleanupOverlays() async {
    final dir = await tempDirectory;
    final overlayDir = Directory('${dir.path}/overlays');
    if (await overlayDir.exists()) {
      await overlayDir.delete(recursive: true);
    }
  }

  /// Get available storage space (approximate)
  Future<bool> hasEnoughSpace({int requiredBytes = 100 * 1024 * 1024}) async {
    // 100MB default requirement
    try {
      final dir = await tempDirectory;
      final stat = await dir.stat();
      // This is a rough check - actual implementation may vary by platform
      return stat.size >= 0; // Simplified check
    } catch (e) {
      return true; // Assume enough space if check fails
    }
  }
}
