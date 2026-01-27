import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/branding_template.dart';
import 'animated_branding_overlay.dart';

/// Video player widget with branding overlay
class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final String? videoPath;
  final String? photoUrl;
  final BrandingTemplate template;
  final bool autoPlay;
  final bool loop;
  final VoidCallback? onInitialized;
  final VoidCallback? onError;

  const VideoPlayerWidget({
    super.key,
    required this.videoUrl,
    this.videoPath,
    this.photoUrl,
    required this.template,
    this.autoPlay = true,
    this.loop = true,
    this.onInitialized,
    this.onError,
  });

  @override
  State<VideoPlayerWidget> createState() => VideoPlayerWidgetState();
}

class VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;
  final GlobalKey<AnimatedBrandingOverlayState> _overlayKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void didUpdateWidget(VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl ||
        oldWidget.videoPath != widget.videoPath) {
      _disposeController();
      _initializeVideo();
    }
  }

  Future<void> _initializeVideo() async {
    debugPrint('🎥 VideoPlayer: Starting initialization...');
    try {
      if (widget.videoPath != null) {
        debugPrint('🎥 VideoPlayer: Using local file: ${widget.videoPath}');
        _controller = VideoPlayerController.file(File(widget.videoPath!));
      } else {
        debugPrint('🎥 VideoPlayer: Using network URL: ${widget.videoUrl}');
        _controller = VideoPlayerController.networkUrl(
          Uri.parse(widget.videoUrl),
        );
      }

      debugPrint('🎥 VideoPlayer: Calling initialize()...');
      await _controller!.initialize();
      debugPrint(
        '🎥 VideoPlayer: Initialized successfully! Duration: ${_controller!.value.duration}',
      );

      if (widget.loop) {
        _controller!.setLooping(true);
      }

      if (widget.autoPlay) {
        debugPrint('🎥 VideoPlayer: Starting playback...');
        _controller!.play();
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _hasError = false;
        });
        debugPrint(
          '🎥 VideoPlayer: State updated, playing = ${_controller!.value.isPlaying}',
        );
        widget.onInitialized?.call();
      }
    } catch (e) {
      debugPrint('❌ VideoPlayer: Initialization failed: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
        widget.onError?.call();
      }
    }
  }

  void _disposeController() {
    _controller?.dispose();
    _controller = null;
    _isInitialized = false;
  }

  /// Restart video and animation
  void restartWithAnimation() {
    _controller?.seekTo(Duration.zero);
    _controller?.play();
    _overlayKey.currentState?.restartAnimation();
  }

  /// Get current playback position
  Duration get currentPosition => _controller?.value.position ?? Duration.zero;

  /// Get video duration
  Duration get videoDuration => _controller?.value.duration ?? Duration.zero;

  /// Play video
  void play() => _controller?.play();

  /// Pause video
  void pause() => _controller?.pause();

  /// Seek to position
  void seekTo(Duration position) => _controller?.seekTo(position);

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildErrorWidget();
    }

    if (!_isInitialized) {
      return _buildLoadingWidget();
    }

    return AspectRatio(
      aspectRatio: _controller!.value.aspectRatio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video layer
          VideoPlayer(_controller!),

          // Branding overlay
          AnimatedBrandingOverlay(
            key: _overlayKey,
            template: widget.template,
            photoUrl: widget.photoUrl,
            autoPlay: widget.autoPlay,
          ),

          // Play/Pause overlay (tap to toggle)
          GestureDetector(
            onTap: () {
              setState(() {
                if (_controller!.value.isPlaying) {
                  _controller!.pause();
                } else {
                  _controller!.play();
                }
              });
            },
            child: Container(
              color: Colors.transparent,
              child: AnimatedOpacity(
                opacity: _controller!.value.isPlaying ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text('Loading video...', style: TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Failed to load video',
              style: TextStyle(color: Colors.white),
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _hasError = false;
                });
                _initializeVideo();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
