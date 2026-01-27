import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'models/branding_template.dart';
import 'services/file_storage_service.dart';
import 'services/network_service.dart';
import 'services/permission_service.dart';
import 'services/video_overlay_service.dart';
import 'widgets/export_progress_dialog.dart';
import 'widgets/video_player_widget.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      debugPrint('🚀 App Starting...');

      // Initialize global error handling
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        debugPrint('🔴 Flutter Error: ${details.exception}');
        debugPrint('Stack trace: ${details.stack}');
      };

      runApp(const VideoOverlayDemoApp());
    },
    (error, stack) {
      debugPrint('🔴 Uncaught Dart Error: $error');
      debugPrint('Stack trace: $stack');
    },
  );
}

class VideoOverlayDemoApp extends StatelessWidget {
  const VideoOverlayDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Video Overlay Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const DemoScreen(),
    );
  }
}

class DemoScreen extends StatefulWidget {
  const DemoScreen({super.key});

  @override
  State<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen> {
  // Sample URLs from the user's request
  static const String _sampleVideoUrl =
      'https://storage.googleapis.com/taza-ai-app.firebasestorage.app/content/hi/love/9.mp4';
  // Using a reliable placeholder photo (original Firebase URL may have expired token)
  static const String _samplePhotoUrl =
      'https://ui-avatars.com/api/?name=Demo+User&size=200&background=random&rounded=true';

  // Services
  late final NetworkService _networkService;

  late final VideoOverlayService _videoOverlay;
  late final PermissionService _permissionService;
  late final FileStorageService _fileStorage;

  // State
  AnimationType _selectedAnimation = AnimationType.slideUpFade;
  String _userName = 'Demo User';
  bool _isLoading = false; // Start with false to show UI immediately
  bool _isExporting = false;
  String? _errorMessage;
  String? _localVideoPath;
  String? _localPhotoPath;
  double _downloadProgress = 0.0;

  // Stream controller for export progress
  StreamController<double>? _exportProgressController;

  // Key for video player to restart animation
  final GlobalKey<VideoPlayerWidgetState> _videoPlayerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    debugPrint('🎬 DemoScreen initState');
    _initializeServices();
    // Download assets in background, but show UI immediately
    _downloadAssets();
  }

  void _initializeServices() {
    _fileStorage = FileStorageService.instance;
    _networkService = NetworkService(fileStorage: _fileStorage);
    // ImageCompositor is used internally by VideoOverlayService
    _videoOverlay = VideoOverlayService(fileStorageService: _fileStorage);
    _permissionService = PermissionService();
  }

  Future<void> _downloadAssets() async {
    debugPrint('📥 Starting asset download...');
    setState(() {
      _downloadProgress = 0.0;
    });

    try {
      // Download video
      debugPrint('📹 Downloading video...');
      final videoResult = await _networkService.downloadVideo(
        _sampleVideoUrl,
        onProgress: (p) {
          setState(() => _downloadProgress = p * 0.7);
          if ((p * 100).toInt() % 20 == 0) {
            debugPrint('📹 Video download: ${(p * 100).toInt()}%');
          }
        },
      );

      if (!videoResult.success) {
        debugPrint('❌ Video download failed: ${videoResult.errorMessage}');
        return;
      }
      _localVideoPath = videoResult.filePath;
      debugPrint('✅ Video downloaded: $_localVideoPath');

      // Download photo
      debugPrint('📷 Downloading photo...');
      final photoResult = await _networkService.downloadImage(
        _samplePhotoUrl,
        onProgress: (p) {
          setState(() => _downloadProgress = 0.7 + (p * 0.3));
        },
      );

      if (!photoResult.success) {
        debugPrint('❌ Photo download failed: ${photoResult.errorMessage}');
        return;
      }
      _localPhotoPath = photoResult.filePath;
      debugPrint('✅ Photo downloaded: $_localPhotoPath');

      setState(() {
        _downloadProgress = 1.0;
      });
      debugPrint('🎉 All assets downloaded!');
    } catch (e) {
      debugPrint('❌ Download error: $e');
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  BrandingTemplate get _currentTemplate => BrandingTemplate(
    animation: _selectedAnimation,
    userName: _userName,
    duration: const Duration(milliseconds: 500),
    delay: const Duration(milliseconds: 500),
  );

  Future<void> _handleExport() async {
    if (_localVideoPath == null || _localPhotoPath == null) {
      _showErrorSnackBar('Please wait for assets to download');
      return;
    }

    // Request permission
    final permissionResult = await _permissionService
        .requestStoragePermission();
    if (!permissionResult.granted) {
      if (permissionResult.permanentlyDenied && mounted) {
        final shouldOpenSettings = await PermissionService.showRationaleDialog(
          context,
          title: 'Permission Required',
          message: permissionResult.message,
        );
        if (shouldOpenSettings) {
          await openAppSettings();
        }
      } else {
        _showErrorSnackBar(permissionResult.message);
      }
      return;
    }

    // Show export dialog
    _exportProgressController = StreamController<double>.broadcast();

    setState(() => _isExporting = true);

    // Show progress dialog
    if (mounted) {
      showExportProgressDialog(
        context,
        progressStream: _exportProgressController!.stream,
        onCancel: () {
          // Cancellation handled internally or effectively instant
          _exportProgressController?.close();
          setState(() => _isExporting = false);
        },
      );
    }

    try {
      // Export video with overlay
      // Note: We skip manual asset generation here as the service handles it
      _exportProgressController?.add(0.2);
      debugPrint('🚀 _handleExport: Calling exportVideoWithOverlay...');

      final result = await _videoOverlay.exportVideoWithOverlay(
        videoPath: _localVideoPath!,
        photoPath: _localPhotoPath,
        template: _currentTemplate,
        onProgress: (progress) {
          _exportProgressController?.add(0.2 + (progress * 0.7));
        },
      );

      debugPrint(
        '✅ _handleExport: Export returned. Success: ${result.success}',
      );

      // Close progress dialog
      if (mounted) {
        Navigator.pop(context);
        debugPrint('✅ _handleExport: Progress dialog closed');
      }

      if (result.success) {
        // Save to gallery
        _exportProgressController?.add(0.95);
        debugPrint('💾 _handleExport: Saving to gallery...');
        final saved = await _videoOverlay.saveToGallery(result.outputPath!);
        debugPrint('💾 _handleExport: Saved to gallery: $saved');

        if (mounted) {
          debugPrint('✨ _handleExport: Showing success dialog');
          showExportResultDialog(
            context,
            success: saved,
            processingTime: result.duration,
            message: saved
                ? 'Video saved to internal storage (Emulator safe mode)'
                : 'Failed to save',
            onRetry: saved ? null : _handleExport,
          );
        }
      } else {
        if (mounted) {
          showExportResultDialog(
            context,
            success: false,
            message: result.errorMessage,
            onRetry: _handleExport,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close progress dialog
        showExportResultDialog(
          context,
          success: false,
          message: e.toString(),
          onRetry: _handleExport,
        );
      }
    } finally {
      _exportProgressController?.close();
      setState(() => _isExporting = false);

      // Cleanup overlay assets
      await _fileStorage.cleanupOverlays();
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  @override
  void dispose() {
    _exportProgressController?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Video Overlay Demo'), elevation: 0),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          // Video Player with Overlay
          _buildVideoPreview(),

          // Controls
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Animation Type Selector
                _buildAnimationSelector(),

                const SizedBox(height: 16),

                // User Name Input
                _buildNameInput(),

                const SizedBox(height: 24),

                // Action Buttons
                _buildActionButtons(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            value: _downloadProgress > 0 ? _downloadProgress : null,
          ),
          const SizedBox(height: 24),
          Text(
            'Downloading assets... ${(_downloadProgress * 100).toStringAsFixed(0)}%',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          Text(
            _downloadProgress < 0.7
                ? 'Downloading video...'
                : 'Downloading photo...',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Failed to load assets',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _downloadAssets,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPreview() {
    return Container(
      color: Colors.black,
      child: AspectRatio(
        aspectRatio: 9 / 16, // Vertical video
        child: VideoPlayerWidget(
          key: _videoPlayerKey,
          videoUrl: _sampleVideoUrl,
          videoPath: _localVideoPath, // Use local file if available
          photoUrl: _samplePhotoUrl,
          template: _currentTemplate,
          autoPlay: true,
          loop: true,
        ),
      ),
    );
  }

  Widget _buildAnimationSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Animation Type',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AnimationType.values.map((type) {
                final isSelected = _selectedAnimation == type;
                return ChoiceChip(
                  label: Text(_getAnimationLabel(type)),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedAnimation = type);
                      // Restart video to see new animation
                      _videoPlayerKey.currentState?.restartWithAnimation();
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  String _getAnimationLabel(AnimationType type) {
    switch (type) {
      case AnimationType.static:
        return 'Static';
      case AnimationType.fadeIn:
        return 'Fade In';
      case AnimationType.slideUp:
        return 'Slide Up';
      case AnimationType.slideUpFade:
        return 'Slide + Fade';
      case AnimationType.revolve:
        return 'Revolve';
      case AnimationType.slideFromRight:
        return 'Slide From Right';
    }
  }

  Widget _buildNameInput() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your Name', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: TextEditingController(text: _userName),
              decoration: const InputDecoration(
                hintText: 'Enter your name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              onChanged: (value) {
                setState(() => _userName = value.isEmpty ? 'Demo User' : value);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isExporting
                ? null
                : () {
                    _videoPlayerKey.currentState?.restartWithAnimation();
                  },
            icon: const Icon(Icons.replay),
            label: const Text('Replay Animation'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: _isExporting ? null : _handleExport,
            icon: _isExporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download),
            label: Text(_isExporting ? 'Exporting...' : 'Export Video'),
          ),
        ),
      ],
    );
  }
}
