import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/branding_template.dart';
import 'file_storage_service.dart';

/// Service for generating overlay image assets using Flutter Canvas.
/// Creates transparent PNGs for profile photos and name pills.
class ImageCompositorService {
  final FileStorageService _fileStorage;

  ImageCompositorService({FileStorageService? fileStorage})
    : _fileStorage = fileStorage ?? FileStorageService.instance;

  /// Generate a circular profile photo with optional border
  Future<String> generateCircularPhoto({
    required String sourceImagePath,
    required double size,
    double borderWidth = 3.0,
    Color borderColor = Colors.white,
  }) async {
    try {
      // Load source image
      final file = File(sourceImagePath);
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final sourceImage = frame.image;

      // Create a picture recorder
      final pictureRecorder = ui.PictureRecorder();
      final canvas = Canvas(pictureRecorder);

      final totalSize = size + (borderWidth * 2);
      final center = Offset(totalSize / 2, totalSize / 2);
      final radius = size / 2;

      // Draw white border circle
      if (borderWidth > 0) {
        final borderPaint = Paint()
          ..color = borderColor
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, radius + borderWidth, borderPaint);
      }

      // Clip to circle and draw image
      canvas.save();
      final clipPath = Path()
        ..addOval(Rect.fromCircle(center: center, radius: radius));
      canvas.clipPath(clipPath);

      // Scale image to fit
      final srcSize = Size(
        sourceImage.width.toDouble(),
        sourceImage.height.toDouble(),
      );
      final minDimension = srcSize.width < srcSize.height
          ? srcSize.width
          : srcSize.height;
      final srcRect = Rect.fromCenter(
        center: Offset(srcSize.width / 2, srcSize.height / 2),
        width: minDimension,
        height: minDimension,
      );
      final dstRect = Rect.fromCircle(center: center, radius: radius);

      canvas.drawImageRect(sourceImage, srcRect, dstRect, Paint());
      canvas.restore();

      // Convert to image
      final picture = pictureRecorder.endRecording();
      final outputImage = await picture.toImage(
        totalSize.toInt(),
        totalSize.toInt(),
      );
      final byteData = await outputImage.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData == null) {
        throw Exception('Failed to convert image to bytes');
      }

      // Save to file
      final outputPath = await _fileStorage.getOverlayAssetPath(
        'profile_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(byteData.buffer.asUint8List());

      // Cleanup
      sourceImage.dispose();
      outputImage.dispose();

      return outputPath;
    } catch (e) {
      throw Exception('Failed to generate circular photo: $e');
    }
  }

  /// Generate a name pill (text on semi-transparent background)
  Future<String> generateNamePill({
    required String name,
    double fontSize = 16.0,
    Color textColor = Colors.white,
    Color backgroundColor = Colors.black54,
    double paddingH = 16.0,
    double paddingV = 8.0,
    double borderRadius = 20.0,
  }) async {
    try {
      // Measure text size
      final textPainter = TextPainter(
        text: TextSpan(
          text: name,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final width = textPainter.width + (paddingH * 2);
      final height = textPainter.height + (paddingV * 2);

      // Create canvas
      final pictureRecorder = ui.PictureRecorder();
      final canvas = Canvas(pictureRecorder);

      // Draw rounded rectangle background
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, width, height),
        Radius.circular(borderRadius),
      );
      final bgPaint = Paint()..color = backgroundColor;
      canvas.drawRRect(rrect, bgPaint);

      // Draw text
      textPainter.paint(canvas, Offset(paddingH, paddingV));

      // Convert to image
      final picture = pictureRecorder.endRecording();
      final outputImage = await picture.toImage(width.toInt(), height.toInt());
      final byteData = await outputImage.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData == null) {
        throw Exception('Failed to convert name pill to bytes');
      }

      // Save to file
      final outputPath = await _fileStorage.getOverlayAssetPath(
        'name_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(byteData.buffer.asUint8List());

      outputImage.dispose();

      return outputPath;
    } catch (e) {
      throw Exception('Failed to generate name pill: $e');
    }
  }

  /// Generate both photo and name pill assets
  Future<({String photoPath, String namePath})> generateBrandingAssets({
    required String sourcePhotoPath,
    required String userName,
    double photoSize = 60.0,
  }) async {
    final photoPath = await generateCircularPhoto(
      sourceImagePath: sourcePhotoPath,
      size: photoSize,
    );

    final namePath = await generateNamePill(name: userName);

    return (photoPath: photoPath, namePath: namePath);
  }

  /// Generate a circular profile photo asset for FFmpeg overlay
  /// Returns the file path to the generated PNG
  Future<String> generatePhotoAsset(
    String sourceImagePath, {
    double size = 60.0,
  }) async {
    return generateCircularPhoto(sourceImagePath: sourceImagePath, size: size);
  }

  /// Generate a name pill asset for FFmpeg overlay
  /// Returns the file path to the generated PNG
  Future<String> generateNameAsset(String name) async {
    return generateNamePill(name: name);
  }

  /// Generate a single composed overlay image containing both photo and name
  /// correctly positioned relative to a 1080x1920 frame.
  Future<String?> generateComposedOverlay({
    required BrandingTemplate template,
    String? photoPath,
  }) async {
    try {
      // 1. Define canvas size (referencing 1080p vertical video)
      const width = 1080.0;
      const height = 1920.0;
      final pictureRecorder = ui.PictureRecorder();
      final canvas = Canvas(pictureRecorder);

      // 2. Generate individual assets
      String? generatedPhotoPath;
      if (photoPath != null) {
        generatedPhotoPath = await generateCircularPhoto(
          sourceImagePath: photoPath,
          size: template.photoSize, // nominal size
        );
      }
      final namePath = await generateNamePill(name: template.userName);

      // 3. Load assets as UI Images
      ui.Image? photoImage;
      if (generatedPhotoPath != null) {
        final photoBytes = await File(generatedPhotoPath).readAsBytes();
        photoImage = await decodeImageFromList(photoBytes);
      }

      final nameBytes = await File(namePath).readAsBytes();
      final nameImage = await decodeImageFromList(nameBytes);

      // 4. Calculate Positions (using the template's Y relative coordinates)
      // Note: template.photoY is relative to Height (0.0 - 1.0)

      double photoY = template.photoY * height;
      // Adjust for centering (the template logic was H*y - h/2)
      if (photoImage != null) {
        photoY -= photoImage.height / 2;
      }

      double nameY = template.nameY * height;
      nameY -= nameImage.height / 2;

      // 5. Draw Photo
      if (photoImage != null) {
        final photoOffset = Offset(
          (width - photoImage.width) / 2, // Center horizontally
          photoY,
        );
        canvas.drawImage(photoImage, photoOffset, Paint());
      }

      // 6. Draw Name
      final nameOffset = Offset(
        (width - nameImage.width) / 2, // Center horizontally
        nameY,
      );
      canvas.drawImage(nameImage, nameOffset, Paint());

      // 7. Save Composition
      final picture = pictureRecorder.endRecording();
      final outputImage = await picture.toImage(width.toInt(), height.toInt());
      final byteData = await outputImage.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData == null) return null;

      final outputPath = await _fileStorage.getOverlayAssetPath(
        'composed_overlay_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await File(outputPath).writeAsBytes(byteData.buffer.asUint8List());

      // Cleanup
      photoImage?.dispose();
      nameImage.dispose();
      outputImage.dispose();

      return outputPath;
    } catch (e) {
      debugPrint('Error generating composed overlay: $e');
      return null;
    }
  }
}
