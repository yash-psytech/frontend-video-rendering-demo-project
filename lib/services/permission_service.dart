import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Result of a permission request
class PermissionResult {
  final bool granted;
  final bool permanentlyDenied;
  final String message;

  PermissionResult({
    required this.granted,
    this.permanentlyDenied = false,
    required this.message,
  });
}

/// Service for handling runtime permissions
class PermissionService {
  /// Request storage/photos permission for saving videos
  Future<PermissionResult> requestStoragePermission() async {
    if (Platform.isAndroid) {
      return await _requestAndroidStoragePermission();
    } else if (Platform.isIOS) {
      return await _requestIOSPhotosPermission();
    }
    return PermissionResult(
      granted: true,
      message: 'Platform does not require permission',
    );
  }

  /// Handle Android storage permissions (different for API levels)
  Future<PermissionResult> _requestAndroidStoragePermission() async {
    // Check Android version
    // Android 13+ (API 33+) uses granular media permissions
    // Android 10-12 (API 29-32) uses READ_EXTERNAL_STORAGE
    // Android 9 and below uses WRITE_EXTERNAL_STORAGE

    // First try photos permission (Android 13+)
    var status = await Permission.photos.status;

    if (status.isGranted) {
      return PermissionResult(granted: true, message: 'Permission granted');
    }

    if (status.isPermanentlyDenied) {
      return PermissionResult(
        granted: false,
        permanentlyDenied: true,
        message: 'Permission permanently denied. Please enable in Settings.',
      );
    }

    // Request permission
    status = await Permission.photos.request();

    if (status.isGranted) {
      return PermissionResult(granted: true, message: 'Permission granted');
    }

    // If photos permission denied, try storage (older Android)
    status = await Permission.storage.status;

    if (status.isGranted) {
      return PermissionResult(granted: true, message: 'Permission granted');
    }

    if (status.isPermanentlyDenied) {
      return PermissionResult(
        granted: false,
        permanentlyDenied: true,
        message:
            'Storage permission permanently denied. Please enable in Settings.',
      );
    }

    status = await Permission.storage.request();

    if (status.isGranted) {
      return PermissionResult(granted: true, message: 'Permission granted');
    }

    return PermissionResult(
      granted: false,
      permanentlyDenied: status.isPermanentlyDenied,
      message: 'Storage permission denied',
    );
  }

  /// Handle iOS photo library permission
  Future<PermissionResult> _requestIOSPhotosPermission() async {
    var status = await Permission.photos.status;

    if (status.isGranted || status.isLimited) {
      return PermissionResult(granted: true, message: 'Permission granted');
    }

    if (status.isPermanentlyDenied) {
      return PermissionResult(
        granted: false,
        permanentlyDenied: true,
        message: 'Photo library access denied. Please enable in Settings.',
      );
    }

    status = await Permission.photos.request();

    if (status.isGranted || status.isLimited) {
      return PermissionResult(granted: true, message: 'Permission granted');
    }

    return PermissionResult(
      granted: false,
      permanentlyDenied: status.isPermanentlyDenied,
      message: 'Photo library permission denied',
    );
  }

  /// Open app settings for user to grant permissions
  Future<bool> openAppSettings() async {
    return await openAppSettings();
  }

  /// Show permission rationale dialog
  static Future<bool> showRationaleDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
