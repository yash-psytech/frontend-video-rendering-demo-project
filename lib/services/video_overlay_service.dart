import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';
import 'package:gal/gal.dart';

import '../models/branding_template.dart';
import 'file_storage_service.dart';
import 'image_compositor_service.dart';

/// Result of a video export operation
class ExportResult {
  final bool success;
  final String? outputPath;
  final String? errorMessage;
  final Duration? duration;

  ExportResult({
    required this.success,
    this.outputPath,
    this.errorMessage,
    this.duration,
  });

  factory ExportResult.success(String path, Duration duration) =>
      ExportResult(success: true, outputPath: path, duration: duration);

  factory ExportResult.failure(String error) =>
      ExportResult(success: false, errorMessage: error);
}

/// Service for exporting videos with animated overlays using FFmpeg.
/// Supports multiple animation types including Slide From Right.
class VideoOverlayService {
  final ImageCompositorService _imageCompositorService;
  final FileStorageService _fileStorageService;

  // Track active session for cancellation
  int? _activeSessionId;
  bool _isCancelled = false;

  VideoOverlayService({
    ImageCompositorService? imageCompositorService,
    FileStorageService? fileStorageService,
  }) : _imageCompositorService =
           imageCompositorService ?? ImageCompositorService(),
       _fileStorageService = fileStorageService ?? FileStorageService.instance;

  /// Export video with branding overlay using FFmpeg
  /// Supports animated overlays (Fade In, Slide Up, Slide From Right)
  Future<ExportResult> exportVideoWithOverlay({
    required String videoPath,
    required BrandingTemplate template,
    String? photoPath,
    required Function(double) onProgress,
  }) async {
    final startTime = DateTime.now();
    _isCancelled = false;

    try {
      debugPrint(
        'Starting FFmpeg export with animation: ${template.animation}',
      );

      // 1. Generate separate overlay assets for animation
      String? generatedPhotoPath;
      String? generatedNamePath;

      if (photoPath != null) {
        debugPrint('Generating photo asset...');
        generatedPhotoPath = await _imageCompositorService.generatePhotoAsset(
          photoPath,
          size: template.photoSize,
        );
        debugPrint('Photo asset generated: $generatedPhotoPath');
      }

      debugPrint('Generating name asset...');
      generatedNamePath = await _imageCompositorService.generateNameAsset(
        template.userName,
      );
      debugPrint('Name asset generated: $generatedNamePath');

      onProgress(0.1);

      // 2. Get video metadata for positioning calculations
      final videoFile = File(videoPath);
      if (!await videoFile.exists()) {
        return ExportResult.failure('Video file not found');
      }

      // 3. Prepare output path
      final outputPath = await _fileStorageService.getExportOutputPath();

      // 4. Build FFmpeg command based on animation type
      final ffmpegCommand = _buildFFmpegCommand(
        videoPath: videoPath,
        photoPath: generatedPhotoPath,
        namePath: generatedNamePath,
        outputPath: outputPath,
        template: template,
      );

      debugPrint('FFmpeg command: $ffmpegCommand');

      // 5. Execute FFmpeg with progress tracking
      final completer = Completer<ExportResult>();

      // Enable statistics callback for progress
      FFmpegKitConfig.enableStatisticsCallback((Statistics statistics) {
        // Calculate progress based on time processed
        // We estimate video duration as 30 seconds for progress calculation
        final timeInMs = statistics.getTime();
        if (timeInMs > 0) {
          // Assume 30 second video for progress estimation
          final estimatedDurationMs = 30000;
          final progress = (timeInMs / estimatedDurationMs).clamp(0.0, 0.9);
          onProgress(0.1 + progress * 0.8);
        }
      });

      final session = await FFmpegKit.executeAsync(
        ffmpegCommand,
        (session) async {
          // Completion callback
          final returnCode = await session.getReturnCode();
          final duration = DateTime.now().difference(startTime);

          if (_isCancelled) {
            // Clean up output file if cancelled
            final outputFile = File(outputPath);
            if (await outputFile.exists()) {
              await outputFile.delete();
            }
            completer.complete(ExportResult.failure('Export cancelled'));
          } else if (ReturnCode.isSuccess(returnCode)) {
            debugPrint(
              'FFmpeg export completed in ${duration.inMilliseconds}ms',
            );
            onProgress(1.0);
            completer.complete(ExportResult.success(outputPath, duration));
          } else {
            final logs = await session.getLogsAsString();
            debugPrint('FFmpeg error logs: $logs');
            completer.complete(
              ExportResult.failure('FFmpeg failed with code: $returnCode'),
            );
          }
        },
        (log) {
          // Log callback - useful for debugging
          debugPrint('FFmpeg: ${log.getMessage()}');
        },
      );

      _activeSessionId = session.getSessionId();

      return await completer.future;
    } catch (e, stack) {
      debugPrint('FFmpeg export error: $e');
      debugPrint('Stack trace: $stack');
      return ExportResult.failure('Export error: $e');
    }
  }

  /// Build the FFmpeg command based on animation type
  String _buildFFmpegCommand({
    required String videoPath,
    String? photoPath,
    String? namePath,
    required String outputPath,
    required BrandingTemplate template,
  }) {
    final animationDuration = template.durationSeconds;
    final delay = template.delaySeconds;

    // Base positions (centered horizontally, positioned near bottom)
    // Photo at ~85% from top, Name at ~92% from top of 1920p video
    const photoYPosition = 'H-500'; // 500px from bottom
    const nameYPosition = 'H-250'; // 250px from bottom

    String filterComplex;

    switch (template.animation) {
      case AnimationType.slideFromRight:
        // Slide from right to center animation
        // Formula: x = EndX + (StartX - EndX) * (1 - min((t-delay)/duration, 1))
        // StartX = W (off-screen right)
        // EndX = (W-w)/2 (center)
        filterComplex = _buildSlideFromRightFilter(
          photoPath: photoPath,
          namePath: namePath,
          photoYPosition: photoYPosition,
          nameYPosition: nameYPosition,
          duration: animationDuration,
          delay: delay,
        );
        break;

      case AnimationType.fadeIn:
        filterComplex = _buildFadeInFilter(
          photoPath: photoPath,
          namePath: namePath,
          photoYPosition: photoYPosition,
          nameYPosition: nameYPosition,
          duration: animationDuration,
          delay: delay,
        );
        break;

      case AnimationType.slideUp:
      case AnimationType.slideUpFade:
        filterComplex = _buildSlideUpFilter(
          photoPath: photoPath,
          namePath: namePath,
          photoYPosition: photoYPosition,
          nameYPosition: nameYPosition,
          duration: animationDuration,
          delay: delay,
          withFade: template.animation == AnimationType.slideUpFade,
        );
        break;

      case AnimationType.revolve:
        filterComplex = _buildRevolveFilter(
          photoPath: photoPath,
          namePath: namePath,
          photoYPosition: photoYPosition,
          nameYPosition: nameYPosition,
          duration: animationDuration,
          delay: delay,
          photoSize: template.photoSize,
        );
        break;

      case AnimationType.static:
        // Static overlay (no animation)
        filterComplex = _buildStaticFilter(
          photoPath: photoPath,
          namePath: namePath,
          photoYPosition: photoYPosition,
          nameYPosition: nameYPosition,
        );
        break;
    }

    // Build the input string
    // Note: -loop 1 before image inputs makes them repeat for the video duration
    final inputs = StringBuffer();
    inputs.write('-i "$videoPath"');
    if (photoPath != null) {
      inputs.write(' -loop 1 -i "$photoPath"');
    }
    if (namePath != null) {
      inputs.write(' -loop 1 -i "$namePath"');
    }

    // Build the complete command
    // Use libx264 software encoder with ultrafast preset for best compatibility
    // The full GPL FFmpeg package includes libx264 and PNG decoder
    return '${inputs.toString()} '
        '-filter_complex "$filterComplex" '
        '-map "[out]" -map 0:a? '
        '-c:v libx264 -preset ultrafast -crf 23 '
        '-c:a copy -shortest '
        '-y "$outputPath"';
  }

  /// Build Slide From Right animation filter
  String _buildSlideFromRightFilter({
    String? photoPath,
    String? namePath,
    required String photoYPosition,
    required String nameYPosition,
    required double duration,
    required double delay,
  }) {
    final filters = <String>[];
    int inputIndex = 1;

    // Animation formula for slide from right:
    // x = (W-w)/2 + (W - (W-w)/2) * (1 - min(max((t-delay)/duration, 0), 1))
    // Simplified: x = (W-w)/2 + W/2 + w/2 * ease_factor
    // where ease_factor goes from 1 (off-screen) to 0 (centered)

    String previousOutput = '0:v';

    if (photoPath != null) {
      final photoXExpr = _buildSlideRightXExpression(duration, delay);
      filters.add(
        '[$previousOutput][$inputIndex:v] overlay='
        "x='$photoXExpr':"
        "y='$photoYPosition':"
        "enable='gte(t,$delay)' [bg_photo]",
      );
      previousOutput = 'bg_photo';
      inputIndex++;
    }

    if (namePath != null) {
      final nameXExpr = _buildSlideRightXExpression(duration, delay);
      final outputLabel = photoPath != null ? 'out' : 'out';
      filters.add(
        '[$previousOutput][$inputIndex:v] overlay='
        "x='$nameXExpr':"
        "y='$nameYPosition':"
        "enable='gte(t,$delay)' [$outputLabel]",
      );
    } else if (photoPath != null) {
      // If only photo, rename bg_photo to out
      filters.add('[bg_photo] copy [out]');
    } else {
      // No overlays, just pass through
      filters.add('[0:v] copy [out]');
    }

    return filters.join('; ');
  }

  /// Build the X expression for slide from right animation
  String _buildSlideRightXExpression(double duration, double delay) {
    // x = (W-w)/2 + (W/2 + w/2) * max(1 - (t-delay)/duration, 0)
    // This starts at W (off-screen right) and ends at (W-w)/2 (center)
    return "(W-w)/2 + (W/2+w/2) * max(1 - (t-$delay)/$duration, 0)";
  }

  /// Build Fade In animation filter
  String _buildFadeInFilter({
    String? photoPath,
    String? namePath,
    required String photoYPosition,
    required String nameYPosition,
    required double duration,
    required double delay,
  }) {
    final filters = <String>[];
    int inputIndex = 1;
    String previousOutput = '0:v';

    // For fade in, we use the format filter to add alpha and fade it
    if (photoPath != null) {
      // Apply fade to photo
      filters.add(
        '[$inputIndex:v] format=rgba, '
        "fade=t=in:st=$delay:d=$duration:alpha=1 [photo_faded]",
      );
      filters.add(
        '[$previousOutput][photo_faded] overlay='
        "x='(W-w)/2':"
        "y='$photoYPosition':"
        "format=auto [bg_photo]",
      );
      previousOutput = 'bg_photo';
      inputIndex++;
    }

    if (namePath != null) {
      filters.add(
        '[$inputIndex:v] format=rgba, '
        "fade=t=in:st=$delay:d=$duration:alpha=1 [name_faded]",
      );
      filters.add(
        '[$previousOutput][name_faded] overlay='
        "x='(W-w)/2':"
        "y='$nameYPosition':"
        "format=auto [out]",
      );
    } else if (photoPath != null) {
      filters.add('[bg_photo] copy [out]');
    } else {
      filters.add('[0:v] copy [out]');
    }

    return filters.join('; ');
  }

  /// Build Slide Up animation filter
  String _buildSlideUpFilter({
    String? photoPath,
    String? namePath,
    required String photoYPosition,
    required String nameYPosition,
    required double duration,
    required double delay,
    bool withFade = false,
  }) {
    final filters = <String>[];
    int inputIndex = 1;
    String previousOutput = '0:v';

    // Slide up: y starts at H (off-screen bottom) and ends at target position
    // y = targetY + (H - targetY) * max(1 - (t-delay)/duration, 0)

    if (photoPath != null) {
      final fadeFilter = withFade
          ? "fade=t=in:st=$delay:d=$duration:alpha=1, "
          : '';
      filters.add(
        '[$inputIndex:v] format=rgba, $fadeFilter'
        "null [photo_prep]",
      );

      final photoYExpr =
          "$photoYPosition + (H - ($photoYPosition)) * max(1 - (t-$delay)/$duration, 0)";
      filters.add(
        '[$previousOutput][photo_prep] overlay='
        "x='(W-w)/2':"
        "y='$photoYExpr':"
        "enable='gte(t,$delay)' [bg_photo]",
      );
      previousOutput = 'bg_photo';
      inputIndex++;
    }

    if (namePath != null) {
      final fadeFilter = withFade
          ? "fade=t=in:st=$delay:d=$duration:alpha=1, "
          : '';
      filters.add(
        '[$inputIndex:v] format=rgba, $fadeFilter'
        "null [name_prep]",
      );

      final nameYExpr =
          "$nameYPosition + (H - ($nameYPosition)) * max(1 - (t-$delay)/$duration, 0)";
      filters.add(
        '[$previousOutput][name_prep] overlay='
        "x='(W-w)/2':"
        "y='$nameYExpr':"
        "enable='gte(t,$delay)' [out]",
      );
    } else if (photoPath != null) {
      filters.add('[bg_photo] copy [out]');
    } else {
      filters.add('[0:v] copy [out]');
    }

    return filters.join('; ');
  }

  /// Build Static overlay filter (no animation)
  String _buildStaticFilter({
    String? photoPath,
    String? namePath,
    required String photoYPosition,
    required String nameYPosition,
  }) {
    final filters = <String>[];
    int inputIndex = 1;
    String previousOutput = '0:v';

    if (photoPath != null) {
      filters.add(
        '[$previousOutput][$inputIndex:v] overlay='
        "x='(W-w)/2':"
        "y='$photoYPosition' [bg_photo]",
      );
      previousOutput = 'bg_photo';
      inputIndex++;
    }

    if (namePath != null) {
      filters.add(
        '[$previousOutput][$inputIndex:v] overlay='
        "x='(W-w)/2':"
        "y='$nameYPosition' [out]",
      );
    } else if (photoPath != null) {
      filters.add('[bg_photo] copy [out]');
    } else {
      filters.add('[0:v] copy [out]');
    }

    return filters.join('; ');
  }

  /// Build Revolve animation filter
  String _buildRevolveFilter({
    String? photoPath,
    String? namePath,
    required String photoYPosition,
    required String nameYPosition,
    required double duration,
    required double delay,
    required double photoSize,
  }) {
    final filters = <String>[];
    int inputIndex = 1;
    String previousOutput = '0:v';

    // Revolve: Rotates from -30 degrees (-0.5 rad) to 0.
    // Also fades in slightly to be smooth.
    // angle = -0.5 * max(1 - (t-delay)/duration, 0)

    if (photoPath != null) {
      // Apply rotation and fade
      // Use fillcolor=none (or c=none) for transparency
      filters.add(
        '[$inputIndex:v] format=rgba, '
        "fade=t=in:st=$delay:d=$duration:alpha=1, "
        "rotate=angle='if(gte(t,$delay), -0.5 * max(1 - (t-$delay)/$duration, 0), -0.5)':"
        "fillcolor=none:ow='rotw(iw)':oh='roth(ih)' [photo_rotated]",
      );

      // Positioning needs to account for the center rotation
      // Since rotation changes dimensions, we center it.
      // Overlay coordinates x,y are top-left.
      // We want to center it at (W-w)/2, etc.
      // Since w, h change with rotation, centering formula (W-w)/2 works dynamically if w is input width
      filters.add(
        '[$previousOutput][photo_rotated] overlay='
        "x='(W-w)/2':"
        "y='$photoYPosition + (roth($photoSize) - h)/2':" // Adjust Y to keep center stable-ish
        "enable='gte(t,$delay)' [bg_photo]",
      );
      previousOutput = 'bg_photo';
      inputIndex++;
    }

    if (namePath != null) {
      // Name also revolves or just fades? Let's revolve it too for consistency.
      filters.add(
        '[$inputIndex:v] format=rgba, '
        "fade=t=in:st=$delay:d=$duration:alpha=1, "
        "rotate=angle='if(gte(t,$delay), -0.5 * max(1 - (t-$delay)/$duration, 0), -0.5)':"
        "fillcolor=none:ow='rotw(iw)':oh='roth(ih)' [name_rotated]",
      );

      filters.add(
        '[$previousOutput][name_rotated] overlay='
        "x='(W-w)/2':"
        "y='$nameYPosition':"
        "enable='gte(t,$delay)' [out]",
      );
    } else if (photoPath != null) {
      filters.add('[bg_photo] copy [out]');
    } else {
      filters.add('[0:v] copy [out]');
    }

    return filters.join('; ');
  }

  /// Cancel the current export operation
  Future<void> cancelExport() async {
    _isCancelled = true;
    if (_activeSessionId != null) {
      try {
        await FFmpegKit.cancel(_activeSessionId!);
        debugPrint('FFmpeg export cancelled');
      } catch (e) {
        debugPrint('Error cancelling FFmpeg: $e');
      }
    }
    _activeSessionId = null;
  }

  /// Save exported video to device gallery
  Future<bool> saveToGallery(String videoPath) async {
    try {
      await Gal.putVideo(videoPath, album: 'Branded Videos');
      debugPrint('Video saved to gallery: $videoPath');
      return true;
    } catch (e) {
      debugPrint('Gallery save error: $e');
      // Fallback: video is still available at the output path
      debugPrint('Video available at: $videoPath');
      return false;
    }
  }
}
