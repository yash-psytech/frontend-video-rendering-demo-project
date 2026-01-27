import 'dart:io';

import 'package:http/http.dart' as http;

import 'file_storage_service.dart';

/// Result of a download operation
class DownloadResult {
  final bool success;
  final String? filePath;
  final String? errorMessage;

  DownloadResult._({required this.success, this.filePath, this.errorMessage});

  factory DownloadResult.success(String filePath) {
    return DownloadResult._(success: true, filePath: filePath);
  }

  factory DownloadResult.failure(String error) {
    return DownloadResult._(success: false, errorMessage: error);
  }
}

/// Service for downloading remote video and image files
class NetworkService {
  static const int _maxRetries = 3;
  static const Duration _timeout = Duration(seconds: 30);

  final FileStorageService _fileStorage;

  NetworkService({FileStorageService? fileStorage})
    : _fileStorage = fileStorage ?? FileStorageService.instance;

  /// Download a video from URL to local cache
  Future<DownloadResult> downloadVideo(
    String url, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final fileName = _getFileNameFromUrl(url, 'video.mp4');
      final localPath = await _fileStorage.getCachedVideoPath(fileName);

      // Check if already cached
      if (await _fileStorage.fileExists(localPath)) {
        onProgress?.call(1.0);
        return DownloadResult.success(localPath);
      }

      return await _downloadWithRetry(url, localPath, onProgress: onProgress);
    } catch (e) {
      return DownloadResult.failure('Failed to download video: $e');
    }
  }

  /// Download an image from URL to local cache
  Future<DownloadResult> downloadImage(
    String url, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final fileName = _getFileNameFromUrl(url, 'image.jpg');
      final localPath = await _fileStorage.getCachedImagePath(fileName);

      // Check if already cached
      if (await _fileStorage.fileExists(localPath)) {
        onProgress?.call(1.0);
        return DownloadResult.success(localPath);
      }

      return await _downloadWithRetry(url, localPath, onProgress: onProgress);
    } catch (e) {
      return DownloadResult.failure('Failed to download image: $e');
    }
  }

  /// Download file with retry logic
  Future<DownloadResult> _downloadWithRetry(
    String url,
    String localPath, {
    void Function(double progress)? onProgress,
  }) async {
    int attempts = 0;
    Duration delay = const Duration(seconds: 1);

    while (attempts < _maxRetries) {
      attempts++;
      try {
        final result = await _downloadFile(url, localPath, onProgress);
        if (result.success) {
          return result;
        }

        if (attempts < _maxRetries) {
          await Future.delayed(delay);
          delay *= 2; // Exponential backoff
        }
      } catch (e) {
        if (attempts >= _maxRetries) {
          return DownloadResult.failure(
            'Download failed after $attempts attempts: $e',
          );
        }
        await Future.delayed(delay);
        delay *= 2;
      }
    }

    return DownloadResult.failure(
      'Download failed after $_maxRetries attempts',
    );
  }

  /// Perform the actual download
  Future<DownloadResult> _downloadFile(
    String url,
    String localPath,
    void Function(double progress)? onProgress,
  ) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request).timeout(_timeout);

      if (response.statusCode != 200) {
        return DownloadResult.failure('Server returned ${response.statusCode}');
      }

      final totalBytes = response.contentLength ?? 0;
      int receivedBytes = 0;

      final file = File(localPath);
      final sink = file.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;

        if (totalBytes > 0 && onProgress != null) {
          onProgress(receivedBytes / totalBytes);
        }
      }

      await sink.close();
      onProgress?.call(1.0);

      return DownloadResult.success(localPath);
    } on SocketException {
      return DownloadResult.failure('No internet connection');
    } on HttpException catch (e) {
      return DownloadResult.failure('HTTP error: ${e.message}');
    } catch (e) {
      return DownloadResult.failure('Download error: $e');
    } finally {
      client.close();
    }
  }

  /// Extract filename from URL or use default
  String _getFileNameFromUrl(String url, String defaultName) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        final lastSegment = pathSegments.last;
        // Remove query parameters and get clean filename
        final cleanName = lastSegment.split('?').first;
        if (cleanName.isNotEmpty &&
            (cleanName.contains('.mp4') ||
                cleanName.contains('.jpg') ||
                cleanName.contains('.png') ||
                cleanName.contains('.jpeg'))) {
          // Add hash to make filename unique based on full URL
          final hash = url.hashCode.toRadixString(16);
          return '${hash}_$cleanName';
        }
      }
    } catch (_) {}

    // Generate unique name from URL hash
    final hash = url.hashCode.toRadixString(16);
    return '${hash}_$defaultName';
  }

  /// Check if device has network connectivity
  Future<bool> hasNetworkConnection() async {
    try {
      final result = await http
          .get(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 5));
      return result.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
