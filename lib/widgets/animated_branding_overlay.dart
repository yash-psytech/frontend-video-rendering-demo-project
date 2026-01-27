import 'package:flutter/material.dart';

import '../models/branding_template.dart';

/// Animated branding overlay widget that mirrors FFmpeg animations.
/// Used for real-time preview in the Flutter UI.
class AnimatedBrandingOverlay extends StatefulWidget {
  final BrandingTemplate template;
  final String? photoUrl;
  final bool autoPlay;
  final VoidCallback? onAnimationComplete;

  const AnimatedBrandingOverlay({
    super.key,
    required this.template,
    this.photoUrl,
    this.autoPlay = true,
    this.onAnimationComplete,
  });

  @override
  State<AnimatedBrandingOverlay> createState() =>
      AnimatedBrandingOverlayState();
}

class AnimatedBrandingOverlayState extends State<AnimatedBrandingOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    if (widget.autoPlay) {
      _startAnimation();
    }
  }

  @override
  void didUpdateWidget(AnimatedBrandingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.template.animation != widget.template.animation) {
      _controller.dispose();
      _setupAnimations();
      if (widget.autoPlay) {
        _startAnimation();
      }
    }
  }

  void _setupAnimations() {
    final duration = widget.template.duration;

    _controller = AnimationController(duration: duration, vsync: this);

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onAnimationComplete?.call();
      }
    });

    // Setup animations based on type
    switch (widget.template.animation) {
      case AnimationType.fadeIn:
      case AnimationType.slideUpFade:
        _fadeAnimation = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
        _slideAnimation = const AlwaysStoppedAnimation(Offset.zero);
        _rotateAnimation = const AlwaysStoppedAnimation(0.0);
        break;

      case AnimationType.slideFromRight:
        // Slide from right (off-screen) to center
        _fadeAnimation = const AlwaysStoppedAnimation(1.0);
        _slideAnimation =
            Tween<Offset>(
              begin: const Offset(1.5, 0.0), // Start off-screen to the right
              end: Offset.zero, // End at center
            ).animate(
              CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
            );
        _rotateAnimation = const AlwaysStoppedAnimation(0.0);
        break;

      case AnimationType.slideUp:
        _fadeAnimation = const AlwaysStoppedAnimation(1.0);
        _slideAnimation = Tween<Offset>(
          begin: const Offset(0.0, 1.0), // Start off-screen at bottom
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
        _rotateAnimation = const AlwaysStoppedAnimation(0.0);
        break;

      case AnimationType.revolve:
        _fadeAnimation = const AlwaysStoppedAnimation(1.0);
        _slideAnimation = const AlwaysStoppedAnimation(Offset.zero);
        _rotateAnimation = Tween<double>(begin: -0.1, end: 0.0).animate(
          CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
        );
        break;

      case AnimationType.static:
        _fadeAnimation = const AlwaysStoppedAnimation(1.0);
        _slideAnimation = const AlwaysStoppedAnimation(Offset.zero);
        _rotateAnimation = const AlwaysStoppedAnimation(0.0);
        break;
    }
  }

  void _startAnimation() {
    Future.delayed(widget.template.delay, () {
      if (mounted) {
        _controller.forward(from: 0.0);
      }
    });
  }

  /// Restart the animation - public method for external control
  void restartAnimation() {
    _controller.reset();
    _startAnimation();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        listenable: _controller,
        builder: (context, child) => FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: RotationTransition(turns: _rotateAnimation, child: child),
          ),
        ),
        child: _buildBrandingContent(),
      ),
    );
  }

  Widget _buildBrandingContent() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Circular Profile Photo
          Container(
            width: widget.template.photoSize,
            height: widget.template.photoSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child: widget.photoUrl != null
                  ? Image.network(
                      widget.photoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, e, s) => _buildPlaceholderPhoto(),
                    )
                  : _buildPlaceholderPhoto(),
            ),
          ),
          const SizedBox(height: 8),

          // Name Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              widget.template.userName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderPhoto() {
    return Container(
      color: Colors.grey[400],
      child: const Icon(Icons.person, color: Colors.white, size: 32),
    );
  }
}

/// Custom AnimatedBuilder that uses child optimization
class AnimatedBuilder extends StatelessWidget {
  final Listenable listenable;
  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;

  const AnimatedBuilder({
    super.key,
    required this.listenable,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: listenable,
      builder: (context, _) => builder(context, child),
      child: child,
    );
  }
}
