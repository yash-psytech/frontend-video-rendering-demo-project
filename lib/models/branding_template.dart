/// Animation types that can be applied to branding overlays.
/// These are designed to work both in Flutter UI and FFmpeg export.
enum AnimationType {
  /// Static overlay with no animation
  static,

  /// Fade in from transparent to opaque
  fadeIn,

  /// Slide up from bottom of screen
  slideUp,

  /// Combined slide up + fade in (Crafto-style)
  slideUpFade,

  /// Revolve animation
  revolve,

  /// Slide in from right to center (primary animation for photo and name)
  slideFromRight,
}

/// Template configuration for branding overlays.
/// This shared model drives both Flutter animations and FFmpeg export.
class BrandingTemplate {
  /// Type of animation to apply
  final AnimationType animation;

  /// Duration of the animation
  final Duration duration;

  /// Delay before animation starts
  final Duration delay;

  /// Photo X position (0.0 = left, 1.0 = right)
  final double photoX;

  /// Photo Y position (0.0 = top, 1.0 = bottom)
  final double photoY;

  /// Name text X position (0.0 = left, 1.0 = right)
  final double nameX;

  /// Name text Y position (0.0 = top, 1.0 = bottom)
  final double nameY;

  /// Size of the circular profile photo
  final double photoSize;

  /// User's display name
  final String userName;

  const BrandingTemplate({
    this.animation = AnimationType.slideUpFade,
    this.duration = const Duration(milliseconds: 500),
    this.delay = const Duration(milliseconds: 500),
    this.photoX = 0.5, // Center by default
    this.photoY = 0.85, // Near bottom
    this.nameX = 0.5, // Center by default
    this.nameY = 0.92, // Below photo
    this.photoSize = 60,
    this.userName = 'User Name',
  });

  /// Creates a copy with modified values
  BrandingTemplate copyWith({
    AnimationType? animation,
    Duration? duration,
    Duration? delay,
    double? photoX,
    double? photoY,
    double? nameX,
    double? nameY,
    double? photoSize,
    String? userName,
  }) {
    return BrandingTemplate(
      animation: animation ?? this.animation,
      duration: duration ?? this.duration,
      delay: delay ?? this.delay,
      photoX: photoX ?? this.photoX,
      photoY: photoY ?? this.photoY,
      nameX: nameX ?? this.nameX,
      nameY: nameY ?? this.nameY,
      photoSize: photoSize ?? this.photoSize,
      userName: userName ?? this.userName,
    );
  }

  /// Get delay in seconds for FFmpeg expressions
  double get delaySeconds => delay.inMilliseconds / 1000.0;

  /// Get duration in seconds for FFmpeg expressions
  double get durationSeconds => duration.inMilliseconds / 1000.0;

  /// Predefined template: Static bottom center
  static const BrandingTemplate staticBottomCenter = BrandingTemplate(
    animation: AnimationType.static,
    photoX: 0.5,
    photoY: 0.85,
    nameX: 0.5,
    nameY: 0.92,
  );

  /// Predefined template: Fade in bottom center
  static const BrandingTemplate fadeInBottomCenter = BrandingTemplate(
    animation: AnimationType.fadeIn,
    duration: Duration(milliseconds: 500),
    delay: Duration(milliseconds: 500),
  );

  /// Predefined template: Slide up (Crafto style)
  static const BrandingTemplate slideUpCrafto = BrandingTemplate(
    animation: AnimationType.slideUpFade,
    duration: Duration(milliseconds: 500),
    delay: Duration(milliseconds: 500),
  );

  /// Predefined template: Revolve animation
  static const BrandingTemplate revolve = BrandingTemplate(
    animation: AnimationType.revolve,
    userName: 'Praveen Kandula',
  );

  /// Predefined template: Slide from right (primary animation)
  static const BrandingTemplate slideFromRightTemplate = BrandingTemplate(
    animation: AnimationType.slideFromRight,
    duration: Duration(milliseconds: 1000),
    delay: Duration(milliseconds: 0),
  );
}
